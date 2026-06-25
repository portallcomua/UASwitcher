#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Автозавантаження та Ярлики ---
try {
    startupShortcut := A_Startup "\UASwitcherPro.lnk"
    desktopShortcut := A_Desktop "\UASwitcherPro.lnk"
    if !FileExist(startupShortcut)
        FileCreateShortcut(A_ScriptFullPath, startupShortcut, A_ScriptDir)
    if !FileExist(desktopShortcut)
        FileCreateShortcut(A_ScriptFullPath, desktopShortcut, A_ScriptDir)
}

; --- Файли та Глобальні змінні ---
global settingsFile := A_ScriptDir "\settings.ini"
global logFile := A_ScriptDir "\activity_log.txt"
global whitelist := Map(), autocorrect := Map(), lastWindowTitle := ""

LoadSettings()

; --- Налаштування іконки ---
;@Ahk2Exe-SetMainIcon icon.ico
if FileExist("icon.ico")
    TraySetIcon("icon.ico")

; --- Меню трею ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Налаштування", (*) => ShowSettingsGUI())
A_TrayMenu.Add("Відкрити Лог", (*) => (FileExist(logFile) ? Run(logFile) : MsgBox("Лог ще порожній")))
A_TrayMenu.Add("Вийти", (*) => ExitApp())
A_TrayMenu.Default := "Налаштування"

; --- СЛОВНИК ---
global en_to_ua := Map("q","й","w","ц","e","у","r","к","t","е","y","н","u","г","i","ш","o","щ","p","з","[","х","]","ї","a","ф","s","і","d","в","f","а","g","п","h","р","j","о","k","л","l","д",";","ж","'","є","z","я","x","ч","c","с","v","м","b","и","n","т","m","ь",",","б",".","ю","/","?", "``","'")
global ua_to_en := Map()
for en, ua in en_to_ua
    ua_to_en[ua] := en

global currentWord := ""

; --- МОНІТОРИНГ ВВОДУ ТА ЛОГУВАННЯ ---
ih := InputHook("V L0")
ih.OnChar := (ih, char) => HandleChar(char)
ih.Start()

HandleChar(char) {
    global currentWord, lastWindowTitle
    try {
        activeTitle := WinGetTitle("A")
        if (activeTitle != lastWindowTitle) {
            cleanTitle := RegExReplace(activeTitle, "i) — (Google Chrome|Mozilla Firefox|Microsoft Edge|Safari|Opera|Cursor)$")
            FileAppend("`r`n`r`n[" FormatTime(, "dd.MM HH:mm") "] >>> " cleanTitle " <<<`r`n", logFile, "UTF-8")
            lastWindowTitle := activeTitle
        }
        if (char = "`r" || char = "`n")
            FileAppend(" [ENTER]`r`n", logFile, "UTF-8")
        else if (char = "`t")
            FileAppend(" [TAB] ", logFile, "UTF-8")
        else
            FileAppend(char, logFile, "UTF-8")
    }
    if RegExMatch(char, "[\s\r\n\t]") {
        if (currentWord != "")
            ProcessFullWord(currentWord, char)
        currentWord := ""
    } else {
        currentWord .= char
    }
}

ProcessFullWord(word, triggerChar) {
    layout := GetLayout()
    if (layout = 0x0419)
        return
    wLower := StrLower(word)
    if whitelist.Has(wLower)
        return
    if autocorrect.Has(wLower) {
        Send("{Backspace " (StrLen(word) + 1) "}")
        Send(autocorrect[wLower] triggerChar)
        return
    }
    if (layout = 0x0409 && RegExMatch(wLower, "^(ds\[jl|dsh\[jl|ghbdtn|rfr|nxj)$")) {
        ShowAlert("ПРОГРАМА НЕ ПІДТРИМУЄ РОСІЙСЬКУ МОВУ!")
        return 
    }
    CheckAndCorrect(word, triggerChar, layout)
}

CheckAndCorrect(word, triggerChar, layout) {
    isEng := (layout = 0x0409), dict := isEng ? en_to_ua : ua_to_en
    targetLayout := isEng ? 0x0422 : 0x0409
    converted := ""
    Loop Parse, word {
        c := StrLower(A_LoopField), res := dict.Has(c) ? dict[c] : A_LoopField
        converted .= (A_LoopField == c ? res : StrUpper(res))
    }
    shouldFix := false, wLower := StrLower(word), convLower := StrLower(converted)
    if (isEng) {
        if (StrLen(word) = 1 && RegExMatch(word, "i)[pizauonsvn]")) || !RegExMatch(word, "i)[aeiouy]") || RegExMatch(wLower, "^(uheif|uhtrf|rj\[fyyz|pd'zpjr)$") || RegExMatch(word, "[\[\]\\; ',\.m``]")
            shouldFix := true
    } else {
        if !RegExMatch(word, "i)[аоіеєуяюїи]") || RegExMatch(convLower, "i)^(hello|my|friend|success|better|final|xerox|red|green|well|you|good|daddy|size|time|day|pear|site|save|ever|raison)$") || RegExMatch(word, "i)[йцкнгшщзхфвпрлджчсмтьб]{4,}")
            shouldFix := true
    }
    if (shouldFix && word != converted) {
        Send("{Backspace " (StrLen(word) + 1) "}")
        PostMessage(0x50, 0, targetLayout,, "A"), Sleep(100)
        Send(converted triggerChar)
    }
}

