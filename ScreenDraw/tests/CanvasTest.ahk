#Requires AutoHotkey v2.0
#SingleInstance Force

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
W := SysGet(78)   ; SM_CXVIRTUALSCREEN
H := SysGet(79)   ; SM_CYVIRTUALSCREEN
X := SysGet(76)   ; SM_XVIRTUALSCREEN
Y := SysGet(77)   ; SM_YVIRTUALSCREEN

; +E0x80000 = WS_EX_LAYERED
; +E0x20    = WS_EX_TRANSPARENT (click-through)
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
hdc   := DllCall("GetDC", "Ptr", 0, "Ptr")
memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", gBitmap, "Ptr*", &hbmp := 0, "UInt", 0)
DllCall("SelectObject", "Ptr", memDC, "Ptr", hbmp)

pt    := Buffer(8, 0)
NumPut("Int", X, pt, 0)
NumPut("Int", Y, pt, 4)
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

; ─── Show the window ─────────────────────────
WinShow(gHWND)

; ─── Cleanup on exit ─────────────────────────
OnExit((*) {
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gGraphics)
    DllCall("gdiplus\GdipDisposeImage",   "Ptr", gBitmap)
    DllCall("gdiplus\GdiplusShutdown",    "Ptr", gToken)
})
