#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode "Mouse", "Screen"

; Global selected color (0xRRGGBB)
global gDrawColor := 0xFF0000   ; default: red

; Hotkey 
^!c:: OpenColorWheel()

global gWheelGui    := 0
global gWheelHWND   := 0
global gWheelBitmap := 0

OpenColorWheel() {
    global gWheelGui, gWheelHWND, gWheelBitmap

    ; Toggle off if already open
    if IsObject(gWheelGui) {
        Hotkey "~LButton Up", WheelClicked, "Off"
        OnMessage(0x000F, WM_PAINT, 0)
        if gWheelBitmap
            DllCall("DeleteObject", "Ptr", gWheelBitmap)
        gWheelBitmap := 0
        gWheelGui.Destroy()
        gWheelGui := 0
        return
    }

    ; Get cursor position in screen coordinates
    MouseGetPos(&cx, &cy)

    outerR  := 90
    innerR  := 34
    padding := 4
    winSize := (outerR + padding) * 2

    ; Create window
    gWheelGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    gWheelGui.BackColor := "000000"
    gWheelGui.Show("w" winSize " h" winSize " Hide")
    gWheelHWND := gWheelGui.Hwnd

    ; Position using absolute screen coordinates
    WinMove(cx - outerR - padding, cy - outerR - padding, , , gWheelHWND)

    ; Clip window to a circle
    hRgn := DllCall("CreateEllipticRgn",
        "Int", 0, "Int", 0, "Int", winSize, "Int", winSize, "Ptr")
    DllCall("SetWindowRgn", "Ptr", gWheelHWND, "Ptr", hRgn, "Int", true)

    ; Pre-render wheel into a stored HBITMAP
    gWheelBitmap := RenderWheel(winSize, outerR, innerR, padding)

    ; Register WM_PAINT handler so Windows paints it whenever ready
    OnMessage(0x000F, WM_PAINT)

    ; Show — WM_PAINT will fire immediately and draw correctly
    WinShow(gWheelHWND)

    ; Select color on mouse button release
    Hotkey "~LButton Up", WheelClicked, "On"
}

; Pre-render wheel into an HBITMAP
RenderWheel(winSize, outerR, innerR, padding) {
    global gDrawColor

    ; Use screen DC as reference for CreateCompatibleBitmap
    screenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    memDC    := DllCall("CreateCompatibleDC", "Ptr", screenDC, "Ptr")
    hbmp     := DllCall("CreateCompatibleBitmap", "Ptr", screenDC, "Int", winSize, "Int", winSize, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", hbmp)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", screenDC)

    ; Fill background black
    rc := Buffer(16, 0)
    NumPut("Int", 0,       rc,  0)
    NumPut("Int", 0,       rc,  4)
    NumPut("Int", winSize, rc,  8)
    NumPut("Int", winSize, rc, 12)
    bgBrush := DllCall("CreateSolidBrush", "UInt", 0x000000, "Ptr")
    DllCall("FillRect", "Ptr", memDC, "Ptr", rc, "Ptr", bgBrush)
    DllCall("DeleteObject", "Ptr", bgBrush)

    cx := outerR + padding
    cy := outerR + padding

    ; Draw 720 wedges (0.5° each) for smooth gradient
    steps := 720
    Loop steps {
        angle := (A_Index - 1) * (360.0 / steps)
        rad1  := (angle - (180.0 / steps)) * 3.14159265358979 / 180
        rad2  := (angle + (180.0 / steps)) * 3.14159265358979 / 180

        x1o := Round(cx + outerR * Cos(rad1))
        y1o := Round(cy + outerR * Sin(rad1))
        x2o := Round(cx + outerR * Cos(rad2))
        y2o := Round(cy + outerR * Sin(rad2))
        x1i := Round(cx + innerR * Cos(rad1))
        y1i := Round(cy + innerR * Sin(rad1))
        x2i := Round(cx + innerR * Cos(rad2))
        y2i := Round(cy + innerR * Sin(rad2))

        bgr := RGBtoBGR(HueToRGB(angle))
        brush := DllCall("CreateSolidBrush", "UInt", bgr, "Ptr")
        pen   := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", bgr, "Ptr")
        DllCall("SelectObject", "Ptr", memDC, "Ptr", brush)
        DllCall("SelectObject", "Ptr", memDC, "Ptr", pen)

        pts := Buffer(32, 0)
        NumPut("Int", x1o, pts,  0), NumPut("Int", y1o, pts,  4)
        NumPut("Int", x2o, pts,  8), NumPut("Int", y2o, pts, 12)
        NumPut("Int", x2i, pts, 16), NumPut("Int", y2i, pts, 20)
        NumPut("Int", x1i, pts, 24), NumPut("Int", y1i, pts, 28)
        DllCall("Polygon", "Ptr", memDC, "Ptr", pts, "Int", 4)

        DllCall("DeleteObject", "Ptr", brush)
        DllCall("DeleteObject", "Ptr", pen)
    }

    ; Center circle showing current selected color
    centerBGR := RGBtoBGR(gDrawColor)
    cBrush := DllCall("CreateSolidBrush", "UInt", centerBGR, "Ptr")
    cPen   := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", 0xCCCCCC, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", cBrush)
    DllCall("SelectObject", "Ptr", memDC, "Ptr", cPen)
    DllCall("Ellipse", "Ptr", memDC,
        "Int", cx - innerR + 3, "Int", cy - innerR + 3,
        "Int", cx + innerR - 3, "Int", cy + innerR - 3)
    DllCall("DeleteObject", "Ptr", cBrush)
    DllCall("DeleteObject", "Ptr", cPen)

    DllCall("DeleteDC", "Ptr", memDC)

    return hbmp
}

