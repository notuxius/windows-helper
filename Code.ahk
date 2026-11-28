; Copyright (C) 2026 Alexander Mentyu
; SPDX-License-Identifier: GPL-2.0-only
; See LICENSE for the full terms and warranty disclaimer.

#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
#UseHook On

Menu, Tray, Tip, Windows Helper
fullscreenWindows := {}
windowMarker := "WindowsHelper.Fullscreen." DllCall("GetCurrentProcessId", "UInt")
OnExit("RestoreFullscreenWindows")
return

^!a::
    Critical
    ToggleFullscreen(WinExist("A"))
    Critical, Off
    KeyWait, a
return

ScrollLock::#+s

Pause::
    error := RequestSleep()
    if (error)
        TrayTip, Windows Helper, Sleep request failed (Windows error %error%)., 5, 3
return

ToggleFullscreen(hwnd)
{
    global fullscreenWindows, windowMarker
    static frameStyle := 0xC40000, edgeStyle := 0x20301
    static showStateStyle := 0x21000000 ; WS_MINIMIZE | WS_MAXIMIZE
    static frameChanged := 0x34 ; SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOZORDER

    if (!hwnd)
        return

    ; A destroyed window loses the marker even if Windows reuses its handle.
    for savedHwnd in fullscreenWindows.Clone()
        if (!DllCall("GetPropW", "Ptr", savedHwnd, "WStr", windowMarker, "Ptr"))
            fullscreenWindows.Delete(savedHwnd)

    if (fullscreenWindows.HasKey(hwnd))
    {
        RestoreWindow(hwnd, fullscreenWindows[hwnd])
        return
    }

    monitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    VarSetCapacity(info, 40, 0) ; MONITORINFO
    NumPut(40, info, 0, "UInt")
    if (!DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", &info))
        return

    state := {style: DllCall("GetWindowLongW", "Ptr", hwnd, "Int", -16, "UInt")
            , exStyle: DllCall("GetWindowLongW", "Ptr", hwnd, "Int", -20, "UInt")}
    state.SetCapacity("placement", 44) ; WINDOWPLACEMENT
    placement := state.GetAddress("placement")
    NumPut(44, placement + 0, 0, "UInt")
    if (!DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", placement)
        || !DllCall("SetPropW", "Ptr", hwnd, "WStr", windowMarker, "Ptr", 1))
        return

    fullscreenWindows[hwnd] := state
    if (state.style & showStateStyle)
        DllCall("ShowWindow", "Ptr", hwnd, "Int", 9) ; SW_RESTORE

    left := NumGet(info, 4, "Int")
    top := NumGet(info, 8, "Int")
    width := NumGet(info, 12, "Int") - left
    height := NumGet(info, 16, "Int") - top
    if (!SetWindowStyle(hwnd, -16, state.style & ~(frameStyle | showStateStyle))
        || !SetWindowStyle(hwnd, -20, state.exStyle & ~edgeStyle)
        || !DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", left, "Int", top
                  , "Int", width, "Int", height, "UInt", frameChanged))
        RestoreWindow(hwnd, state)
}

SetWindowStyle(hwnd, index, style)
{
    DllCall("SetLastError", "UInt", 0)
    previous := DllCall("SetWindowLongW", "Ptr", hwnd, "Int", index, "UInt", style, "UInt")
    return previous || !A_LastError
}

RestoreWindow(hwnd, state)
{
    global fullscreenWindows, windowMarker
    static showStateStyle := 0x21000000 ; WS_MINIMIZE | WS_MAXIMIZE
    static refreshFrame := 0x37 ; Frame changed, with position, size, activation, and Z order preserved.

    if (!DllCall("GetPropW", "Ptr", hwnd, "WStr", windowMarker, "Ptr"))
        return

    ; SetWindowPlacement restores the show state as well as the normal bounds.
    currentStyle := DllCall("GetWindowLongW", "Ptr", hwnd, "Int", -16, "UInt")
    restoredStyle := (state.style & ~showStateStyle) | (currentStyle & showStateStyle)
    if (!SetWindowStyle(hwnd, -16, restoredStyle)
        || !SetWindowStyle(hwnd, -20, state.exStyle)
        || !DllCall("SetWindowPlacement", "Ptr", hwnd, "Ptr", state.GetAddress("placement"))
        || !DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0
                  , "Int", 0, "Int", 0, "UInt", refreshFrame))
        return

    DllCall("RemovePropW", "Ptr", hwnd, "WStr", windowMarker, "Ptr")
    fullscreenWindows.Delete(hwnd)
}

RestoreFullscreenWindows(exitReason, exitCode)
{
    global fullscreenWindows
    for hwnd, state in fullscreenWindows.Clone()
        RestoreWindow(hwnd, state)
}

RequestSleep()
{
    static tokenAccess := 0x28 ; TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY
    static privilegeSize := 16 ; TOKEN_PRIVILEGES with one LUID_AND_ATTRIBUTES
    static genericFailure := 31 ; ERROR_GEN_FAILURE

    process := DllCall("GetCurrentProcess", "Ptr")
    if (!DllCall("Advapi32\OpenProcessToken", "Ptr", process, "UInt", tokenAccess, "PtrP", token))
        return A_LastError ? A_LastError : genericFailure

    try
    {
        VarSetCapacity(privilege, privilegeSize, 0)
        NumPut(1, privilege, 0, "UInt")
        if (!DllCall("Advapi32\LookupPrivilegeValueW", "Ptr", 0, "WStr", "SeShutdownPrivilege"
                   , "Ptr", &privilege + 4))
            return A_LastError ? A_LastError : genericFailure

        NumPut(2, privilege, 12, "UInt") ; SE_PRIVILEGE_ENABLED
        VarSetCapacity(previous, privilegeSize, 0)
        if (!DllCall("Advapi32\AdjustTokenPrivileges", "Ptr", token, "Int", 0, "Ptr", &privilege
                   , "UInt", privilegeSize, "Ptr", &previous, "UIntP", previousSize) || A_LastError)
            return A_LastError ? A_LastError : genericFailure

        try
        {
            if (DllCall("PowrProf\SetSuspendState", "UChar", 0, "UChar", 0, "UChar", 0, "UChar"))
                return 0
            return A_LastError ? A_LastError : genericFailure
        }
        finally
        {
            DllCall("Advapi32\AdjustTokenPrivileges", "Ptr", token, "Int", 0, "Ptr", &previous
                  , "UInt", 0, "Ptr", 0, "Ptr", 0)
        }
    }
    finally
    {
        DllCall("CloseHandle", "Ptr", token)
    }
}
