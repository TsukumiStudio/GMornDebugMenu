extends Resource

## GMornDebugMenu のエディタドックへ差し込むセクションの基底。
##
## Unity版 `MornDebugMenuBase`（ScriptableObject派生を並べる仕組み）に相当する。
## これを継承したスクリプトを書いて `create_control()` をオーバーライドし、
## そのスクリプトを付けた `.tres` を `gmorn_debug_menu/section_dir`
## （既定 `res://assets/debug_sections/`）へ置くと、エディタに入るたびに
## `gmorn_debug_menu_section_scanner.gd` が列挙し、ドックへセクションとして
## 足す。コードは変えず `.tres` を足すだけで増える。手順は README.md の
## 「9. ドックへセクションを足す」を参照。
##
## `class_name` は付けない。付けるとエディタが一度走査するまで名前を引けず、
## 取り込んだ直後にヘッドレスで走らせると読み込みごと失敗する
## （`gmorn_debug_menu_settings.gd` と同じ理由）。派生側は
## `extends "res://addons/gmorn_debug_menu/gmorn_debug_menu_section.gd"` と書く。

## ドックの見出しに出す名前。
@export var title: String = ""

## `register_section()` に渡す id。空なら `gmorn_debug_menu_section_scanner.gd`
## がファイル名から作る。同じ置き場に複数の `.tres` を並べるとき、ファイル名が
## 被らなければ指定しなくてよい。
@export var section_id: StringName = &""

## セクションの中身を作って返す。派生側で必ずオーバーライドする。
func create_control() -> Control:
	push_error("GMornDebugMenuSection.create_control() がオーバーライドされていない: %s" % resource_path)
	return null
