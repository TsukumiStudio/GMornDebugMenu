extends VBoxContainer

## エディタドックの中身。セクション（タイトル+Control）を縦に並べる。

const SECTION_BOX := preload("gmorn_debug_menu_section_box.tscn")

## `id (StringName) -> {panel: PanelContainer, container: VBoxContainer, header: Button, control: Control}`
var _sections: Dictionary = {}
var _list: VBoxContainer

func setup() -> void:
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_list)

## 同じ `id` があれば外してから差し替えるので、並び順は最後尾へ移る。
func register_section(id: StringName, title: String, control: Control, hide_when_playing := false) -> void:
	if _sections.has(id):
		unregister_section(id)
	var panel: PanelContainer = SECTION_BOX.instantiate()
	var container: VBoxContainer = panel.get_node("Content")
	var header: Button = container.get_node("Header")
	header.toggled.connect(func(expanded: bool) -> void:
		control.visible = expanded
		panel.size_flags_vertical = control.size_flags_vertical if expanded else Control.SIZE_FILL
		header.text = ("▼  " if expanded else "▶  ") + title
		header.tooltip_text = "クリックで閉じる" if expanded else "クリックで開く"
	)
	control.size_flags_changed.connect(func() -> void:
		if is_instance_valid(panel):
			panel.size_flags_vertical = control.size_flags_vertical if header.button_pressed else Control.SIZE_FILL
	)
	container.add_child(control)
	_list.add_child(panel)
	header.button_pressed = true
	_sections[id] = {"panel": panel, "container": container, "header": header, "control": control, "hide_when_playing": hide_when_playing}

## `control` は呼び出し側が作った物なので消さず、木から外すだけ。
func unregister_section(id: StringName) -> void:
	if not _sections.has(id):
		return
	var section: Dictionary = _sections[id]
	var container: VBoxContainer = section.container
	var control: Control = section.control
	container.remove_child(control)
	_list.remove_child(section.panel)
	section.panel.queue_free()
	_sections.erase(id)

func has_section(id: StringName) -> bool:
	return _sections.has(id)

func section_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _sections.keys():
		ids.append(id)
	return ids

## 見出しの開閉状態は変えない。
func set_playing(playing: bool) -> void:
	for section: Dictionary in _sections.values():
		section.panel.visible = not (playing and section.hide_when_playing)
