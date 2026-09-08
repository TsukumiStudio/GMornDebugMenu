extends SceneTree

const Tab := preload("gmorn_debug_menu_debugger_tab.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tab := Tab.new()
	root.add_child(tab)
	tab.setup()
	var items := [
		{"id": 0, "kind": "button", "label": "未分類"},
		{"id": 1, "kind": "number", "label": "とても長い名前の現在のお金を編集する項目", "value": 12345678, "category": "経済/お金", "minimum": 0, "maximum": 99999999, "step": 1},
		{"id": 2, "kind": "option", "label": "ノベル", "value": 0, "options": ["とても長い選択肢の名前が右にはみ出さず表示される"], "category": "ノベル"},
		{"id": 3, "kind": "label", "label": "", "value": "長い状況説明を表示します。長い状況説明を表示します。", "category": "経済/お金"},
	]
	tab.handle_message("gmorn_debug_menu:sync", [items])
	assert(tab._list.get_child_count() == 3)
	tab._list.get_child(0).get_node("Actions/Action").pressed.emit()
	assert(tab._expanded.get("経済", false))
	tab._list.get_child(1).get_node("Rows").get_child(0).get_node("Actions/Action").pressed.emit()
	assert(tab._rows.has(1))
	assert(tab._list.get_child_count() == 4, "兄弟フォルダーや未分類が消えた")
	tab.handle_message("gmorn_debug_menu:sync", [items])
	assert(tab._rows.has(1), "再同期で折りたたまれた")
	tab._toggle_folder("経済")
	assert(not tab._rows.has(1))
	tab.handle_message("gmorn_debug_menu:value", [1, 98765432])
	tab._toggle_folder("経済")
	assert(tab._rows[1].control.text == "現在: 98765432")
	tab._toggle_folder("ノベル")
	assert(tab._rows.has(1) and tab._rows.has(2), "複数フォルダーを同時に開けない")
	for width: float in [240.0, 320.0, 520.0]:
		tab.size = Vector2(width, 800.0)
		for frame in range(5):
			await process_frame
		assert(tab.size.x <= width + 1.0)
		_check_width(tab, tab.get_global_rect())
		assert(tab._rows[1].control.global_position.x >= tab._list.global_position.x + 32, "子項目がインデントされていない")
		assert(not tab._browser.get_node("Scroll").get_h_scroll_bar().visible)
	tab.on_session_stopped()
	assert(tab._list.get_child_count() == 0)
	assert(tab._expanded.is_empty())
	tab.free()
	print("GMORN BROWSER VERIFY: PASS")
	quit()

func _check_width(node: Node, bounds: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		assert(rect.position.x >= bounds.position.x - 1.0, "左にはみ出す: " + str(node.get_path()))
		assert(rect.end.x <= bounds.end.x + 1.0, "右にはみ出す: " + str(node.get_path()))
	for child in node.get_children():
		_check_width(child, bounds)
