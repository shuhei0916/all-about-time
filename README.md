# all-about-time
映画「TIME」にインスパイアされた、プレイヤー寿命が０になると死ぬゲームを開発します。

## テストの実行
`godot` コマンド（Godot 4.7 の console 版）が通る状態で、プロジェクト直下で実行する。

```powershell
godot --headless --import; godot --headless -s addons/gut/gut_cmdln.gd
```

設定はGUTの既定どおり `res://.gutconfig.json` から読まれる。

先に `--import` するのは、`class_name` の登録キャッシュ(`.godot/global_script_class_cache.cfg`)がヘッドレス実行だけでは更新されず、新しく追加したクラスが認識されないため。
