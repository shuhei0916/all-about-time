# Runs a program on a separate, invisible Windows desktop and waits for it to exit.
#
# Used by screenshot.sh to start Godot with rendering, without showing a window and
# without stealing focus: a window on another desktop never appears on the user's
# desktop and can never become the foreground window.
# (Start flags such as "no activate" or an off-screen position do not help: Godot asks
# for the foreground itself right after start.)
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File run_on_hidden_desktop.ps1
#       -ArgsFile <UTF-8 text file: one argument per line, the first line is the program>
#       -Cwd <working directory> [-TimeoutSeconds 120]
#
# Exit code: the program's exit code, or 124 on timeout (the program is killed).
# The program's standard output is not captured; let it write to a log file instead.
#
# NOTE: keep this file ASCII only. Windows PowerShell 5.1 misreads UTF-8 without BOM.
param(
    [Parameter(Mandatory = $true)][string]$ArgsFile,
    [Parameter(Mandatory = $true)][string]$Cwd,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class HiddenDesktopRunner {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX; public int dwY; public int dwXSize; public int dwYSize;
        public int dwXCountChars; public int dwYCountChars; public int dwFillAttribute;
        public int dwFlags; public short wShowWindow; public short cbReserved2;
        public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit,
        int flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr sa);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr h);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h, int code);
    [DllImport("kernel32.dll")] static extern int WaitForSingleObject(IntPtr h, int ms);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out int code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

    const uint GENERIC_ALL = 0x10000000;
    const int WAIT_OBJECT_0 = 0;

    // Runs cmdline on a new desktop and waits. Returns the exit code, or -2 on timeout (process is killed).
    public static int Run(string cmdline, string cwd, string desktopName, int timeoutMs) {
        IntPtr desktop = CreateDesktop(desktopName, IntPtr.Zero, IntPtr.Zero, 0, GENERIC_ALL, IntPtr.Zero);
        if (desktop == IntPtr.Zero)
            throw new Exception("CreateDesktop failed: " + Marshal.GetLastWin32Error());
        try {
            var si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            si.lpDesktop = "WinSta0\\" + desktopName;
            PROCESS_INFORMATION pi;
            if (!CreateProcess(null, new StringBuilder(cmdline), IntPtr.Zero, IntPtr.Zero, false, 0,
                    IntPtr.Zero, cwd, ref si, out pi))
                throw new Exception("CreateProcess failed: " + Marshal.GetLastWin32Error());
            try {
                if (WaitForSingleObject(pi.hProcess, timeoutMs) != WAIT_OBJECT_0) {
                    TerminateProcess(pi.hProcess, 1);
                    WaitForSingleObject(pi.hProcess, 5000);
                    return -2;
                }
                int code;
                GetExitCodeProcess(pi.hProcess, out code);
                return code;
            } finally {
                CloseHandle(pi.hThread);
                CloseHandle(pi.hProcess);
            }
        } finally {
            CloseDesktop(desktop);
        }
    }
}
'@

$arguments = @(Get-Content -LiteralPath $ArgsFile -Encoding UTF8 | Where-Object { $_ -ne "" })
if ($arguments.Count -eq 0) { throw "no program in $ArgsFile" }
$cmd = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join " "

$code = [HiddenDesktopRunner]::Run($cmd, $Cwd, "godot-run-$PID", $TimeoutSeconds * 1000)
if ($code -eq -2) {
    Write-Output "FAILED: timed out after $TimeoutSeconds s (process killed)"
    exit 124
}
exit $code
