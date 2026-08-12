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
| `add_separator()` | 区切り線 | `HSeparator` |

`add_number()` の行は、板を開くたびに `getter` を読み直して表示へ戻す。開いている間に外で値が変わることがあるためである。

### 4. その他の口

| 呼び出し | 何をするか |
| --- | --- |
| `open()` / `close()` / `toggle()` | 板の開け閉め |
| `is_open()` | いま開いているか |
| `set_status(message)` | 板の下の一行を書き換える |
| `clear_items()` | 足した項目をすべて外す。場面が変わったときに使う |
| `set_button_visible(value)` | 隅の釦を出し入れする |
| `panel_toggled(opened)` | 開け閉めのたびに流れる |

### 5. 動かし方を変える

| 項目 | プロジェクト設定 | 環境変数 | 既定 |
| --- | --- | --- | --- |
| 板を作るか | `gmorn_debug_menu/enabled` | `GMORN_DEBUG_MENU_DISABLED=1` で切る | `true` |
| 画面が無くても作るか | `gmorn_debug_menu/build_when_headless` | — | `false` |
| 釦を置く隅 | `gmorn_debug_menu/button_corner` | — | `top_right` |
| 釦の大きさ | `gmorn_debug_menu/button_width` / `button_height` | — | `40` / `40` |
| 縁からの間 | `gmorn_debug_menu/button_margin_x` / `button_margin_y` | — | `12` / `12` |
| 釦の濃さ | `gmorn_debug_menu/button_alpha` | — | `0.82` |
| 板の大きさ | `gmorn_debug_menu/panel_width` / `panel_height` | — | `420` / `520` |
| 板の色 | `gmorn_debug_menu/panel_color` / `panel_border_color` | — | 濃紫 / 桃 |

同じ隅に別の釦（[GMornIssueMaker](https://github.com/TsukumiStudio/GMornIssueMaker) の不具合報告など）があるときは、`button_margin_y` を縦にずらして重なりを避ける。

### 手を入れる

`verify.sh` で、項目の足し方と二度押しの構えを確かめられる。板を作らない側でも呼び出しが通ることも見る。

```
./verify.sh
```

## ライセンス

Unlicense（パブリックドメイン）。