; --- ГРАФІЧНИЙ ІНТЕРФЕЙС (БЕЗ ЗАКЛАДОК) ---
ShowSettingsGUI() {
    static MainGui := 0
    if MainGui {
        MainGui.Show()
        return
    }
    MainGui := Gui("+AlwaysOnTop", "UASwitcher Pro - Налаштування")
    
    ; Секція ВИКЛЮЧЕННЯ
    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "w450 Center", "--- ВИКЛЮЧЕННЯ (Whitelist) ---")
    MainGui.SetFont("s9")
    MainGui.Add("Text", "xm", "Слово:")
    EditWhite := MainGui.Add("Edit", "w200")
    BtnAddWhite := MainGui.Add("Button", "x+10 w100 Default", "Додати")
    LBWhite := MainGui.Add("ListBox", "xm w430 h80")
    BtnDelWhite := MainGui.Add("Button", "w100", "Видалити")

    MainGui.Add("Text", "xm h2 w430 0x10")

    ; Секція АВТОЗАМІНА
    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "w450 Center", "--- АВТОЗАМІНА ---")
    MainGui.SetFont("s9")
    MainGui.Add("Text", "xm", "Замінити:")
    EditAutoFrom := MainGui.Add("Edit", "w100")
    MainGui.Add("Text", "x+5", "на:")
    EditAutoTo := MainGui.Add("Edit", "x+5 w200")
    BtnAddAuto := MainGui.Add("Button", "x+5 w70", "Додати")
    LBAuto := MainGui.Add("ListBox", "xm w430 h80")
    BtnDelAuto := MainGui.Add("Button", "w100", "Видалити")

    MainGui.Add("Text", "xm h2 w430 0x10")
    BtnLog := MainGui.Add("Button", "xm w430 h40", "ВІДКРИТИ ІСТОРІЮ ДІЙ (LOG)")

    RefreshLists() {
        LBWhite.Delete(), LBAuto.Delete()
        for word, val in whitelist
            LBWhite.Add([word])
        for from, to in autocorrect
            LBAuto.Add([from " -> " to])
    }
    RefreshLists()

    BtnAddWhite.OnEvent("Click", (*) => (AddDataFunc("White", EditWhite.Value, "", RefreshLists), EditWhite.Value := ""))
    BtnDelWhite.OnEvent("Click", (*) => DelDataFunc("White", LBWhite.Text, RefreshLists))
    BtnAddAuto.OnEvent("Click", (*) => (AddDataFunc("Auto", EditAutoFrom.Value, EditAutoTo.Value, RefreshLists), EditAutoFrom.Value := "", EditAutoTo.Value := ""))
    BtnDelAuto.OnEvent("Click", (*) => DelDataFunc("Auto", LBAuto.Text, RefreshLists))
    BtnLog.OnEvent("Click", (*) => (FileExist(logFile) ? Run(logFile) : 0))
    MainGui.Show()
}

AddDataFunc(type, v1, v2, cb) {
    if (v1 = "")
        return
    if (type = "White") {
        whitelist[StrLower(v1)] := 1
        IniWrite(1, settingsFile, "Whitelist", v1)
    } else {
        if (v2 = "")
            return
        autocorrect[StrLower(v1)] := v2
        IniWrite(v2, settingsFile, "Autocorrect", v1)
    }
    if (cb != 0)
        cb()
}

DelDataFunc(type, sel, cb) {
    if (sel = "")
        return
    if (type = "White") {
        whitelist.Delete(StrLower(sel)), IniDelete(settingsFile, "Whitelist", sel)
    } else {
        key := RegExReplace(sel, " ->.*"), autocorrect.Delete(StrLower(key)), IniDelete(settingsFile, "Autocorrect", key)
    }
    if (cb != 0)
        cb()
}

LoadSettings() {
    if !FileExist(settingsFile)
        return
    try {
        white := IniRead(settingsFile, "Whitelist")
        Loop Parse, white, "`n" {
            k := RegExReplace(A_LoopField, "=.*")
            if (k != "")
                whitelist[StrLower(k)] := 1
        }
    }
    try {
        auto := IniRead(settingsFile, "Autocorrect")
        Loop Parse, auto, "`n" {
            p := StrSplit(A_LoopField, "=")
            if (p.Length >= 2)
                autocorrect[StrLower(p[1])] := p[2]
        }
    }
}

ShowAlert(msg) {
    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow"), MyGui.BackColor := "Red", MyGui.SetFont("s18 w700", "Verdana")
    MyGui.Add("Text", "Center cWhite", "  " msg "  "), MyGui.Show("xCenter y20 NoActivate")
    SetTimer(() => MyGui.Destroy(), 3000)
}

GetLayout() => DllCall("GetKeyboardLayout", "UInt", DllCall("GetWindowThreadProcessId", "Ptr", DllCall("GetForegroundWindow"), "Ptr", 0), "Ptr") & 0xFFFF

~Backspace:: {
    global currentWord
    if (StrLen(currentWord) > 0)
        currentWord := SubStr(currentWord, 1, -1)
}
