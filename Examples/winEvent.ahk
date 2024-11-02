#Requires AutoHotkey v2.0

#Include ../Lib/v2/Helpers.ahk
#Include <WinEvent>

windowTitle := "RuneLite - katjak4j"

; Register the Minimize event listener
minimizeHook := WinEvent.Minimize(MinimizeCallback, windowTitle)
; Register the Restore event listener
restoreHook := WinEvent.Restore(RestoreCallback, windowTitle)
moveHook := WinEvent.Move(MoveRunelite, windowTitle)

Persistent()

MoveRunelite(eventObj, hWnd, dwmsEventTime) {
    MyTip("window moved")
}
; Callback function for the Minimize event
MinimizeCallback(eventObj, hWnd, dwmsEventTime) {
    MyTip("window minimized true")
}

; Callback function for the Restore event
RestoreCallback(eventObj, hWnd, dwmsEventTime) {
    MyTip("window minimized false")
}