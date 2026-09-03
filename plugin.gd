@tool
extends EditorPlugin

## GMornDebugMenu を組み込むための入口。
##
## 板はどの場面でも同じ隅に居てほしいので、自動読み込みに登録する。
## 実行中の項目をエディタから見て操れるように、デバッガパネルとドックを足す。

const AUTOLOAD_NAME := "GMornDebugMenu"
const DebuggerPluginScript := preload("gmorn_debug_menu_debugger_plugin.gd")
const TabScript := preload("gmorn_debug_menu_debugger_tab.gd")

var _debugger_plugin: EditorDebuggerPlugin
## エディタに常時表示するドック。中身は `gmorn_debug_menu_debugger_tab.gd` を使い回す。
var _dock: EditorDock
var _dock_content: Control

## 置き場所を決め打ちにしない。submodule で好きな名前の場所へ入れられるように、
## 自分の居場所から辿る。
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_debug_menu.gd")

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())
	_debugger_plugin = DebuggerPluginScript.new()
	add_debugger_plugin(_debugger_plugin)
	_dock_content = TabScript.new()
	_dock_content.setup()
	_dock = EditorDock.new()
	_dock.name = AUTOLOAD_NAME
	_dock.title = AUTOLOAD_NAME
	_dock.layout_key = "kimekyawa_gmorn_debug_menu"
	_dock.icon_name = &"Debug"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UR
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_dock.add_child(_dock_content)
	add_dock(_dock)
	_debugger_plugin.bind_dock(_dock_content)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_debugger_plugin(_debugger_plugin)
	_debugger_plugin.unbind_dock()
	_debugger_plugin = null
	remove_dock(_dock)
	_dock.queue_free()
	_dock = null
	_dock_content = null
