@tool
extends EditorPlugin

## GMornDebugMenu を組み込むための入口。
##
## 板はどの場面でも同じ隅に居てほしいので、自動読み込みに登録する。
## 実行中の項目をエディタから見て操れるように、デバッガパネルも足す。

const AUTOLOAD_NAME := "GMornDebugMenu"
const DebuggerPluginScript := preload("gmorn_debug_menu_debugger_plugin.gd")

var _debugger_plugin: EditorDebuggerPlugin

## 置き場所を決め打ちにしない。submodule で好きな名前の場所へ入れられるように、
## 自分の居場所から辿る。
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_debug_menu.gd")

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())
	_debugger_plugin = DebuggerPluginScript.new()
	add_debugger_plugin(_debugger_plugin)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_debugger_plugin(_debugger_plugin)
	_debugger_plugin = null
