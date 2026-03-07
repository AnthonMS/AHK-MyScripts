#Requires AutoHotkey v2.0
#SingleInstance Force


CoordMode "Mouse", "Screen"

; ═════════════════════════════════════════════
;  GDI+ startup
; ═════════════════════════════════════════════
StartupInput := Buffer(16, 0)
NumPut("UInt", 1, StartupInput, 0)
DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok := 0, "Ptr", StartupInput, "Ptr", 0)
gToken := tok

; ─── Cursor setup ────────────────────────────
global gArrow := DllCall("LoadCursor", "Ptr", 0, "Int", 32512, "Ptr")
global gCursorIds := [
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
    32649, ; Hand (modern finger pointer)
]

; ═════════════════════════════════════════════
;  Create full screen layered canvas
; ═════════════════════════════════════════════
W := SysGet(78)
H := SysGet(79)
X := SysGet(76)
Y := SysGet(77)

canvas := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound +E0x80000 +E0x20")
canvas.Show("x" X " y" Y " w" W " h" H " Hide")
gHWND := canvas.Hwnd

; ─── GDI+ bitmap — starts fully transparent ──
DllCall("gdiplus\GdipCreateBitmapFromScan0",
    "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &gBitmap := 0)
DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", gBitmap, "Ptr*", &gGraphics := 0)
DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gGraphics, "Int", 4)

UpdateOverlay()
WinShow(gHWND)

gDefaultCursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr")

; ─── Draw color (0xRRGGBB) ───────────────────
global gDrawColor := 0xFF0000   ; default red

; ─── Always-running preview state tracker ────
global gPreviewActive := false
global gLastX         := 0
global gLastY         := 0
global gFirstStroke   := true
SetTimer(PreviewTick, 16)

; ─── Color wheel globals ─────────────────────
global gWheelGui    := 0
global gWheelHWND   := 0
global gWheelBitmap := 0

; ═════════════════════════════════════════════
;  HOTKEYS
; ═════════════════════════════════════════════
; Ctrl+Alt+LButton — draw
^!LButton:: {
    global gFirstStroke
    ForceCursors()
    MouseGetPos(&mx, &my)
    DrawCircle(mx, my, 20, DrawARGB())
    gFirstStroke := false
}

; Ctrl+Alt+RButton — erase
^!RButton:: {
    global gFirstStroke
    ForceCursors()
    MouseGetPos(&mx, &my)
    EraseCircle(mx, my, 20)
    gFirstStroke := false
}

; Ctrl+Alt+D — clear entire canvas
^!d:: {
    global gGraphics
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
    UpdateOverlay()
}

; Ctrl+Alt+C — open color wheel
^!c:: OpenColorWheel()

; On button release, reset interpolation so next stroke starts fresh
~LButton Up:: ResetStroke()
~RButton Up:: ResetStroke()

; Restore cursors on modifier release
~LCtrl Up:: RestoreCursors()
~LAlt Up::  RestoreCursors()
~RCtrl Up:: RestoreCursors()
~RAlt Up::  RestoreCursors()

ResetStroke() {
    global gFirstStroke
    gFirstStroke := true
}

; ═════════════════════════════════════════════
;  Helper — build full ARGB from gDrawColor
; ═════════════════════════════════════════════
DrawARGB() {
    global gDrawColor
    return 0xFF000000 | gDrawColor
}

PreviewARGB() {
    global gDrawColor
    return 0x44000000 | gDrawColor   ; ~27% opacity
}

