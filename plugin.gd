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
		_dock_content.register_section(SectionScannerScript.section_id(section), section.title, control)

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
