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

; ═════════════════════════════════════════════
;  Create full screen layered canvas
; ═════════════════════════════════════════════
W := SysGet(78)
H := SysGet(79)
X := SysGet(76)
Y := SysGet(77)

; Click-through by default (+E0x20 = WS_EX_TRANSPARENT)
canvas := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound +E0x80000 +E0x20")
canvas.Show("x" X " y" Y " w" W " h" H " Hide")
gHWND := canvas.Hwnd

; ─── GDI+ bitmap ─────────────────────────────
DllCall("gdiplus\GdipCreateBitmapFromScan0",
    "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &gBitmap := 0)
DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", gBitmap, "Ptr*", &gGraphics := 0)
DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gGraphics, "Int", 4)

; ─── Draw red circle in the center ───────────
cx := W // 2
cy := H // 2
r  := 50

DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFF0000, "Ptr*", &brush := 0)
DllCall("gdiplus\GdipFillEllipse",
    "Ptr", gGraphics, "Ptr", brush,
    "Float", cx - r, "Float", cy - r,
    "Float", r * 2,  "Float", r * 2)
DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)

; ─── Push bitmap to layered window ───────────
UpdateOverlay()

; ─── Show ─────────────────────────────────────
WinShow(gHWND)

; ═════════════════════════════════════════════
;  HOTKEYS
; ═════════════════════════════════════════════

; When Ctrl+Alt pressed — remove WS_EX_TRANSPARENT so canvas receives clicks
~^!:: {
    global gHWND
    ; Remove click-through by clearing WS_EX_TRANSPARENT (0x20)
    style := DllCall("GetWindowLong", "Ptr", gHWND, "Int", -20, "Int")
    DllCall("SetWindowLong", "Ptr", gHWND, "Int", -20, "Int", style & ~0x20)
}

; When Ctrl+Alt released — restore WS_EX_TRANSPARENT
~^! Up:: {
    global gHWND
    ToolTip()
    style := DllCall("GetWindowLong", "Ptr", gHWND, "Int", -20, "Int")
    DllCall("SetWindowLong", "Ptr", gHWND, "Int", -20, "Int", style | 0x20)
}

; Ctrl+Alt+LButton — show tooltip with click coords
^!LButton:: {
    MouseGetPos(&mx, &my)
    ToolTip("Canvas clicked at X:" mx " Y:" my)
}

; Ctrl+Alt+RButton — show tooltip with click coords
^!RButton:: {
    MouseGetPos(&mx, &my)
    ToolTip("Canvas clicked at X:" mx " Y:" my)
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

; ─── Cleanup on exit ─────────────────────────
OnExit((*) {
    global gGraphics, gBitmap, gToken
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gGraphics)
    DllCall("gdiplus\GdipDisposeImage",   "Ptr", gBitmap)
    DllCall("gdiplus\GdiplusShutdown",    "Ptr", gToken)
})