; ════════════════════════════════════════════════════════
;  Preview tick — always running, checks key state itself
; ════════════════════════════════════════════════════════
PreviewTick() {
    global gPreviewActive, gLastX, gLastY, gFirstStroke
    bothHeld := GetKeyState("LCtrl", "P") && GetKeyState("LAlt", "P")

    if bothHeld {
        MouseGetPos(&mx, &my)

        lDown := GetKeyState("LButton", "P")
        rDown := GetKeyState("RButton", "P")

        if (lDown || rDown) {
            if gFirstStroke {
                if lDown
                    DrawCircle(mx, my, 20, DrawARGB())
                else
                    EraseCircle(mx, my, 20)
                gLastX := mx
                gLastY := my
                gFirstStroke := false
            } else if (mx != gLastX || my != gLastY) {
                dx   := mx - gLastX
                dy   := my - gLastY
                dist := Sqrt(dx * dx + dy * dy)
                step := 10
                steps := Max(1, Floor(dist / step))
                loop steps {
                    t  := A_Index / steps
                    ix := Round(gLastX + dx * t)
                    iy := Round(gLastY + dy * t)
                    if lDown
                        DrawCircleNoFlush(ix, iy, 20, DrawARGB())
                    else
                        EraseCircleNoFlush(ix, iy, 20)
                }
                UpdateOverlay()
                gLastX := mx
                gLastY := my
            }
        } else {
            gLastX := mx
            gLastY := my
            UpdateOverlayWithPreview(mx, my, 20)
        }

        gPreviewActive := true
    } else if gPreviewActive {
        UpdateOverlay()
        gPreviewActive := false
        gFirstStroke   := true
    }
}

; ═════════════════════════════════════════════
;  Cursor functions
; ═════════════════════════════════════════════
ForceCursors() {
    global gArrow, gCursorIds
    for id in gCursorIds {
        hCur := DllCall("CopyIcon", "Ptr", gArrow, "Ptr")
        DllCall("SetSystemCursor", "Ptr", hCur, "UInt", id)
    }
}

RestoreCursors() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)
}

; ═════════════════════════════════════════════
;  Draw / Erase — no-flush variants (used during interpolation)
; ═════════════════════════════════════════════
DrawCircleNoFlush(mx, my, r, argb) {
    global gGraphics
    ox := SysGet(76)
    oy := SysGet(77)
    px := mx - ox - r
    py := my - oy - r
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &brush := 0)
    DllCall("gdiplus\GdipFillEllipse",
        "Ptr", gGraphics, "Ptr", brush,
        "Float", px, "Float", py,
        "Float", r * 2, "Float", r * 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
}

EraseCircleNoFlush(mx, my, r) {
    global gGraphics
    ox := SysGet(76)
    oy := SysGet(77)
    px := mx - ox - r
    py := my - oy - r
    DllCall("gdiplus\GdipSetCompositingMode", "Ptr", gGraphics, "Int", 1)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0x00000000, "Ptr*", &brush := 0)
    DllCall("gdiplus\GdipFillEllipse",
        "Ptr", gGraphics, "Ptr", brush,
        "Float", px, "Float", py,
        "Float", r * 2, "Float", r * 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    DllCall("gdiplus\GdipSetCompositingMode", "Ptr", gGraphics, "Int", 0)
}

DrawCircle(mx, my, r, argb) {
    DrawCircleNoFlush(mx, my, r, argb)
    UpdateOverlay()
}

EraseCircle(mx, my, r) {
    EraseCircleNoFlush(mx, my, r)
    UpdateOverlay()
}

; ═════════════════════════════════════════════
;  Push GDI+ bitmap to layered window
; ═════════════════════════════════════════════
UpdateOverlay() {
    global gHWND, gBitmap
    W  := SysGet(78)
    H  := SysGet(79)
    ox := SysGet(76)
    oy := SysGet(77)

    hdc   := DllCall("GetDC", "Ptr", 0, "Ptr")
    memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", gBitmap, "Ptr*", &hbmp := 0, "UInt", 0)
    DllCall("SelectObject", "Ptr", memDC, "Ptr", hbmp)

    pt    := Buffer(8, 0)
    NumPut("Int", ox, pt, 0)
    NumPut("Int", oy, pt, 4)
    sz    := Buffer(8, 0)
    NumPut("Int", W, sz, 0)
    NumPut("Int", H, sz, 4)
    src   := Buffer(8, 0)
    blend := Buffer(4, 0)
    NumPut("UChar", 0,   blend, 0)
    NumPut("UChar", 0,   blend, 1)
    NumPut("UChar", 255, blend, 2)
    NumPut("UChar", 1,   blend, 3)

    DllCall("UpdateLayeredWindow",
        "Ptr", gHWND, "Ptr", hdc, "Ptr", pt, "Ptr", sz,
        "Ptr", memDC, "Ptr", src, "UInt", 0, "Ptr", blend, "UInt", 2)

    DllCall("DeleteObject", "Ptr", hbmp)
    DllCall("DeleteDC",     "Ptr", memDC)
    DllCall("ReleaseDC",    "Ptr", 0, "Ptr", hdc)
}

