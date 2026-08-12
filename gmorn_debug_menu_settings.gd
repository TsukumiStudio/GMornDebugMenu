extends RefCounted

## GMornDebugMenu の設定。
##
## `class_name` は付けない。付けるとエディタが一度走査するまで名前を引けず、
## 取り込んだ直後にヘッドレスで走らせると読み込みごと失敗する。使う側は
## `preload` で直に指す。

## 板を作るか。配布物から外したいときに false にする。
##
## 既定は有効。デバッグ機能を開発中だけのものにすると、配ったものに触って
## もらったときに状況を作れない。
var enabled := true
## 画面の無い実行でも板を作るか。既定では作らない。
##
## 板そのものを検証したいときだけ true にする。
var build_when_headless := false
## 釦を置く隅。`top_right` / `top_left` / `bottom_right` / `bottom_left`。
var button_corner := "top_right"
## 釦の大きさ（画素）。
var button_size := Vector2(40.0, 40.0)
## 画面の縁から釦までの間（画素）。
##
## 同じ隅に別の釦（不具合報告など）があるときは、縦にずらして重なりを避ける。
var button_margin := Vector2(12.0, 12.0)
## 釦の濃さ。遊びの邪魔にならない程度に薄くできる。
var button_alpha := 0.82
## 板の大きさ（画素）。
var panel_size := Vector2(420.0, 520.0)
## 板の地の色。
var panel_color := Color(0.055, 0.035, 0.09, 0.97)
## 板の縁の色。
var panel_border_color := Color(1.0, 0.3, 0.72, 1.0)

const SETTING_PREFIX := "gmorn_debug_menu/"

## 設定を読み込む。自分自身へ書き込むので、作ってから呼ぶ。
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
	# 環境変数は最後に効かせる。撮影のときだけ消したい、といった使い方をする。
	if OS.get_environment("GMORN_DEBUG_MENU_DISABLED") == "1":
		enabled = false

## 色は `Color` でも `"#ff00ff"` のような文字でも受ける。`project.godot` へ
## 手で書くときは文字のほうが書きやすい。
static func _color(key: String, fallback_value: Color) -> Color:
	var value: Variant = _setting(key, fallback_value)
	if value is Color:
		return value as Color
	if value is String and Color.html_is_valid(value as String):
		return Color.html(value as String)
	return fallback_value

static func _setting(key: String, fallback_value: Variant) -> Variant:
	var path := SETTING_PREFIX + key
	if not ProjectSettings.has_setting(path):
		return fallback_value
	return ProjectSettings.get_setting(path, fallback_value)
