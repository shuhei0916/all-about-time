#!/usr/bin/env bash
# 描画ありでシーンを起動し、入力シナリオを流してスクリーンショットを撮る。
# 引数は dump_tree.sh と同じ。撮影は --do の中の shot:<絶対パス.png> ステップで行う。
#   screenshot.sh "--do=wait:10;shot:C:/tmp/a.png" --depth=0
# ウィンドウの大きさは環境変数 RESOLUTION で決まる（既定 1280x720）。
#
# Windows では、見えない別のデスクトップでゲームを起動する（run_on_hidden_desktop.ps1）。
# ウィンドウは画面に出ず、フォーカスも奪わないので、ほかの作業の邪魔にならない。
# 環境変数 TIMEOUT（秒、既定 120）を過ぎたら強制終了する。
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
GODOT_BIN=$("$SCRIPT_DIR/find_godot.sh")
RESOLUTION=${RESOLUTION:-1280x720}
TIMEOUT=${TIMEOUT:-120}

cd "$PROJECT_DIR"
"$GODOT_BIN" --headless --import >/dev/null 2>&1 || true

if ! command -v cygpath >/dev/null 2>&1 || ! command -v powershell >/dev/null 2>&1; then
	# Windows 以外: 普通に起動する（ウィンドウが一瞬開く）
	"$GODOT_BIN" --resolution "$RESOLUTION" --script res://tools/dump_scene_tree.gd -- "$@"
	exit $?
fi

# コンソール版は別のコンソール窓を伴うので、あればウィンドウ版の実行ファイルを使う
GUI_BIN=${GODOT_BIN/_console/}
[ -f "$GUI_BIN" ] || GUI_BIN=$GODOT_BIN

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
LOG_FILE="$WORK_DIR/godot.log"
ARGS_FILE="$WORK_DIR/args.txt"
# 見えないデスクトップのプロセスの標準出力は受け取れないので、ログファイルに書かせてあとで出す
{
	cygpath -w "$GUI_BIN"
	echo "--path"
	cygpath -w "$PROJECT_DIR"
	echo "--log-file"
	cygpath -w "$LOG_FILE"
	echo "--resolution"
	echo "$RESOLUTION"
	echo "--script"
	echo "res://tools/dump_scene_tree.gd"
	echo "--"
	for arg in "$@"; do
		echo "$arg"
	done
} >"$ARGS_FILE"

status=0
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$SCRIPT_DIR/run_on_hidden_desktop.ps1")" \
	-ArgsFile "$(cygpath -w "$ARGS_FILE")" -Cwd "$(cygpath -w "$PROJECT_DIR")" \
	-TimeoutSeconds "$TIMEOUT" || status=$?
[ -f "$LOG_FILE" ] && cat "$LOG_FILE"
exit $status
