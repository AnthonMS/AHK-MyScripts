#Requires AutoHotkey v2.0+

; Win + N (Open Notepad++)
#n:: {
    if !WinExist("ahk_exe notepad++.exe") {
        Run "C:\Program Files\Notepad++\notepad++.exe"
        WinWait("ahk_exe notepad++.exe", , 10)  ; Wait for up to 10 seconds
        WinActivate("ahk_exe notepad++.exe")
    } else {
        WinActivate("ahk_exe notepad++.exe")
    }
}

; Win + C (Open VSCode)
#c:: {
    if !WinExist("ahk_exe code.exe") {
        Run "C:\Users\Anthon\AppData\Local\Programs\Microsoft VS Code\code.exe"
        WinWait("ahk_exe code.exe", , 10)
        WinActivate("ahk_exe code.exe")
    } else {
        WinActivate("ahk_exe code.exe")
    }
}

; Win + B (Open Git Bash)
#b:: {
    if WinExist("ahk_class mintty") {
        WinActivate()
    } else {
        Run "C:\Program Files\Git\git-bash.exe"
        WinWait("ahk_class mintty")
        WinActivate("ahk_class mintty")
    }
}

; Win + F (Open Firefox)
#f:: {
    if !WinExist("ahk_exe firefox.exe") {
        Run "C:\Program Files\Mozilla Firefox\firefox.exe"
        WinWait("ahk_exe firefox.exe", , 10)
        WinActivate("ahk_exe firefox.exe")
    } else {
        WinActivate("ahk_exe firefox.exe")
    }
}

; Win + D (Open Discord)
#d:: {
    if !WinExist("ahk_exe Discord.exe") {
        Run "C:\Users\Anthon\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk"
        WinWait("ahk_exe Discord.exe", , 10)
        WinActivate("ahk_exe Discord.exe")
    } else {
        WinActivate("ahk_exe Discord.exe")
    }
}

; Win + S (Open Steam)
#s:: {
    if !WinExist("ahk_exe steam.exe") {
        Run "C:\Program Files (x86)\Steam\steam.exe"
        WinWait("ahk_exe steam.exe", , 10)
        WinActivate("ahk_exe steam.exe")
    } else {
        WinActivate("ahk_exe steam.exe")
    }
}

; Win + Q (Open qBitTorrent)
#q:: {
    if !WinExist("ahk_exe steam.exe") {
        Run "C:\Program Files\qBittorrent\qbittorrent.exe"
        WinWait("ahk_exe qbittorrent.exe", , 10)
        WinActivate("ahk_exe qbittorrent.exe")
    } else {
        WinActivate("ahk_exe qbittorrent.exe")
    }
}

#1:: {
    startOrStopScript("C:\Users\Anthon\Scripts\ahk\auto-mouse.ahk")
}


; Ctrl + F12 to Exit all AHK apps except the calling script
^F12::ExitAll()


startOrStopScript(scriptPath) {
    DetectHiddenWindows true
    SetTitleMatchMode 'RegEx'
    scriptHWND := 0 

    ; Retrieve the list of all AutoHotkey windows
    HWNDs := WinGetList('ahk_exe AutoHotkey')
    For HWND in HWNDs {
        if HWND != A_ScriptHwnd {
            windowTitle := WinGetTitle(HWND)
            if InStr(windowTitle, scriptPath) {
                scriptHWND := HWND
                break
            }
        }
    }

    if (scriptHWND != 0) {
        WinClose(scriptHWND) ; Close the specific instance
    } 
    else {
        Run(scriptPath) ; Run the script if it is not currently running
    }
}


ExitAll() {
	DetectHiddenWindows true
	SetTitleMatchMode 'RegEx'
	HWNDs := WinGetList('ahk_exe AutoHotkey')
	For HWND in HWNDs
	{
		if HWND != A_ScriptHwnd
			try
				WinKill(HWND)
	}
	ExitApp
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