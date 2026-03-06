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

;  Create full screen layered canvas
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

; ─── Load default arrow cursor ───────────────
; IDC_ARROW = 32512
gDefaultCursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr")

; Always-running preview state tracker
global gPreviewActive := false
global gLastX := 0
global gLastY := 0
global gFirstStroke := true   ; track whether we have a valid last position for interpolation
SetTimer(PreviewTick, 16)   ; ~60 fps, runs forever

; ═════════════════════════════════════════════
;  HOTKEYS
; ═════════════════════════════════════════════
; Ctrl+Alt+LButton
^!LButton:: {
    global gFirstStroke
    ForceCursors()
    MouseGetPos(&mx, &my)
    DrawCircle(mx, my, 20, 0xFFFF0000)
    gFirstStroke := false
}

; Ctrl+Alt+RButton
^!RButton:: {
    global gFirstStroke
    ForceCursors()
    MouseGetPos(&mx, &my)
    EraseCircle(mx, my, 20)
    gFirstStroke := false
}

; On button release, reset interpolation so next stroke starts fresh
~LButton Up:: ResetStroke()
~RButton Up:: ResetStroke()

; Ctrl+Alt+D — clear entire canvas
^!d:: {
    global gGraphics
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", gGraphics, "UInt", 0x00000000)
    UpdateOverlay()
}

; Calling RestoreCursor for each key up so it does not interfere with the above hotkeys
~LCtrl Up:: RestoreCursors()
~LAlt Up::  RestoreCursors()
~RCtrl Up:: RestoreCursors()
~RAlt Up::  RestoreCursors()

ResetStroke() {
    global gFirstStroke
    gFirstStroke := true
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
                ; First tick of a new stroke — no previous point to interpolate from
                if lDown
                    DrawCircle(mx, my, 20, 0xFFFF0000)
                else
                    EraseCircle(mx, my, 20)
                gLastX := mx
                gLastY := my
                gFirstStroke := false
            } else if (mx != gLastX || my != gLastY) {
                ; Interpolate circles along the line from last pos to current pos
                ; Step size = radius so circles overlap and leave no gap
                dx   := mx - gLastX
                dy   := my - gLastY
                dist := Sqrt(dx * dx + dy * dy)
                step := 10   ; half the radius — ensures solid overlap
                steps := Max(1, Floor(dist / step))
                loop steps {
                    t  := A_Index / steps
                    ix := Round(gLastX + dx * t)
                    iy := Round(gLastY + dy * t)
                    if lDown
                        DrawCircleNoFlush(ix, iy, 20, 0xFFFF0000)
                    else
                        EraseCircleNoFlush(ix, iy, 20)
                }
                UpdateOverlay()   ; single flush after all interpolated circles
                gLastX := mx
                gLastY := my
            }
        } else {
            ; No button held — show preview, keep last pos updated
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
;  Draw / Erase — versions that skip the overlay flush
;  (used during interpolation so we batch into one flush)
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

; ═════════════════════════════════════════════
;  Draw a filled circle on the canvas (single click — flushes immediately)
; ═════════════════════════════════════════════
DrawCircle(mx, my, r, argb) {
    DrawCircleNoFlush(mx, my, r, argb)
    UpdateOverlay()
}

; ═════════════════════════════════════════════
;  Erase a circle-shaped area (single click — flushes immediately)
; ═════════════════════════════════════════════
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
;  (gBitmap itself is never modified here)
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
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0x44FF0000, "Ptr*", &brush := 0)
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

; ─── Cleanup on exit ─────────────────────────
OnExit((*) {
    global gGraphics, gBitmap, gToken
    SetTimer(PreviewTick, 0)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gGraphics)
    DllCall("gdiplus\GdipDisposeImage",   "Ptr", gBitmap)
    DllCall("gdiplus\GdiplusShutdown",    "Ptr", gToken)
    RestoreCursors()
})
