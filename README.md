# GMornDebugMenu

## 概要

配布したものにも載せられる、画面の隅の釦から開くデバッグ板のGodotアドオン。

デバッグ機能を開発中だけのものにすると、**配ったものに触ってもらったときに状況を作れない**。「その場面を出してください」と頼んでも、遊ぶ側には出し方が分からない。隅の小さな釦から開ける板にして、配布物にもそのまま載せる。

中身（項目）はこの部品では持たない。作品ごとに違うためで、外から足す。

## 動作環境

- Godot 4.x（4.7で確認）
- [GMornBeat](https://github.com/TsukumiStudio/GMornBeat)（無くても動く。あれば板の中の釦だけ拍動から外す）

画面のない実行（`--headless`）では既定で板を作らない。作らない側でも、項目を足す呼び出しはそのまま通る。呼ぶ側に「板があるか」を書かせないためである。

## 何ができるか

- **画像ファイルが要らない**。工具の絵はSVGを実行時に起こす。絵文字は環境の書体に左右されて豆腐になることがあるため、絵そのものを持つ。
- **押し間違いを防ぐ**。`add_confirm_button()` は1度目で構え、決められた時間内にもう1度押したときだけ通す。確認の窓を出す手もあるが、窓は板の上へ重なって位置がずれるうえ、画面の無い実行では出せない。同じ釦の文字を変えるだけなら、どこでも同じに動く。
- **何をしたかが見える**。板の下の一行に結果を返す。押した結果が見えないと、効いたのかどうか分からない。
- **開発用の板は揺れない**。`GMornBeat` で拍動する釦を使っていても、板の中のものは群れから外す。開発用UIまで揺れると読みにくい。
- **隠せる**。`set_button_visible(false)` で釦だけ消える。撮影や配信のときに使う。
- **音量をその場で掛けられる**。板の一番上に音量の行がある。母線の音量そのものではなく**増幅の効果**で掛けるので、作品が自分で音量を変えても倍率は残る。撮影で音を絞る、小さすぎる音を上げて確かめる、といった用途はどの作品でも同じ形で出るため、これだけは部品が持つ。

## 使い方

### 1. 取り込む

アドオン一式をリポジトリ直下へ置いてある。取り込む側の `addons/gmorn_debug_menu` へそのまま submodule として足せる。

```
git submodule add https://github.com/TsukumiStudio/GMornDebugMenu.git addons/gmorn_debug_menu
```

Godotのエディタで「プロジェクト設定 → プラグイン」から `GMornDebugMenu` を有効にする。自動読み込みへ `GMornDebugMenu` が登録される。

**リポジトリ直下に `project.godot` は置かない。** 置くとGodotがそこを別のプロジェクトと見なし、**そのフォルダを丸ごとスキャンから外す**。submoduleとして取り込んだ場合、エディタでは動くのに書き出した実行ファイルにだけアドオンが入らない。

### 2. 項目を足す

```gdscript
func _ready() -> void:
    var menu := get_node_or_null("/root/GMornDebugMenu")
    if menu == null:
        return
    menu.add_number("所持金",
        func() -> float: return float(GameState.money()),
        func(value: float) -> void: GameState.set_money(roundi(value)),
        0.0, 9999999.0)
    menu.add_button("1000円足す", func() -> void: GameState.add_money(1000))
    menu.add_separator()
    menu.add_confirm_button("セーブデータ削除",
        func() -> void: GameState.delete_save_data(), "もう一度押して削除")
```

### 3. 足せる行

| 呼び出し | 何が出るか | 返るもの |
| --- | --- | --- |
| `add_button(label, action)` | 押すと何かする釦 | `Button` |
| `add_confirm_button(label, action, arm_text, seconds)` | 二度押しで通る釦 | `Button` |
| `add_number(label, getter, setter, min, max, step)` | 数を入れて「決定」で渡す行 | `SpinBox` |
| `add_option(label, options, on_selected, selected)` | 選ぶ行。選んだ番号が渡る | `OptionButton` |
| `add_toggle(label, on_toggled, pressed)` | 入り切りの行 | `CheckButton` |
| `add_label(text)` | 見るだけの行 | `Label` |
| `add_slider(label, getter, setter, min, max, step)` | つまみで動かす行。動かしている最中に渡る | `HSlider` |
| `add_separator()` | 区切り線 | `HSeparator` |

`add_slider()` は「決定」を待たない。音量のように、動かしながら結果を確かめたいものは、決定を挟むと合わせられない。決めてから渡したいものは `add_number()` を使う。

`add_number()` の行は、板を開くたびに `getter` を読み直して表示へ戻す。**開いている間に外で値が変えたときは、変えた側から `refresh_numbers()` を呼ぶ。** 読み直さないと、古い値のまま「決定」を押して変更をなかったことにしてしまう。

板は自動読み込みなので、項目を足した側（場面のスクリプトなど）より長生きする。足した側が片付くときは `_exit_tree()` などで `clear_items()` を呼び、シグナルへの繋ぎもそこで外す。呼ばないと、消えたものを捕まえたままの釦が押せる状態で残り、押した瞬間に落ちる。

### 4. 音量を掛ける

板の一番上に音量の行が出る。`0.00` で無音、`1.00` で素のまま。

**母線の音量そのものは書き換えない。**書き換える作りにすると、作品が自分で音量を変えた瞬間に上書きされ、掛けたはずの倍率が消える。代わりに母線へ増幅の効果を積んで、その後ろで必ず掛かるようにしてある。作品がいくら音量を触っても倍率は残る。

**等倍のあいだは何も積まない。**触っていない作品の音の道を変えないためで、倍率を動かしたところで初めて効果が付く。

**倍率は覚える。**`user://gmorn_debug_menu.cfg` へ書き、次に起動したときに戻す。合わせ直した音量が毎回戻ると、確かめたい状態を作るのに同じ操作を繰り返させることになる。書くときは読んでから書くので、同じ置き場に別の値を並べても消えない。覚えさせたくなければ `gmorn_debug_menu/volume_store` を空にする。

この行は `clear_items()` で消えない。作品が場面を切り替えるたびに音量を合わせ直すことになるためである。

外から動かすこともできる。板を作らない実行でもそのまま通る。

```gdscript
var menu := get_node_or_null("/root/GMornDebugMenu")
if menu != null:
    menu.set_volume_multiplier(0.0)   # 撮影のあいだだけ黙らせる
    print(menu.volume_multiplier())
```

### 5. その他の口

| 呼び出し | 何をするか |
| --- | --- |
| `open()` / `close()` / `toggle()` | 板の開け閉め |
| `is_open()` | いま開いているか |
| `set_status(message)` | 板の下の一行を書き換える |
| `clear_items()` | 足した項目をすべて外す。**項目を足した側が片付くときは必ず呼ぶ** |
| `refresh_numbers()` | 数の行をいまの値へ戻す。板を開くときは自動で呼ばれる |
| `set_button_visible(value)` | 隅の釦を出し入れする |
| `panel_toggled(opened)` | 開け閉めのたびに流れる |

### 6. 動かし方を変える

| 項目 | プロジェクト設定 | 環境変数 | 既定 |
| --- | --- | --- | --- |
| 板を作るか | `gmorn_debug_menu/enabled` | `GMORN_DEBUG_MENU_DISABLED=1` で切る | `true` |
| 画面が無くても作るか | `gmorn_debug_menu/build_when_headless` | — | `false` |
| 釦を置く隅 | `gmorn_debug_menu/button_corner` | — | `top_right` |
| 釦の大きさ | `gmorn_debug_menu/button_width` / `button_height` | — | `40` / `40` |
| 縁からの間 | `gmorn_debug_menu/button_margin_x` / `button_margin_y` | — | `12` / `12` |
| 釦の濃さ | `gmorn_debug_menu/button_alpha` | — | `0.82` |
| 板の大きさ（目安） | `gmorn_debug_menu/panel_width` / `panel_height` | — | `420` / `520` |
| 板の色 | `gmorn_debug_menu/panel_color` / `panel_border_color` | — | 濃紫 / 桃 |
| 書体 | `gmorn_debug_menu/font_path` | — | `gui/theme/custom_font` があればそれ |
| 文字の大きさ | `gmorn_debug_menu/font_size` | — | `0`（既定のまま） |
| 音量の行を出すか | `gmorn_debug_menu/volume_row` | — | `true` |
| 音量を掛ける母線 | `gmorn_debug_menu/volume_bus` | — | `Master` |
| 倍率の上限 | `gmorn_debug_menu/volume_max` | — | `2.0` |
| 倍率をしまう置き場 | `gmorn_debug_menu/volume_store` | — | `user://gmorn_debug_menu.cfg`（空で覚えない） |

**板の大きさは目安である。板は画面の中に収まるところまで収める。** 行を足すのは作品側で、板を作った後に足される。指定した幅より広い行が1つでも来ると `PanelContainer` はその最小の幅まで広がるので、指定をそのまま守ると**はみ出したぶんが画面の外へ出る**（実際に、取り込んだ作品で右端が画面より 59px 外に出ていた）。

開くたびに次の順で置き直す。

1. 中身が指定より広ければ、入るところまで広げる
2. 画面に入らなければ、そこで止めて中を流す（横も縦も）
3. 収めたうえで、画面の外へ出ない場所へ置く

画面の大きさが変わったときも置き直すので、窓を縮めても全画面へ切り替えても板は画面の中に残る。開いている最中に行を足した場合は、次に開き直したときに広がる（その間も横へ流せるので画面の外へは出ない）。

**これ以上は縮まない大きさ**（左右の余白と一行ぶん）が画面より大きい極小の画面では、左上だけを守って右下がはみ出す。そこまで狭い画面は縮めようが無い。

**日本語などを出すなら書体を指定する。** Godotの既定の書体はASCIIしか持たない。卓上では実行環境の書体が肩代わりするため気付けないが、肩代わりの無い環境（Webへ書き出したもの）では文字がすべて豆腐になる。実際に配ったWeb版で、板の項目名が全部四角になっていた。

```
[gmorn_debug_menu]

font_path="res://assets/fonts/myfont.otf"
font_size=25
```

`gui/theme/custom_font` をプロジェクト全体で指定してあれば、何も書かなくてもそれを借りる。

同じ隅に別の釦（[GMornIssueMaker](https://github.com/TsukumiStudio/GMornIssueMaker) の不具合報告など）があるときは、`button_margin_y` を縦にずらして重なりを避ける。

### 7. リモート操作の仕組み

エディタから「実行」したとき（`EngineDebugger.is_active()` が真のとき）は、足した項目の一覧と監視値がエディタのデバッガパネルの「GMornDebugMenu」タブへ届く。タブから釦を押す・つまみや数を送る・入り切りを切り替える・選ぶと、実行中のゲームの側で対応する `Callable`（`add_button()` の `action`、`add_number()`/`add_slider()` の `setter`、`add_toggle()` の `on_toggled`、`add_option()` の `on_selected`）がそのまま呼ばれる。実機・書き出したものが手元に無くても、画面を持たないヘッドレスな実行でも、エディタから項目を叩ける。

配布物には `plugin.gd` だけが載る（エディタ拡張なので配布物の中では動かない）。既存の `add_*` 系の呼び出し方・返り値は変わらない。

合言葉は `gmorn_debug_menu`。`EngineDebugger.register_message_capture()`（ランタイム側）と `EditorDebuggerPlugin._has_capture()`（エディタ側）の両方がこの文字列で揃っている。

知らせは `"gmorn_debug_menu:サブコマンド"` の形。

| 向き | サブコマンド | data | いつ流れるか |
| --- | --- | --- | --- |
| ランタイム→エディタ | `sync` | `[items: Array]` | 項目を足したとき・`sync_request` を受けたとき。`items` は `{id, kind, label, value?, options?}` の配列 |
| ランタイム→エディタ | `value` | `[id, value]` | 監視値が変わったとき（0.3秒ごとに巡回して差分だけ送る） |
| ランタイム→エディタ | `status` | `[message]` | `set_status()` が呼ばれたとき |
| ランタイム→エディタ | `clear` | `[]` | `clear_items()` が呼ばれたとき |
| エディタ→ランタイム | `sync_request` | `[]` | パネルのタブを開いた・実行が始まったとき |
| エディタ→ランタイム | `invoke` | `[id]` | 釦を押したとき（`add_button()` / `add_confirm_button()` の行） |
| エディタ→ランタイム | `set_value` | `[id, value]` | つまみ・数・選び・入り切りの行を操作したとき |

`kind` は `button` / `slider` / `number` / `option` / `toggle` / `label` のいずれか。`add_separator()` の区切り線は流さない。

### 8. エディタのドック

プラグインを有効にすると、デバッガパネルのタブと同じ項目一覧・監視値を映すドックがエディタに常時表示される（`EditorPlugin.add_dock()` で足している。既定の置き場所はエディタ右上だが、ドラッグでレイアウトを変えられる）。ツールメニューには何も足さない。パネルを毎回開き直さず、常に見える場所へ置いておける。

- 実行中のプロセスがあれば、そのままデバッガパネルのタブと同じ内容が届く。押す・つまむ・選ぶ・入り切りの操作も同じように実行中のゲームへ届く
- 実行していない、またはまだ繋がっていないときは「実行中プロセスなし」と表示され、エラーは出さない

中身は `gmorn_debug_menu_dock.gd`。複数のセクション（タイトル+Control）を縦に並べる仕組みで、実行中プロセス連携UI（`gmorn_debug_menu_debugger_tab.gd`）は `id = "process"` の既定セクションとしてここへ載っている。繋ぐ先のセッションは `gmorn_debug_menu_debugger_plugin.gd` の `bind_dock()` が選ぶ。

### 9. ドックへセクションを足す

他のアドオンやプロジェクトが、このドックへ自分のセクション（タイトル+Control）を差し込める。Unity版 `MornDebugMenuBase` の派生をデバッグメニューへ並べる仕組みに相当する。

**1. ドックの中身 (`gmorn_debug_menu_dock.gd` のインスタンス) を見つける。**

`GMornDebugMenu` の `plugin.gd` はエディタに入るとき、`Engine.set_meta(&"gmorn_debug_menu_dock", <ドックの中身>)` でドックの中身を印す（エディタから出るとき `Engine.remove_meta()` で外す）。他のアドオンの `plugin.gd` から次のように参照する。

```gdscript
func _enter_tree() -> void:
	if Engine.has_meta(&"gmorn_debug_menu_dock"):
		var dock: Control = Engine.get_meta(&"gmorn_debug_menu_dock")
		dock.register_section(&"my_addon", "自分のアドオン", _build_my_control())
```

`GMornDebugMenu` が無効・未導入のときは `has_meta()` が偽になるので、無くても落ちない作りにする（`GMornDebugMenu` への依存を必須にしない）。

**2. `register_section(id, title, control)` / `unregister_section(id)`**

| 呼び出し | 効き目 |
| --- | --- |
| `register_section(id: StringName, title: String, control: Control)` | `control` を、折りたたみ釦付きの見出し（`title`）と一緒にドックの最後尾へ足す。同じ `id` が既にあれば先に外してから差し替える（**並び順は最後尾へ移る**） |
| `unregister_section(id: StringName)` | 足したセクションを外す。**渡した `control` 自体は消さず、木から外すだけ**に留める。以後の後始末（`queue_free()` など）は呼び出し側が行う。登録していない `id` を渡しても何もしない |
| `has_section(id: StringName) -> bool` | 登録済みか |
| `section_ids() -> Array[StringName]` | いま並んでいるセクションの `id` を登録順で返す |

`control` は呼び出し側が作って渡す（`gmorn_debug_menu_dock.gd` 側では作らない）。`plugin.gd` の `_exit_tree()` でアドオンを外すときは、自分で `unregister_section()` を呼ぶこと。`GMornDebugMenu` 側のドックごと消える場合（`GMornDebugMenu` 自体を無効にしたときなど）は、渡した `control` も一緒に消える。

**3. `.tres` を置くだけで足す（コードを変えない）**

`register_section()` を呼ぶコードを書かなくても、`.tres` を決まった置き場へ足すだけでセクションが増える仕組みがある。Unity版 `MornDebugMenuBase`（`ScriptableObject` 派生を並べる仕組み）の Godot 版に相当する。`plugin.gd` がエディタに入るたびに `gmorn_debug_menu_section_scanner.gd` が置き場を列挙し、見つけた `.tres` を `register_section()` で足す。

手順は次の3つ。

1. `gmorn_debug_menu_section.gd` を継承したスクリプトを書き、`create_control()` をオーバーライドする。

    ```gdscript
    extends "res://addons/gmorn_debug_menu/gmorn_debug_menu_section.gd"

    func create_control() -> Control:
        var label := Label.new()
        label.text = "自分のアドオン"
        return label
    ```

2. Godotのエディタでこのスクリプトを付けた `Resource`（新規リソース → スクリプトを選ぶ）を作り、`.tres` として保存する。Inspectorの `Title` にドックの見出しを入れる。`Section Id` は空でよい（空なら `.tres` のファイル名から作る。他の置き場と被らない `id` にしたいときだけ指定する）。

3. その `.tres` を `gmorn_debug_menu/section_dir`（既定 `res://assets/debug_sections/`）へ置く。エディタを開き直す（またはプラグインを入れ直す）と、ドックへセクションとして並ぶ。

置き場を既定から変えたいときは、`project.godot` へ書く。

```
[gmorn_debug_menu]

section_dir="res://addons/my_project/debug_sections/"
```

置き場が無い、または `.tres` を1つも置いていないプロジェクトでも落ちない。継承していない `.tres` が同じ置き場に紛れ込んでいても無視する。`register_section()` を直に呼ぶ側（上の1・2）とは独立しており、両方を同時に使ってよい。

### 手を入れる

`verify.sh` で、項目の足し方と二度押しの構えを確かめられる。板を作らない側でも呼び出しが通ることも見る。エディタへの橋渡し（`_bridge_*`）も、`EngineDebugger` に繋がっていない前提でここから直に呼んで確かめる。

```
./verify.sh
```

## ライセンス

Unlicense（パブリックドメイン）。
