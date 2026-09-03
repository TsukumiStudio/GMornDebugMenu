extends EditorDebuggerPlugin

## デバッガパネル側の入口。
##
## 合言葉 `gmorn_debug_menu` で始まる知らせだけを受け取り、セッションごとの
## タブ (`gmorn_debug_menu_debugger_tab.gd`) へ渡す。仕様は README.md の
## 「リモート操作の仕組み」を参照。
##
## エディタ常時表示のドック (`plugin.gd` が `add_dock()` で足す) も同じ入口を
## 通す。ドックは `bind_dock()` で登録するだけで、繋ぐ先のセッションはここが選ぶ
## （動いているセッションへ繋ぎ、止まれば他に動いているものへ繋ぎ直す）。

const CAPTURE_NAME := "gmorn_debug_menu"
const TabScript := preload("gmorn_debug_menu_debugger_tab.gd")

## セッションごとのタブ。`session_id (int) -> Control`。
var _tabs: Dictionary = {}

## ドックの中身。登録されていなければ `null`。
var _dock_content: Control
## いま `_dock_content` が繋がっているセッションの id。繋いでいなければ -1。
var _dock_session_id: int = -1

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
	# ドックがまだどこにも繋がっていなければ、ここへ繋ぐ。
	if _dock_content != null and _dock_session_id == -1:
		_attach_dock_to_session(session_id)

func _capture(message: String, data: Array, session_id: int) -> bool:
	if not message.begins_with(CAPTURE_NAME + ":"):
		return false
	var tab: Control = _tabs.get(session_id)
	if tab != null:
		tab.handle_message(message, data)
	if _dock_content != null and _dock_session_id == session_id:
		_dock_content.handle_message(message, data)
	return true

## エディタ常時表示ドックの中身を登録する。今すでに動いているセッションがあれば、
## すぐそこへ繋ぐ。無ければ未接続のまま。
func bind_dock(content: Control) -> void:
	_dock_content = content
	var active_id := _find_active_session_id()
	if active_id != -1:
		_attach_dock_to_session(active_id)
	else:
		content.set_session(null)

## プラグインを外す（`_exit_tree()`）ときに呼ぶ。
func unbind_dock() -> void:
	_dock_content = null
	_dock_session_id = -1

func _find_active_session_id() -> int:
	for session_id: int in _tabs.keys():
		var session := get_session(session_id)
		if session != null and session.is_active():
			return session_id
	return -1

func _attach_dock_to_session(session_id: int) -> void:
	_dock_session_id = session_id
	_dock_content.set_session(get_session(session_id))
	_dock_content.request_sync()

func _on_session_stopped(session_id: int) -> void:
	if _dock_session_id != session_id:
		return
	var next_id := _find_active_session_id()
	if next_id != -1:
		_attach_dock_to_session(next_id)
	else:
		_dock_session_id = -1
		if _dock_content != null:
			_dock_content.on_session_stopped()
