extends CanvasLayer

## 配布物にも載せるデバッグ板。開発中だけの機能だと、配ったものに触ってもらった
## ときに状況を作れない。中身（項目）は作品ごとに違うので外から足す。

## `addons/gmorn_beat` の群れの名前。`preload` で指すと、その部品を取っていない状態で
## この台本ごと読めなくなるので、値をそのまま書く。
const BEAT_SCALE_GROUP := &"gmorn_beat_scaler"

const SETTINGS := preload("gmorn_debug_menu_settings.gd")

const PANEL_GAP := 8.0

## 作品のHUDや遷移の幕（数十〜数百の層）より上。低いと板や覆いの上にHUDが重なる。
const DRAW_LAYER := 1000

const CATEGORY_INDENT := 16

## 他の値を並べて置けるように節を切ってある。
const STORE_SECTION := "gmorn_debug_menu"
const STORE_VOLUME_KEY := "volume_multiplier"

## 数の行がいまの値の読み方を持つメタ。行と一緒に消える。
const NUMBER_GETTER_META := &"gmorn_debug_menu_getter"

## 釦の工具の絵。絵文字は環境の書体で豆腐になり、画像ファイルは付属物を増やすので、
## SVG 文字列を実行時に起こす。
const WRENCH_ICON_SVG := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M14.7 6.3a4 4 0 0 0 5 5l-9.4 9.4a2.1 2.1 0 0 1-3-3z"/>
<path d="M14.7 6.3 17.5 3.5a4 4 0 0 1 3 5.5l-2.8-2.7z"/>
</svg>"""

signal panel_toggled(opened: bool)

var settings: RefCounted

var _button: Button
var _panel: PanelContainer
## `modal` のとき後ろを覆う幕。
var _dim: ColorRect
## 板を画面へ収めるときに中身の幅を測る。
var _scroll: ScrollContainer
var _stack: VBoxContainer
var _items: VBoxContainer
var _status_label: Label
var _theme: Theme
var _volume_multiplier := 1.0
## 掛け始めるまでは作らない。
var _volume_effect: AudioEffectAmplify = null
## 部品が持つ行。`clear_items()` で消える `_items` と一緒にすると、場面を切り替える
## たびに音量の行まで消える。
var _builtins: VBoxContainer
## 二度押しの世代。古い待ちが新しい構えを解かないように数える。
var _confirm_generation := 0

# --- エディタのデバッガパネルとの橋渡し（仕様は README.md） ------------------

## エディタ側の `_has_capture()` と揃える。
const BRIDGE_NAME := "gmorn_debug_menu"
const BRIDGE_POLL_SECONDS := 0.3

## `id -> {kind, label, invoke?, set_value?, value_getter?, options?, last_value?}`。
## `EngineDebugger` が無くても記録は続ける。検証がこの中身を直に確かめる。
var _bridge_items: Dictionary = {}
var _bridge_next_id := 0
var _category := ""
## `"親/子" -> 中身の VBoxContainer`。
var _category_boxes: Dictionary = {}
## `clear_items()` を跨いで開閉を覚え、足し直しても開いていた分類は開いたまま出す。
var _category_folded: Dictionary = {}
var _bridge_active := false

func _ready() -> void:
	layer = DRAW_LAYER
	settings = SETTINGS.new()
	settings.load_from_environment()
	# 板を作る前に倍率を戻す。つまみが最初からその位置で出る。
	_load_volume_multiplier()
	# 板を作らない実行でも置き場は作る。足した項目が返す `Label` 等を捨てると、
	# 呼ぶ側の参照が freed になり書き込んだ瞬間に落ちる。
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 橋渡しは板の有無と無関係。画面の無い実行でもリモートから項目を操る。
	_bridge_setup()
	# ヘッドレスでは板を作らない。検証のたびに木へ余計なノードが増える。
	if not settings.enabled \
			or (DisplayServer.get_name() == "headless" and not settings.build_when_headless):
		_items.visible = false
		add_child(_items)
		return
	_build_ui()
	_disable_beat_scale(self)

## 撮影や配信のときに隠す。
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

func _unhandled_input(event: InputEvent) -> void:
	if settings != null and settings.modal and is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## 板の下の一行。押した結果が見えないと効いたのかどうか分からない。
func set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
	if _bridge_active:
		EngineDebugger.send_message("%s:status" % BRIDGE_NAME, [message])

## 以後に足す項目の分類。`/` で子階層。
func set_category(path: String) -> void:
	_category = "/".join(path.split("/", false))

# --- 項目を足す -------------------------------------------------------------

func add_button(label: String, action: Callable, row_group := "") -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: action.call())
	_add_item(button)
	if not row_group.is_empty():
		var group: HBoxContainer = null
		var parent := _category_box(_category)
		for child in parent.get_children():
			if child.get_meta("row_group", "") == _category + "/" + row_group:
				group = child
		if group == null:
			group = preload("gmorn_debug_menu_button_group.tscn").instantiate()
			group.set_meta("row_group", _category + "/" + row_group)
			parent.add_child(group)
		button.reparent(group)
		button.tooltip_text = label
	_bridge_register("button", label, {"invoke": func() -> void: button.pressed.emit(), "row_group": row_group})
	return button

## 二度押しで通す釦。確認の窓は板の上へ重なって位置がずれ、画面の無い実行では
## 出せないので、同じ釦の文字を変える。
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
	_bridge_register("button", label, {"invoke": func() -> void: button.pressed.emit()})
	return button

## 板を作らない実行でも通る。呼ぶ側に「板があるか」を書かせない。
func set_volume_multiplier(value: float) -> void:
	_volume_multiplier = maxf(value, 0.0)
	_apply_volume_multiplier()
	_save_volume_multiplier()

func volume_multiplier() -> float:
	return _volume_multiplier

## 母線の音量ではなく増幅の効果で掛ける。音量を書き換えると、作品が自分で音量を
## 変えた瞬間に倍率が消える。等倍のあいだは積まず、作品の音の道を変えない。
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
	# 0 倍は対数では表せない。
	_volume_effect.volume_db = -80.0 if _volume_multiplier <= 0.0001 \
		else linear_to_db(_volume_multiplier)

func _load_volume_multiplier() -> void:
	if String(settings.volume_store).is_empty():
		return
	var file := ConfigFile.new()
	if file.load(settings.volume_store) != OK:
		return
	var stored := float(file.get_value(STORE_SECTION, STORE_VOLUME_KEY, 1.0))
	_volume_multiplier = clampf(stored, 0.0, float(settings.volume_max))
	_apply_volume_multiplier()

func _save_volume_multiplier() -> void:
	if String(settings.volume_store).is_empty():
		return
	var file := ConfigFile.new()
	# 読んでから書く。作り直すと同じ置き場に並べた他の値を消す。
	file.load(settings.volume_store)
	file.set_value(STORE_SECTION, STORE_VOLUME_KEY, _volume_multiplier)
	var result := file.save(settings.volume_store)
	if result != OK:
		push_warning("音量の倍率を書けなかった: %s (%d)" % [settings.volume_store, result])

## `setter` は動かしている最中も呼ばれる。音量のように動かしながら合わせるものは、
## 決定を待たせると合わせられない。
func add_slider(label: String, getter: Callable, setter: Callable,
		minimum := 0.0, maximum := 1.0, step := 0.05) -> HSlider:
	var slider := _build_slider_row(label, float(getter.call()), setter, minimum, maximum, step)
	_add_item(slider.get_parent())
	_bridge_register("slider", label, {
		"minimum": minimum, "maximum": maximum, "step": step,
		"value_getter": func() -> float: return slider.value,
		"set_value": func(value: float) -> void: slider.value = value,
	})
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

## 数を入れて「決定」で渡す行。
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
		# 決定釦がフォーカスを受けないため、入力中の LineEdit の文字列が
		# SpinBox.value へ反映されないまま押されることがある。文字列から読む。
		var value: float = spin.value
		var line_edit: LineEdit = spin.get_line_edit()
		var text: String = line_edit.text.strip_edges()
		if text.is_valid_float():
			value = clampf(float(text), spin.min_value, spin.max_value)
		setter.call(value)
		set_status("%s を %s にしました" % [label, value]))
	row.add_child(apply)
	# 読み直し方は `panel_toggled` へ繋がず行のメタに置く。繋ぐと `clear_items()` の後も
	# 繋がりだけが残り、次に開いたとき解放済みの入力欄へ書いて落ちる。
	spin.set_meta(NUMBER_GETTER_META, getter)
	_add_item(row)
	_bridge_register("number", label, {
		"minimum": minimum, "maximum": maximum, "step": step,
		"value_getter": getter,
		"set_value": func(value: float) -> void:
			setter.call(value)
			spin.set_value_no_signal(value)
			set_status("%s を %s にしました" % [label, value]),
	})
	return spin

## 開いている間に外で値が変わったら、変えた側から呼ぶ。読み直さないと古い値のまま
## 「決定」を押して上書きする。
func refresh_numbers() -> void:
	if not is_instance_valid(_items):
		return
	_refresh_numbers_in(_items)

func _refresh_numbers_in(node: Node) -> void:
	for child in node.get_children():
		if child is SpinBox and child.has_meta(NUMBER_GETTER_META):
			var getter: Callable = child.get_meta(NUMBER_GETTER_META)
			# 行を足した側が先に片付くと getter の指す先が消えている。
			if getter.is_valid():
				(child as SpinBox).set_value_no_signal(float(getter.call()))
		_refresh_numbers_in(child)

## `on_selected` には選んだ番号が渡る。
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
	_bridge_register("option", label, {
		"value_getter": func() -> int: return option.selected,
		"options": options,
		"set_value": func(value: int) -> void:
			option.selected = value
			on_selected.call(value),
	})
	return option

func add_toggle(label: String, on_toggled: Callable, pressed := false) -> CheckButton:
	var check := CheckButton.new()
	check.text = label
	check.button_pressed = pressed
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(value: bool) -> void: on_toggled.call(value))
	_add_item(check)
	_bridge_register("toggle", label, {
		"value_getter": func() -> bool: return check.button_pressed,
		# `button_pressed` へ書くと `toggled` が流れ、押した場合と同じ道を通る。
		"set_value": func(value: bool) -> void: check.button_pressed = value,
	})
	return check

## 返る `Label` の `text` を書き換えて使う。
func add_label(text := "") -> Label:
	var label := Label.new()
	label.text = text
	_add_item(label)
	_bridge_register("label", text, {"value_getter": func() -> String: return label.text})
	return label

## 作品が組んだ部品を1つの項目として置く。中身が分からないので Editor へは写さない。
func add_control(control: Control) -> Control:
	_add_item(control)
	return control

func add_separator() -> HSeparator:
	var separator := HSeparator.new()
	_add_item(separator)
	return separator

## 項目を足した側が片付くときに呼ぶ。板は自動読み込みで長生きするので、呼ばないと
## 消えたものを捕まえたままの釦が押せる状態で残る。
func clear_items() -> void:
	if not is_instance_valid(_items):
		return
	# 世代を進め、構えている釦の待ちが明けても消えた釦へ書き込まないようにする。
	_confirm_generation += 1
	# 開閉を覚えてから消す。
	for path: String in _category_boxes:
		var fold := (_category_boxes[path] as Node).get_parent().get_parent() as FoldableContainer
		_category_folded[path] = fold.folded
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	_bridge_items.clear()
	_bridge_next_id = 0
	_category = ""
	_category_boxes.clear()
	if _bridge_active:
		EngineDebugger.send_message("%s:clear" % BRIDGE_NAME, [])

# --- 中身 -------------------------------------------------------------------

func _add_item(control: Control) -> void:
	if not is_instance_valid(_items):
		control.queue_free()
		return
	# 釦を板いっぱいに伸ばすと、どこまでが釦か分からない。
	if control is Button and not control is CheckButton:
		control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_category_box(_category).add_child(control)
	_disable_beat_scale(control)

## 分類ごとの折りたたみの中身（無ければ作る）。分類が空なら `_items` へ直に置く。
func _category_box(path: String) -> VBoxContainer:
	if path.is_empty():
		return _items
	if _category_boxes.has(path):
		return _category_boxes[path]
	var parts := path.split("/")
	var parent := _category_box("/".join(parts.slice(0, parts.size() - 1)))
	var fold := FoldableContainer.new()
	fold.title = parts[parts.size() - 1]
	fold.focus_mode = Control.FOCUS_NONE
	# 既定は畳む。開くと一覧が長くなり構造が見えない。
	fold.folded = _category_folded.get(path, true)
	# 寄せないと、入れ子の見出しが親と同じ列に並び、どこまでが同じ分類か見えない。
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", CATEGORY_INDENT)
	fold.add_child(indent)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	indent.add_child(box)
	parent.add_child(fold)
	_category_boxes[path] = box
	return box

# --- エディタのデバッガパネルとの橋渡し --------------------------------------

func _bridge_setup() -> void:
	if not EngineDebugger.is_active():
		return
	_bridge_active = true
	EngineDebugger.register_message_capture(BRIDGE_NAME, _bridge_capture)
	var timer := Timer.new()
	timer.wait_time = BRIDGE_POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_bridge_poll_values)
	add_child(timer)

## `opts`: `invoke`（釦の実行）, `set_value`（値の変更）, `value_getter`（同期と巡回）,
## `options`（選択肢）。
func _bridge_register(kind: String, label: String, opts: Dictionary) -> void:
	var entry := opts.duplicate()
	entry["kind"] = kind
	entry["label"] = label
	entry["category"] = _category
	_bridge_items[_bridge_next_id] = entry
	_bridge_next_id += 1
	_bridge_send_sync()

func _bridge_snapshot() -> Array:
	var items: Array = []
	for id: int in _bridge_items.keys():
		var entry: Dictionary = _bridge_items[id]
		var item := {"id": id, "kind": entry.kind, "label": entry.label, "category": entry.get("category", "")}
		for key: String in ["minimum", "maximum", "step", "row_group"]:
			if entry.has(key):
				item[key] = entry[key]
		if entry.has("value_getter"):
			item["value"] = (entry.value_getter as Callable).call()
		if entry.has("options"):
			item["options"] = entry.options
		items.append(item)
	return items

func _bridge_send_sync() -> void:
	if not _bridge_active:
		return
	EngineDebugger.send_message("%s:sync" % BRIDGE_NAME, [_bridge_snapshot()])

## Godot が合言葉とコロンを除いてから渡すため、命令名だけで照合する。
func _bridge_capture(message: String, data: Array) -> bool:
	match message:
		"sync_request":
			_bridge_send_sync()
			return true
		"invoke":
			if data.size() >= 1:
				_bridge_invoke(int(data[0]))
			return true
		"set_value":
			if data.size() >= 2:
				_bridge_set_value(int(data[0]), data[1])
			return true
		_:
			return false

func _bridge_invoke(id: int) -> void:
	if not _bridge_items.has(id):
		return
	var entry: Dictionary = _bridge_items[id]
	if entry.has("invoke"):
		(entry.invoke as Callable).call()

func _bridge_set_value(id: int, value: Variant) -> void:
	if not _bridge_items.has(id):
		return
	var entry: Dictionary = _bridge_items[id]
	if entry.has("set_value"):
		(entry.set_value as Callable).call(value)

## 値が変わった項目だけを送る。
func _bridge_poll_values() -> void:
	for id: int in _bridge_items.keys():
		var entry: Dictionary = _bridge_items[id]
		if not entry.has("value_getter"):
			continue
		var value: Variant = (entry.value_getter as Callable).call()
		if entry.has("last_value") and entry.last_value == value:
			continue
		entry["last_value"] = value
		if _bridge_active:
			EngineDebugger.send_message("%s:value" % BRIDGE_NAME, [id, value])

func _set_open(value: bool) -> void:
	if not is_instance_valid(_panel) or _panel.visible == value:
		return
	_panel.visible = value
	if is_instance_valid(_dim):
		_dim.visible = value
	if value:
		refresh_numbers()
		# 開くたびに置き直す。行は板を作った後に足されるので、作ったときの寸法のままだと
		# 広い行のぶんが画面の外へ出る。
		_layout_panel()
	panel_toggled.emit(value)

func _disarm_later(button: Button, label: String, armed: Array,
		generation: int, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if generation != _confirm_generation:
		return
	# 待っている間に `clear_items()` で釦だけが先に片付くことがある。
	if not is_instance_valid(button):
		return
	armed[0] = false
	button.text = label

## 開発用の板は揺らさない。
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
	if settings.modal:
		# 幕は釦より下。釦でも閉じられるようにする。
		_dim = ColorRect.new()
		_dim.color = settings.dim_color
		_dim.visible = false
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		_dim.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				close())
		add_child(_dim)
		move_child(_dim, 0)
	_panel = PanelContainer.new()
	_panel.visible = false
	# 置き場は `_layout_panel()` が左上からの座標で決める。
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	# テーマは子へ伝わるので、行を足すたびに指定し直さない。
	_panel.theme = _ui_theme()
	add_child(_panel)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(column)

	# 流すのは項目だけ。状況の一行まで流すと、項目が増えたとき押した結果が見えない。
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 横も流す。流せないと行の最小幅が枠の最小幅になり、`PanelContainer` が指定を
	# 無視して画面の外へ広がる。
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	_scroll = scroll

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	_stack = stack
	_builtins = VBoxContainer.new()
	_builtins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_builtins)
	if settings.volume_row:
		_build_volume_row()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_items)

	column.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_status_label)

	_layout_panel()
	# 画面の大きさが変わっても板が画面の中に残るように置き直す。
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_layout_panel):
		viewport.size_changed.connect(_layout_panel)

## `panel_size` は目安。指定より広い行が来ると `PanelContainer` はその最小幅まで
## 広がるので、画面に入るところまで広げ、入らなければ止めて中を流し、画面の外へ
## 出ない場所へ置く。
func _layout_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var view := viewport.get_visible_rect().size
	var margin: Vector2 = settings.button_margin
	# 釦と重ならない高さ。中央に出すときは釦を避けない。
	var reserved: float = 0.0 if settings.modal else settings.button_size.y + PANEL_GAP
	var available := Vector2(
		maxf(view.x - margin.x * 2.0, 1.0),
		maxf(view.y - margin.y * 2.0 - reserved, 1.0))
	var wanted: float = settings.panel_size.x
	if is_instance_valid(_stack):
		wanted = maxf(wanted, _stack.get_combined_minimum_size().x + _panel_inner_width())
	var size := Vector2(minf(wanted, available.x), minf(float(settings.panel_size.y), available.y))
	# 余白と一行ぶんより縮まないので、画面がそれより狭いときは左上だけ守る。
	size = size.max(_panel.get_combined_minimum_size())
	var to_left: bool = settings.button_corner in ["top_left", "bottom_left"]
	var to_top: bool = settings.button_corner in ["top_left", "top_right"]
	var position := Vector2(
		margin.x if to_left else view.x - margin.x - size.x,
		margin.y + reserved if to_top else view.y - margin.y - reserved - size.y)
	if settings.modal:
		position = ((view - size) * 0.5).floor()
	# 指定した余白が画面より大きくても外へ出さない。
	position.x = clampf(position.x, 0.0, maxf(view.x - size.x, 0.0))
	position.y = clampf(position.y, 0.0, maxf(view.y - size.y, 0.0))
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = position.x
	_panel.offset_top = position.y
	_panel.offset_right = position.x + size.x
	_panel.offset_bottom = position.y + size.y

func _panel_inner_width() -> float:
	var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	var width := 0.0
	if style != null:
		width += style.content_margin_left + style.content_margin_right
	if is_instance_valid(_scroll):
		width += _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	return width

func _build_volume_row() -> void:
	var slider := _build_slider_row("音量 (%s)" % settings.volume_bus,
		_volume_multiplier,
		func(value: float) -> void:
			set_volume_multiplier(value)
			set_status("音量を ×%.2f にしました" % value),
		0.0, settings.volume_max, 0.05)
	_builtins.add_child(slider.get_parent())
	_builtins.add_child(HSeparator.new())

## 作品のテーマ（`gui/theme/custom`）は借りない。飾りのテーマでは道具の釦が釦に見えない。
func _ui_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	if not settings.font_path.is_empty():
		var font := load(settings.font_path) as Font
		if font != null:
			_theme.default_font = font
		else:
			push_warning("書体を読めなかったため既定のままにする: %s" % settings.font_path)
	if settings.font_size > 0:
		_theme.default_font_size = settings.font_size
	_apply_control_styles(_theme)
	return _theme

func _apply_control_styles(theme: Theme) -> void:
	var text := Color(0.92, 0.93, 0.95)
	var muted := Color(0.5, 0.52, 0.56)
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, _box(Color(0.17, 0.185, 0.21), Color(0.42, 0.45, 0.5)))
		theme.set_stylebox("hover", type, _box(Color(0.23, 0.25, 0.29), Color(0.62, 0.66, 0.73)))
		theme.set_stylebox("pressed", type, _box(Color(0.16, 0.38, 0.72), Color(0.38, 0.6, 0.95)))
		theme.set_stylebox("hover_pressed", type, _box(Color(0.19, 0.43, 0.8), Color(0.45, 0.66, 1.0)))
		theme.set_stylebox("disabled", type, _box(Color(0.12, 0.125, 0.14), Color(0.22, 0.235, 0.26)))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, text)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_hover_pressed_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, muted)
	for type: String in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, _box(Color(0.045, 0.05, 0.06), Color(0.42, 0.45, 0.5)))
		theme.set_stylebox("focus", type, _box(Color(0.045, 0.05, 0.06), Color(0.38, 0.6, 0.95)))
		theme.set_color("font_color", type, text)
		theme.set_color("font_placeholder_color", type, muted)
	theme.set_color("font_color", "Label", text)
	theme.set_color("font_color", "CheckButton", text)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = settings.panel_color
	style.border_color = settings.panel_border_color
	style.set_border_width_all(settings.panel_border_width)
	style.set_corner_radius_all(settings.panel_corner_radius)
	style.set_content_margin_all(12)
	return style
