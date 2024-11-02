#Requires AutoHotkey v2.0

isHolding := false


~LButton:: {
    global isHolding
    if !isHolding {
        ; Start timer when left mouse button is pressed
        SetTimer(HoldMouse, 5000)
    }
}

~LButton Up:: {
    global isHolding
    if isHolding {
        ; If it was held automatically, release it
        Click("D") ; Simulate releasing the hold
        isHolding := false
    } else {
        ; Stop timer if button released manually within 5 seconds
        SetTimer(HoldMouse, 0) ; Use 0 to turn off the timer
    }
}

HoldMouse() {
    global isHolding
    ; If timer triggered, hold mouse automatically
    isHolding := true
    Click("D") ; Simulate holding
    SoundBeep(500, 200) ; Play a 1000 Hz beep for 200 milliseconds to indicate toggle on
    SetTimer(HoldMouse, 0) ; Use 0 to turn off the timer
}