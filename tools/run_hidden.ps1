<#
Godot を、窓を一度も画面に出さずに起動し、スクリプトを動かす。画面の撮影など、描画が要る時に使う。

  powershell -ExecutionPolicy Bypass -File tools/run_hidden.ps1 -Script <スクリプト> [-Resolution 1280x720] [-TimeoutSec 120]

- --headless は描画を dummy に固定するので、絵を撮れない。代わりに、Windows に窓を隠したまま
  起動させる(Start-Process -WindowStyle Hidden)。隠した窓でも描画は続き、タスクバーにも出ない。
- 隠した窓でも、Godot は起動時に手前の窓(フォアグラウンド)を取ることがある。取られたら、
  起動前に手前にあった窓へすぐに戻す。
  (no_focus の設定で取らせない手もあるが、そうすると Godot は隠す指定を無視して窓を見せてしまう)
- スクリプトの中で窓を動かしたり最小化したりしない(見えてしまう)。
- 隠した窓では標準出力が見えないので、--log-file に書かせ、終わったら表示する。
- 時間内に終わらなければ、ここで起動した Godot だけを PID で止める(名前では止めない)。
#>
param(
	[Parameter(Mandatory = $true)][string]$Script,
	[string]$Resolution = "1280x720",
	[int]$TimeoutSec = 120,
	[string]$Godot = "C:\tools\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ForegroundGuard {
	[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
	public static uint OwnerOf(IntPtr window) {
		uint processId;
		GetWindowThreadProcessId(window, out processId);
		return processId;
	}
}
"@
$project = Split-Path -Parent $PSScriptRoot
$log = Join-Path ([IO.Path]::GetTempPath()) ("godot_hidden_{0}.log" -f [Guid]::NewGuid())
$arguments = @("--path", "`"$project`"", "--resolution", $Resolution, "--log-file", "`"$log`"", "-s", "`"$Script`"")
$previous = [ForegroundGuard]::GetForegroundWindow()
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
$clock = [Diagnostics.Stopwatch]::StartNew()
$restored = 0
while (-not $process.HasExited -and $clock.Elapsed.TotalSeconds -lt $TimeoutSec) {
	$foreground = [ForegroundGuard]::GetForegroundWindow()
	if ($foreground -ne [IntPtr]::Zero -and [ForegroundGuard]::OwnerOf($foreground) -eq $process.Id) {
		if ($previous -ne [IntPtr]::Zero -and [ForegroundGuard]::SetForegroundWindow($previous)) {
			$restored += 1
		}
	} elseif ($foreground -ne [IntPtr]::Zero) {
		# 使っている人が別の窓へ移ったら、戻す先もそちらにする。
		$previous = $foreground
	}
	Start-Sleep -Milliseconds 2
}
if (-not $process.HasExited) {
	Stop-Process -Id $process.Id -Confirm:$false
	Write-Output "時間切れ: 起動した Godot (PID $($process.Id)) を止めた"
}
if (Test-Path $log) {
	Get-Content -Path $log -Encoding UTF8
	Remove-Item $log
}
if ($restored -gt 0) {
	Write-Output "Godot に取られた手前の窓を $restored 回、元の窓へ戻した"
}
exit $process.ExitCode