; ─────────────────────────────────────────────
;  WM_PAINT handler — fires whenever Windows
;  needs to redraw the wheel window
; ─────────────────────────────────────────────
WM_PAINT(wParam, lParam, msg, hwnd) {
    global gWheelHWND, gWheelBitmap
    if (hwnd != gWheelHWND || !gWheelBitmap)
        return

    ps    := Buffer(64, 0)
    hdc   := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
    memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", gWheelBitmap)

    WinGetPos(, , &ww, &wh, hwnd)
    DllCall("BitBlt",
        "Ptr", hdc,   "Int", 0, "Int", 0, "Int", ww, "Int", wh,
        "Ptr", memDC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)

    DllCall("DeleteDC", "Ptr", memDC)
    DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    return 0
}

; Handle mouse release on the wheel
WheelClicked(thisHotkey) {
    global gWheelGui, gWheelHWND, gWheelBitmap, gDrawColor

    if !IsObject(gWheelGui)
        return

    MouseGetPos(&mx, &my)
    hwnd := gWheelHWND

    WinGetPos(&wx, &wy, &ww, &wh, hwnd)

    ; Released outside the window — just close
    if (mx < wx || mx > wx+ww || my < wy || my > wy+wh) {
        Hotkey "~LButton Up", WheelClicked, "Off"
        OnMessage(0x000F, WM_PAINT, 0)
        if gWheelBitmap
            DllCall("DeleteObject", "Ptr", gWheelBitmap)
        gWheelBitmap := 0
        gWheelGui.Destroy()
        gWheelGui := 0
        return
    }

    ; Sample pixel at release position
    lx := mx - wx
    ly := my - wy
    screenDC := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    bgr      := DllCall("GetPixel", "Ptr", screenDC, "Int", lx, "Int", ly, "UInt")
    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", screenDC)

    ; Black = background/outside ring — close without selecting
    if (bgr = 0x000000 || bgr = 0) {
        Hotkey "~LButton Up", WheelClicked, "Off"
        OnMessage(0x000F, WM_PAINT, 0)
        if gWheelBitmap
            DllCall("DeleteObject", "Ptr", gWheelBitmap)
        gWheelBitmap := 0
        gWheelGui.Destroy()
        gWheelGui := 0
        return
    }

    ; Valid color — store and close
    gDrawColor := RGBtoBGR(bgr)
    Hotkey "~LButton Up", WheelClicked, "Off"
    OnMessage(0x000F, WM_PAINT, 0)
    if gWheelBitmap
        DllCall("DeleteObject", "Ptr", gWheelBitmap)
    gWheelBitmap := 0
    gWheelGui.Destroy()
    gWheelGui := 0

    ToolTip("Selected: #" Format("{:06X}", gDrawColor))
    SetTimer(() => ToolTip(), -1500)
}

; Helpers
HueToRGB(h) {
    h := Mod(h, 360)
    s := 1.0
    v := 1.0
    hi := Floor(h / 60)
    f  := (h / 60) - hi
    p  := v * (1 - s)
    q  := v * (1 - f * s)
    t  := v * (1 - (1 - f) * s)
    if (hi = 0) {
        r := v, g := t, b := p
    } else if (hi = 1) {
        r := q, g := v, b := p
    } else if (hi = 2) {
        r := p, g := v, b := t
    } else if (hi = 3) {
        r := p, g := q, b := v
    } else if (hi = 4) {
        r := t, g := p, b := v
    } else {
        r := v, g := p, b := q
    }
    return (Round(r*255) << 16) | (Round(g*255) << 8) | Round(b*255)
}

RGBtoBGR(c) {
    return ((c & 0xFF) << 16) | (c & 0x00FF00) | ((c >> 16) & 0xFF)
}
