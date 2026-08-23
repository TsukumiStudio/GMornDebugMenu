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

**板の大きさは目安である。板は必ず画面の中に収まる。** 行を足すのは作品側で、板を作った後に足される。指定した幅より広い行が1つでも来ると `PanelContainer` はその最小の幅まで広がるので、指定をそのまま守ると**はみ出したぶんが画面の外へ出る**（実際に、取り込んだ作品で右端が画面より 59px 外に出ていた）。

開くたびに次の順で置き直す。

1. 中身が指定より広ければ、入るところまで広げる
2. 画面に入らなければ、そこで止めて中を流す（横も縦も）
3. 収めたうえで、画面の外へ出ない場所へ置く

画面の大きさが変わったときも置き直すので、窓を縮めても全画面へ切り替えても板は画面の中に残る。

**日本語などを出すなら書体を指定する。** Godotの既定の書体はASCIIしか持たない。卓上では実行環境の書体が肩代わりするため気付けないが、肩代わりの無い環境（Webへ書き出したもの）では文字がすべて豆腐になる。実際に配ったWeb版で、板の項目名が全部四角になっていた。

```
[gmorn_debug_menu]

font_path="res://assets/fonts/myfont.otf"
font_size=25
```

`gui/theme/custom_font` をプロジェクト全体で指定してあれば、何も書かなくてもそれを借りる。

同じ隅に別の釦（[GMornIssueMaker](https://github.com/TsukumiStudio/GMornIssueMaker) の不具合報告など）があるときは、`button_margin_y` を縦にずらして重なりを避ける。

### 手を入れる

`verify.sh` で、項目の足し方と二度押しの構えを確かめられる。板を作らない側でも呼び出しが通ることも見る。

```
./verify.sh
```

## ライセンス

Unlicense（パブリックドメイン）。
