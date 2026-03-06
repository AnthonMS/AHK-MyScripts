#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global arrow := DllCall("LoadCursor", "ptr", 0, "int", 32512, "ptr")
global cursorIds := [
    32512, ; Arrow
    32513, ; IBeam
    32514, ; Wait
    32515, ; Cross
    32516, ; UpArrow
    32640, ; SizeNWSE
    32641, ; SizeNESW
    32642, ; SizeWE
    32643, ; SizeNS
    32644, ; SizeAll
    32645, ; No
    32646, ; Hand (old)
    32648, ; AppStarting
    32649  ; Hand (modern finger pointer)
]

; Using & combinator syntax instead of ^! prefix
; This fires when both Ctrl and Alt are physically held
LCtrl & LAlt:: {
    global arrow, cursorIds
    for id in cursorIds {
        hCur := DllCall("CopyIcon", "ptr", arrow, "ptr")
        DllCall("SetSystemCursor", "ptr", hCur, "uint", id)
    }
}

LCtrl & LAlt Up:: {
    RestoreCursors()
}

OnExit(RestoreCursors)

RestoreCursors(*) {
    DllCall("SystemParametersInfo", "uint", 0x57, "uint", 0, "ptr", 0, "uint", 0)
}