; ═════════════════════════════════════════════
;  Clone base bitmap, draw preview circle, push to overlay
; ═════════════════════════════════════════════
UpdateOverlayWithPreview(mx, my, r) {
    global gHWND, gBitmap
    W  := SysGet(78)
    H  := SysGet(79)
    ox := SysGet(76)
    oy := SysGet(77)

    DllCall("gdiplus\GdipCloneImage", "Ptr", gBitmap, "Ptr*", &tempBitmap := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", tempBitmap, "Ptr*", &tempG := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", tempG, "Int", 4)

    px := mx - ox - r
    py := my - oy - r
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", PreviewARGB(), "Ptr*", &brush := 0)
    DllCall("gdiplus\GdipFillEllipse",
        "Ptr", tempG, "Ptr", brush,
        "Float", px, "Float", py,
        "Float", r * 2, "Float", r * 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", tempG)

    hdc   := DllCall("GetDC", "Ptr", 0, "Ptr")
    memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", tempBitmap, "Ptr*", &hbmp := 0, "UInt", 0)
    DllCall("SelectObject", "Ptr", memDC, "Ptr", hbmp)

    pt    := Buffer(8, 0)
    NumPut("Int", ox, pt, 0)
    NumPut("Int", oy, pt, 4)
    sz    := Buffer(8, 0)
    NumPut("Int", W, sz, 0)
    NumPut("Int", H, sz, 4)
    src   := Buffer(8, 0)
    blend := Buffer(4, 0)
    NumPut("UChar", 0,   blend, 0)
    NumPut("UChar", 0,   blend, 1)
    NumPut("UChar", 255, blend, 2)
    NumPut("UChar", 1,   blend, 3)

    DllCall("UpdateLayeredWindow",
        "Ptr", gHWND, "Ptr", hdc, "Ptr", pt, "Ptr", sz,
        "Ptr", memDC, "Ptr", src, "UInt", 0, "Ptr", blend, "UInt", 2)

    DllCall("DeleteObject",             "Ptr", hbmp)
    DllCall("DeleteDC",                 "Ptr", memDC)
    DllCall("ReleaseDC",                "Ptr", 0, "Ptr", hdc)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", tempBitmap)
}

; ═════════════════════════════════════════════
;  Color wheel
; ═════════════════════════════════════════════
OpenColorWheel() {
    global gWheelGui, gWheelHWND, gWheelBitmap

    ; Toggle off if already open
    if IsObject(gWheelGui) {
        CloseColorWheel()
        return
    }

    MouseGetPos(&cx, &cy)

    outerR   := 90
    innerR   := 34
    padding  := 4
    winSize  := (outerR + padding) * 2   ; 188 — wheel diameter
    barGap   := 6
    barH     := 14
    barInset := 8
    totalH   := winSize + barGap + barH

    gWheelGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    gWheelGui.BackColor := "000000"
    gWheelGui.Show("w" winSize " h" totalH " Hide")
    gWheelHWND := gWheelGui.Hwnd

    WinMove(cx - outerR - padding, cy - outerR - padding, , , gWheelHWND)

    ; Combined region: circle (wheel) + rounded rect (gradient bar)
    hEllipse  := DllCall("CreateEllipticRgn",
        "Int", 0, "Int", 0, "Int", winSize, "Int", winSize, "Ptr")
    hBar      := DllCall("CreateRoundRectRgn",
        "Int", barInset, "Int", winSize + barGap,
        "Int", winSize - barInset, "Int", totalH,
        "Int", barH, "Int", barH, "Ptr")
    hCombined := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 1, "Int", 1, "Ptr")
    DllCall("CombineRgn", "Ptr", hCombined, "Ptr", hEllipse, "Ptr", hBar, "Int", 2)
    DllCall("SetWindowRgn", "Ptr", gWheelHWND, "Ptr", hCombined, "Int", true)
    DllCall("DeleteObject", "Ptr", hEllipse)
    DllCall("DeleteObject", "Ptr", hBar)

    gWheelBitmap := RenderWheel(winSize, outerR, innerR, padding, barGap, barH, barInset, totalH)

    OnMessage(0x000F, WM_PAINT)
    WinShow(gWheelHWND)

    Hotkey "~LButton Up", WheelClicked, "On"
}

