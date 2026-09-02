extends Window

## GMornDebugMenu の独立エディターウィンドウ。
##
## `plugin.gd` がエディタメニューから作る。中身は `gmorn_debug_menu_debugger_tab.gd`
## をそのまま使い回す（デバッガパネルのタブと同じ項目UI・監視値UI）。どのセッションへ
## 繋ぐかは `gmorn_debug_menu_debugger_plugin.gd` 側（`bind_window()`）が決める。
##
## `@tool` を付けない。エディタの中でノードを組み立てる部分（デバッガパネルの
## タブと同じ形）は、既存どおり `setup()` を明示的に呼ぶだけで済み、
## `_ready()` に頼らない。

var _debugger_plugin: EditorDebuggerPlugin

## `plugin.gd` がインスタンス化した直後に1度だけ呼ぶ。
func setup(debugger_plugin: EditorDebuggerPlugin) -> void:
	_debugger_plugin = debugger_plugin
	close_requested.connect(hide)
	%Content.setup()
	debugger_plugin.bind_window(%Content)

## メニューから押されるたびに呼ぶ。すでに開いていても手前へ出すだけでよい。
func open_window() -> void:
	show()
	grab_focus()
