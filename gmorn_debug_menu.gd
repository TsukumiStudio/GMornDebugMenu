extends CanvasLayer

## 配布したものにも載せられるデバッグ板。
##
## デバッグ機能を開発中だけのものにすると、配ったものに触ってもらったときに
## 状況を作れない。「その場面を出してください」と頼んでも、遊ぶ側には出し方が
## 分からない。隅の小さな釦から開ける板にして、配布物にもそのまま載せる。
##
## 隠したくなったら `set_button_visible(false)` を呼ぶ。撮影や配信のときに使う。
##
## 中身（項目）はこの部品では持たない。作品ごとに違うためで、外から足す。
##
##   var menu := get_node("/root/GMornDebugMenu")
##   menu.add_number("所持金", func(): return money, func(v): set_money(v))
##   menu.add_button("1000円足す", func(): add_money(1000))
##   menu.add_confirm_button("セーブデータ削除", func(): erase_save())
##
## 使い方は README.md を参照。

## 拍動の群れの名前。`addons/gmorn_beat` にある値と同じものを持つ。
##
## `preload` で指すと、その部品を取っていない状態でこの台本ごと読めなくなる。
## そうなると板が開きっぱなしのまま操作を受け付けなくなる。名前を1つ持つだけ
## なので、そのまま書く。
const BEAT_SCALE_GROUP := &"gmorn_beat_scaler"

const SETTINGS := preload("gmorn_debug_menu_settings.gd")

## 数の行が、いまの値の読み方をしまう場所。行と一緒に消える。
const NUMBER_GETTER_META := &"gmorn_debug_menu_getter"

