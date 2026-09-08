extends VBoxContainer

## エディタドックの中身。複数のセクション（タイトル+Control）を縦に並べる。
##
## 他のアドオンやプロジェクトが `register_section()` で自分のセクションを差し込める。
## 既存の実行中プロセス連携UI (`gmorn_debug_menu_debugger_tab.gd`) も `plugin.gd` が
## 1つの既定セクションとしてここへ載せている。使い方は README.md の
## 「9. ドックへセクションを足す」を参照。

const SECTION_BOX := preload("gmorn_debug_menu_section_box.tscn")

## `id (StringName) -> {panel: PanelContainer, container: VBoxContainer, header: Button, control: Control}`
var _sections: Dictionary = {}
var _list: VBoxContainer

func setup() -> void:
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_list)

## セクションを登録する。同じ `id` が既にあれば、先に外してから差し替える
## （**並び順は最後尾へ移る**。差し替えても元の位置を保ちたい場合は、
## 呼び出し側で `register_section()` を呼ぶ順を保つこと）。
## `control` は縦に並ぶ最後尾へ足す。見出しの釦は折りたたみも兼ねる。
func register_section(id: StringName, title: String, control: Control) -> void:
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
	_sections[id] = {"panel": panel, "container": container, "header": header, "control": control}

## `register_section()` で足したセクションを外す。渡された `control` 自体は消さず、
## 木から外すだけに留める。呼び出し側が作った物なので、後始末は呼び出し側に委ねる。
## 登録されていない `id` を渡しても何もしない。
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

## 登録済みか。
func has_section(id: StringName) -> bool:
	return _sections.has(id)

## いま並んでいるセクションの `id` を、登録順で返す。
func section_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _sections.keys():
		ids.append(id)
	return ids
