#!/bin/sh
# GUTのテストをヘッドレスで実行する。
# class_name の登録キャッシュ(.godot/global_script_class_cache.cfg)は
# ヘッドレス実行だけでは更新されないため、先に --import で更新してから走らせる。
cd "$(dirname "$0")"
GODOT="/c/Users/shuhe/Godot/godot.exe"
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
