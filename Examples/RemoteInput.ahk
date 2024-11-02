#Requires AutoHotkey v2.0

A_WorkingDir := A_ScriptDir  

targetWindow := WinExist("ahk_exe runelite.exe")


MyTip("FUck off! " targetWindow)
; 700, 330
clickX := 700
clickY := 330


WinGetPos(&winX, &winY, , , "ahk_id " targetWindow)
screenX := winX + clickX
screenY := winY + clickY

; Create a POINT structure to hold the coordinates
VarSetCapacity(pt, 8, 0)
NumPut(clickX, pt, 0, "UInt")
NumPut(clickY, pt, 4, "UInt")

; Send a left mouse click to the target window
DllCall("user32\SendMessage"
        , "ptr", targetWindow
        , "uint", 0x201  ; WM_LBUTTONDOWN
        , "wparam", 1    ; Left mouse button down
        , "ptr", &pt, "int")

DllCall("user32\SendMessage"
        , "ptr", targetWindow
        , "uint", 0x202  ; WM_LBUTTONUP
        , "wparam", 0    ; Left mouse button up
        , "ptr", &pt, "int")







MyTip(str:="Tooltip yo!", ms:=2500) {
    ToolTip(str)
    SetTimer(RemoveTooltip, ms)
}

RemoveTooltip() {
    Tooltip  ; Remove the tooltip
}