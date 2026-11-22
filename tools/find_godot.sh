#!/usr/bin/env bash
# Godot 実行ファイルのパスを標準出力に1行で返す。見つからなければ exit 1。
# 探索順: $GODOT → PATH 上の godot/godot4 → よくある設置場所
set -u

if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then
	echo "$GODOT"; exit 0
fi

for name in godot godot4 Godot; do
	if p=$(command -v "$name" 2>/dev/null); then
		echo "$p"; exit 0
	fi
done

# Windows はコンソール版（*_console.exe）を優先する（標準出力が取れるため）
for pattern in \
	"/c/Tools/Godot*/Godot*_console.exe" \
	"/c/Tools/Godot*_console.exe" \
	"$HOME/scoop/apps/godot/current/godot*_console.exe" \
	"/c/Program Files/Godot*/Godot*_console.exe" \
	"$HOME/Desktop/Godot*/Godot*_console.exe" \
	"$HOME/Downloads/Godot*/Godot*_console.exe" \
	"/usr/local/bin/godot*" \
	"/opt/godot*/godot*" \
	"/Applications/Godot.app/Contents/MacOS/Godot"; do
	# shellcheck disable=SC2086
	for p in $pattern; do
		if [ -x "$p" ] || [ -f "$p" ]; then
			echo "$p"; exit 0
		fi
	done
done

echo "Godot が見つかりません。環境変数 GODOT に実行ファイルのパスを設定してください。" >&2
exit 1
