#Requires AutoHotkey v2.0

#Include *i <Gdip_All>
; #include *i ../Lib/v2/gdip_all.ahk

pToken := Gdip_Startup()
win_title:="RuneLite - katjak4j"
pBitmap := Gdip_BitmapFromHWND(WinExist(win_title))
; if needed get area of bitmap for search
x:=20 , y:=20 ,w:=100 ,h:=100
area_bitmap := Gdip_CloneBitmapArea(pBitmap, x, y, w, h)
argb:=0xff28f028
posX:=0, posY:=0
Gdip_PixelSearch(area_bitmap,argb, &posX, &posY)
; pBitmap := Gdip_CreateBitmapFromFile("image.png")
; if !Gdip_PixelSearch(pBitmap, ARGB := 0xff0118d9, x, y)
; 	MsgBox, Pixel %ARGB% found at (%x%, %y%)
; else
; 	MsgBox, Pixel %ARGB% not found
; Gdip_DisposeImage(pBitmap)
; Gdip_Shutdown(pToken)
; return

Gdip_PixelSearch(pBitmap, ARGB, &x, &y) {
	static _PixelSearch := 0
	if (!_PixelSearch) {
		MCode_PixelSearch := "8B44241099535583E2035603C233F6C1F80239742418577E388B7C24148B6C24248B5424188D1C85000000008D64240033C085"
		. "D27E108BCF3929743183C00183C1043BC27CF283C60103FB3B74241C7CDF8B4424288B4C242C5F5EC700FFFFFFFF5DC701FFFFFFFF83C8FF5BC38B4C2"
		. "4288B54242C5F890189325E5D33C05BC3"

		; VarSetCapacity(_PixelSearch, StrLen(MCode_PixelSearch)//2)
		Loop (StrLen(MCode_PixelSearch)//2) {
			NumPut("0x" SubStr(MCode_PixelSearch, (2*A_Index)-1, 2), _PixelSearch, A_Index-1, "char")
        }
	}
    Width := 0
    Height := 0
	Gdip_GetImageDimensions(pBitmap, Width, Height)
	if !(Width && Height)
		return -1

    Stride1 := 0, Scan01 := 0, BitmapData1:=0
	if (E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, Stride1, Scan01, BitmapData1))
		return -2

	x := y := 0
	E := DllCall(&_PixelSearch, "uint", Scan01, "int", Width, "int", Height, "int", Stride1, "uint", ARGB, "int*", x, "int*", y)
	Gdip_UnlockBits(pBitmap, BitmapData1)
	return (E = "") ? -3 : E
}

; ;---------------- create demo gui ---------------- 
; hbitmap:=Create_bgrd_png()


; ; Gui.add,text,+0xE w200 h200 hwndimage_hwnd       ; +0xE is SS_BITMAP
; ; Gui, show,,demo

; SendMessage(, (STM_SETIMAGE:=0x172), (IMAGE_BITMAP:=0x0), hBitmap,, "ahk_id " image_hwnd)
; win_title:="demo"
; ;---------------- end create demo gui ---------------- 
; sleep 2000

; pBitmap := Gdip_BitmapFromHWND(WinExist(win_title))

; ; if needed get area of bitmap for search
; x:=20 , y:=20 ,w:=100 ,h:=100

; area_bitmap:=Gdip_CloneBitmapArea(pBitmap, x, y, w, h)

; ;color to search for
; argb:=0xff28f028  

; Gdip_PixelSearch(area_bitmap,argb, posx, posy)

; MouseMove, x+posx,y+posy

; msgbox % x+posx "`n" y+posy 

; ; if needed cleanup
; Gdip_DisposeImage(pBitmap)
; Gdip_DisposeImage(area_bitmap)
; Gdip_Shutdown(pToken)

; exitapp


; Gdip_PixelSearch(pBitmap, ARGB, &x, &y)
; {
; 	static _PixelSearch
; 	if !_PixelSearch
; 	{
; 		MCode_PixelSearch := "8B44241099535583E2035603C233F6C1F80239742418577E388B7C24148B6C24248B5424188D1C85000000008D64240033C085"
; 		. "D27E108BCF3929743183C00183C1043BC27CF283C60103FB3B74241C7CDF8B4424288B4C242C5F5EC700FFFFFFFF5DC701FFFFFFFF83C8FF5BC38B4C2"
; 		. "4288B54242C5F890189325E5D33C05BC3"

; 		VarSetCapacity(_PixelSearch, StrLen(MCode_PixelSearch)//2)
; 		Loop (StrLen(MCode_PixelSearch)//2)
; 			NumPut("0x" SubStr(MCode_PixelSearch, (2*A_Index)-1, 2), _PixelSearch, A_Index-1, "char")
; 	}
; 	Gdip_GetImageDimensions(pBitmap, Width, Height)
; 	if !(Width && Height)
; 		return -1

; 	if (E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, Stride1, Scan01, BitmapData1))
; 		return -2

; 	x := y := 0
; 	E := DllCall(&_PixelSearch, "uint", Scan01, "int", Width, "int", Height, "int", Stride1, "uint", ARGB, "int*", x, "int*", y)
; 	Gdip_UnlockBits(pBitmap, BitmapData1)
; 	return (E = "") ? -3 : E
; }
