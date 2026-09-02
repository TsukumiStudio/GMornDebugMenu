extends EditorDebuggerPlugin

## デバッガパネル側の入口。
##
## 合言葉 `gmorn_debug_menu` で始まる知らせだけを受け取り、セッションごとの
## タブ (`gmorn_debug_menu_debugger_tab.gd`) へ渡す。仕様は README.md の
## 「リモート操作の仕組み」を参照。
##
## 独立ウィンドウ (`gmorn_debug_menu_window.gd`) も同じ入口を通す。窓は
## `bind_window()` で登録するだけで、繋ぐ先のセッションはここが選ぶ
## （動いているセッションへ繋ぎ、止まれば他に動いているものへ繋ぎ直す）。

const CAPTURE_NAME := "gmorn_debug_menu"
const TabScript := preload("gmorn_debug_menu_debugger_tab.gd")

## セッションごとのタブ。`session_id (int) -> Control`。
var _tabs: Dictionary = {}

## 独立ウィンドウの中身。開いていなければ `null`。
var _window_content: Control
## いま `_window_content` が繋がっているセッションの id。繋いでいなければ -1。
var _window_session_id: int = -1

func _has_capture(capture: String) -> bool:
	return capture == CAPTURE_NAME

func _setup_session(session_id: int) -> void:
	var session := get_session(session_id)
	var tab: Control = TabScript.new()
	tab.name = "GMornDebugMenu"
	tab.setup(session)
	session.add_session_tab(tab)
	_tabs[session_id] = tab
	# 実行が始まるたびに、そのときの項目一覧を貰い直す。
	session.started.connect(tab.request_sync)
	session.stopped.connect(_on_session_stopped.bind(session_id))
	# ウィンドウがまだどこにも繋がっていなければ、ここへ繋ぐ。
	if _window_content != null and _window_session_id == -1:
		_attach_window_to_session(session_id)

func _capture(message: String, data: Array, session_id: int) -> bool:
	if not message.begins_with(CAPTURE_NAME + ":"):
		return false
	var tab: Control = _tabs.get(session_id)
	if tab != null:
		tab.handle_message(message, data)
	if _window_content != null and _window_session_id == session_id:
		_window_content.handle_message(message, data)
	return true

## 独立ウィンドウの中身を登録する。今すでに動いているセッションがあれば、
## すぐそこへ繋ぐ。無ければ未接続のまま。
func bind_window(content: Control) -> void:
	_window_content = content
	var active_id := _find_active_session_id()
	if active_id != -1:
		_attach_window_to_session(active_id)
	else:
		content.set_session(null)

## 独立ウィンドウを閉じる（作り直す）ときに呼ぶ。
func unbind_window() -> void:
	_window_content = null
	_window_session_id = -1

func _find_active_session_id() -> int:
	for session_id: int in _tabs.keys():
		var session := get_session(session_id)
		if session != null and session.is_active():
			return session_id
	return -1

func _attach_window_to_session(session_id: int) -> void:
	_window_session_id = session_id
	_window_content.set_session(get_session(session_id))
	_window_content.request_sync()

func _on_session_stopped(session_id: int) -> void:
	if _window_session_id != session_id:
		return
	var next_id := _find_active_session_id()
	if next_id != -1:
		_attach_window_to_session(next_id)
	else:
		_window_session_id = -1
		if _window_content != null:
			_window_content.on_session_stopped()
