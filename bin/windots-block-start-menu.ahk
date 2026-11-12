   #Requires AutoHotkey v2.0
   #SingleInstance Force

   ~LWin::Send "{Blind}{vkE8}"
   ~RWin::Send "{Blind}{vkE8}"

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
