; Win + N (Open Notepad++)
#n::
    IfWinNotExist, AHK_EXE notepad++.exe
    {
        Run "C:\Program Files\Notepad++\notepad++.exe"
    }
    IfWinExist, AHK_EXE notepad++.exe
    {
        WinActivate AHK_EXE notepad++.exe
    }
    Return

; Win + C (Open VSCode)
#c::
    IfWinNotExist, AHK_EXE code.exe
    {
        Run "C:\Users\Antho\AppData\Local\Programs\Microsoft VS Code\code.exe"
    }
    IfWinExist, AHK_EXE code.exe
    {
        WinActivate AHK_EXE code.exe
    }
    Return

; Win + B (Open Git Bash)
#b::
    IfWinExist, ahk_class mintty
    {
        WinActivate
    }
    else
    {
        ; Otherwise, run a new instance
        Run "C:\Program Files\Git\git-bash.exe"
        WinWait, ahk_class mintty
        WinActivate
    }
    Return

; Win + F (Open Firefox)
#f::
    IfWinNotExist, AHK_EXE firefox.exe
    {
        Run "C:\Program Files\Mozilla Firefox\firefox.exe"
    }
    IfWinExist, AHK_EXE firefox.exe
    {
        WinActivate AHK_EXE firefox.exe
    }
    Return

; Win + D (Open Discord)
#d::
    IfWinNotExist, AHK_EXE Discord.exe
    {
        Run "C:\Users\Antho\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk"
    }
    IfWinExist, AHK_EXE Discord.exe
    {
        WinActivate AHK_EXE Discord.exe
    }
    Return


; Win + S (Open Steam)
#s::
    IfWinNotExist, AHK_EXE steam.exe
    {
        Run "C:\Program Files (x86)\Steam\steam.exe"
    }
    IfWinExist, AHK_EXE steam.exe
    {
        WinActivate AHK_EXE steam.exe
    }
    Return

; Win + P (Open Playnite)
; #p::
;     IfWinNotExist, AHK_EXE Playnite.DesktopApp.exe
;         Run "C:\Users\Antho\AppData\Local\Playnite\Playnite.DesktopApp.exe"
;     IfWinExist, AHK_EXE Playnite.DesktopApp.exe
;         WinActivate AHK_EXE Playnite.DesktopApp.exe
;     Return


; Ctrl + F12
^F12::
    ExitAll()   ; Exits all AHK apps except the calling script.
    return



ExitAll() {  
	DetectHiddenWindows, % ( ( DHW:=A_DetectHiddenWindows ) + 0 ) . "On"
	WinGet, L, List, ahk_class AutoHotkey
	Loop %L%
		If ( L%A_Index% <> WinExist( A_ScriptFullPath " ahk_class AutoHotkey" ) )
			PostMessage, 0x111, 65405, 0,, % "ahk_id " L%A_Index%
	DetectHiddenWindows, %DHW%
}







;RCtrl::
;Send, {LCtrl down}{LShift down}{Space down}{Space up}{LShift up}{LCtrl up}

; Win+Alt+G - Open Gmail in Chrome
;#!g::
;    Run "C:\Program Files\Google\Chrome\Application\chrome.exe" --app="https://mail.google.com/mail/"
;    Return

; Win+Shift+Break - Edit this file
;#+Break::
;    Run "c:\Program Files\Vim\vim73\gvim.exe" "d:\AutoHotkey.ahk"
;    Return


;^F12::
;    MsgBox "Hotkey activated!"