CloseColorWheel() {
    global gWheelGui, gWheelBitmap
    Hotkey "~LButton Up", WheelClicked, "Off"
    OnMessage(0x000F, WM_PAINT, 0)
    if gWheelBitmap
        DllCall("DeleteObject", "Ptr", gWheelBitmap)
    gWheelBitmap := 0
    gWheelGui.Destroy()
    gWheelGui := 0
}

RenderWheel(winSize, outerR, innerR, padding, barGap, barH, barInset, totalH) {
    global gDrawColor

    screenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    memDC    := DllCall("CreateCompatibleDC", "Ptr", screenDC, "Ptr")
    hbmp     := DllCall("CreateCompatibleBitmap", "Ptr", screenDC, "Int", winSize, "Int", totalH, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", hbmp)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", screenDC)

    ; Fill entire background black
    rc := Buffer(16, 0)
    NumPut("Int", 0,       rc,  0)
    NumPut("Int", 0,       rc,  4)
    NumPut("Int", winSize, rc,  8)
    NumPut("Int", totalH,  rc, 12)
    bgBrush := DllCall("CreateSolidBrush", "UInt", 0x000000, "Ptr")
    DllCall("FillRect", "Ptr", memDC, "Ptr", rc, "Ptr", bgBrush)
    DllCall("DeleteObject", "Ptr", bgBrush)

    cx := outerR + padding
    cy := outerR + padding

    ; ── Hue wheel ────────────────────────────
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

        bgr   := RGBtoBGR(HueToRGB(angle))
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

    ; Center circle — shows current draw color
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

    ; ── Black-to-white gradient bar ──────────
    ; Layout: [black cap][gradient][white cap]
    barX1   := barInset
    barY1   := winSize + barGap
    barW    := winSize - barInset * 2
    capW    := 18   ; solid black/white end caps (easier to click)
    gradW   := barW - capW * 2

    ; Black cap
    brc := Buffer(16, 0)
    NumPut("Int", barX1,         brc,  0)
    NumPut("Int", barY1,         brc,  4)
    NumPut("Int", barX1 + capW,  brc,  8)
    NumPut("Int", barY1 + barH,  brc, 12)
    bBrush := DllCall("CreateSolidBrush", "UInt", 0x000000, "Ptr")
    DllCall("FillRect", "Ptr", memDC, "Ptr", brc, "Ptr", bBrush)
    DllCall("DeleteObject", "Ptr", bBrush)

    ; Gradient middle
    Loop gradW {
        t   := (A_Index - 1) / (gradW - 1)   ; 0.0 → 1.0
        v   := Round(t * 255)
        bgr := (v << 16) | (v << 8) | v
        gBrush := DllCall("CreateSolidBrush", "UInt", bgr, "Ptr")
        x := barX1 + capW + A_Index - 1
        grc := Buffer(16, 0)
        NumPut("Int", x,             grc,  0)
        NumPut("Int", barY1,         grc,  4)
        NumPut("Int", x + 1,         grc,  8)
        NumPut("Int", barY1 + barH,  grc, 12)
        DllCall("FillRect", "Ptr", memDC, "Ptr", grc, "Ptr", gBrush)
        DllCall("DeleteObject", "Ptr", gBrush)
    }

    ; White cap
    wrc := Buffer(16, 0)
    NumPut("Int", barX1 + capW + gradW,         wrc,  0)
    NumPut("Int", barY1,                         wrc,  4)
    NumPut("Int", barX1 + capW + gradW + capW,   wrc,  8)
    NumPut("Int", barY1 + barH,                  wrc, 12)
    wBrush := DllCall("CreateSolidBrush", "UInt", 0xFFFFFF, "Ptr")
    DllCall("FillRect", "Ptr", memDC, "Ptr", wrc, "Ptr", wBrush)
    DllCall("DeleteObject", "Ptr", wBrush)

    DllCall("DeleteDC", "Ptr", memDC)
    return hbmp
}

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

