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
global logFile := A_ScriptDir "\activity_log.csv"
global learnedFile := A_ScriptDir "\learned_words.txt"
global whitelist := Map(), autocorrect := Map(), lastWindowTitle := ""
global guiOpen := false
global lastCorrection := ""
global lastCorrectionTime := 0
global russianModeActive := false
global suppressInput := false

LoadSettings()

; --- Налаштування іконки ---
;@Ahk2Exe-SetMainIcon icon.ico
if FileExist("icon.ico")
    TraySetIcon("icon.ico")

; --- Меню трею ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Налаштування", (*) => ShowSettingsGUI())
A_TrayMenu.Add("Відкрити Лог", (*) => OpenLog())
A_TrayMenu.Add("Вийти", (*) => ExitApp())
A_TrayMenu.Default := "Налаштування"

; --- СЛОВНИК РОЗКЛАДКИ ---
global en_to_ua := Map("q","й","w","ц","e","у","r","к","t","е","y","н","u","г","i","ш","o","щ","p","з","[","х","]","ї","a","ф","s","і","d","в","f","а","g","п","h","р","j","о","k","л","l","д",";","ж","'","є","z","я","x","ч","c","с","v","м","b","и","n","т","m","ь",",","б",".","ю","/","?","``","'")
global ua_to_en := Map()
for en, ua in en_to_ua
    ua_to_en[ua] := en

; --- РОСІЙСЬКА → АНГЛІЙСЬКА КЛАВІАТУРА ---
global ru_to_en := Map("й","q","ц","w","у","e","к","r","е","t","н","y","г","u","ш","i","щ","o","з","p","х","[","ъ","]","ф","a","ы","s","в","d","а","f","п","g","р","h","о","j","л","k","д","l","ж",";","э","'","я","z","ч","x","с","c","м","v","и","b","т","n","ь","m","б",",","ю",".")

global currentWord := ""

; --- СЛОВНИКИ ДЛЯ РОЗПІЗНАВАННЯ МОВИ ---
#Include en_dict.ahk
#Include uk_dict.ahk

global enDict := Map(), ukDict := Map()
LoadDict(enDict, enDictStr)
LoadDict(ukDict, ukDictStr)

; --- НАВЧАННЯ: завантажити вивчені слова ---
global learnedEn := Map(), learnedUk := Map()
LoadLearnedWords()

; --- ОНЛАЙН-ВИЯВЛЕННЯ РОСІЙСЬКОЇ МОВИ ---
global onlineCache := Map()
global onlineEnabled := 1
global lastOnlineRequest := 0

LoadDict(dict, str) {
    Loop Parse, str, " " {
        if (A_LoopField != "")
            dict[A_LoopField] := 1
    }
}

LoadLearnedWords() {
    global learnedEn, learnedUk, learnedFile
    if !FileExist(learnedFile)
        return
    try {
        content := FileRead(learnedFile, "UTF-8")
        Loop Parse, content, "`n`r" {
            line := Trim(A_LoopField)
            if (line = "" || InStr(line, ";"))
                continue
            parts := StrSplit(line, "|")
            if (parts.Length >= 2) {
                lang := parts[1], word := parts[2]
                if (lang = "en")
                    learnedEn[word] := 1
                else if (lang = "uk")
                    learnedUk[word] := 1
            }
        }
    }
}

SaveLearnedWord(lang, word) {
    global learnedFile
    FileAppend(lang "|" word "`r`n", learnedFile, "UTF-8")
}

