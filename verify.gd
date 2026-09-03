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

## 倍率をしまう置き場を消す。走をまたいで残ると、次の走が前の値を読む。
static func _forget_stored_volume() -> void:
	for path: String in ["user://gmorn_debug_menu.cfg", "user://verify_volume.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script: GDScript = load(MENU_PATH)
	# **前の走で書いたものを消してから始める。**倍率をしまう既定の置き場
	# （`user://gmorn_debug_menu.cfg`）は走をまたいで残るので、この検証が
	# 途中で書いた 0.5 を次の走が読み、「はじめから等倍でない」で落ちていた。
	# 一時の置き場に作るのはプロジェクトだけで、`user://` は作品名から決まる。
	_forget_stored_volume()

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

	# --- エディタのデバッガパネルとの橋渡し ------------------------------------
	#
	# `EngineDebugger` に繋がっていない（ここでの実行はそう）ときも、足した
	# 項目の記録は続く。`_bridge_*` を直に呼んで、繋がったときの動きを確かめる。
	assert(quiet._bridge_items.size() == 3, "板の無い側でも記録が %d 件" % quiet._bridge_items.size())
	var snapshot: Array = quiet._bridge_snapshot()
	assert(snapshot.size() == 3, "一覧の数が %d" % snapshot.size())
	assert(snapshot[0].kind == "button" and snapshot[0].label == "何か",
		"釦の記録が %s" % str(snapshot[0]))
	assert(snapshot[1].kind == "label" and snapshot[1].value == "見るだけ",
		"見るだけの行の記録が %s" % str(snapshot[1]))
	assert(snapshot[2].kind == "toggle" and snapshot[2].value == false,
		"入り切りの行の記録が %s" % str(snapshot[2]))

	# 合言葉に合わない知らせは扱わず false を返す。
	assert(not quiet._bridge_capture("gmorn_debug_menu:何か知らない", []),
		"知らない知らせを扱ってしまった")

	# invoke は釦を押した扱いと同じ道を通す。
	var bridged_pressed: Array = []
	quiet.add_button("橋渡し用", func() -> void: bridged_pressed.append(true))
	var bridged_button_id: int = quiet._bridge_next_id - 1
	assert(quiet._bridge_capture("gmorn_debug_menu:invoke", [bridged_button_id]),
		"invoke を扱わなかった")
	assert(bridged_pressed.size() == 1, "invoke で押されない")

	# set_value は対応する受け口を呼ぶ。
	var bridged_toggled: Array = []
	quiet.add_toggle("橋渡し切替", func(value: bool) -> void: bridged_toggled.append(value))
	var toggle_id: int = quiet._bridge_next_id - 1
	assert(quiet._bridge_capture("gmorn_debug_menu:set_value", [toggle_id, true]),
		"set_value を扱わなかった")
	assert(bridged_toggled == [true], "set_value で切り替わらない: %s" % str(bridged_toggled))

	# 巡回すると、変わった監視値を憶える。
	quiet._bridge_poll_values()
	assert(quiet._bridge_items[toggle_id].last_value == true,
		"巡回しても監視値が更新されない")
	# 変わっていないところをもう一度巡っても落ちない。
	quiet._bridge_poll_values()
	assert(quiet._bridge_items[toggle_id].last_value == true,
		"変わっていないのに監視値が変わった")

	# clear_items() で記録も一緒に消える。次に開いたときに古い id が残らない。
	quiet.clear_items()
	assert(quiet._bridge_items.is_empty(), "clear_items() で橋渡しの記録が残っている")

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

	# 覚えた倍率は、起動し直しても戻る。合わせ直した音量が毎回戻ると、確かめたい
	# 状態を作るのに同じ操作を繰り返させることになる。
	var store := "user://verify_volume.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store))
	ProjectSettings.set_setting("gmorn_debug_menu/volume_store", store)
	var first: CanvasLayer = script.new()
	root.add_child(first)
	await process_frame
	assert(is_equal_approx(first.volume_multiplier(), 1.0),
		"覚えていないのに等倍でない: %f" % first.volume_multiplier())
	first.set_volume_multiplier(0.4)
	assert(FileAccess.file_exists(store), "しまう先が作られていない")
	var second: CanvasLayer = script.new()
	root.add_child(second)
	await process_frame
	assert(is_equal_approx(second.volume_multiplier(), 0.4),
		"覚えた倍率が戻らない: %f" % second.volume_multiplier())
	# 同じ置き場に並べた他の値を消さない。読んでから書くこと。
	var shared := ConfigFile.new()
	shared.load(store)
	shared.set_value("別の節", "残す", 7)
	shared.save(store)
	second.set_volume_multiplier(0.9)
	var reread := ConfigFile.new()
	reread.load(store)
	assert(int(reread.get_value("別の節", "残す", 0)) == 7, "同じ置き場の他の値を消した")
	# 置き場を空にすれば覚えない。
	ProjectSettings.set_setting("gmorn_debug_menu/volume_store", "")
	var forgetful: CanvasLayer = script.new()
	root.add_child(forgetful)
	await process_frame
	assert(is_equal_approx(forgetful.volume_multiplier(), 1.0),
		"覚えない設定なのに読んだ: %f" % forgetful.volume_multiplier())
	forgetful.set_volume_multiplier(0.2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store))
	first.set_volume_multiplier(1.0)
	second.set_volume_multiplier(1.0)
	forgetful.set_volume_multiplier(1.0)

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

	# **どんな行を足しても、板は画面の中に収まる。**
	#
	# 行を足すのは作品側で、板を作った後に足される。指定した大きさより広い行が
	# 1つでも来ると、`PanelContainer` はその最小の幅まで広がる。以前は広がった
	# ぶんがそのまま画面の外へ出ていた（取り込んだ作品で、幅 491px・右端が
	# 1979px と画面より 59px 外に出ていた）。
	ProjectSettings.set_setting("gmorn_debug_menu/font_size", 0)
	# **画面の広さを決めてから測る。**窓の無い実行の既定は 64×64 で、そこでは
	# 何を置いてもはみ出す。遊ぶ人が見る広さに近い値へ広げて確かめる。
	root.size = Vector2i(1280, 720)
	await process_frame
	var view: Vector2 = root.get_visible_rect().size
	assert(view.x >= 1000.0, "画面の広さを決められていない: %s" % view)

	# **広げる側**。指定より中身が広く、それでも画面には入る場合は、中身に
	# 合わせて広げる。指定を 100px まで絞って、必ずこの枝に落とす。
	ProjectSettings.set_setting("gmorn_debug_menu/panel_width", 100.0)
	var widened: CanvasLayer = script.new()
	root.add_child(widened)
	await process_frame
	widened.add_button("そこそこ長い行", func() -> void: pass)
	widened.open()
	await process_frame
	var widened_content: float = widened._stack.get_combined_minimum_size().x \
		+ widened._panel_inner_width()
	assert(widened_content > 100.0 and widened_content < view.x - 24.0,
		"検査の前提が崩れている。中身の幅が %.0f（100 と %.0f の間に無い）" % [
			widened_content, view.x - 24.0])
	assert(absf(widened._panel.size.x - widened_content) <= 1.0,
		"中身に合わせて広がっていない: 板 %.0f / 中身 %.0f" % [
			widened._panel.size.x, widened_content])
	widened.queue_free()
	await process_frame
	ProjectSettings.set_setting("gmorn_debug_menu/panel_width", 420.0)

	# **止める側**。画面に入らないほど中身が広ければ、そこで止めて中を流す。
	# 4隅すべてで見る。寄せ方ごとに座標の出し方が違う。
	for corner: String in ["top_right", "top_left", "bottom_right", "bottom_left"]:
		ProjectSettings.set_setting("gmorn_debug_menu/button_corner", corner)
		var cornered: CanvasLayer = script.new()
		root.add_child(cornered)
		await process_frame
		# 板の指定より明らかに広い行を足す。
		cornered.add_label("と".repeat(400))
		cornered.add_button("も" + "の".repeat(200), func() -> void: pass)
		cornered.open()
		await process_frame
		# **前提を先に確かめる。**足した行が実は狭ければ、板は最初から画面に
		# 収まっていて、直した分岐を1つも通らないまま assert が素通りする
		# （既定の書体は日本語の字を持たないので、字幅は環境で変わる）。
		var content: float = cornered._stack.get_combined_minimum_size().x \
			+ cornered._panel_inner_width()
		assert(content > view.x - 24.0,
			"検査の前提が崩れている。足した行の幅が %.0f で、画面（%.0f）に収まってしまう" % [
				content, view.x - 24.0])
		var panel: PanelContainer = cornered._panel
		var rect := Rect2(panel.position, panel.size)
		assert(rect.position.x >= -0.5 and rect.position.y >= -0.5,
			"%s で板が画面の左上より外にある: %s" % [corner, rect])
		assert(rect.end.x <= view.x + 0.5 and rect.end.y <= view.y + 0.5,
			"%s で板が画面の外へ出ている: 右端 %.0f / 下端 %.0f（画面は %s）" % [
				corner, rect.end.x, rect.end.y, view])
		# 入り切らないぶんは流して見せる。切り落とすと触れない行が出る。
		assert(cornered._scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
			"%s で横に流せない。入り切らない行へ届かなくなる" % corner)
		cornered.queue_free()
		await process_frame
	ProjectSettings.set_setting("gmorn_debug_menu/button_corner", "top_right")

	# **開いたまま画面を縮めても収まる。**窓を掴んで縮める、全画面から戻す、
	# といった場面で置き直せているか。`size_changed` の繋ぎが外れると、
	# 開きっぱなしの板だけが前の広さのまま取り残される。
	var resized: CanvasLayer = script.new()
	root.add_child(resized)
	await process_frame
	resized.add_label("と".repeat(120))
	resized.open()
	await process_frame
	root.size = Vector2i(900, 500)
	await process_frame
	var small_view: Vector2 = root.get_visible_rect().size
	var small_rect := Rect2(resized._panel.position, resized._panel.size)
	assert(small_rect.position.x >= -0.5 and small_rect.position.y >= -0.5,
		"縮めた画面で板が左上より外にある: %s" % small_rect)
	assert(small_rect.end.x <= small_view.x + 0.5 and small_rect.end.y <= small_view.y + 0.5,
		"開いたまま画面を縮めたら板がはみ出した: 右端 %.0f / 下端 %.0f（画面は %s）" % [
			small_rect.end.x, small_rect.end.y, small_view])
	resized.queue_free()
	root.size = Vector2i(1280, 720)
	await process_frame

	# 釦は隠せる。撮影や配信のときに使う。
	menu.set_button_visible(false)
	assert(not menu._button.visible, "隠れない")

	# 走の間に置き土産を残さない。次の走が読んでしまう。
	_forget_stored_volume()

	# --- エディタ常時表示ドックが使う項目UI（gmorn_debug_menu_debugger_tab.gd）--
	#
	# デバッガパネルのタブとエディタのドックは同じこのスクリプトを使い回す。
	# 繋いだ側（本物の EditorDebuggerSession が要る）はエディタの中でしか
	# 確かめられないため、ここでは繋がない側の分岐だけを見る。未接続でも
	# 表示だけ出てエラーにならないことが、非実行時の要件そのもの。
	var tab_script: GDScript = load(
		"res://addons/gmorn_debug_menu/gmorn_debug_menu_debugger_tab.gd")
	var tab: VBoxContainer = tab_script.new()
	root.add_child(tab)
	tab.setup()
	assert(tab._status_label.text == "実行中プロセスなし",
		"未接続の表示が %s" % tab._status_label.text)
	tab.handle_message("gmorn_debug_menu:sync", [[
		{"id": 1, "kind": "button", "label": "何か"},
	]])
	assert(tab._list.get_child_count() == 1, "項目が描かれない")
	tab.on_session_stopped()
	assert(tab._list.get_child_count() == 0, "止まっても一覧が残る")
	assert(tab._status_label.text == "実行中プロセスなし",
		"止まっても未接続の表示に戻らない")
	# セッションが無いままボタンを押しても落ちない（送る先が無いだけ）。
	tab.handle_message("gmorn_debug_menu:sync", [[
		{"id": 2, "kind": "button", "label": "押しても落ちない"},
	]])
	var pressless_button: Button = tab._list.get_child(0).get_child(1)
	pressless_button.pressed.emit()
	tab.queue_free()

	# --- エディタドックのセクション拡張（gmorn_debug_menu_dock.gd）------------
	#
	# 他のアドオンやプロジェクトが `register_section()` / `unregister_section()`
	# で自分のセクションを差し込める。既存の実行中プロセス連携UIも
	# `plugin.gd` から見ればこの仕組みに載る1つのセクションでしかない
	# （`plugin.gd` 自体はエディタでしか動かないためここでは確かめない）。
	var dock_script: GDScript = load(
		"res://addons/gmorn_debug_menu/gmorn_debug_menu_dock.gd")
	var dock: VBoxContainer = dock_script.new()
	root.add_child(dock)
	dock.setup()
	assert(dock.section_ids().is_empty(), "はじめから節がある")

	var section_a := Label.new()
	section_a.text = "節A"
	dock.register_section(&"a", "節A", section_a)
	var section_b := Label.new()
	section_b.text = "節B"
	dock.register_section(&"b", "節B", section_b)
	assert(dock.section_ids() == [&"a", &"b"], "登録した順に並ばない: %s" % str(dock.section_ids()))
	assert(dock.has_section(&"a") and dock.has_section(&"b"), "登録した節が無いと言う")
	assert(_is_under(section_a, dock), "節Aの中身がドックの下に無い")
	assert(_is_under(section_b, dock), "節Bの中身がドックの下に無い")

	# 見出しの釦は折りたたみも兼ねる。押すと中身の表示が切り替わる。
	var header_a: Button = section_a.get_parent().get_child(0)
	assert(header_a.text == "節A", "見出しの文字が %s" % header_a.text)
	assert(section_a.visible, "はじめから畳まれている")
	header_a.toggled.emit(false)
	assert(not section_a.visible, "畳んでも隠れない")
	header_a.toggled.emit(true)
	assert(section_a.visible, "開いても表示されない")

	# 同じ id で登録し直すと、古い方を外して差し替える。並び順は最後尾へ移る
	# （外してから足し直すだけの単純な仕組みなので、元の位置には戻らない）。
	var section_a2 := Label.new()
	section_a2.text = "節A差し替え"
	dock.register_section(&"a", "節A差し替え", section_a2)
	assert(dock.section_ids() == [&"b", &"a"], "差し替え後の並びが %s" % str(dock.section_ids()))
	assert(not _is_under(section_a, dock), "差し替えた古い中身が残っている")
	assert(_is_under(section_a2, dock), "差し替えた新しい中身が無い")
	section_a.queue_free()

	# 外すと一覧から消える。渡した Control 自体は消さず、呼び出し側へ返す。
	dock.unregister_section(&"b")
	assert(dock.section_ids() == [&"a"], "外した後の並びが %s" % str(dock.section_ids()))
	assert(not dock.has_section(&"b"), "外したのに残っていると言う")
	assert(section_b.get_parent() == null, "外した中身がまだ木に居る")
	assert(not section_b.is_queued_for_deletion(), "外しただけで中身を消してしまった")
	section_b.queue_free()

	# 登録していない id を外しても落ちない。
	dock.unregister_section(&"存在しない")
	dock.queue_free()

	print("知らせ=%s 数=%f 選び=%d" % [str(toggles), stored[0], chosen[0]])
	print("GMORN DEBUG MENU VERIFY: PASS")
	quit(0)
