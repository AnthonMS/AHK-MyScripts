#Requires AutoHotkey v2.0
#SingleInstance Force


CoordMode "Mouse", "Screen"

; GDI+ startup
StartupInput := Buffer(16, 0)
NumPut("UInt", 1, StartupInput, 0)
DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok := 0, "Ptr", StartupInput, "Ptr", 0)
gToken := tok

; Cursor setup
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

; Create full screen layered canvas
W := SysGet(78)
H := SysGet(79)
X := SysGet(76)
Y := SysGet(77)

canvas := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound +E0x80000 +E0x20")
canvas.Show("x" X " y" Y " w" W " h" H " Hide")
gHWND := canvas.Hwnd

; GDI+ bitmap — starts fully transparent
DllCall("gdiplus\GdipCreateBitmapFromScan0",
    "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &gBitmap := 0)
DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", gBitmap, "Ptr*", &gGraphics := 0)
DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gGraphics, "Int", 4)

UpdateOverlay()
WinShow(gHWND)

gDefaultCursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr")

; Draw color (0xRRGGBB)
global gDrawColor := 0xFF0000   ; default red (0xRRGGBB)
global gOpacity   := 255        ; 0 = fully transparent, 255 = fully opaque
global gBrushSize := 20         ; diameter in pixels

; Size slider globals
global gSliderGui  := 0
global gSliderHWND := 0

; Always-running preview state tracker
global gPreviewActive   := false
global gLastX           := 0
global gLastY           := 0
global gFirstStroke     := true
SetTimer(PreviewTick, 16)

; Color wheel globals
global gWheelGui    := 0
global gWheelHWND   := 0
global gWheelBitmap := 0

; HOTKEYS

; Draw/erase only when cursor is NOT over a tool window
#HotIf !MouseOverToolWindow()

