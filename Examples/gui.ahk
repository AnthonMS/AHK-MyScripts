#Requires AutoHotkey v2.0

#Include <Gui/Window>
#Include <Gui/Page>

class HomePage extends Page {
    __New(window:=false, name:="Home") {
        super.__New(window, name)

        ; this.AddElement("Text", "x15 y15 w100 h25 +0x200 -Background", "Tester123")
    }

    Init() {
        this.AddElement("Text", "x15 y15 w100 h25 +0x200 -Background", "Home")
    }

    Show() {
        super.Show()
    }
}


class InfoPage extends Page {
    __New(window:=false, name:="Info") {
        super.__New(window, name)
    }

    Init() {
        this.AddElement("Text", "x15 y15 w100 h25 +0x200 -Background", "Info")
    }

    Show() {
        super.Show()
    }
}

pageHome := HomePage()
pageInfo := InfoPage()
myGui := Window("GUI Example", "+Resize -MaximizeBox +MinSize500x +MaxSize500x", pageHome)
myGui.AddPage(InfoPage())
myGui.Show()
Sleep(2000)
myGui.ShowPage("Info")