#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode "Mouse", "Screen"

; ── Global brush/eraser size ──────────────────
global gBrushSize := 20   ; diameter in pixels

; ── Hotkey ───────────────────────────────────
^!s:: OpenSizeSlider()

; ═════════════════════════════════════════════
;  SIZE SLIDER
; ═════════════════════════════════════════════
global gSliderGui  := 0
global gSliderHWND := 0

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global gSliderHWND
    if (hwnd = gSliderHWND)
        PostMessage(0x00A1, 2, 0, , gSliderHWND)
}

OpenSizeSlider() {
    global gSliderGui, gSliderHWND, gBrushSize

    ; Toggle off if already open
    if IsObject(gSliderGui) {
        gSliderGui.Destroy()
        gSliderGui := 0
        return
    }

    MouseGetPos(&cx, &cy)

    winW := 50
    winH := 220

    gSliderGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    gSliderGui.BackColor := "1E1E1E"
    gSliderGui.Show("w" winW " h" winH " Hide")
    gSliderHWND := gSliderGui.Hwnd

    ; Position at cursor using absolute screen coords
    WinMove(cx, cy - (winH // 2), , , gSliderHWND)

    ; ── Close button ──────────────────────────
    gSliderGui.SetFont("s11 cGray Bold", "Segoe UI")
    closeBtn := gSliderGui.Add("Text", "x0 y4 w50 h24 Center +0x100", "✕")
    closeBtn.OnEvent("Click", (*) {
        global gSliderGui
        gSliderGui.Destroy()
        gSliderGui := 0
    })

    ; ── Size readout ──────────────────────────
    gSliderGui.SetFont("s8 cWhite", "Segoe UI")
    sizeLabel := gSliderGui.Add("Text", "x5 y34 w40 Center", gBrushSize)

    ; ── Vertical slider ───────────────────────
    slider := gSliderGui.Add("Slider",
        "x15 y58 w20 h140 Vertical Invert Range1-100 NoTicks", gBrushSize)

    slider.OnEvent("Change", (*) {
        global gBrushSize
        gBrushSize := slider.Value
        sizeLabel.Value := slider.Value
    })

    ; ── Drag to move ──────────────────────────
    OnMessage(0x0201, WM_LBUTTONDOWN)

    WinShow(gSliderHWND)
}