WheelClicked(thisHotkey) {
    global gWheelGui, gWheelHWND, gDrawColor

    if !IsObject(gWheelGui)
        return

    MouseGetPos(&mx, &my)
    WinGetPos(&wx, &wy, &ww, &wh, gWheelHWND)

    ; Released outside the window — close without selecting
    if (mx < wx || mx > wx+ww || my < wy || my > wy+wh) {
        CloseColorWheel()
        return
    }

    lx := mx - wx
    ly := my - wy

    ; ── Gradient bar zone: compute color mathematically ──
    ; Bar geometry must match RenderWheel (outerR=90, padding=4, barGap=6, barH=14, barInset=8)
    outerR   := 90
    padding  := 4
    winSize  := (outerR + padding) * 2
    barGap   := 6
    barH     := 14
    barInset := 8
    barY1    := winSize + barGap
    barX1    := barInset
    barW     := winSize - barInset * 2

    capW  := 18
    gradW := barW - capW * 2

    if (ly >= barY1 && ly < barY1 + barH && lx >= barX1 && lx < barX1 + barW) {
        localX := lx - barX1
        if (localX < capW) {
            v := 0          ; black cap
        } else if (localX >= capW + gradW) {
            v := 255        ; white cap
        } else {
            t := (localX - capW) / (gradW - 1)
            v := Round(t * 255)
        }
        gDrawColor := (v << 16) | (v << 8) | v
        CloseColorWheel()
        ToolTip("Color: #" Format("{:06X}", gDrawColor))
        SetTimer(() => ToolTip(), -1500)
        return
    }

    ; ── Hue wheel zone: sample pixel ──────────
    screenDC := DllCall("GetDC", "Ptr", gWheelHWND, "Ptr")
    bgr      := DllCall("GetPixel", "Ptr", screenDC, "Int", lx, "Int", ly, "UInt")
    DllCall("ReleaseDC", "Ptr", gWheelHWND, "Ptr", screenDC)

    ; Black = background/gap — close without selecting
    if (bgr = 0x000000 || bgr = 0) {
        CloseColorWheel()
        return
    }

    ; Store as 0xRRGGBB and close
    gDrawColor := RGBtoBGR(bgr)
    CloseColorWheel()

    ToolTip("Color: #" Format("{:06X}", gDrawColor))
    SetTimer(() => ToolTip(), -1500)
}

; ═════════════════════════════════════════════
;  Color helpers
; ═════════════════════════════════════════════
HueToRGB(h) {
    h := Mod(h, 360)
    s := 1.0
    v := 1.0
    hi := Floor(h / 60)
    f  := (h / 60) - hi
    p  := v * (1 - s)
    q  := v * (1 - f * s)
    t  := v * (1 - (1 - f) * s)
    if (hi = 0)
        r := v, g := t, b := p
    else if (hi = 1)
        r := q, g := v, b := p
    else if (hi = 2)
        r := p, g := v, b := t
    else if (hi = 3)
        r := p, g := q, b := v
    else if (hi = 4)
        r := t, g := p, b := v
    else
        r := v, g := p, b := q
    return (Round(r*255) << 16) | (Round(g*255) << 8) | Round(b*255)
}

RGBtoBGR(c) {
    return ((c & 0xFF) << 16) | (c & 0x00FF00) | ((c >> 16) & 0xFF)
}

; ─── Cleanup on exit ─────────────────────────
OnExit((*) {
    global gGraphics, gBitmap, gToken
    SetTimer(PreviewTick, 0)
    if IsObject(gWheelGui)
        CloseColorWheel()
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gGraphics)
    DllCall("gdiplus\GdipDisposeImage",   "Ptr", gBitmap)
    DllCall("gdiplus\GdiplusShutdown",    "Ptr", gToken)
    RestoreCursors()
})