; --- СПИСОК РОСІЙСЬКИХ СЛІВ (англ розкладкою) ---
global russianWords := Map()
for w in StrSplit("ghbdtn|rfr|vyt|ytn|tckb|xtkjdtr|ltkfnm|d[jl|vjq|jy|dtcm|gjxnj|rjulf|jntxtcnrf|ytxtnrf|ntxtcnrf|ckfy|cthtnbz|rfkby|rfxfkby|vjkjltq|rjy|xtkjd|kbyrf|pltcm|dctv|yjdsq|vyjuj|yflj|gjnjve|ctqxf|gjkyjcnm|vjvtyn|gjyznyj|djphfcm|gjckb|gjckbq|gjckdlyt|gjckdlr|gjcvjnht|gjcktlrb|gjcktlrf|vytnf|gjhlrj|gjhljdf|gjcktlybq|gjcktljdf|rjhvf|rjhjv|rfxfk|ghbdj|vtnfy|djjcnf|rfkbyj|ltkf|ntcn|htnm|gjyznyj|gjckt|gjcktl|lf|pflf|xnj|'nj|yt|b|d|yf|z|c|f|jyf|gj|jyb|jyj|r|e|ns|;t|ds|,sk|lks|,s|jn|ghb|vyt|tcnm|dhtvz|nf|nj|tuj|tuz|ckjdj|kbwj|ult|ltym|ltkj|herf|hf,jnf|ljv|ctvz|lheu|;bdym|ht,tyr|vfvf|gfgf|,hfn|ctcnhf|ltyub|vfibyf|rybuf|irjkf|hf,jnfnm|k.,bnm|[jxtnm|vxfm|ujdjdbnm|pyfnm|dbltnm|cksifnm|gjybvfnm|cghfibdfnm|jndtxtnm|gbcfnm|xbnfnm|cbnfnm|;bnm|gbnm|cfgnm|[jlbnm|,ufnm|cbltnm|cnjznm|kt;fnm|regbnm|ghjlfnm|lfnm|yfqnb|jnrhsnm|pfrhsnm|yfxfnm|cgfcnbq|gj;fkrfcnb|gjvjue|cvjnthz|nf,rjq|gthdsq|[jhjibq|,jkj;sq|[jhjij|gk[jj|yjhvfkmyj|jnkbxyj|ye;lyj|vjkjlyj|ytktkz|df;jyj|bynthtcyj|djpvj;yj|rjyatxyj|ghfdbkmyj|ytghfdbkmyj|,scnhj|vtltyyj|vfktymrbq|dscjrbq|ybprbq|lkbyyjq|rjhnrbq|ibhjrbq|eprbq|njcnbq|njyrbq|rhfcbdsq|cnfhbq|lj,hbq|pkjq|evyjq|ukgegq|cbkmyjq|ckf,bq|,jkmyjq|pljhjdbq|,jufnbq|,tlyjq", "|")
    russianWords[w] := 1

global russianCyrillicWords := Map()
for w in StrSplit("русский|русская|русское|россия|российский|спасибо|пожалуйста|сейчас|почему|конечно|можно|нужно|хорошо|плохо|работа|работать|говорить|понимать|спрашивать|отвечать|ребенок|деньги|машина|книга|школа|любить|хотеть|помогать", "|")
    russianCyrillicWords[w] := 1

; --- ІНІЦІАЛІЗАЦІЯ ЛОГУ (CSV) ---
if !FileExist(logFile)
    FileAppend("Дата;Час;Програма;Слово;Дія`r`n", logFile, "UTF-8")

; --- МОНІТОРИНГ ВВОДУ ---
ih := InputHook("V L0")
ih.OnChar := (ih, char) => HandleChar(char)
ih.Start()

HandleChar(char) {
    global currentWord, lastWindowTitle, guiOpen, russianModeActive, suppressInput
    if suppressInput
        return

    try {
        activeTitle := WinGetTitle("A")
        if (activeTitle != lastWindowTitle) {
            cleanTitle := RegExReplace(activeTitle, "i) — (Google Chrome|Mozilla Firefox|Microsoft Edge|Safari|Opera|Cursor)$")
            LogAction(cleanTitle, "", "Вікно")
            lastWindowTitle := cleanTitle
        }
    }

    if guiOpen {
        currentWord := ""
        return
    }

    if RegExMatch(char, "[\s\r\n\t]") {
        if (currentWord != "")
            ProcessFullWord(currentWord, char)
        currentWord := ""
        russianModeActive := false
        return
    }

    if (GetLayout() = 0x0419) {
        if !russianModeActive {
            russianModeActive := true
            ShowAlert("ПРОГРАМА НЕ ПІДТРИМУЄ МОВУ ОКУПАНТА!")
        }
        converted := ConvertWord(ConvertWord(char, ru_to_en), en_to_ua)
        ReplaceCurrentInput(char, converted, 0x0422)
        currentWord .= converted
        return
    }

    currentWord .= char
} 

