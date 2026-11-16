; windots-hotkeys (AutoHotkey v2)
;
; Hotkeys whkd can't handle. Started at login by windots-refresh-autostart.
;   - Win key never opens the Start menu
;   - Alt+drag moves a window, Alt+right-drag resizes it
;   - Alt+Shift+/ on ABNT2 keyboards (whkd breaks with custom key codes like 0xC1;
;     US / US-Intl "/" stays in whkdrc as oem_2)

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Win key: don't open Start ---
~LWin::Send "{Blind}{vkE8}"
~RWin::Send "{Blind}{vkE8}"

; --- Square corners on every window ---
; Windows 11 rounds the corners of every window, which clashes with komorebi's square borders (border_style "Square").
; There is no setting for it (no registry value, no policy), but DWM takes a corner preference per window, and
; DWMWCP_DONOTROUND (1) makes one square, from any process. A shell hook announces each new top-level window; the ones
; already open (the hidden ones too) are done when this script starts. Not a Windhawk mod: nothing is injected into dwm.exe.
SquareCorners(hwnd) {
    static pref := Buffer(4)
    NumPut("Int", 1, pref)   ; DWMWCP_DONOTROUND
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 33, "Ptr", pref, "Int", 4)   ; DWMWA_WINDOW_CORNER_PREFERENCE
}
OnShellEvent(wParam, lParam, *) {
    if (wParam = 1)   ; HSHELL_WINDOWCREATED
        SquareCorners(lParam)
}
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), OnShellEvent)
; EnumWindows, not WinGetList: komorebi cloaks the windows of the other workspaces, and WinGetList does not list those.
EnumProc := CallbackCreate((hwnd, lParam) => (SquareCorners(hwnd), true), "Fast", 2)
DllCall("EnumWindows", "Ptr", EnumProc, "Ptr", 0)
CallbackFree(EnumProc)

; --- Win+Space: the windots menu, like omarchy's Super+Space ---
; windots-launcher keeps one resident process that listens on a named pipe. Writing to the pipe from here
; opens the menu in a few milliseconds; starting windots-launcher.exe with the verb costs a whole .NET
; process (~300 ms), so that is only the fallback, for when no resident process is running yet.
; whkd can't take a combination with the Windows key. Not installed: windots install launcher.
LauncherMenu(verb, route := "root", fallback := "") {
    DllCall("AllowSetForegroundWindow", "UInt", 0xFFFFFFFF)   ; the resident process may take focus
    h := DllCall("CreateFileW", "Str", "\\.\pipe\windots-launcher", "UInt", 0x40000000, "UInt", 0, "Ptr", 0
        , "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
    if (h != -1) {
        msg := verb "`t" route "`n"
        buf := Buffer(StrPut(msg, "UTF-8") - 1)
        StrPut(msg, buf, "UTF-8")
        ok := DllCall("WriteFile", "Ptr", h, "Ptr", buf, "UInt", buf.Size, "UInt*", &written := 0, "Ptr", 0)
        DllCall("CloseHandle", "Ptr", h)
        if ok
            return
    }
    exe := EnvGet("USERPROFILE") "\.local\share\windots-launcher\windots-launcher.exe"
    if FileExist(exe)
        Run '"' exe '" ' verb ' ' route
    else if (fallback != "")
        Run fallback, , "Hide"   ; the fzf menu, for a machine without the launcher
}

#Space::LauncherMenu("toggle")   ; Menu do windots (menu raiz)

; Win+Alt+Space is the launcher, like omarchy's Super+Alt+Space (apps): it opens listing the apps, most used first,
; and searches apps, commands, themes, calculations, `> shell` and `kill` as you type. Alt+Space is not bound.
#!Space::LauncherMenu("toggle", "launcher")   ; Lançador (apps, comandos, temas, contas)

; These two used to be whkd bindings: whkd starts a pwsh for every hotkey (~300 ms), AutoHotkey is resident.
!k::LauncherMenu("toggle", "keys", "pwsh -NoProfile -Command windots-menu-keybindings")   ; Atalhos de teclado (este menu)
!^+Space::LauncherMenu("toggle", "style.theme", "pwsh -NoProfile -Command windots-menu-theme")   ; Escolher o tema (omarchy: Super+Ctrl+Shift+Space)

; --- Alt+Shift+/ on ABNT2 (VK_ABNT_C1): passwords, like omarchy ---
!+vkC1:: {
    exe := EnvGet("LOCALAPPDATA") "\Programs\omapass\omapass.exe"
    Run "pwsh -NoProfile -Command windots-launch-or-focus --float '^(omapass)$' `"" exe "`"", , "Hide"
}

; --- Alt+drag: move / Alt+right-drag: resize ---
CoordMode "Mouse", "Screen"

!LButton:: {
    MouseGetPos &startX, &startY, &hwnd
    if !hwnd || WinGetMinMax("ahk_id " hwnd) != 0
        return
    WinGetPos &wx, &wy, , , "ahk_id " hwnd
    while GetKeyState("LButton", "P") {
        MouseGetPos &x, &y
        WinMove wx + x - startX, wy + y - startY, , , "ahk_id " hwnd
        Sleep 10
    }
}

!RButton:: {
    MouseGetPos &startX, &startY, &hwnd
    if !hwnd || WinGetMinMax("ahk_id " hwnd) != 0
        return
    WinGetPos &wx, &wy, &ww, &wh, "ahk_id " hwnd
    while GetKeyState("RButton", "P") {
        MouseGetPos &x, &y
        WinMove , , Max(200, ww + x - startX), Max(100, wh + y - startY), "ahk_id " hwnd
        Sleep 10
    }
}
