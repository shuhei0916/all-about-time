# all-about-time
映画「TIME」にインスパイアされた、プレイヤー寿命が０になると死ぬゲームを開発します。

## テストの実行
`godot` コマンド（Godot 4.7 の console 版）が通る状態で、プロジェクト直下で実行する。

```powershell
godot --headless --import; godot --headless -s addons/gut/gut_cmdln.gd
```

設定はGUTの既定どおり `res://.gutconfig.json` から読まれる。

先に `--import` するのは、`class_name` の登録キャッシュ(`.godot/global_script_class_cache.cfg`)がヘッドレス実行だけでは更新されず、新しく追加したクラスが認識されないため。

## 窓を出さずに描画するスクリプトの実行(画面の撮影など)
`--headless` では描画されないので、絵を撮るスクリプトは次で動かす。窓を一度も画面に出さず、作業中の窓から入力も奪わない(しくみは `tools/run_hidden.ps1` の先頭)。

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_hidden.ps1 -Script <スクリプト>
```

## スクリーンショット(見た目の確認)
見た目の確認には `tools/screenshot.sh`(Git Bash)を使う。見えない別のデスクトップで Godot を描画ありで起動する(`tools/run_on_hidden_desktop.ps1`)ので、窓は画面に出ず、フォーカスも奪わない。

```bash
tools/screenshot.sh "--do=wait:30;shot:C:/path/to/out.png" --depth=1
```

- 引数は `tools/dump_scene_tree.gd` にそのまま渡る(使い方はファイルの先頭)。`--do` は `;` 区切りの入力シナリオで、`key:` `action:` `move:` `click:` `wait:` `call:` `script:` などを並べ、`shot:<絶対パス.png>` で画面を保存する。
- 終わるとシーンツリーと `print` の出力がまとめて表示される。
- 解像度は環境変数 `RESOLUTION`(既定 1280x720)、時間切れは `TIMEOUT`(秒、既定 120)。
- 描画の要らない動作確認は、同じ引数で `tools/dump_tree.sh`(ヘッドレス)を使う。
- Godot は `tools/find_godot.sh` が探す(環境変数 `GODOT` → PATH → `C:\Tools\Godot*` など)。