ReplaceCurrentInput(original, replacement, targetLayout := 0) {
    global suppressInput
    suppressInput := true
    Send("{Backspace " StrLen(original) "}")
    if targetLayout {
        PostMessage(0x50, 0, targetLayout,, "A")
        Sleep(60)
    }
    Send(replacement)
    suppressInput := false
}

ProcessFullWord(word, triggerChar) {
    layout := GetLayout()
    wLower := StrLower(word)

    ; --- РОСІЙСЬКА РОЗКЛАДКА: резервний захист для вже набраного слова ---
    if (layout = 0x0419) {
        ShowAlert("ПРОГРАМА НЕ ПІДТРИМУЄ МОВУ ОКУПАНТА!")
        converted := ConvertWord(ConvertWord(word, ru_to_en), en_to_ua)
        ReplaceCurrentInput(word triggerChar, converted triggerChar, 0x0422)
        LogAction("", word, "Рос. розкладка -> українська")
        return
    }

    if whitelist.Has(wLower)
        return
    if autocorrect.Has(wLower) {
        Send("{Backspace " (StrLen(word) + 1) "}")
        Send(autocorrect[wLower] triggerChar)
        LogAction("", word, "Автозаміна -> " autocorrect[wLower])
        return
    }

    ; --- РОСІЙСЬКЕ СЛОВО (будь-яка розкладка): блокуємо ---
    if (russianWords.Has(wLower) || russianCyrillicWords.Has(wLower)) {
        ShowAlert("ПРОГРАМА НЕ ПІДТРИМУЄ МОВУ ОКУПАНТА!")
        LogAction("", word, "Російське слово (заблоковано)")
        return
    }

    ; --- ОНЛАЙН-ВИЯВЛЕННЯ: для слів, яких немає в жодному словнику ---
    if (onlineEnabled && StrLen(word) >= 3 && HasCyrillic(word) && !enDict.Has(wLower) && !ukDict.Has(wLower) && !learnedEn.Has(wLower) && !learnedUk.Has(wLower)) {
        lang := DetectLanguageOnline(word)
        if (lang = "ru") {
            ShowAlert("ПРОГРАМА НЕ ПІДТРИМУЄ МОВУ ОКУПАНТА!")
            LogAction("", word, "Російське слово (онлайн)")
            return
        }
    }

    CheckAndCorrect(word, triggerChar, layout)
}

CheckAndCorrect(word, triggerChar, layout) {
    global lastCorrection, lastCorrectionTime, learnedEn, learnedUk
    isEng := (layout = 0x0409)
    dict := isEng ? en_to_ua : ua_to_en
    targetLayout := isEng ? 0x0422 : 0x0409
    converted := ConvertWord(word, dict)
    wLower := StrLower(word)
    convLower := StrLower(converted)

    shouldFix := false

    if (isEng) {
        ; Перевіряємо: основний словник + вивчені слова
        if (ukDict.Has(convLower) || learnedUk.Has(convLower)) {
            if !enDict.Has(wLower) && !learnedEn.Has(wLower)
                shouldFix := true
        } else {
            shouldFix := ShouldFixFromEn(word, wLower, convLower)
        }
    } else {
        if (enDict.Has(convLower) || learnedEn.Has(convLower)) {
            if !ukDict.Has(wLower) && !learnedUk.Has(wLower)
                shouldFix := true
        } else {
            shouldFix := ShouldFixFromUa(word, wLower, convLower)
        }
    }

    if (shouldFix && word != converted) {
        Send("{Backspace " (StrLen(word) + 1) "}")
        PostMessage(0x50, 0, targetLayout,, "A"), Sleep(100)
        Send(converted triggerChar)
        LogAction("", word, "Виправлено -> " converted)
        lastCorrection := converted
        lastCorrectionTime := A_TickCount
    }
}

