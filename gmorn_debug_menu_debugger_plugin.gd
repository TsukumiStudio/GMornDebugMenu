extends EditorDebuggerPlugin

## デバッガパネル側の入口。
##
## 合言葉 `gmorn_debug_menu` で始まる知らせだけを受け取り、セッションごとの
## タブ (`gmorn_debug_menu_debugger_tab.gd`) へ渡す。仕様は README.md の
## 「リモート操作の仕組み」を参照。

const CAPTURE_NAME := "gmorn_debug_menu"
const TabScript := preload("gmorn_debug_menu_debugger_tab.gd")

## セッションごとのタブ。`session_id (int) -> Control`。
var _tabs: Dictionary = {}

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

func _capture(message: String, data: Array, session_id: int) -> bool:
	if not message.begins_with(CAPTURE_NAME + ":"):
		return false
	var tab: Control = _tabs.get(session_id)
	if tab != null:
		tab.handle_message(message, data)
	return true
