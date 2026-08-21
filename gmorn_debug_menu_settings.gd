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
## 板で使う書体（`res://` から始まる置き場）。空なら既定のまま。
##
## 指定しないと、Godotが用意している既定の書体で描く。この書体は日本語の
## 字を持たないが、卓上では実行環境の書体が肩代わりするため気付けない。
## 肩代わりの無い環境（Webへ書き出したもの）では、日本語がすべて豆腐になる。
## 実際に配ったWeb版で、板の項目名が全部四角になっていた。
var font_path := ""
## 板の文字の大きさ。0なら既定のまま。
var font_size := 0
## 音量の行を板へ出すか。
##
## どの作品でも要るので、この部品が持つ数少ない中身の1つ。撮影のときに音を
## 絞る、うるさい効果音を聞き直す、といった用途がどこでも同じ形で出る。
var volume_row := true
## 音量を掛ける母線の名前。
var volume_bus := "Master"
## 音量の倍率の上限。1.0 より上げられるようにしてあるのは、小さすぎる音を
## 確かめたいことがあるため。
var volume_max := 2.0
## 音量の倍率をしまう置き場。空なら覚えない。
##
## 合わせ直した音量が起動のたびに戻ると、確かめたい状態を作るのに毎回同じ操作を
## させることになる。遊ぶ側に触ってもらうための板なので、覚えておく。
var volume_store := "user://gmorn_debug_menu.cfg"

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
	font_path = String(_setting("font_path", font_path))
	font_size = int(_setting("font_size", font_size))
	volume_row = bool(_setting("volume_row", volume_row))
	volume_bus = String(_setting("volume_bus", volume_bus))
	volume_max = float(_setting("volume_max", volume_max))
	volume_store = String(_setting("volume_store", volume_store))
	# 何も指定が無ければ、プロジェクト全体の書体を借りる。作品が既に持って
	# いるものを使えば、板のためだけに置き場を書かせなくて済む。
	if font_path.is_empty():
		font_path = String(_setting_at("gui/theme/custom_font", ""))
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
	return _setting_at(SETTING_PREFIX + key, fallback_value)

static func _setting_at(path: String, fallback_value: Variant) -> Variant:
	if not ProjectSettings.has_setting(path):
		return fallback_value
	return ProjectSettings.get_setting(path, fallback_value)