ConvertWord(word, dict) {
    converted := ""
    Loop Parse, word {
        c := StrLower(A_LoopField)
        res := dict.Has(c) ? dict[c] : A_LoopField
        converted .= (A_LoopField == c ? res : StrUpper(res))
    }
    return converted
}

; --- ЕВРИСТИКИ ДЛЯ АНГЛІЙСЬКОЇ РОЗКЛАДКИ ---
HasUkSpecific(s) => RegExMatch(s, "[іїєґ']")

ShouldFixFromEn(word, wLower, convLower) {
    if (StrLen(word) = 1) {
        if RegExMatch(word, "i)^[aeiou]$")
            return false
        if en_to_ua.Has(wLower)
            return true
        return false
    }
    if (StrLen(word) = 2) {
        if !RegExMatch(word, "i)[aeiouy]") {
            if HasUkSpecific(convLower)
                return true
            return false
        }
        return false
    }
    if !RegExMatch(word, "i)[aeiouy]") {
        if HasUkSpecific(convLower)
            return true
        if RegExMatch(word, "[\[\]\\;]")
            return true
        return false
    }
    if RegExMatch(word, "[\[\]\\;]")
        return true
    return false
}

; --- ЕВРИСТИКИ ДЛЯ УКРАЇНСЬКОЇ РОЗКЛАДКИ ---
ShouldFixFromUa(word, wLower, convLower) {
    if (StrLen(word) = 1)
        return false
    if (StrLen(word) = 2) {
        if !RegExMatch(word, "i)[аоіеєуяюїи]") {
            if RegExMatch(convLower, "[aeiouy]")
                return true
        }
        return false
    }
    if !RegExMatch(word, "i)[аоіеєуяюїи]") {
        if RegExMatch(convLower, "[aeiouy]")
            return true
        return false
    }
    return false
}

; --- ЛОГУВАННЯ В CSV ---
LogAction(app, word, action) {
    global logFile, lastWindowTitle
    date := FormatTime(, "dd.MM.yyyy")
    time := FormatTime(, "HH:mm:ss")
    if (app = "")
        app := lastWindowTitle
    app := StrReplace(app, ";", ",")
    word := StrReplace(word, ";", ",")
    action := StrReplace(action, ";", ",")
    FileAppend(date ";" time ";" app ";" word ";" action "`r`n", logFile, "UTF-8")
}

OpenLog() {
    global logFile
    if FileExist(logFile)
        Run(logFile)
    else
        MsgBox("Лог ще порожній")
}

; --- ГРАФІЧНИЙ ІНТЕРФЕЙС ---
ShowSettingsGUI() {
    global guiOpen
    static MainGui := 0
    if MainGui {
        MainGui.Show()
        return
    }
    guiOpen := true
    MainGui := Gui("+AlwaysOnTop", "UASwitcher Pro - Налаштування")
    MainGui.OnEvent("Close", (*) => (guiOpen := false))
    MainGui.OnEvent("Escape", (*) => (guiOpen := false, MainGui.Hide()))

    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "w450 Center", "--- ВИКЛЮЧЕННЯ (Whitelist) ---")
    MainGui.SetFont("s9")
    MainGui.Add("Text", "xm", "Слово:")
    EditWhite := MainGui.Add("Edit", "w200")
    BtnAddWhite := MainGui.Add("Button", "x+10 w100 Default", "Додати")
    LBWhite := MainGui.Add("ListBox", "xm w430 h80")
    BtnDelWhite := MainGui.Add("Button", "w100", "Видалити")

    MainGui.Add("Text", "xm h2 w430 0x10")

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

    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "w450 Center", "--- ОНЛАЙН-ВИЯВЛЕННЯ ---")
    MainGui.SetFont("s9")
    ChkOnline := MainGui.Add("CheckBox", "xm w430", "Увімкнути Google Translate для виявлення російських слів")
    ChkOnline.Value := onlineEnabled
    ChkOnline.OnEvent("Click", (*) => ToggleOnline(ChkOnline.Value))

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
    BtnLog.OnEvent("Click", (*) => OpenLog())
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

