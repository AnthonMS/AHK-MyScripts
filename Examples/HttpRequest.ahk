#Requires AutoHotkey v2.0

#Include ../Lib/v2/WinHttpRequest.ahk

url := "http://localhost:8081/events"

oOptions := Map()
oOptions["SslError"] := false
oOptions["UA"] := "Autohotkey-lol"

http := WinHttpRequest(oOptions)

; endpoint := "http://httpbin.org/get?key1=val1&key2=val2"
response := http.GET(url)
MsgBox(response.Text, "GET", 0x40040)









; GET
; endpoint := "http://httpbin.org/get?key1=val1&key2=val2"
; response := http.GET(endpoint)
; MsgBox(response.Text, "GET", 0x40040)

; ; or

; endpoint := "http://httpbin.org/get"
; body := "key1=val1&key2=val2"
; response := http.GET(endpoint, body)
; MsgBox(response.Text, "GET", 0x40040)

; ; or

; endpoint := "http://httpbin.org/get"
; body := Map()
; body["key1"] := "val1"
; body["key2"] := "val2"
; response := http.GET(endpoint, body)
; MsgBox(response.Text, "GET", 0x40040)




; POST, regular
; endpoint := "http://httpbin.org/post"
; body := Map("key1", "val1", "key2", "val2")
; response := http.POST(endpoint, body)
; MsgBox(response.Text, "POST", 0x40040)




; POST, force multipart (for big payloads): 
; endpoint := "http://httpbin.org/post"
; body := Map()
; body["key1"] := "val1"
; body["key2"] := "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
; options := {Multipart:true}
; response := http.POST(endpoint, body, , options)
; MsgBox(response.Text, "POST", 0x40040)




; HEAD, retrieve a specific header: 
; endpoint := "https://github.com/"
; response := http.HEAD(endpoint)
; MsgBox(response.Headers["X-GitHub-Request-Id"], "HEAD", 0x40040)




; Download the response (it handles binary data): 
; endpoint := "https://www.google.com/favicon.ico"
; options := Map("Save", A_Temp "\google.ico")
; http.GET(endpoint, , , options)
; RunWait(A_Temp "\google.ico")
; FileDelete(A_Temp "\google.ico")



; To upload files, put the paths inside an array: 
; ; Image credit: http://probablyprogramming.com/2009/03/15/the-tiniest-gif-ever
; Download("http://probablyprogramming.com/wp-content/uploads/2009/03/handtinyblack.gif", A_Temp "\1x1.gif")

; endpoint := "http://httpbun.org/anything"
; ; Single file
; body := Map("test", 123, "my_image", [A_Temp "\1x1.gif"])
; ; Multiple files (PHP server style)
; ; body := Map("test", 123, "my_image[]", [A_Temp "\1x1.gif", A_Temp "\1x1.gif"])
; headers := Map()
; headers["Accept"] := "application/json"
; response := http.POST(endpoint, body, headers)
; MsgBox(response.Json.files.my_image, "Upload", 0x40040)