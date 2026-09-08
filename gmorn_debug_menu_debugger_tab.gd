extends VBoxContainer

## デバッガパネルの中身。項目一覧を描き、監視値の知らせで更新表示し、
## 釦・つまみ・選び・入り切りの操作をランタイムへ送る。ランタイム側は
## `gmorn_debug_menu.gd` の `_bridge_*`。
##
## デバッガパネルのタブ (`gmorn_debug_menu_debugger_plugin.gd` が作る) と、
## エディタ常時表示のドック (`plugin.gd` が作る) の両方から使う。
## ドック側はセッションが無い状態でも表示するため、`session` は無くてよい。

const DISCONNECTED_STATUS := "実行中プロセスなし"

var _session: EditorDebuggerSession
var _list: VBoxContainer
var _status_label: Label
## 監視値を映す行。`id (int) -> {kind, control}`。
var _rows: Dictionary = {}

const BROWSER := preload("gmorn_debug_menu_browser.tscn")
const ROW := preload("gmorn_debug_menu_remote_row.tscn")
var _items: Array = []
const BRANCH := preload("gmorn_debug_menu_branch.tscn")
var _expanded: Dictionary = {}
var _browser: Control

func setup(session: EditorDebuggerSession = null) -> void:
	_browser = BROWSER.instantiate()
	add_child(_browser)
	_list = _browser.get_node("Scroll/Rows")
	_status_label = _browser.get_node("Status")
	set_session(session)

## 繋ぐセッションを差し替える。`null` なら未接続として表示する。
func set_session(session: EditorDebuggerSession) -> void:
	_session = session
	if _session == null:
		_rebuild([])
		_status_label.text = DISCONNECTED_STATUS
	else:
		_status_label.text = ""

## 繋いでいたセッションが止まったときに呼ぶ。一覧を空にし、未接続の旨を表示する。
func on_session_stopped() -> void:
	set_session(null)

## 実行が始まったとき、いまの項目一覧を貰い直す。
func request_sync() -> void:
	if _session != null:
		_session.send_message("gmorn_debug_menu:sync_request")

## `gmorn_debug_menu_debugger_plugin.gd` の `_capture()` から渡される。
func handle_message(message: String, data: Array) -> void:
	match message:
		"gmorn_debug_menu:sync":
			_rebuild(data[0] if data.size() >= 1 else [])
		"gmorn_debug_menu:value":
			if data.size() >= 2:
				_update_value(int(data[0]), data[1])
		"gmorn_debug_menu:status":
			if data.size() >= 1:
				_status_label.text = String(data[0])
		"gmorn_debug_menu:clear":
			_rebuild([])

func _rebuild(items: Array) -> void:
	size_flags_vertical = Control.SIZE_FILL if items.is_empty() else Control.SIZE_EXPAND_FILL
	_items = items
	if items.is_empty():
		_expanded.clear()
	_render_items()

func _toggle_folder(path: String) -> void:
	_expanded[path] = not _expanded.get(path, false)
	_render_items()

func _render_items() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_render_branch("", _list)

func _render_branch(path: String, parent: VBoxContainer) -> void:
	var folders: Dictionary = {}
	for item: Dictionary in _items:
		var category := String(item.get("category", ""))
		if category == path:
			continue
		if not path.is_empty() and not category.begins_with(path + "/"):
			continue
		var relative := category if path.is_empty() else category.substr(path.length() + 1)
		var folder := relative.get_slice("/", 0)
		if folder.is_empty() or folders.has(folder):
			continue
		folders[folder] = true
		var destination := folder if path.is_empty() else path + "/" + folder
		var expanded: bool = _expanded.get(destination, false)
		var row: Control = ROW.instantiate()
		_prepare_row(row)
		row.get_node("Name").hide()
		var button: Button = row.get_node("Actions/Action")
		button.text = ("▾  " if expanded else "▸  ") + folder
		button.tooltip_text = folder + (" を閉じる" if expanded else " を開く")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if has_theme_icon("Folder", "EditorIcons"):
			button.icon = get_theme_icon("Folder", "EditorIcons")
		button.show()
		button.pressed.connect(_toggle_folder.bind(destination))
		parent.add_child(row)
		if expanded:
			var branch := BRANCH.instantiate()
			parent.add_child(branch)
			_render_branch(destination, branch.get_node("Rows"))
	var groups: Dictionary = {}
	for item: Dictionary in _items:
		if String(item.get("category", "")) == path:
			var group := String(item.get("row_group", ""))
			if group.is_empty():
				_add_row(item, parent)
			else:
				if not groups.has(group):
					groups[group] = preload("gmorn_debug_menu_button_group.tscn").instantiate()
					parent.add_child(groups[group])
				_add_row(item, groups[group])

func _prepare_row(row: Control) -> void:
	row.get_node("Value").hide()
	for control in row.get_node("Actions").get_children():
		control.hide()

func _add_row(item: Dictionary, parent: Container) -> void:
	var id: int = item.get("id", -1)
	var kind: String = item.get("kind", "")
	var row: Control = ROW.instantiate()
	_prepare_row(row)
	var name_label: Label = row.get_node("Name")
	name_label.text = String(item.get("label", ""))
	name_label.visible = not name_label.text.is_empty()
	var button: Button = row.get_node("Actions/Action")
	var value_label: Label = row.get_node("Value")
	match kind:
		"button":
			name_label.hide()
			button.text = name_label.text
			button.tooltip_text = name_label.text
			button.show()
			button.pressed.connect(func() -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:invoke", [id]))
		"toggle":
			var check: CheckButton = row.get_node("Actions/Toggle")
			check.show()
			check.button_pressed = bool(item.get("value", false))
			check.toggled.connect(func(value: bool) -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:set_value", [id, value]))
			_rows[id] = {"kind": kind, "control": check}
		"option":
			var option: OptionButton = row.get_node("Actions/Option")
			option.show()
			for text: String in item.get("options", PackedStringArray()):
				option.add_item(text)
			option.selected = int(item.get("value", 0))
			option.item_selected.connect(func(index: int) -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:set_value", [id, index]))
			_rows[id] = {"kind": kind, "control": option}
		"number", "slider":
			value_label.show()
			value_label.text = "現在: " + str(item.get("value", ""))
			var spin: SpinBox = row.get_node("Actions/Spin")
			spin.show()
			spin.min_value = float(item.get("minimum", -99999999.0))
			spin.max_value = float(item.get("maximum", 99999999.0))
			spin.step = float(item.get("step", 1.0))
			spin.value = float(item.get("value", 0.0))
			button.show()
			button.text = "設定"
			button.clip_text = false
			button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			button.size_flags_horizontal = Control.SIZE_FILL
			button.pressed.connect(func() -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:set_value", [id, spin.value]))
			_rows[id] = {"kind": kind, "control": value_label}
		"label":
			name_label.hide()
			value_label.show()
			value_label.text = str(item.get("value", ""))
			_rows[id] = {"kind": kind, "control": value_label}
	parent.add_child(row)

func _update_value(id: int, value: Variant) -> void:
	for item: Dictionary in _items:
		if int(item.get("id", -1)) == id:
			item["value"] = value
			break
	if not _rows.has(id):
		return
	var info: Dictionary = _rows[id]
	var control: Control = info.control
	match info.kind:
		"toggle":
			(control as CheckButton).set_pressed_no_signal(bool(value))
		"option":
			(control as OptionButton).select(int(value))
		"number", "slider":
			(control as Label).text = "現在: " + str(value)
		"label":
			(control as Label).text = str(value)
