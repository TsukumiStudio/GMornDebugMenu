extends EditorDebuggerPlugin

## デバッガパネル側の入口。セッションごとのタブとドックへ知らせを渡す。
## ドックが繋ぐセッションはここが選ぶ（止まれば他に動いているものへ繋ぎ直す）。

const CAPTURE_NAME := "gmorn_debug_menu"
const TabScript := preload("gmorn_debug_menu_debugger_tab.gd")

## `session_id -> Control`。
var _tabs: Dictionary = {}

var _dock_content: Control
## 繋いでいなければ -1。
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
	session.started.connect(_on_session_started.bind(session_id))
	session.stopped.connect(_on_session_stopped.bind(session_id))
	if session.is_active():
		_on_session_started(session_id)

## セッションは再実行で再利用されるので、生成時ではなく開始通知ごとに接続する。
func _on_session_started(session_id: int) -> void:
	var tab: Control = _tabs[session_id]
	tab.set_session(get_session(session_id))
	tab.request_sync()
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

func bind_dock(content: Control) -> void:
	_dock_content = content
	var active_id := _find_active_session_id()
	if active_id != -1:
		_attach_dock_to_session(active_id)
	else:
		_dock_session_id = -1
		content.set_session(null)

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
	_tabs[session_id].on_session_stopped()
	if _dock_session_id != session_id:
		return
	var next_id := _find_active_session_id()
	if next_id != -1:
		_attach_dock_to_session(next_id)
	else:
		_dock_session_id = -1
		if _dock_content != null:
			_dock_content.on_session_stopped()