^!LButton:: {               ; Ctrl+Alt+LButton — draw
    global gFirstStroke
    ForceCursors()
    MouseGetPos(&mx, &my)
    DrawCircle(mx, my, gBrushSize // 2, DrawARGB())
    gFirstStroke := false
}


^!RButton:: {               ; Ctrl+Alt+RButton — erase
    global gFirstStroke
    ForceCursors()
    MouseGetPos(&mx, &my)
    EraseCircle(mx, my, gBrushSize // 2)
    gFirstStroke := false
}
#HotIf


^!d:: {                     ; Ctrl+Alt+D — clear screen
    global gGraphics
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
    UpdateOverlay()
}


^!c:: OpenColorWheel()      ; Ctrl+Alt+C — color wheel


^!s:: OpenSizeSlider()      ; Ctrl+Alt+S — size slider

; Reset interpolation so next stroke starts fresh
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

; Helper — build full ARGB from gDrawColor
DrawARGB() {
    global gDrawColor, gOpacity
    return (gOpacity << 24) | gDrawColor
}

PreviewARGB() {
    global gDrawColor, gOpacity
    previewAlpha := Max(0x33, gOpacity >> 2)   ; at least faintly visible
    return (previewAlpha << 24) | gDrawColor
}

; Preview tick — always running, checks key state itself
PreviewTick() {
    global gPreviewActive, gLastX, gLastY, gFirstStroke
    bothHeld := GetKeyState("LCtrl", "P") && GetKeyState("LAlt", "P")

    if bothHeld {
        MouseGetPos(&mx, &my)

        lDown := GetKeyState("LButton", "P")
        rDown := GetKeyState("RButton", "P")

        if (lDown || rDown) {
            if MouseOverToolWindow() {
                gFirstStroke := true
            } else if gFirstStroke {
                if lDown
                    DrawCircle(mx, my, gBrushSize // 2, DrawARGB())
                else
                    EraseCircle(mx, my, gBrushSize // 2)
                gLastX := mx
                gLastY := my
                gFirstStroke := false
            } else if (mx != gLastX || my != gLastY) {
                dx   := mx - gLastX
                dy   := my - gLastY
                dist := Sqrt(dx * dx + dy * dy)
                step  := Max(1, gBrushSize // 4)   ; half-radius step keeps strokes solid
                steps := Max(1, Floor(dist / step))
                loop steps {
                    t  := A_Index / steps
                    ix := Round(gLastX + dx * t)
                    iy := Round(gLastY + dy * t)
                    if lDown
                        DrawCircleNoFlush(ix, iy, gBrushSize // 2, DrawARGB())
                    else
                        EraseCircleNoFlush(ix, iy, gBrushSize // 2)
                }
                UpdateOverlay()
                gLastX := mx
                gLastY := my
            }
        } else {
            gLastX := mx
            gLastY := my
            if !MouseOverToolWindow()
                UpdateOverlayWithPreview(mx, my, gBrushSize // 2)
            else
                UpdateOverlay()
        }

        gPreviewActive := true
    } else if gPreviewActive {
        UpdateOverlay()
        gPreviewActive := false
        gFirstStroke   := true
    }
}

; Cursor functions
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

MouseOverToolWindow() {
    global gWheelGui, gWheelHWND, gSliderGui, gSliderHWND
    ; Use WindowFromPoint so we get the exact HWND under the cursor,
    ; then walk up to the root window — MouseGetPos returns child controls
    ; which won't match the parent GUI HWNDs.
    MouseGetPos(&mx, &my)
    hwnd := DllCall("WindowFromPoint", "Int64", mx | (my << 32), "Ptr")
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")   ; GA_ROOT = 2
    return (IsObject(gWheelGui)   && root = gWheelHWND)
        || (IsObject(gSliderGui)  && root = gSliderHWND)
}

; Draw / Erase — no-flush variants (used during interpolation)
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

; Push GDI+ bitmap to layered window
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

; Clone base bitmap, draw preview circle, push to overlay
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

; Color wheel
OpenColorWheel() {
    global gWheelGui, gWheelHWND, gWheelBitmap

    ; Toggle off if already open
    if IsObject(gWheelGui) {
        CloseColorWheel()
        return
    }

    MouseGetPos(&cx, &cy)

    outerR      := 90
    innerR      := 34
    padding     := 4
    winSize     := (outerR + padding) * 2   ; 188 — wheel diameter
    barGap      := 6
    barH        := 14
    barInset    := 8
    sliderGap   := 6
    sliderW     := 14
    sliderInset := 6
    totalW      := winSize + sliderGap + sliderW
    totalH      := winSize + barGap + barH

    gWheelGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    gWheelGui.BackColor := "000000"
    gWheelGui.Show("w" totalW " h" totalH " Hide")
    gWheelHWND := gWheelGui.Hwnd

    WinMove(cx - outerR - padding, cy - outerR - padding, , , gWheelHWND)

    ; Combined region: circle + bottom bar + right opacity slider pill
    hEllipse  := DllCall("CreateEllipticRgn",
        "Int", 0, "Int", 0, "Int", winSize, "Int", winSize, "Ptr")
    hBar      := DllCall("CreateRoundRectRgn",
        "Int", barInset, "Int", winSize + barGap,
        "Int", winSize - barInset, "Int", totalH,
        "Int", barH, "Int", barH, "Ptr")
    hSlider   := DllCall("CreateRoundRectRgn",
        "Int", winSize + sliderGap, "Int", sliderInset,
        "Int", totalW, "Int", winSize - sliderInset,
        "Int", sliderW, "Int", sliderW, "Ptr")
    ; Close button: 22x22 square in top-left corner
    btnSz := 22
    hBtn  := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", btnSz, "Int", btnSz, "Ptr")
    hCombined := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 1, "Int", 1, "Ptr")
    DllCall("CombineRgn", "Ptr", hCombined, "Ptr", hEllipse,  "Ptr", hBar,    "Int", 2)
    DllCall("CombineRgn", "Ptr", hCombined, "Ptr", hCombined, "Ptr", hSlider, "Int", 2)
    DllCall("CombineRgn", "Ptr", hCombined, "Ptr", hCombined, "Ptr", hBtn,    "Int", 2)
    DllCall("SetWindowRgn", "Ptr", gWheelHWND, "Ptr", hCombined, "Int", true)
    DllCall("DeleteObject", "Ptr", hEllipse)
    DllCall("DeleteObject", "Ptr", hBar)
    DllCall("DeleteObject", "Ptr", hSlider)
    DllCall("DeleteObject", "Ptr", hBtn)

    gWheelBitmap := RenderWheel(winSize, outerR, innerR, padding, barGap, barH, barInset, totalH, totalW, sliderGap, sliderW, sliderInset)

    OnMessage(0x000F, WM_PAINT)
    OnMessage(0x0084, WM_NCHITTEST_Wheel)   ; WM_NCHITTEST — enables center-drag
    OnMessage(0x0200, WM_MOUSEMOVE_Wheel)   ; WM_MOUSEMOVE — drag-to-pick color
    WinShow(gWheelHWND)

    Hotkey "~LButton Up", WheelClicked, "On"
}

CloseColorWheel() {
    global gWheelGui, gWheelBitmap
    Hotkey "~LButton Up", WheelClicked, "Off"
    OnMessage(0x000F, WM_PAINT, 0)
    OnMessage(0x0084, WM_NCHITTEST_Wheel, 0)
    OnMessage(0x0200, WM_MOUSEMOVE_Wheel, 0)
    if gWheelBitmap
        DllCall("DeleteObject", "Ptr", gWheelBitmap)
    gWheelBitmap := 0
    gWheelGui.Destroy()
    gWheelGui := 0
}

RenderWheel(winSize, outerR, innerR, padding, barGap, barH, barInset, totalH, totalW, sliderGap, sliderW, sliderInset) {
    global gDrawColor, gOpacity

    screenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    memDC    := DllCall("CreateCompatibleDC", "Ptr", screenDC, "Ptr")
    hbmp     := DllCall("CreateCompatibleBitmap", "Ptr", screenDC, "Int", totalW, "Int", totalH, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", hbmp)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", screenDC)

    ; Fill entire background black
    rc := Buffer(16, 0)
    NumPut("Int", 0,      rc,  0)
    NumPut("Int", 0,      rc,  4)
    NumPut("Int", totalW, rc,  8)
    NumPut("Int", totalH, rc, 12)
    bgBrush := DllCall("CreateSolidBrush", "UInt", 0x000000, "Ptr")
    DllCall("FillRect", "Ptr", memDC, "Ptr", rc, "Ptr", bgBrush)
    DllCall("DeleteObject", "Ptr", bgBrush)

    cx := outerR + padding
    cy := outerR + padding

    ; Close button (top-left 22x22)
    btnSz := 22
    btnBrush := DllCall("CreateSolidBrush", "UInt", 0x1A1A1A, "Ptr")
    btnRc := Buffer(16, 0)
    NumPut("Int", 0,     btnRc,  0), NumPut("Int", 0,     btnRc,  4)
    NumPut("Int", btnSz, btnRc,  8), NumPut("Int", btnSz, btnRc, 12)
    DllCall("FillRect", "Ptr", memDC, "Ptr", btnRc, "Ptr", btnBrush)
    DllCall("DeleteObject", "Ptr", btnBrush)
    ; Draw X with two diagonal lines
    xPad := 6
    xPen := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", 0xAAAAAA, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", xPen)
    DllCall("MoveToEx", "Ptr", memDC, "Int", xPad,          "Int", xPad,          "Ptr", 0)
    DllCall("LineTo",   "Ptr", memDC, "Int", btnSz - xPad,  "Int", btnSz - xPad)
    DllCall("MoveToEx", "Ptr", memDC, "Int", btnSz - xPad,  "Int", xPad,          "Ptr", 0)
    DllCall("LineTo",   "Ptr", memDC, "Int", xPad,          "Int", btnSz - xPad)
    DllCall("DeleteObject", "Ptr", xPen)

    ; Hue wheel
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

    ; Black-to-white gradient bar
    barX1   := barInset
    barY1   := winSize + barGap
    barW    := winSize - barInset * 2
    capW    := 18
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
        t   := (A_Index - 1) / (gradW - 1)
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
    NumPut("Int", barX1 + capW + gradW,        wrc,  0)
    NumPut("Int", barY1,                        wrc,  4)
    NumPut("Int", barX1 + capW + gradW + capW,  wrc,  8)
    NumPut("Int", barY1 + barH,                 wrc, 12)
    wBrush := DllCall("CreateSolidBrush", "UInt", 0xFFFFFF, "Ptr")
    DllCall("FillRect", "Ptr", memDC, "Ptr", wrc, "Ptr", wBrush)
    DllCall("DeleteObject", "Ptr", wBrush)

    ; Opacity slider
    ; Layout: [white cap (100%)][gradient][black cap (0%)]
    sX1  := winSize + sliderGap
    sY1  := sliderInset
    sH   := winSize - sliderInset * 2
    sCapH := 14   ; solid end caps — easier to hit 100% and 0%
    sGradH := sH - sCapH * 2

    ; Top cap — fully opaque (bright)
    tcBrush := DllCall("CreateSolidBrush", "UInt", 0xFFFFFF, "Ptr")
    trc := Buffer(16, 0)
    NumPut("Int", sX1,          trc,  0), NumPut("Int", sY1,           trc,  4)
    NumPut("Int", sX1 + sliderW, trc, 8), NumPut("Int", sY1 + sCapH,   trc, 12)
    DllCall("FillRect", "Ptr", memDC, "Ptr", trc, "Ptr", tcBrush)
    DllCall("DeleteObject", "Ptr", tcBrush)

    ; Gradient middle
    Loop sGradH {
        t   := 1.0 - (A_Index - 1) / (sGradH - 1)
        v   := Round(t * 200) + 55
        bgr := (v << 16) | (v << 8) | v
        sBrush := DllCall("CreateSolidBrush", "UInt", bgr, "Ptr")
        src := Buffer(16, 0)
        NumPut("Int", sX1,                        src,  0)
        NumPut("Int", sY1 + sCapH + A_Index - 1,  src,  4)
        NumPut("Int", sX1 + sliderW,              src,  8)
        NumPut("Int", sY1 + sCapH + A_Index,      src, 12)
        DllCall("FillRect", "Ptr", memDC, "Ptr", src, "Ptr", sBrush)
        DllCall("DeleteObject", "Ptr", sBrush)
    }

    ; Bottom cap — fully transparent (dark)
    bcBrush := DllCall("CreateSolidBrush", "UInt", 0x373737, "Ptr")
    brc := Buffer(16, 0)
    NumPut("Int", sX1,           brc,  0), NumPut("Int", sY1 + sCapH + sGradH,         brc,  4)
    NumPut("Int", sX1 + sliderW, brc,  8), NumPut("Int", sY1 + sCapH + sGradH + sCapH, brc, 12)
    DllCall("FillRect", "Ptr", memDC, "Ptr", brc, "Ptr", bcBrush)
    DllCall("DeleteObject", "Ptr", bcBrush)

    ; Marker line showing current opacity position
    markerY := sY1 + sCapH + Round((1.0 - gOpacity / 255) * (sGradH - 1))
    mPen := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", 0xFFFFFF, "Ptr")
    DllCall("SelectObject", "Ptr", memDC, "Ptr", mPen)
    DllCall("MoveToEx", "Ptr", memDC, "Int", sX1,             "Int", markerY, "Ptr", 0)
    DllCall("LineTo",   "Ptr", memDC, "Int", sX1 + sliderW,   "Int", markerY)
    DllCall("DeleteObject", "Ptr", mPen)

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

    ; Draw center dot live so it always reflects the current gDrawColor
    outerR  := 90
    innerR  := 34
    padding := 4
    cx := outerR + padding
    cy := outerR + padding
    centerBGR := RGBtoBGR(gDrawColor)
    cBrush := DllCall("CreateSolidBrush", "UInt", centerBGR, "Ptr")
    cPen   := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", 0xCCCCCC, "Ptr")
    DllCall("SelectObject", "Ptr", hdc, "Ptr", cBrush)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", cPen)
    DllCall("Ellipse", "Ptr", hdc,
        "Int", cx - innerR + 3, "Int", cy - innerR + 3,
        "Int", cx + innerR - 3, "Int", cy + innerR - 3)
    DllCall("DeleteObject", "Ptr", cBrush)
    DllCall("DeleteObject", "Ptr", cPen)

    DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    return 0
}

; Drag wheel window by clicking the center dot
WM_NCHITTEST_Wheel(wParam, lParam, msg, hwnd) {
    global gWheelHWND
    if (hwnd != gWheelHWND)
        return

    ; Convert screen coords from lParam to window-local coords
    sx := lParam & 0xFFFF
    sy := (lParam >> 16) & 0xFFFF
    ; Handle sign extension for negative screen coords
    if (sx >= 0x8000)
        sx -= 0x10000
    if (sy >= 0x8000)
        sy -= 0x10000
    WinGetPos(&wx, &wy, , , gWheelHWND)
    lx := sx - wx
    ly := sy - wy

    ; Center circle: innerR=34, padding=4, outerR=90 → cx=cy=94
    cx := 94
    cy := 94
    innerR := 34
    dx := lx - cx
    dy := ly - cy
    if (dx * dx + dy * dy <= innerR * innerR)
        return 2   ; HTCAPTION — Windows handles drag natively
}

; Drag-to-pick: update color while LButton held and mouse moves
WM_MOUSEMOVE_Wheel(wParam, lParam, msg, hwnd) {
    global gWheelHWND, gDrawColor, gOpacity
    if (hwnd != gWheelHWND)
        return
    if !(wParam & 0x0001)   ; MK_LBUTTON — only act when left button is held
        return

    lx := lParam & 0xFFFF
    ly := (lParam >> 16) & 0xFFFF

    ; Geometry (must match RenderWheel)
    outerR      := 90
    innerR      := 34
    padding     := 4
    winSize     := (outerR + padding) * 2
    barGap      := 6
    barH        := 14
    barInset    := 8
    barY1       := winSize + barGap
    barX1       := barInset
    barW        := winSize - barInset * 2
    capW        := 18
    gradW       := barW - capW * 2
    sliderGap   := 6
    sliderW     := 14
    sliderInset := 6
    sX1    := winSize + sliderGap
    sY1    := sliderInset
    sH     := winSize - sliderInset * 2
    sCapH  := 14
    sGradH := sH - sCapH * 2

    ; Opacity slider
    if (lx >= sX1 && lx < sX1 + sliderW && ly >= sY1 && ly < sY1 + sH) {
        localY := ly - sY1
        if (localY < sCapH)
            gOpacity := 255
        else if (localY >= sCapH + sGradH)
            gOpacity := 0
        else {
            t        := 1.0 - (localY - sCapH) / (sGradH - 1)
            gOpacity := Round(t * 255)
        }
        ToolTip(Round(gOpacity / 255 * 100) "%")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    ; Grayscale bar
    if (ly >= barY1 && ly < barY1 + barH && lx >= barX1 && lx < barX1 + barW) {
        localX := lx - barX1
        if (localX < capW)
            v := 0
        else if (localX >= capW + gradW)
            v := 255
        else {
            t := (localX - capW) / (gradW - 1)
            v := Round(t * 255)
        }
        gDrawColor := (v << 16) | (v << 8) | v
        DllCall("InvalidateRect", "Ptr", gWheelHWND, "Ptr", 0, "Int", true)
        return
    }

    ; Hue wheel ring
    cx   := outerR + padding
    cy   := outerR + padding
    dx   := lx - cx
    dy   := ly - cy
    dist := Sqrt(dx * dx + dy * dy)
    if (dist >= innerR && dist <= outerR) {
        hdc := DllCall("GetDC", "Ptr", gWheelHWND, "Ptr")
        bgr := DllCall("GetPixel", "Ptr", hdc, "Int", lx, "Int", ly, "UInt")
        DllCall("ReleaseDC", "Ptr", gWheelHWND, "Ptr", hdc)
        if (bgr != 0x000000 && bgr != 0) {
            gDrawColor := RGBtoBGR(bgr)
            DllCall("InvalidateRect", "Ptr", gWheelHWND, "Ptr", 0, "Int", true)
        }
    }
}

WheelClicked(thisHotkey) {
    global gWheelGui, gWheelHWND, gDrawColor, gOpacity

    if !IsObject(gWheelGui)
        return

    MouseGetPos(&mx, &my)
    WinGetPos(&wx, &wy, &ww, &wh, gWheelHWND)

    ; Click outside window — ignore
    if (mx < wx || mx > wx+ww || my < wy || my > wy+wh)
        return

    lx := mx - wx
    ly := my - wy

    ; Close button (top-left 22x22)
    if (lx >= 0 && lx < 22 && ly >= 0 && ly < 22) {
        CloseColorWheel()
        return
    }

    ; Geometry constants (must match RenderWheel)
    outerR      := 90
    padding     := 4
    winSize     := (outerR + padding) * 2
    barGap      := 6
    barH        := 14
    barInset    := 8
    barY1       := winSize + barGap
    barX1       := barInset
    barW        := winSize - barInset * 2
    capW        := 18
    gradW       := barW - capW * 2
    sliderGap   := 6
    sliderW     := 14
    sliderInset := 6
    sX1 := winSize + sliderGap
    sY1 := sliderInset
    sH  := winSize - sliderInset * 2

    ; Opacity slider
    sCapH  := 14
    sGradH := sH - sCapH * 2

    if (lx >= sX1 && lx < sX1 + sliderW && ly >= sY1 && ly < sY1 + sH) {
        localY := ly - sY1
        if (localY < sCapH)
            gOpacity := 255                                          ; top cap = 100%
        else if (localY >= sCapH + sGradH)
            gOpacity := 0                                            ; bottom cap = 0%
        else {
            t        := 1.0 - (localY - sCapH) / (sGradH - 1)
            gOpacity := Round(t * 255)
        }
        ToolTip(Round(gOpacity / 255 * 100) "%")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    ; Grayscale bar
    if (ly >= barY1 && ly < barY1 + barH && lx >= barX1 && lx < barX1 + barW) {
        localX := lx - barX1
        if (localX < capW)
            v := 0
        else if (localX >= capW + gradW)
            v := 255
        else {
            t := (localX - capW) / (gradW - 1)
            v := Round(t * 255)
        }
        gDrawColor := (v << 16) | (v << 8) | v
        DllCall("InvalidateRect", "Ptr", gWheelHWND, "Ptr", 0, "Int", true)
        return
    }

    ; Hue wheel
    screenDC := DllCall("GetDC", "Ptr", gWheelHWND, "Ptr")
    bgr      := DllCall("GetPixel", "Ptr", screenDC, "Int", lx, "Int", ly, "UInt")
    DllCall("ReleaseDC", "Ptr", gWheelHWND, "Ptr", screenDC)

    ; Black = background gap — ignore
    if (bgr = 0x000000 || bgr = 0)
        return

    gDrawColor := RGBtoBGR(bgr)
    DllCall("InvalidateRect", "Ptr", gWheelHWND, "Ptr", 0, "Int", true)
}

; Color helpers
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


; Size slider
WM_LBUTTONDOWN_Slider(wParam, lParam, msg, hwnd) {
    global gSliderHWND
    if (hwnd = gSliderHWND)
        PostMessage(0x00A1, 2, 0, , gSliderHWND)   ; SC_MOVE — let Windows drag it
}

OpenSizeSlider() {
    global gSliderGui, gSliderHWND, gBrushSize

    ; Toggle off if already open
    if IsObject(gSliderGui) {
        CloseSizeSlider()
        return
    }

    MouseGetPos(&cx, &cy)

    winW := 50
    winH := 380

    gSliderGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    gSliderGui.BackColor := "1E1E1E"
    gSliderGui.Show("w" winW " h" winH " Hide")
    gSliderHWND := gSliderGui.Hwnd

    WinMove(cx, cy - (winH // 2), , , gSliderHWND)

    ; Close button
    gSliderGui.SetFont("s11 cGray Bold", "Segoe UI")
    closeBtn := gSliderGui.Add("Text", "x0 y4 w50 h24 Center +0x100", "✕")
    closeBtn.OnEvent("Click", (*) => CloseSizeSlider())

    ; Vertical slider
    slider := gSliderGui.Add("Slider",
        "x15 y34 w20 h300 Vertical Invert Range1-500 NoTicks", gBrushSize)

    slider.OnEvent("Change", (*) {
        global gBrushSize
        gBrushSize := slider.Value
        ToolTip(gBrushSize "px")
        SetTimer(() => ToolTip(), -1500)
    })

    ; Continuous tooltip while dragging
    OnMessage(0x0115, WM_VSCROLL_Slider)   ; WM_VSCROLL fires on every slider move

    ; Drag to move
    OnMessage(0x0201, WM_LBUTTONDOWN_Slider)

    WinShow(gSliderHWND)
}

WM_VSCROLL_Slider(wParam, lParam, msg, hwnd) {
    global gSliderHWND, gBrushSize, gSliderGui
    if (hwnd != gSliderHWND || !IsObject(gSliderGui))
        return
    ; lParam is the HWND of the slider control — read its value via control message
    val := SendMessage(0x0400, 0, 0, lParam)   ; TBM_GETPOS = 0x0400
    val := (1 + 500) - val                     ; correct for Invert style
    if (val > 0) {
        gBrushSize := val
        ToolTip(gBrushSize "px")
        SetTimer(() => ToolTip(), -1500)
    }
}

CloseSizeSlider() {
    global gSliderGui
    OnMessage(0x0115, WM_VSCROLL_Slider, 0)
    OnMessage(0x0201, WM_LBUTTONDOWN_Slider, 0)
    gSliderGui.Destroy()
    gSliderGui := 0
}

OnExit((*) {
    global gGraphics, gBitmap, gToken
    SetTimer(PreviewTick, 0)
    if IsObject(gWheelGui)
        CloseColorWheel()
    if IsObject(gSliderGui)
        CloseSizeSlider()
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gGraphics)
    DllCall("gdiplus\GdipDisposeImage",   "Ptr", gBitmap)
    DllCall("gdiplus\GdiplusShutdown",    "Ptr", gToken)
    RestoreCursors()
})