ToggleOnline(value) {
    global onlineEnabled, settingsFile
    onlineEnabled := value
    IniWrite(value, settingsFile, "Settings", "OnlineDetection")
}

LoadSettings() {
    global onlineEnabled
    if !FileExist(settingsFile)
        return
    try {
        onlineEnabled := IniRead(settingsFile, "Settings", "OnlineDetection", 1)
    }
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

; --- ОНЛАЙН-ВИЯВЛЕННЯ МОВИ ЧЕРЕЗ GOOGLE TRANSLATE ---
DetectLanguageOnline(text) {
    global onlineCache, lastOnlineRequest
    wLower := StrLower(text)
    if onlineCache.Has(wLower)
        return onlineCache[wLower]

    if (A_TickCount - lastOnlineRequest < 300) {
        onlineCache[wLower] := ""
        return ""
    }
    lastOnlineRequest := A_TickCount

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(2000, 2000, 2000, 2000)
        encoded := UriEncode(text)
        url := "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=uk&dt=t&q=" encoded
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "UASwitcher/2.0")
        http.SetRequestHeader("Accept", "application/json")
        http.Send()
        if (http.Status != 200) {
            onlineCache[wLower] := ""
            return ""
        }
        response := http.ResponseText
        if RegExMatch(response, '\]\],null,"([a-z]{2})"', &m) {
            lang := m[1]
            onlineCache[wLower] := lang
            return lang
        }
    } catch {
        onlineCache[wLower] := ""
        return ""
    }
    onlineCache[wLower] := ""
    return ""
}

UriEncode(str) {
    buffer := Buffer(StrPut(str, "UTF-8"))
    length := StrPut(str, buffer, "UTF-8") - 1
    result := ""
    Loop length {
        byte := NumGet(buffer, A_Index - 1, "UChar")
        if ((byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A) || byte = 0x2D || byte = 0x2E || byte = 0x5F || byte = 0x7E)
            result .= Chr(byte)
        else
            result .= "%" Format("{:02X}", byte)
    }
    return result
}

HasCyrillic(text) => RegExMatch(text, "[А-Яа-яІіЇїЄєҐґЁёЫыЭэЪъ]" )

GetLayout() => DllCall("GetKeyboardLayout", "UInt", DllCall("GetWindowThreadProcessId", "Ptr", DllCall("GetForegroundWindow"), "Ptr", 0), "Ptr") & 0xFFFF

; --- Backspace: скасування виправлення та автонавчання ---
~Backspace:: {
    global currentWord, lastCorrection, lastCorrectionTime, learnedEn, learnedUk
    if (StrLen(currentWord) > 0) {
        currentWord := SubStr(currentWord, 1, -1)
    } else {
        ; Якщо користувач натискає Backspace одразу після виправлення —
        ; це означає, що виправлення було помилковим.
        ; Скасовуємо виправлення і запам'ятовуємо, що оригінальне слово — правильне.
        if (lastCorrection != "" && (A_TickCount - lastCorrectionTime) < 2000) {
            ; Користувач скасував виправлення — запам'ятовуємо оригінальне слово
            ; як правильне в цій мові (автонавчання)
            layout := GetLayout()
            if (layout = 0x0422) {
                ; Була українська розкладка, виправлення було на англійську
                ; Користувач хоче залишити українське слово
                ; Запам'ятовуємо: це слово — українське
                w := lastCorrection
                if !ukDict.Has(StrLower(w)) {
                    learnedUk[StrLower(w)] := 1
                    SaveLearnedWord("uk", StrLower(w))
                    LogAction("", w, "Вивчено (укр)")
                }
            } else if (layout = 0x0409) {
                ; Була англійська розкладка, виправлення було на українську
                ; Користувач хоче залишити англійське слово
                w := lastCorrection
                if !enDict.Has(StrLower(w)) {
                    learnedEn[StrLower(w)] := 1
                    SaveLearnedWord("en", StrLower(w))
                    LogAction("", w, "Вивчено (англ)")
                }
            }
            lastCorrection := ""
            lastCorrectionTime := 0
        }
    }
}
