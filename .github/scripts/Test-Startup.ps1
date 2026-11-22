[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
$executable = (Get-Item -LiteralPath $Path).FullName

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WindowsHelperStartup
{
    private delegate bool WindowVisitor(IntPtr window, IntPtr argument);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(WindowVisitor visitor, IntPtr argument);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr window, StringBuilder className, int capacity);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wParam, IntPtr lParam,
        uint flags, uint timeout, out UIntPtr result);

    public static bool IsResponsive(uint processId)
    {
        IntPtr mainWindow = IntPtr.Zero;
        bool hasDialog = false;
        var className = new StringBuilder(256);
        bool enumerated = EnumWindows((window, argument) =>
        {
            GetWindowThreadProcessId(window, out uint owner);
            if (owner != processId) return true;

            if (GetClassName(window, className, className.Capacity) == 0) return true;
            string name = className.ToString();
            if (name == "AutoHotkey") mainWindow = window;
            if (name == "#32770") hasDialog = true;
            return true;
        }, IntPtr.Zero);

        if (!enumerated) return false;
        if (hasDialog)
            throw new InvalidOperationException("The executable opened a startup dialog.");
        if (mainWindow == IntPtr.Zero)
            return false;

        // WM_NULL checks the message loop without invoking a shortcut.
        const uint flags = 0x0002 | 0x0020; // SMTO_ABORTIFHUNG | SMTO_ERRORONEXIT
        return SendMessageTimeout(mainWindow, 0, IntPtr.Zero, IntPtr.Zero, flags, 500, out _) != IntPtr.Zero;
    }
}
'@

$process = Start-Process -FilePath $executable -PassThru -WindowStyle Hidden
try {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt 10) {
        $responding = [WindowsHelperStartup]::IsResponsive($process.Id)
        if ($process.HasExited) {
            throw "The executable exited during startup (exit code $($process.ExitCode))."
        }
        if ($responding) {
            Write-Output 'WindowsHelper.exe started and responded to a window message.'
            return
        }
        Start-Sleep -Milliseconds 100
    }
    throw 'WindowsHelper.exe did not respond within 10 seconds of launch.'
}
finally {
    if (!$process.HasExited) {
        Stop-Process -InputObject $process -ErrorAction SilentlyContinue
    }
    $exited = $process.WaitForExit(3000)
    $process.Dispose()
    if (!$exited) { throw 'Could not stop the startup smoke-test process.' }
}
