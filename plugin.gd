@tool
extends EditorPlugin

## GMornDebugMenu を組み込むための入口。
##
## 板はどの場面でも同じ隅に居てほしいので、自動読み込みに登録する。
## 実行中の項目をエディタから見て操れるように、デバッガパネルも足す。

const AUTOLOAD_NAME := "GMornDebugMenu"
const DebuggerPluginScript := preload("gmorn_debug_menu_debugger_plugin.gd")
const WindowScene := preload("gmorn_debug_menu_window.tscn")

var _debugger_plugin: EditorDebuggerPlugin
## メニューから開く独立ウィンドウ。閉じても作り直さず、隠すだけにする。
var _window: Window

## 置き場所を決め打ちにしない。submodule で好きな名前の場所へ入れられるように、
## 自分の居場所から辿る。
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_debug_menu.gd")

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())
	_debugger_plugin = DebuggerPluginScript.new()
	add_debugger_plugin(_debugger_plugin)
	add_tool_menu_item(AUTOLOAD_NAME, _open_window)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_debugger_plugin(_debugger_plugin)
	_debugger_plugin = null
	remove_tool_menu_item(AUTOLOAD_NAME)
	if _window != null:
		_window.queue_free()
		_window = null

## エディタメニューの『GMornDebugMenu』から呼ばれる。
func _open_window() -> void:
	if _window == null:
		_window = WindowScene.instantiate() as Window
		EditorInterface.get_base_control().add_child(_window)
		_window.setup(_debugger_plugin)
	_window.open_window()
