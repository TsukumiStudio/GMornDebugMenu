extends VBoxContainer

## デバッガパネルの中身。項目一覧を描き、監視値の知らせで更新表示し、
## 釦・つまみ・選び・入り切りの操作をランタイムへ送る。ランタイム側は
## `gmorn_debug_menu.gd` の `_bridge_*`。
##
## デバッガパネルのタブ (`gmorn_debug_menu_debugger_plugin.gd` が作る) と、
## 独立ウィンドウ (`gmorn_debug_menu_window.gd` が作る) の両方から使う。
## ウィンドウ側はセッションが無い状態でも開けるため、`session` は無くてよい。

const DISCONNECTED_STATUS := "実行中プロセスなし"

var _session: EditorDebuggerSession
var _list: VBoxContainer
var _status_label: Label
## 監視値を映す行。`id (int) -> {kind, control}`。
var _rows: Dictionary = {}

func setup(session: EditorDebuggerSession = null) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	add_child(HSeparator.new())
	_status_label = Label.new()
	add_child(_status_label)
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
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	for item: Dictionary in items:
		_add_row(item)

func _add_row(item: Dictionary) -> void:
	var id: int = item.get("id", -1)
	var kind: String = item.get("kind", "")
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = String(item.get("label", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	match kind:
		"button":
			var button := Button.new()
			button.text = "実行"
			button.pressed.connect(func() -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:invoke", [id]))
			row.add_child(button)
		"toggle":
			var check := CheckButton.new()
			check.button_pressed = bool(item.get("value", false))
			check.toggled.connect(func(value: bool) -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:set_value", [id, value]))
			row.add_child(check)
			_rows[id] = {"kind": kind, "control": check}
		"option":
			var option := OptionButton.new()
			for text: String in item.get("options", PackedStringArray()):
				option.add_item(text)
			option.selected = int(item.get("value", 0))
			option.item_selected.connect(func(index: int) -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:set_value", [id, index]))
			row.add_child(option)
			_rows[id] = {"kind": kind, "control": option}
		"number", "slider":
			var value_label := Label.new()
			value_label.text = str(item.get("value", ""))
			value_label.custom_minimum_size = Vector2(72.0, 0.0)
			row.add_child(value_label)
			var spin := SpinBox.new()
			spin.min_value = -99999999.0
			spin.max_value = 99999999.0
			spin.value = float(item.get("value", 0.0))
			row.add_child(spin)
			var apply := Button.new()
			apply.text = "送る"
			apply.pressed.connect(func() -> void:
				if _session != null:
					_session.send_message("gmorn_debug_menu:set_value", [id, spin.value]))
			row.add_child(apply)
			_rows[id] = {"kind": kind, "control": value_label}
		"label":
			var value_label := Label.new()
			value_label.text = str(item.get("value", ""))
			row.add_child(value_label)
			_rows[id] = {"kind": kind, "control": value_label}
		_:
			pass
	_list.add_child(row)

func _update_value(id: int, value: Variant) -> void:
	if not _rows.has(id):
		return
	var info: Dictionary = _rows[id]
	var control: Control = info.control
	match info.kind:
		"toggle":
			(control as CheckButton).set_pressed_no_signal(bool(value))
		"option":
			(control as OptionButton).select(int(value))
		"number", "slider", "label":
			(control as Label).text = str(value)
