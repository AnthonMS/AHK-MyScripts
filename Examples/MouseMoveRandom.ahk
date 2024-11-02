#Requires AutoHotkey v2.0


; #Include ../Lib/v2/Helpers.ahk
#Include <RandomBezier>

MouseMoveRandom(1500, 0, params:={relative:true, mode:"really-slow", blockMouse:true})

Insert:: {
    Reload
}
; SleepJittery(5000, params:={blockMouse:false})

MyTip(str:="Tooltip yo!", ms:=2500) {
    ToolTip(str)
    SetTimer(RemoveTooltip, ms)
}
RemoveTooltip() {
    Tooltip  ; Remove the tooltip
}

; MyTip("Mouse idle: " A_TimeIdleMouse)

; BlockInput("MouseMove")
; Sleep(1500)
; MyTip("Mouse idle: " A_TimeIdleMouse)
; Sleep(1500)
; MyTip("Mouse idle: " A_TimeIdleMouse)

; BlockInput(0)



; BlockInput("MouseMove")
; Sleep(1500)

; BlockInput("MouseMoveOff")