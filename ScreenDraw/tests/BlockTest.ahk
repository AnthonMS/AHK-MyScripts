#Requires AutoHotkey v2.0
#SingleInstance Force

; While Ctrl+Alt held, LButton and RButton are blocked
^!LButton:: ToolTip("LButton blocked")
^!RButton:: ToolTip("RButton blocked")
