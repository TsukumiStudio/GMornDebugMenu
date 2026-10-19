extends Resource

## ドックへ差し込むセクションの基底。継承して `create_control()` を上書きし、
## `.tres` を `gmorn_debug_menu/section_dir` へ置くと scanner が拾う。
##
## `class_name` は付けない（`gmorn_debug_menu_settings.gd` と同じ理由）。派生側は
## `extends "res://addons/gmorn_debug_menu/gmorn_debug_menu_section.gd"` と書く。

@export var title: String = ""

## 空なら scanner がファイル名から作る。
@export var section_id: StringName = &""

## 再生中は見出しごと隠す。
@export var hide_when_playing := false

## 派生側で必ず上書きする。
func create_control() -> Control:
	push_error("GMornDebugMenuSection.create_control() がオーバーライドされていない: %s" % resource_path)
	return null
