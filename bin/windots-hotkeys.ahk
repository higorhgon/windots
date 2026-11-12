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
