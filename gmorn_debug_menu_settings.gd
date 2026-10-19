extends RefCounted

## `class_name` は付けない。エディタが一度走査するまで名前を引けず、取り込んだ
## 直後のヘッドレス実行で読み込みごと失敗する。使う側は `preload` で直に指す。

## 既定は有効。開発中だけの機能だと、配ったものに触ってもらったときに状況を作れない。
var enabled := true
## 板そのものを検証したいときだけ true。
var build_when_headless := false
var button_corner := "top_right"
var button_size := Vector2(40.0, 40.0)
## 同じ隅に別の釦（不具合報告など）があるときは縦にずらす。
var button_margin := Vector2(12.0, 12.0)
var button_alpha := 0.82
## 目安。中身に合わせて画面に収まる範囲で広がる。
var panel_size := Vector2(420.0, 520.0)
var panel_color := Color(0.055, 0.035, 0.09, 0.97)
var panel_border_color := Color(1.0, 0.3, 0.72, 1.0)
## 0 で縁を描かない。
var panel_border_width := 3
var panel_corner_radius := 16
## 板を中央へ出して後ろを覆う。項目の多い作品向け。覆いを押すか Esc で閉じる。
var modal := false
var dim_color := Color(0.0, 0.0, 0.0, 0.5)
## 空なら `gui/theme/custom_font`、それも無ければ既定の書体。既定の書体は日本語を持たず、
## 肩代わりの無い環境（Web 書き出し）では豆腐になるので、日本語を出すなら指定する。
var font_path := ""
## 0 なら既定のまま。
var font_size := 0
## 音量の行はどの作品でも要るので、部品が持つ数少ない中身の1つ。
var volume_row := true
var volume_bus := "Master"
## 1.0 より上げられるのは、小さすぎる音を確かめるため。
var volume_max := 2.0
## 空なら覚えない。覚えないと、確かめたい状態を作るのに起動のたびに同じ操作をさせる。
var volume_store := "user://gmorn_debug_menu.cfg"

const SETTING_PREFIX := "gmorn_debug_menu/"

func load_from_environment() -> void:
	enabled = bool(_setting("enabled", enabled))
	build_when_headless = bool(_setting("build_when_headless", build_when_headless))
	button_corner = String(_setting("button_corner", button_corner))
	button_size = Vector2(
		float(_setting("button_width", button_size.x)),
		float(_setting("button_height", button_size.y)))
	button_margin = Vector2(
		float(_setting("button_margin_x", button_margin.x)),
		float(_setting("button_margin_y", button_margin.y)))
	button_alpha = float(_setting("button_alpha", button_alpha))
	panel_size = Vector2(
		float(_setting("panel_width", panel_size.x)),
		float(_setting("panel_height", panel_size.y)))
	panel_color = _color("panel_color", panel_color)
	panel_border_color = _color("panel_border_color", panel_border_color)
	panel_border_width = int(_setting("panel_border_width", panel_border_width))
	panel_corner_radius = int(_setting("panel_corner_radius", panel_corner_radius))
	modal = bool(_setting("modal", modal))
	dim_color = _color("dim_color", dim_color)
	font_path = String(_setting("font_path", font_path))
	font_size = int(_setting("font_size", font_size))
	volume_row = bool(_setting("volume_row", volume_row))
	volume_bus = String(_setting("volume_bus", volume_bus))
	volume_max = float(_setting("volume_max", volume_max))
	volume_store = String(_setting("volume_store", volume_store))
	# 指定が無ければプロジェクト全体の書体を借りる。板のためだけに置き場を書かせない。
	if font_path.is_empty():
		font_path = String(_setting_at("gui/theme/custom_font", ""))
	# 環境変数は最後。撮影のときだけ消す用途なので設定より優先する。
	if OS.get_environment("GMORN_DEBUG_MENU_DISABLED") == "1":
		enabled = false

## `"#ff00ff"` のような文字も受ける。`project.godot` へ手で書くときに要る。
static func _color(key: String, fallback_value: Color) -> Color:
	var value: Variant = _setting(key, fallback_value)
	if value is Color:
		return value as Color
	if value is String and Color.html_is_valid(value as String):
		return Color.html(value as String)
	return fallback_value

static func _setting(key: String, fallback_value: Variant) -> Variant:
	return _setting_at(SETTING_PREFIX + key, fallback_value)

static func _setting_at(path: String, fallback_value: Variant) -> Variant:
	if not ProjectSettings.has_setting(path):
		return fallback_value
	return ProjectSettings.get_setting(path, fallback_value)
