@tool
extends EditorPlugin

## GMornDebugMenu を組み込むための入口。
##
## 板はどの場面でも同じ隅に居てほしいので、自動読み込みに登録する。
## 実行中の項目をエディタから見て操れるように、デバッガパネルとドックを足す。

const AUTOLOAD_NAME := "GMornDebugMenu"
const DebuggerPluginScript := preload("gmorn_debug_menu_debugger_plugin.gd")
const TabScript := preload("gmorn_debug_menu_debugger_tab.gd")
const DockScript := preload("gmorn_debug_menu_dock.gd")
const SectionScannerScript := preload("gmorn_debug_menu_section_scanner.gd")

## 実行中プロセス連携UIを載せる既定セクションの id とタイトル。
const PROCESS_SECTION_ID := &"process"
const PROCESS_SECTION_TITLE := "実行中プロセス"

## 他アドオンが `Engine.get_meta(&"gmorn_debug_menu_dock")` でドックの中身
## (`gmorn_debug_menu_dock.gd` のインスタンス) を見つけるための鍵。
## README.md の「9. ドックへセクションを足す」を参照。
const DOCK_META_KEY := &"gmorn_debug_menu_dock"

var _debugger_plugin: EditorDebuggerPlugin
## エディタに常時表示するドック。中身は `gmorn_debug_menu_dock.gd` で、
## セクションを縦に並べる。実行中プロセス連携UIも1つのセクションとして載る。
var _dock: EditorDock
var _dock_content: Control
## 既定セクション（実行中プロセス連携UI）の中身。`gmorn_debug_menu_debugger_tab.gd`。
var _process_section: Control

## 置き場所を決め打ちにしない。submodule で好きな名前の場所へ入れられるように、
## 自分の居場所から辿る。
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_debug_menu.gd")

func _enter_tree() -> void:
	_register_settings()
	# 既に登録済みなら足さない。毎回足すとエディタの起動ごとに「自動読み込みを追加」の
	# 履歴が（アドオンの数だけ）並ぶ。project.godot に書いてあれば、それで動く。
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())
	_debugger_plugin = DebuggerPluginScript.new()
	add_debugger_plugin(_debugger_plugin)
	_dock_content = DockScript.new()
	_dock_content.setup()
	_process_section = TabScript.new()
	_process_section.setup()
	_dock_content.register_section(PROCESS_SECTION_ID, PROCESS_SECTION_TITLE, _process_section)
	_register_tres_sections()
	_dock = EditorDock.new()
	_dock.name = AUTOLOAD_NAME
	_dock.title = AUTOLOAD_NAME
	_dock.layout_key = "kimekyawa_gmorn_debug_menu"
	_dock.icon_name = &"Debug"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UR
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_dock.add_child(_dock_content)
	add_dock(_dock)
	_debugger_plugin.bind_dock(_process_section)
	Engine.set_meta(DOCK_META_KEY, _dock_content)

## `gmorn_debug_menu_section_scanner.gd` が見つけた `.tres` を、ドックへ
## セクションとして足す。`.tres` を足すだけで増える側で、既存の
## `register_section()` を直に呼ぶ側とは独立している（両方を同時に使ってよい）。
func _register_tres_sections() -> void:
	for section: Resource in SectionScannerScript.scan():
		var control: Control = section.create_control()
		if control == null:
			push_warning("セクションの中身が作られなかった: %s" % section.resource_path)
			continue
		_dock_content.register_section(SectionScannerScript.section_id(section), section.title, control, section.hide_when_playing)

func _process(_delta: float) -> void:
	if is_instance_valid(_dock_content):
		_dock_content.set_playing(EditorInterface.is_playing_scene())

func _exit_tree() -> void:
	Engine.remove_meta(DOCK_META_KEY)
	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_debugger_plugin(_debugger_plugin)
	_debugger_plugin.unbind_dock()
	_debugger_plugin = null
	remove_dock(_dock)
	_dock.queue_free()
	_dock = null
	_dock_content = null
	_process_section = null

## 設定の既定値と型をプロジェクト設定へ登録する。
##
## 登録が無いと「プロジェクト設定」画面で全項目に戻す印（回転の矢印）が付き、
## どれを変えたのか分からない。パスは選択の窓から、列挙は一覧から選べるようにする。
## 値は読む側（既定値）と同じにすること。読む側はここに依らず、無くても動く。
func _register_settings() -> void:
	# `section_dir` はドックの節（.tres）の置き場（gmorn_debug_menu_section_scanner.gd）。
	for row in [
		["enabled", true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
		["build_when_headless", false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
		["button_corner", "top_right", TYPE_STRING, PROPERTY_HINT_ENUM, "top_left,top_right,bottom_left,bottom_right"],
		["button_width", 40.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "8,400,1"],
		["button_height", 40.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "8,400,1"],
		["button_margin_x", 12.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,400,1"],
		["button_margin_y", 12.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,400,1"],
		["button_alpha", 0.82, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,1,0.01"],
		["panel_width", 420.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "100,4000,1"],
		["panel_height", 520.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "100,4000,1"],
		["panel_color", Color(0.055, 0.035, 0.09, 0.97), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
		["panel_border_color", Color(1.0, 0.3, 0.72, 1.0), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
		["font_path", "", TYPE_STRING, PROPERTY_HINT_FILE, "*.ttf,*.otf,*.woff,*.woff2,*.fnt,*.tres"],
		["font_size", 0, TYPE_INT, PROPERTY_HINT_RANGE, "0,200,1"],
		["volume_row", true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
		["volume_bus", "Master", TYPE_STRING, PROPERTY_HINT_NONE, ""],
		["volume_max", 2.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "1,10,0.1"],
		["volume_store", "user://gmorn_debug_menu.cfg", TYPE_STRING, PROPERTY_HINT_NONE, ""],
		["section_dir", "res://assets/debug_sections/", TYPE_STRING, PROPERTY_HINT_DIR, ""],
	]:
		var key: String = "gmorn_debug_menu/" + String(row[0])
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, row[1])
		ProjectSettings.set_initial_value(key, row[1])
		ProjectSettings.add_property_info({
			"name": key, "type": row[2], "hint": row[3], "hint_string": row[4],
		})
		ProjectSettings.set_as_basic(key, true)
