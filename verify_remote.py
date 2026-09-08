#!/usr/bin/env python3
"""ヘッドレスEditorとゲームを接続し、2回の実行でドックの釦が届くか確認する。"""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time

ADDON = Path(__file__).resolve().parent
GODOT = os.environ.get("GODOT_BIN", shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot")

PROBE = '''@tool
extends EditorPlugin

var invoked := false

func _enter_tree() -> void:
	EditorInterface.get_editor_settings().set_setting("network/debug/remote_port", int(OS.get_environment("GMORN_REMOTE_PORT")))
	_run.call_deferred()

func _run() -> void:
	while not Engine.has_meta(&"gmorn_debug_menu_dock"):
		await get_tree().process_frame
	var dock = Engine.get_meta(&"gmorn_debug_menu_dock")
	var tab = dock._sections[&"process"].control
	for index in range(2):
		invoked = false
		EditorInterface.play_custom_scene("res://client.tscn")
		var deadline := Time.get_ticks_msec() + 10000
		while not FileAccess.file_exists("res://invoked") and Time.get_ticks_msec() < deadline:
			if not invoked and tab._session != null and tab._session.is_active():
				if not tab._items.is_empty() and not tab._expanded.get("検証/操作", false):
					tab._expanded["検証"] = true
					tab._toggle_folder("検証/操作")
				for label in tab._list.find_children("Name", "Label", true, false):
					var row = label.get_parent()
					if label.text == "remote_probe" and row.size.y > 0 and tab._list.get_parent().size.y >= row.size.y:
						invoked = true
						row.get_node("Actions/Action").pressed.emit()
			await get_tree().process_frame
		EditorInterface.stop_playing_scene()
		if not FileAccess.file_exists("res://invoked"):
			_finish("FAIL: %d回目のドック操作がゲームへ届かない session=%s rows=%d" % [index + 1, tab._session, tab._list.get_child_count()])
			return
		DirAccess.remove_absolute("res://invoked")
		deadline = Time.get_ticks_msec() + 5000
		while tab._session != null and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if tab._session != null:
			_finish("FAIL: 停止後にドックが切断されない")
			return
		print("実行%d: 接続・操作送信・停止後の切断 OK" % (index + 1))
	_finish("GMORN REMOTE VERIFY: PASS")

func _finish(result: String) -> void:
	FileAccess.open("res://result.txt", FileAccess.WRITE).store_string(result)
'''
CLIENT = '''extends Node

func _ready() -> void:
	get_node("/root/GMornDebugMenu").set_category("検証/操作")
	get_node("/root/GMornDebugMenu").add_button("remote_probe", func() -> void:
		FileAccess.open("res://invoked", FileAccess.WRITE).store_string("ok")
	)
'''


def run():
    with tempfile.TemporaryDirectory(prefix="gmorn-remote-") as temporary:
        work = Path(temporary)
        addon = work / "addons/gmorn_debug_menu"
        addon.mkdir(parents=True)
        for source in ADDON.iterdir():
            if source.suffix in (".gd", ".tscn", ".cfg"):
                shutil.copy2(source, addon / source.name)
        probe = work / "addons/probe"
        probe.mkdir()
        (probe / "plugin.cfg").write_text('[plugin]\nname="Probe"\ndescription="検証"\nauthor=""\nversion="1"\nscript="probe.gd"\n')
        (probe / "probe.gd").write_text(PROBE)
        (work / "client.gd").write_text(CLIENT)
        (work / "client.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://client.gd" id="1"]\n[node name="Client" type="Node"]\nscript=ExtResource("1")\n')
        (work / "project.godot").write_text('''config_version=5
[application]
config/name="GMorn Remote Verify"
[autoload]
GMornDebugMenu="*res://addons/gmorn_debug_menu/gmorn_debug_menu.gd"
[editor]
run/main_run_args="--headless --ignore-error-breaks"
[editor_plugins]
enabled=PackedStringArray("res://addons/gmorn_debug_menu/plugin.cfg", "res://addons/probe/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
''')
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            address = f"tcp://127.0.0.1:{listener.getsockname()[1]}"
        # 実際のプロジェクトやユーザーの保存・Editor設定へ触れない。
        environment = dict(os.environ, HOME=str(work / "home"), XDG_DATA_HOME=str(work / "data"), XDG_CONFIG_HOME=str(work / "config"), GMORN_REMOTE_PORT=address.rsplit(":", 1)[1])
        base = [GODOT, "--headless", "--path", str(work)]
        project = work / "project.godot"
        project.write_text(project.read_text().replace("--headless --ignore-error-breaks", f"--headless --ignore-error-breaks --remote-debug {address}"))
        with (work / "editor.log").open("w") as log:
            editor = subprocess.Popen(base + ["--editor", "--debug-server", address], stdout=log, stderr=subprocess.STDOUT, env=environment)
            try:
                result = work / "result.txt"
                deadline = time.monotonic() + 35
                while not result.exists():
                    if editor.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("デバッガ検証が完了しない")
                    time.sleep(0.05)
                outcome = result.read_text()
                if "PASS" not in outcome:
                    raise RuntimeError(outcome)
                print(outcome)
            except Exception:
                print((work / "editor.log").read_text())
                raise
            finally:
                editor.terminate()
                try:
                    editor.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    editor.kill()
                    editor.wait()


if __name__ == "__main__":
    run()
