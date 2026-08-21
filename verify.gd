extends SceneTree

## 項目の足し方と、二度押しの構えを確かめる。
##
## 画面の無い実行では既定で板を作らない。作らない側でも、項目を足す呼び出しが
## そのまま通ることが要る。呼ぶ側に「板があるか」を書かせないためである。
## ここでは両方を見る。

const MENU_PATH := "res://addons/gmorn_debug_menu/gmorn_debug_menu.gd"

## `node` が `ancestor` の下にあるか。
static func _is_under(node: Node, ancestor: Node) -> bool:
	var walk := node
	while walk != null:
		if walk == ancestor:
			return true
		walk = walk.get_parent()
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script: GDScript = load(MENU_PATH)

	# 板を作らない側。項目を足しても落ちない。
	var quiet: CanvasLayer = script.new()
	root.add_child(quiet)
	await process_frame
	assert(not quiet.is_open(), "板が無いのに開いていると言う")
	quiet.add_button("何か", func() -> void: pass)
	quiet.add_label("見るだけ")
	quiet.add_toggle("入り切り", func(_v: bool) -> void: pass)
	quiet.set_status("何も起きない")
	quiet.toggle()
	assert(not quiet.is_open(), "板が無いのに開いた")

	# ここから先は板を作らせる。
	ProjectSettings.set_setting("gmorn_debug_menu/build_when_headless", true)
	var menu: CanvasLayer = script.new()
	root.add_child(menu)
	await process_frame
	assert(not menu.is_open(), "はじめから開いている")

	# 開け閉めのたびに知らせが流れる。
	var toggles: Array = []
	menu.panel_toggled.connect(func(opened: bool) -> void: toggles.append(opened))
	menu.open()
	assert(menu.is_open(), "開かない")
	menu.open()
	assert(toggles.size() == 1, "同じ状態で流れている: %d" % toggles.size())
	menu.close()
	assert(not menu.is_open(), "閉じない")
	assert(toggles == [true, false], "知らせの中身が %s" % str(toggles))

	# 押すと呼ばれる。
	var pressed: Array = []
	var button: Button = menu.add_button("押す", func() -> void: pressed.append(true))
	button.pressed.emit()
	assert(pressed.size() == 1, "押しても呼ばれない")

	# 二度押しの釦は、1度目では通さない。
	var erased: Array = []
	var danger: Button = menu.add_confirm_button(
		"削除", func() -> void: erased.append(true), "もう一度押して削除", 3.0)
	danger.pressed.emit()
	assert(erased.is_empty(), "1度目で通ってしまった")
	assert(danger.text == "もう一度押して削除", "構えた文字が %s" % danger.text)
	danger.pressed.emit()
	assert(erased.size() == 1, "2度目で通らない")
	assert(danger.text == "削除", "通した後の文字が %s" % danger.text)

	# 数の行は、決めたときだけ受け口へ渡る。
	var stored := [0.0]
	var spin: SpinBox = menu.add_number("お金",
		func() -> float: return stored[0],
		func(value: float) -> void: stored[0] = value,
		0.0, 1000.0, 1.0)
	spin.value = 500.0
	assert(stored[0] == 0.0, "決める前に渡っている")
	# 「決定」は数の行の3つ目に置いてある。
	var apply := spin.get_parent().get_child(2) as Button
	apply.pressed.emit()
	assert(stored[0] == 500.0, "決めても渡らない: %f" % stored[0])

	# 板を開き直すと、いまの値へ戻る。開いている間に外で変わることがある。
	stored[0] = 42.0
	menu.open()
	assert(is_equal_approx(spin.value, 42.0), "開き直しても %f のまま" % spin.value)

	# 選ぶ行は選んだ番号を渡す。
	var chosen := [-1]
	var option: OptionButton = menu.add_option("状況",
		PackedStringArray(["なし", "地雷", "天使"]),
		func(index: int) -> void: chosen[0] = index)
	option.item_selected.emit(2)
	assert(chosen[0] == 2, "選んだ番号が %d" % chosen[0])

	# 何をしたかを返す一行が書き換わる。効いたのかどうかが見えないと困る。
	menu.set_status("試した")
	assert(menu._status_label.text == "試した", "状況が %s" % menu._status_label.text)

	# 開いている間に外で値が変わったら、変えた側から読み直させる。読み直さないと、
	# 古い値のまま「決定」を押して変更をなかったことにしてしまう。
	stored[0] = 7.0
	menu.refresh_numbers()
	assert(is_equal_approx(spin.value, 7.0), "読み直しても %f のまま" % spin.value)

	# 構えたまま項目を外しても、待ちが明けたときに落ちない。板は自動読み込みなので
	# 待ちだけが残り、釦が先に消える形になる。
	var short_confirm: Button = menu.add_confirm_button(
		"短い確認", func() -> void: pass, "もう一度", 0.2)
	short_confirm.pressed.emit()
	menu.clear_items()
	await create_timer(0.5).timeout

	# 外した後に開き直しても落ちない。数の行の読み直しが、消えた入力欄を
	# 触らないこと。
	menu.close()
	menu.open()
	assert(menu.is_open(), "開き直せない")

	# 状況の一行は流れる側に入れない。項目が増えても押した結果が見えるように
	# するためで、以前は一行ごと流れて画面の外へ出ていた。
	var scrolls: Array = []
	for child in menu._status_label.get_parent().get_children():
		if child is ScrollContainer:
			scrolls.append(child)
	assert(scrolls.size() == 1, "流れる場所が %d 個ある" % scrolls.size())
	# 直の親ではなく、流れる側の下にあるかで見る。部品が持つ行と作品が足す行を
	# 分ける置き場が間に挟まっても、確かめたいこと (項目は流れる) は変わらない。
	assert(_is_under(menu._items, scrolls[0]), "項目が流れる側に入っていない")
	assert(not _is_under(menu._status_label, scrolls[0]), "状況の一行が流れる側に入っている")
	assert(_is_under(menu._builtins, scrolls[0]), "部品が持つ行が流れる側に入っていない")

	# 書体を指定していなければテーマを作らない。既定のままにする。
	assert(menu._ui_theme() == null, "指定していないのにテーマを作った")

	# 大きさだけでも指定すればテーマができ、板と釦の両方へ付く。
	ProjectSettings.set_setting("gmorn_debug_menu/font_size", 25)
	var themed: CanvasLayer = script.new()
	root.add_child(themed)
	await process_frame
	assert(themed._panel.theme != null, "板へテーマが付いていない")
	assert(themed._button.theme != null, "釦へテーマが付いていない")
	assert(themed._panel.theme.default_font_size == 25,
		"文字の大きさが %d" % themed._panel.theme.default_font_size)
	# 板と釦で同じものを使い回す。作り直すと、書体が二重に読み込まれる。
	assert(themed._panel.theme == themed._button.theme, "テーマを作り直している")
	ProjectSettings.set_setting("gmorn_debug_menu/font_size", 0)

	# 読めない置き場を指しても落ちない。既定のままにするだけ。
	ProjectSettings.set_setting("gmorn_debug_menu/font_path", "res://無い書体.otf")
	var broken: CanvasLayer = script.new()
	root.add_child(broken)
	await process_frame
	assert(broken._panel != null, "書体を読めないだけで板が作られなくなった")
	ProjectSettings.set_setting("gmorn_debug_menu/font_path", "")

	# 音量の倍率。板を作らない側でも通る。
	assert(is_equal_approx(quiet.volume_multiplier(), 1.0), "はじめから等倍でない")
	quiet.set_volume_multiplier(0.5)
	assert(is_equal_approx(quiet.volume_multiplier(), 0.5), "倍率が入らない")

	# 等倍のあいだは母線へ何も積まない。触っていない作品の音の道を変えない。
	var bus := AudioServer.get_bus_index("Master")
	var before: int = AudioServer.get_bus_effect_count(bus)
	var untouched: CanvasLayer = script.new()
	root.add_child(untouched)
	await process_frame
	assert(AudioServer.get_bus_effect_count(bus) == before,
		"等倍なのに効果を積んでいる: %d → %d" % [before, AudioServer.get_bus_effect_count(bus)])

	# 倍率を変えたところで初めて積む。母線の音量そのものは触らない。
	var volume_before := AudioServer.get_bus_volume_db(bus)
	untouched.set_volume_multiplier(0.25)
	assert(AudioServer.get_bus_effect_count(bus) == before + 1,
		"倍率を変えても効果を積んでいない")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(bus), volume_before),
		"母線の音量そのものを書き換えている")
	var amp := AudioServer.get_bus_effect(bus, before) as AudioEffectAmplify
	assert(amp != null, "積んだものが増幅でない")
	assert(is_equal_approx(amp.volume_db, linear_to_db(0.25)),
		"掛かった量が %f" % amp.volume_db)
	# 作品が母線の音量を変えても、倍率は掛かったまま残る。**強制的に乗算する**
	# とはこの形である。母線の音量を書き換える作りだと、ここで倍率が消える。
	AudioServer.set_bus_volume_db(bus, volume_before - 6.0)
	assert(is_equal_approx(amp.volume_db, linear_to_db(0.25)),
		"作品が音量を変えたら倍率が消えた")
	AudioServer.set_bus_volume_db(bus, volume_before)
	# 0 倍は無音まで落とす。対数では 0 を表せない。
	untouched.set_volume_multiplier(0.0)
	assert(amp.volume_db <= -80.0, "0倍で無音になっていない: %f" % amp.volume_db)
	untouched.set_volume_multiplier(1.0)

	# 音量の行は、作品が場面を切り替えても消えない。`clear_items()` で消える
	# 側へ混ぜていると、場面が変わるたびに音量を合わせ直すことになる。
	assert(menu._builtins != null and menu._builtins.get_child_count() > 0,
		"音量の行が置かれていない")
	var builtin_rows: int = menu._builtins.get_child_count()
	menu.add_button("あとで消す", func() -> void: pass)
	menu.clear_items()
	assert(menu._builtins.get_child_count() == builtin_rows,
		"clear_items() で音量の行まで消えた")

	# つまみの行は、動かしている最中に渡る。決定を待たせると音を合わせられない。
	var slid: Array = []
	var slider: HSlider = menu.add_slider("つまみ",
		func() -> float: return 0.5,
		func(value: float) -> void: slid.append(value), 0.0, 1.0, 0.1)
	assert(is_equal_approx(slider.value, 0.5), "はじめの値が %f" % slider.value)
	slider.value = 0.8
	assert(slid.size() == 1 and is_equal_approx(slid[0], 0.8),
		"動かしても渡らない: %s" % str(slid))

	# 釦は隠せる。撮影や配信のときに使う。
	menu.set_button_visible(false)
	assert(not menu._button.visible, "隠れない")

	print("知らせ=%s 数=%f 選び=%d" % [str(toggles), stored[0], chosen[0]])
	print("GMORN DEBUG MENU VERIFY: PASS")
	quit(0)
