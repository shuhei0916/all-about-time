#!/usr/bin/env bash
# シーンをヘッドレスで起動し、入力を流し込んだあとのシーンツリーを出力する。
# 引数は tools/dump_scene_tree.gd にそのまま渡す（使い方は SKILL.md 参照）
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
GODOT_BIN=$("$SCRIPT_DIR/find_godot.sh")

cd "$PROJECT_DIR"
"$GODOT_BIN" --headless --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --script res://tools/dump_scene_tree.gd -- "$@"