## 釦へ出す工具の絵。
##
## 絵文字は環境の書体に左右されて豆腐になることがあるため、絵そのものを持つ。
## SVGを実行時に起こすので、画像ファイルを足さなくてよい。
const WRENCH_ICON_SVG := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M14.7 6.3a4 4 0 0 0 5 5l-9.4 9.4a2.1 2.1 0 0 1-3-3z"/>
<path d="M14.7 6.3 17.5 3.5a4 4 0 0 1 3 5.5l-2.8-2.7z"/>
</svg>"""

## 板の開け閉めのたびに流れる。
signal panel_toggled(opened: bool)

var settings: RefCounted

var _button: Button
var _panel: PanelContainer
var _items: VBoxContainer
var _status_label: Label
var _theme: Theme
## 音量の倍率。1.0 が素のまま。
var _volume_multiplier := 1.0
## 倍率を掛けるために母線へ積む増幅。掛け始めるまでは作らない。
var _volume_effect: AudioEffectAmplify = null
## 部品が持つ行の置き場。`clear_items()` で消える `_items` とは分けてある。
## 一緒にしていると、作品が場面を切り替えるたびに音量の行まで消える。
var _builtins: VBoxContainer
## 二度押しの世代。押し直しの待ち時間が重なっても、古い待ちが新しい構えを
## 解いてしまわないようにするために数える。
var _confirm_generation := 0

func _ready() -> void:
	settings = SETTINGS.new()
	settings.load_from_environment()
	# 項目の置き場は必ず作る。板を作らない実行でも、足した項目が返す `Label` や
	# `Button` は生きていなければならない。捨ててしまうと、呼ぶ側が持っている
	# 参照が freed になり、書き込んだ瞬間に落ちる。
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 画面の無い実行では板を作らない。作っても誰も見ないうえ、検証のたびに
	# 木へ余計なノードが増える。切ってあるときも同じ。
	if not settings.enabled \
			or (DisplayServer.get_name() == "headless" and not settings.build_when_headless):
		# 置き場だけを隠して持つ。木の下に居るので、この板と一緒に片付く。
		_items.visible = false
		add_child(_items)
		return
	_build_ui()
	# 開発用の板は製品画面ではない。拍動する釦を使っていても、ここでは揺らさない。
	_disable_beat_scale(self)

## 釦の出し入れ。撮影や配信のときに隠せるようにする。
func set_button_visible(value: bool) -> void:
	if is_instance_valid(_button):
		_button.visible = value

func is_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible

func open() -> void:
	_set_open(true)

func close() -> void:
	_set_open(false)

func toggle() -> void:
	_set_open(not is_open())

## 板の下の方へ出す一行。何をしたかを返す場所。
func set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message

# --- 項目を足す -------------------------------------------------------------

## 押すと何かする釦。
func add_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: action.call())
	_add_item(button)
	return button

## 押し間違えたら困る釦。1度目で構え、決められた時間内にもう1度押すと通す。
##
## 確認の窓を出す手もあるが、窓は板の上へ重なって位置がずれるうえ、
## 画面の無い実行では出せない。同じ釦の文字を変えるだけなら、どこでも同じに動く。
func add_confirm_button(label: String, action: Callable, arm_text := "もう一度押す",
		seconds := 3.0) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	var armed := [false]
	button.pressed.connect(func() -> void:
		if not armed[0]:
			armed[0] = true
			_confirm_generation += 1
			button.text = arm_text
			set_status("誤操作防止：%.0f秒以内にもう一度押してください" % seconds)
			_disarm_later(button, label, armed, _confirm_generation, seconds)
			return
		armed[0] = false
		_confirm_generation += 1
		button.text = label
		action.call())
	_add_item(button)
	return button

## 音量の倍率を変える。0.0 で無音、1.0 で素のまま。
##
## 板を作らない実行でも通る。呼ぶ側に「板があるか」を書かせないためである。
func set_volume_multiplier(value: float) -> void:
	_volume_multiplier = maxf(value, 0.0)
	_apply_volume_multiplier()

## いまの音量の倍率。
func volume_multiplier() -> float:
	return _volume_multiplier

## 倍率は、母線の音量そのものではなく **増幅の効果** で掛ける。
##
## 母線の音量を書き換える形にすると、作品が自分で音量を変えた瞬間に上書きされ、
## 掛けたはずの倍率が消える。効果は音量とは別に積まれるので、作品がいくら音量を
## 触っても、その後ろで必ず掛かる。**強制的に乗算する**とはこの形である。
##
## 等倍のあいだは何も積まない。触っていない作品の音の道を変えないため。
func _apply_volume_multiplier() -> void:
	var bus := AudioServer.get_bus_index(settings.volume_bus)
	if bus < 0:
		push_warning("音量を掛ける母線が無い: %s" % settings.volume_bus)
		return
	if _volume_effect == null:
		if is_equal_approx(_volume_multiplier, 1.0):
			return
		_volume_effect = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(bus, _volume_effect)
	# 0 倍は対数では表せない。聞こえない値まで落として無音にする。
	_volume_effect.volume_db = -80.0 if _volume_multiplier <= 0.0001 \
		else linear_to_db(_volume_multiplier)

## つまみで動かす行。`setter` は動かしている最中も呼ばれる。
##
## 数を入れて「決定」を押す行と分けてある。音量のように、動かしながら結果を
## 確かめたいものは、決定を待たせると合わせられない。
func add_slider(label: String, getter: Callable, setter: Callable,
		minimum := 0.0, maximum := 1.0, step := 0.05) -> HSlider:
	var slider := _build_slider_row(label, float(getter.call()), setter, minimum, maximum, step)
	_add_item(slider.get_parent())
	return slider

func _build_slider_row(label: String, value: float, setter: Callable,
		minimum: float, maximum: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "×%.2f" % value
	value_label.custom_minimum_size = Vector2(56.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	slider.value_changed.connect(func(next_value: float) -> void:
		value_label.text = "×%.2f" % next_value
		setter.call(next_value))
	return slider

## 数を入れて決める行。`getter` はいまの値、`setter` は決めたときの受け口。
func add_number(label: String, getter: Callable, setter: Callable,
		minimum := 0.0, maximum := 99999999.0, step := 1.0) -> SpinBox:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = float(getter.call())
	row.add_child(spin)
	var apply := Button.new()
	apply.text = "決定"
	apply.focus_mode = Control.FOCUS_NONE
	apply.pressed.connect(func() -> void:
		setter.call(spin.value)
		set_status("%s を %s にしました" % [label, spin.value]))
	row.add_child(apply)
	# 読み直し方を行そのものに持たせる。`panel_toggled` へ繋ぐと、`clear_items()`
	# で行を捨てた後も繋がりだけが残り、次に板を開いたときに解放済みの入力欄へ
	# 書き込んで落ちる。行と一緒に消えるところへ置けば、その形にならない。
	spin.set_meta(NUMBER_GETTER_META, getter)
	_add_item(row)
	return spin

## 数の行を、いまの値へ戻す。
##
## 板を開くたびに呼ばれる。開いている間に外で値が変わったときは、変えた側から
## 呼ぶ。読み直さないと、古い値のまま「決定」を押して上書きしてしまう。
func refresh_numbers() -> void:
	if not is_instance_valid(_items):
		return
	_refresh_numbers_in(_items)

func _refresh_numbers_in(node: Node) -> void:
	for child in node.get_children():
		if child is SpinBox and child.has_meta(NUMBER_GETTER_META):
			var getter: Callable = child.get_meta(NUMBER_GETTER_META)
			# 読み直し方が指す先が消えていることがある。行を足した側が
			# 先に片付いた場合で、そのときは触らない。
			if getter.is_valid():
				(child as SpinBox).set_value_no_signal(float(getter.call()))
		_refresh_numbers_in(child)

## 選ぶ行。`on_selected` には選んだ番号が渡る。
func add_option(label: String, options: PackedStringArray, on_selected: Callable,
		selected := 0) -> OptionButton:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var option := OptionButton.new()
	for text: String in options:
		option.add_item(text)
	option.selected = clampi(selected, 0, maxi(options.size() - 1, 0))
	option.item_selected.connect(func(index: int) -> void: on_selected.call(index))
	row.add_child(option)
	_add_item(row)
	return option

## 入り切りの行。
func add_toggle(label: String, on_toggled: Callable, pressed := false) -> CheckButton:
	var check := CheckButton.new()
	check.text = label
	check.button_pressed = pressed
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(value: bool) -> void: on_toggled.call(value))
	_add_item(check)
	return check

## 見るだけの行。返る `Label` の `text` を書き換えて使う。
func add_label(text := "") -> Label:
	var label := Label.new()
	label.text = text
	_add_item(label)
	return label

## 区切り線。項目が増えてきたときに固まりを分ける。
func add_separator() -> HSeparator:
	var separator := HSeparator.new()
	_add_item(separator)
	return separator

## 足した項目をすべて外す。場面が変わって、前の場面の項目が意味を失ったときに使う。
##
## 板は自動読み込みなので、項目を足した側より長生きする。足した側が片付くときは
## ここを呼ぶ。呼ばないと、消えたものを捕まえたままの釦が押せる状態で残る。
func clear_items() -> void:
	if not is_instance_valid(_items):
		return
	# 構えている釦の待ちを無効にする。世代を進めておけば、待ちが明けても
	# 消えた釦へ書き込まない。
	_confirm_generation += 1
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()

# --- 中身 -------------------------------------------------------------------

func _add_item(control: Control) -> void:
	if not is_instance_valid(_items):
		control.queue_free()
		return
	# 板が無い実行でも同じように受け取る。呼ぶ側に「板があるか」を書かせない。
	# 置き場ごと隠してあるので、出ることはない。
	_items.add_child(control)
	_disable_beat_scale(control)

func _set_open(value: bool) -> void:
	if not is_instance_valid(_panel) or _panel.visible == value:
		return
	_panel.visible = value
	if value:
		refresh_numbers()
	panel_toggled.emit(value)

func _disarm_later(button: Button, label: String, armed: Array,
		generation: int, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if generation != _confirm_generation:
		return
	# 待っている間に `clear_items()` で釦が消えていることがある。この待ちは板
	# （自動読み込み）に属するので、釦だけが先に片付く形になる。
	if not is_instance_valid(button):
		return
	armed[0] = false
	button.text = label

## 開発用の板は製品画面ではない。拍動する釦を使っていても、ここでは揺らさない。
func _disable_beat_scale(node: Node) -> void:
	if node is BaseButton and node.is_in_group(BEAT_SCALE_GROUP):
		node.remove_from_group(BEAT_SCALE_GROUP)
	for child in node.get_children():
		_disable_beat_scale(child)

func _build_ui() -> void:
	_button = Button.new()
	_button.icon = _wrench_icon()
	_button.expand_icon = true
	_button.tooltip_text = "開発用の操作板を開く"
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(_button_preset())
	_button.offset_left = settings.button_margin.x \
		if settings.button_corner in ["top_left", "bottom_left"] \
		else -settings.button_size.x - settings.button_margin.x
	_button.offset_right = _button.offset_left + settings.button_size.x
	_button.offset_top = settings.button_margin.y \
		if settings.button_corner in ["top_left", "top_right"] \
		else -settings.button_size.y - settings.button_margin.y
	_button.offset_bottom = _button.offset_top + settings.button_size.y
	_button.modulate.a = settings.button_alpha
	_button.pressed.connect(toggle)
	_button.theme = _ui_theme()
	add_child(_button)
	_build_panel()

## 工具の絵を起こす。書体に頼らないので、どの環境でも同じ形が出る。
func _wrench_icon() -> Texture2D:
	var image := Image.new()
	var size := int(minf(settings.button_size.x, settings.button_size.y) * 0.55)
	if image.load_svg_from_string(WRENCH_ICON_SVG, float(maxi(size, 8)) / 24.0) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _button_preset() -> int:
	match settings.button_corner:
		"top_left":
			return Control.PRESET_TOP_LEFT
		"bottom_left":
			return Control.PRESET_BOTTOM_LEFT
		"bottom_right":
			return Control.PRESET_BOTTOM_RIGHT
		_:
			return Control.PRESET_TOP_RIGHT

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(_button_preset())
	# 板は釦と同じ側へ寄せる。釦の反対側に出ると、押してから目を移す先が遠い。
	var to_left: bool = settings.button_corner in ["top_left", "bottom_left"]
	_panel.offset_left = settings.button_margin.x if to_left \
		else -settings.panel_size.x - settings.button_margin.x
	_panel.offset_right = _panel.offset_left + settings.panel_size.x
	_panel.offset_top = settings.button_margin.y + settings.button_size.y + 8.0 \
		if settings.button_corner in ["top_left", "top_right"] \
		else -settings.panel_size.y - settings.button_size.y - settings.button_margin.y - 8.0
	_panel.offset_bottom = _panel.offset_top + settings.panel_size.y
	_panel.add_theme_stylebox_override("panel", _panel_style())
	# 書体は板そのものへ付ける。テーマは子へ伝わるので、行を足すたびに
	# 指定し直さなくてよい。
	_panel.theme = _ui_theme()
	add_child(_panel)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(column)

	# 項目だけを流れるようにする。項目が板より多くなっても、下の一行は
	# 流れずに残る。以前は一行ごと流していたため、項目が増えると押した結果が
	# 画面の外へ出て見えなくなっていた。
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	# 部品が持つ行は、作品が足す行より上に、別の置き場で持つ。`clear_items()`
	# で消える側へ混ぜると、作品が場面を切り替えるたびに音量の行まで消える。
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	_builtins = VBoxContainer.new()
	_builtins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_builtins)
	if settings.volume_row:
		_build_volume_row()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_items)

	column.add_child(HSeparator.new())

	# 何をしたかを返す一行。押した結果が見えないと、効いたのかどうか分からない。
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_status_label)

## 板で使うテーマを作る。書体の指定が無ければ `null` を返し、既定のままにする。
##
## 既定の書体は日本語の字を持たない。卓上では実行環境の書体が肩代わりするため
## 気付けないが、肩代わりの無い環境（Webへ書き出したもの）では日本語がすべて
## 豆腐になる。実際に配ったWeb版で、板の項目名が全部四角になっていた。
## 音量の行。部品が持つ数少ない中身の1つ。
func _build_volume_row() -> void:
	var slider := _build_slider_row("音量 (%s)" % settings.volume_bus,
		_volume_multiplier,
		func(value: float) -> void:
			set_volume_multiplier(value)
			set_status("音量を ×%.2f にしました" % value),
		0.0, settings.volume_max, 0.05)
	_builtins.add_child(slider.get_parent())
	_builtins.add_child(HSeparator.new())

func _ui_theme() -> Theme:
	if _theme != null:
		return _theme
	if settings.font_path.is_empty() and settings.font_size <= 0:
		return null
	_theme = Theme.new()
	if not settings.font_path.is_empty():
		var font := load(settings.font_path) as Font
		if font != null:
			_theme.default_font = font
		else:
			push_warning("書体を読めなかったため既定のままにする: %s" % settings.font_path)
	if settings.font_size > 0:
		_theme.default_font_size = settings.font_size
	return _theme

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = settings.panel_color
	style.border_color = settings.panel_border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(12)
	return style
