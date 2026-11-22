# Windows Helper

Windows Helper is an AutoHotkey v1 tray app with three global shortcuts.

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+A | Toggle borderless fullscreen on the active window's monitor. Each window restores to its original style and placement. |
| Scroll Lock | Open the Windows screen snipping overlay. |
| Pause | Request Windows sleep. The tray shows an error if Windows rejects the request. |

Download `WindowsHelper.exe` from [Releases](https://github.com/notuxius/windows-helper/releases) and run it. To run from source, open `Code.ahk` with AutoHotkey v1.1.33 or later in the v1.1 series.

## Build

1. Install [AutoHotkey v1.1](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v1.1.37.02) with the Unicode 64-bit runtime and [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases).
2. Open PowerShell in the repository root and run the following command. Adjust the paths if you installed the tools elsewhere.

   ```powershell
   Start-Process -Wait -FilePath 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' `
       -ArgumentList '/in "Code.ahk" /out "WindowsHelper.exe" /base "C:\Program Files\AutoHotkey\AutoHotkeyU64.exe" /icon "Icon.ico"'
   ```

3. Run the resulting `WindowsHelper.exe` and check for the Windows Helper tray icon.

## Smoke test

1. Open two resizable windows at different sizes and positions. Press **Ctrl+Alt+A** on each, then switch back and toggle each off. Both should return to their original size, position, and frame. Repeat with a maximized window and an already-borderless window. Hold the shortcut down once and check that it toggles only once.
2. Move one window to a secondary monitor and toggle it. It should fill that monitor and restore to its previous position there. If available, use monitors with different scaling or a secondary monitor positioned to the left of the primary.
3. Toggle a window to fullscreen, then choose **Exit** from the Windows Helper tray menu. Check that the window restores, then relaunch the app.
4. Press **Scroll Lock**, verify that the snipping overlay appears, and press **Esc** to dismiss it.
5. On a machine where you can safely interrupt your session, press **Pause**. If sleep is available to your account, the machine should sleep and resume normally. If Windows rejects the request, check for the error notification.
