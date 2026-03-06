#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode "Mouse", "Screen"

; ═════════════════════════════════════════════
;  Global state
; ═════════════════════════════════════════════
global gDrawColor  := 0xFF0000   ; default red (0xRRGGBB)
global gBrushSize  := 20         ; diameter in pixels

global gCanvas     := 0
global gHWND       := 0
global gGraphics   := 0
global gBitmap     := 0
global gToken      := 0

global gDrawActive := false
global gIsDrawing  := false
global gIsErasing  := false
global gLastX      := 0
global gLastY      := 0

; ═════════════════════════════════════════════
;  GDI+ startup
; ═════════════════════════════════════════════
StartupInput := Buffer(16, 0)
NumPut("UInt", 1, StartupInput, 0)
DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok := 0, "Ptr", StartupInput, "Ptr", 0)
gToken := tok

; ═════════════════════════════════════════════
;  Create canvas on startup
; ═════════════════════════════════════════════
CreateCanvas()
OnExit(CleanupAll)

; ═════════════════════════════════════════════
;  HOTKEYS
; ═════════════════════════════════════════════

; ~ so Ctrl+Alt+C / Ctrl+Alt+S etc. in other scripts still fire
~^!:: {
    global gDrawActive
    if gDrawActive
        return
    gDrawActive := true
    ; Register blocking hotkeys only while Ctrl+Alt held
    Hotkey "LButton",    LDown,  "On"
    Hotkey "LButton Up", LUp,    "On"
    Hotkey "RButton",    RDown,  "On"
    Hotkey "RButton Up", RUp,    "On"
}

~^! Up:: {
    global gDrawActive, gIsDrawing, gIsErasing
    gDrawActive := false
    gIsDrawing  := false
    gIsErasing  := false
    gLastX      := 0
    gLastY      := 0
    SetTimer DrawLoop,  0
    SetTimer EraseLoop, 0
    ; Unregister hotkeys so mouse works normally again
    Hotkey "LButton",    LDown,  "Off"
    Hotkey "LButton Up", LUp,    "Off"
    Hotkey "RButton",    RDown,  "Off"
    Hotkey "RButton Up", RUp,    "Off"
}

; ─────────────────────────────────────────────
;  Mouse button handlers — only active while
;  Ctrl+Alt is held. No ~ so clicks are blocked.
; ─────────────────────────────────────────────
LDown(*) {
    global gIsDrawing, gLastX, gLastY
    gIsDrawing := true
    gIsErasing := false
    MouseGetPos(&mx, &my)
    gLastX := mx
    gLastY := my
    SetTimer DrawLoop, 16
}

LUp(*) {
    global gIsDrawing
    gIsDrawing := false
    SetTimer DrawLoop, 0
}

RDown(*) {
    global gIsErasing
    gIsErasing := true
    gIsDrawing := false
    SetTimer EraseLoop, 16
}

RUp(*) {
    global gIsErasing
    gIsErasing := false
    SetTimer EraseLoop, 0
}

; ═════════════════════════════════════════════
;  Draw / Erase loops — only run while button held
; ═════════════════════════════════════════════
DrawLoop() {
    global gIsDrawing, gLastX, gLastY, gDrawColor, gBrushSize
    if !gIsDrawing {
        SetTimer DrawLoop, 0
        return
    }
    MouseGetPos(&mx, &my)
    if (gLastX = mx && gLastY = my)
        return
    PaintStroke(gLastX, gLastY, mx, my, gDrawColor, gBrushSize)
    gLastX := mx
    gLastY := my
    UpdateOverlay()
}

EraseLoop() {
    global gIsErasing, gBrushSize
    if !gIsErasing {
        SetTimer EraseLoop, 0
        return
    }
    MouseGetPos(&mx, &my)
    EraseStroke(mx, my, gBrushSize)
    UpdateOverlay()
}

; ═════════════════════════════════════════════
;  GDI+ painting
; ═════════════════════════════════════════════
PaintStroke(x1, y1, x2, y2, color, size) {
    global gGraphics
    ox := SysGet(76)
    oy := SysGet(77)
    argb := 0xFF000000 | color
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &brush := 0)
    dx    := x2 - x1
    dy    := y2 - y1
    dist  := Sqrt(dx*dx + dy*dy)
    steps := Max(1, Round(dist))
    r     := size / 2
    Loop steps + 1 {
        t  := (A_Index - 1) / steps
        px := x1 + dx * t - ox
        py := y1 + dy * t - oy
        DllCall("gdiplus\GdipFillEllipse",
            "Ptr", gGraphics, "Ptr", brush,
            "Float", px - r, "Float", py - r,
            "Float", size,   "Float", size)
    }
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
}

EraseStroke(x, y, size) {
    global gGraphics
    ox := SysGet(76)
    oy := SysGet(77)
    r  := size / 2
    px := x - ox - r
    py := y - oy - r
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0x00000000, "Ptr*", &brush := 0)
    DllCall("gdiplus\GdipSetCompositingMode", "Ptr", gGraphics, "Int", 1)
    DllCall("gdiplus\GdipFillEllipse",
        "Ptr", gGraphics, "Ptr", brush,
        "Float", px, "Float", py,
        "Float", size, "Float", size)
    DllCall("gdiplus\GdipSetCompositingMode", "Ptr", gGraphics, "Int", 0)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
}

; ═════════════════════════════════════════════
;  Canvas setup
; ═════════════════════════════════════════════
CreateCanvas() {
    global gCanvas, gHWND, gGraphics, gBitmap

    W := SysGet(78)
    H := SysGet(79)
    X := SysGet(76)
    Y := SysGet(77)

    gCanvas := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound +E0x80000 +E0x20")
    gCanvas.Show("x" X " y" Y " w" W " h" H " Hide")
    gHWND := gCanvas.Hwnd

    DllCall("gdiplus\GdipCreateBitmapFromScan0",
        "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    gBitmap := bmp

    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", gBitmap, "Ptr*", &g := 0)
    gGraphics := g

    DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gGraphics, "Int", 4)

    UpdateOverlay()
    WinShow(gHWND)
}

; ═════════════════════════════════════════════
;  Push GDI+ bitmap to the layered window
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
;  Cleanup on exit
; ═════════════════════════════════════════════
CleanupAll(*) {
    global gGraphics, gBitmap, gToken
    try {
        if gGraphics
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gGraphics)
    }
    try {
        if gBitmap
            DllCall("gdiplus\GdipDisposeImage", "Ptr", gBitmap)
    }
    try {
        if gToken
            DllCall("gdiplus\GdiplusShutdown", "Ptr", gToken)
    }
    gGraphics := 0
    gBitmap   := 0
    gToken    := 0
}
