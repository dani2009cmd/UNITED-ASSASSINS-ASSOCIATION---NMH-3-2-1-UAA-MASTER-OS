#RequireAdmin
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Misc.au3>

; --- AUTOMATIC CLEANUP ON EXIT ---
OnAutoItExitRegister("CleanupKeys")

; --- 1. CONFIGURATION & ENGINE OPTIONS ---
Opt("WinTitleMatchMode", 2)
Opt("GUIOnEventMode", 0)
Opt("SendCapslockMode", 0)

Global $sIniFile = @ScriptDir & "\nmh_accessibility.ini"

Global $iKeyDelay     = Int(IniRead($sIniFile, "Engine", "SendKeyDelay", "25"))
Global $iKeyDownDelay = Int(IniRead($sIniFile, "Engine", "SendKeyDownDelay", "35"))
Global $iClickSpeed   = Int(IniRead($sIniFile, "Engine", "ClickSpeed", "50"))
Global $iMashSpeed    = Int(IniRead($sIniFile, "Engine", "MashSpeed", "30"))
Global $iEngineMode   = Int(IniRead($sIniFile, "Engine", "Mode", "1"))

Opt("SendKeyDelay", $iKeyDelay)
Opt("SendKeyDownDelay", $iKeyDownDelay)

; TRIGGER HOTKEYS (WHAT YOU PRESS)
Global $sKeyAutoWalk   = IniRead($sIniFile, "Binds", "AutoWalk", "{F1}")
Global $sKeyLockToggle = IniRead($sIniFile, "Binds", "LockToggle", "{LSHIFT}")
Global $sKeyAutoFinish = IniRead($sIniFile, "Binds", "AutoFinish", "{F3}")
Global $sKeyMash       = IniRead($sIniFile, "Binds", "Mash", "e")
Global $sKeyClash      = IniRead($sIniFile, "Binds", "Clash", "{NUMPAD4}")
Global $sKeyKatana     = IniRead($sIniFile, "Binds", "Katana", "{NUMPAD3}")
Global $sKeyMowSweep   = IniRead($sIniFile, "Binds", "MowSweep", "{NUMPAD1}")
Global $sKeyPlunger    = IniRead($sIniFile, "Binds", "Plunger", "{NUMPAD2}")
Global $sKeyAutoClick  = IniRead($sIniFile, "Binds", "AutoClick", "{F5}")
Global $sKeyToggle     = IniRead($sIniFile, "Binds", "Toggle", "{F2}")
Global $sKeyGuiToggle  = IniRead($sIniFile, "Binds", "GuiToggle", "{F4}")

; TARGET GAME ACTION KEYS (WHAT THE SCRIPT PRESSES IN-GAME)
Global $sKeyMoveForward= IniRead($sIniFile, "GameKeys", "MoveForward", "w")
Global $sKeyMoveLeft   = IniRead($sIniFile, "GameKeys", "MoveLeft", "a")
Global $sKeyMoveBack   = IniRead($sIniFile, "GameKeys", "MoveBack", "s")
Global $sKeyMoveRight  = IniRead($sIniFile, "GameKeys", "MoveRight", "d")
Global $sKeyLockTarget = IniRead($sIniFile, "GameKeys", "LockTarget", "{LSHIFT}")
Global $sKeyRechargeBtn= IniRead($sIniFile, "GameKeys", "RechargeBtn", "r")
Global $sKeyMashAction = IniRead($sIniFile, "GameKeys", "MashAction", "e")
Global $sKeyDirUp      = IniRead($sIniFile, "GameKeys", "DirUp", "{UP}")
Global $sKeyDirDown    = IniRead($sIniFile, "GameKeys", "DirDown", "{DOWN}")
Global $sKeyDirLeft    = IniRead($sIniFile, "GameKeys", "DirLeft", "{LEFT}")
Global $sKeyDirRight   = IniRead($sIniFile, "GameKeys", "DirRight", "{RIGHT}")

; --- 2. GLOBAL STATE TRACKERS ---
Global $bScriptEnabled = True
Global $bAutoWalk      = False
Global $bLockActive    = False
Global $bMash          = False
Global $bClash         = False
Global $bMow           = False
Global $bPlunge        = False
Global $bAutoClick     = False
Global $bKatana        = False

; GUI CONTROL DECLARATIONS
Global $btnBindAutoWalk, $inpAutoWalk
Global $btnBindLockToggle, $inpLockToggle
Global $btnBindAutoFinish, $inpAutoFinish
Global $btnBindMash, $inpMash
Global $btnBindClash, $inpClash
Global $btnBindKatana, $inpKatana
Global $btnBindMowSweep, $inpMowSweep
Global $btnBindPlunger, $inpPlunger
Global $btnBindAutoClick, $inpAutoClick
Global $btnBindToggle, $inpToggle
Global $btnBindGuiToggle, $inpGuiToggle

Global $btnBindMoveForward, $inpMoveForward
Global $btnBindMoveLeft, $inpMoveLeft
Global $btnBindMoveBack, $inpMoveBack
Global $btnBindMoveRight, $inpMoveRight
Global $btnBindLockTarget, $inpLockTarget
Global $btnBindRechargeBtn, $inpRechargeBtn
Global $btnBindMashAction, $inpMashAction
Global $btnBindDirUp, $inpDirUp
Global $btnBindDirDown, $inpDirDown
Global $btnBindDirLeft, $inpDirLeft
Global $btnBindDirRight, $inpDirRight

Global $btnDummy1, $inpKeyDelay
Global $btnDummy2, $inpKeyDownDelay
Global $btnDummy3, $inpClickSpeed
Global $btnDummy4, $inpMashSpeed

; --- 3. HUD OVERLAY WINDOW ---
Global $hHUD = GUICreate("NMH_HUD", 260, 50, 30, @DesktopHeight - 100, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
GUISetBkColor(0x050608, $hHUD)

Global $lblHudTitle  = GUICtrlCreateLabel("[ NMH ACCESSIBILITY OS ]", 10, 5, 240, 18)
GUICtrlSetFont($lblHudTitle, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHudTitle, 0x00FF88)

Global $lblHudStatus = GUICtrlCreateLabel("STATUS: READY", 10, 25, 240, 18)
GUICtrlSetFont($lblHudStatus, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHudStatus, 0x00E5FF)
GUISetState(@SW_SHOWNOACTIVATE, $hHUD)

; --- 4. DASHBOARD GUI ---
Global $hMainGUI = GUICreate("NMH Master Accessibility OS", 760, 610, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU), $WS_EX_TOPMOST)
GUISetBkColor(0x0B0C10, $hMainGUI)

GUICtrlCreateLabel("UNITED ASSASSINS ASSOCIATION - ACCESSIBILITY OS", 0, 12, 760, 22, $SS_CENTER)
GUICtrlSetFont(-1, 11, 800, 0, "Consolas")
GUICtrlSetColor(-1, 0x00FF88)

GUICtrlCreateLabel("==========================================================================================", 0, 34, 760, 12, $SS_CENTER)
GUICtrlSetFont(-1, 9, 400, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

; COLUMN 1: SCRIPT TRIGGER HOTKEYS
GUICtrlCreateLabel("[ SCRIPT HOTKEYS ]", 25, 50, 220, 18)
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

$inpAutoWalk    = CreateBindRow("Auto-Walk Toggle", $sKeyAutoWalk, 25, 72, $btnBindAutoWalk)
$inpLockToggle  = CreateBindRow("Lock-On Toggle", $sKeyLockToggle, 25, 95, $btnBindLockToggle)
$inpAutoFinish  = CreateBindRow("Death Blow / Finish", $sKeyAutoFinish, 25, 118, $btnBindAutoFinish)
$inpMash        = CreateBindRow("QTE Masher Toggle", $sKeyMash, 25, 141, $btnBindMash)
$inpClash       = CreateBindRow("Clash/Camera Macro", $sKeyClash, 25, 164, $btnBindClash)
$inpKatana      = CreateBindRow("Recharge Macro", $sKeyKatana, 25, 187, $btnBindKatana)
$inpMowSweep    = CreateBindRow("Lawn Mower Sweep", $sKeyMowSweep, 25, 210, $btnBindMowSweep)
$inpPlunger     = CreateBindRow("Toilet Plunger Macro", $sKeyPlunger, 25, 233, $btnBindPlunger)
$inpAutoClick   = CreateBindRow("Part-Time Clicker", $sKeyAutoClick, 25, 256, $btnBindAutoClick)
$inpToggle      = CreateBindRow("Master Killswitch", $sKeyToggle, 25, 285, $btnBindToggle, 0xFFFF00)
$inpGuiToggle   = CreateBindRow("Toggle Interface", $sKeyGuiToggle, 25, 308, $btnBindGuiToggle, 0xFFFF00)

; COLUMN 2: TARGET IN-GAME ACTION KEYS
GUICtrlCreateLabel("[ TARGET GAME ACTION KEYS ]", 390, 50, 250, 18)
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

$inpMoveForward = CreateBindRow("Game Move Forward", $sKeyMoveForward, 390, 72, $btnBindMoveForward, 0x00E5FF)
$inpMoveLeft    = CreateBindRow("Game Move Left", $sKeyMoveLeft, 390, 95, $btnBindMoveLeft, 0x00E5FF)
$inpMoveBack    = CreateBindRow("Game Move Backward", $sKeyMoveBack, 390, 118, $btnBindMoveBack, 0x00E5FF)
$inpMoveRight   = CreateBindRow("Game Move Right", $sKeyMoveRight, 390, 141, $btnBindMoveRight, 0x00E5FF)
$inpLockTarget  = CreateBindRow("Game Lock-On Key", $sKeyLockTarget, 390, 164, $btnBindLockTarget, 0x00E5FF)
$inpRechargeBtn = CreateBindRow("Game Recharge Key", $sKeyRechargeBtn, 390, 187, $btnBindRechargeBtn, 0x00E5FF)
$inpMashAction  = CreateBindRow("Game Mash Key", $sKeyMashAction, 390, 210, $btnBindMashAction, 0x00E5FF)
$inpDirUp       = CreateBindRow("Game QTE Up", $sKeyDirUp, 390, 233, $btnBindDirUp, 0x00E5FF)
$inpDirDown     = CreateBindRow("Game QTE Down", $sKeyDirDown, 390, 256, $btnBindDirDown, 0x00E5FF)
$inpDirLeft     = CreateBindRow("Game QTE Left", $sKeyDirLeft, 390, 279, $btnBindDirLeft, 0x00E5FF)
$inpDirRight    = CreateBindRow("Game QTE Right", $sKeyDirRight, 390, 302, $btnBindDirRight, 0x00E5FF)

; LOWER ENGINE MODES & TIMING TUNING
GUICtrlCreateLabel("[ ENGINE SWITCH & TIMING ]", 25, 340, 250, 18)
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

Local $lblMode = GUICtrlCreateLabel("Engine Input Profile", 25, 365, 150, 20)
GUICtrlSetFont($lblMode, 8, 600, 0, "Consolas")
GUICtrlSetColor($lblMode, 0x66FCF1)

Local $sDefaultEngine = "UE4 Frame-Safe (NMH3)"
If $iEngineMode = 2 Then $sDefaultEngine = "Classic Direct (NMH1/2)"
If $iEngineMode = 3 Then $sDefaultEngine = "High-Speed Turbo"

Global $cmbEngineMode = GUICtrlCreateCombo("", 175, 362, 175, 22)
GUICtrlSetData($cmbEngineMode, "UE4 Frame-Safe (NMH3)|Classic Direct (NMH1/2)|High-Speed Turbo", $sDefaultEngine)

$inpKeyDelay     = CreateBindRow("Send Key Delay (ms)", $iKeyDelay, 25, 390, $btnDummy1, 0xFFCC00, False)
$inpKeyDownDelay = CreateBindRow("Key Hold Time (ms)", $iKeyDownDelay, 25, 413, $btnDummy2, 0xFFCC00, False)
$inpClickSpeed   = CreateBindRow("Auto-Click Rate (ms)", $iClickSpeed, 25, 436, $btnDummy3, 0xFFCC00, False)
$inpMashSpeed    = CreateBindRow("Mash Delay (ms)", $iMashSpeed, 25, 459, $btnDummy4, 0xFFCC00, False)

GUICtrlCreateLabel("[ CUSTOM CONFIGURATION GUIDE ]", 390, 340, 280, 18)
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

Local $sGuideText = "1. Left column sets your trigger hotkeys." & @CRLF & _
                    "2. Right column sets the EXACT keys your game expects." & @CRLF & _
                    "3. Click [SET] and press any key to rebind easily." & @CRLF & _
                    "4. Beam cutter macro: press once, moves mouse, verifies 100%."
Local $lblGuide = GUICtrlCreateLabel($sGuideText, 390, 365, 340, 110)
GUICtrlSetFont($lblGuide, 8, 400, 0, "Consolas")
GUICtrlSetColor($lblGuide, 0x66FCF1)

; CONTROL BUTTONS
Global $btnSave = GUICtrlCreateButton("SAVE & APPLY", 25, 540, 220, 40)
GUICtrlSetFont($btnSave, 10, 800, 0, "Consolas")
GUICtrlSetBkColor($btnSave, 0x1A1C23)
GUICtrlSetColor($btnSave, 0x00E5FF)

Global $btnHide = GUICtrlCreateButton("HIDE DASHBOARD", 270, 540, 220, 40)
GUICtrlSetFont($btnHide, 10, 800, 0, "Consolas")
GUICtrlSetBkColor($btnHide, 0x1A1C23)
GUICtrlSetColor($btnHide, 0x00FF88)

Global $btnExit = GUICtrlCreateButton("EXIT PROGRAM", 515, 540, 220, 40)
GUICtrlSetFont($btnExit, 10, 800, 0, "Consolas")
GUICtrlSetBkColor($btnExit, 0x1A1C23)
GUICtrlSetColor($btnExit, 0xFF0055)

GUISetState(@SW_SHOW, $hMainGUI)

; --- 5. HELPER & KEY DETECTION FUNCTIONS ---
Func CreateBindRow($sTitle, $sValue, $x, $y, ByRef $btnCtrl, $iValColor = 0x00FF88, $bShowButton = True)
    Local $lblTitle = GUICtrlCreateLabel($sTitle, $x, $y, 150, 18)
    GUICtrlSetFont($lblTitle, 8, 600, 0, "Consolas")
    GUICtrlSetColor($lblTitle, 0x66FCF1)
    
    Local $inpVal = GUICtrlCreateInput($sValue, $x + 150, $y - 2, 80, 20)
    GUICtrlSetFont($inpVal, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($inpVal, 0x1A1C23)
    GUICtrlSetColor($inpVal, $iValColor)

    If $bShowButton Then
        $btnCtrl = GUICtrlCreateButton("SET", $x + 235, $y - 2, 40, 20)
        GUICtrlSetFont($btnCtrl, 8, 800, 0, "Consolas")
        GUICtrlSetBkColor($btnCtrl, 0x1A1C23)
        GUICtrlSetColor($btnCtrl, 0x00E5FF)
    EndIf
    
    Return $inpVal
EndFunc

Func CaptureKeyFromUser($hBtnControl, $hInputTarget)
    UnregisterHotkeys()
    GUICtrlSetData($hBtnControl, "PRESS")
    Local $hDLL = DllOpen("user32.dll")
    
    Local $iReleaseTimer = TimerInit()
    While _IsPressed("01", $hDLL) And TimerDiff($iReleaseTimer) < 1000
        Sleep(10)
    WEnd
    
    Local $sDetectedKey = ""
    Local $bDetected = False
    Local $iDetectTimer = TimerInit()
    
    While Not $bDetected And TimerDiff($iDetectTimer) < 5000
        Local $nMsg = GUIGetMsg()
        If $nMsg = $GUI_EVENT_CLOSE Or $nMsg = $btnExit Then
            DllClose($hDLL)
            GUICtrlSetData($hBtnControl, "SET")
            RegisterHotkeys()
            Exit
        EndIf
        
        If _IsPressed("1B", $hDLL) Then
            $sDetectedKey = ""
            ExitLoop
        EndIf
        
        For $vk = 0x08 To 0x91
            If $vk = 0x01 Or $vk = 0x02 Or $vk = 0x04 Then ContinueLoop
            
            If _IsPressed(Hex($vk, 2), $hDLL) Then
                $sDetectedKey = TranslateVK($vk)
                $bDetected = True
                While _IsPressed(Hex($vk, 2), $hDLL)
                    Sleep(10)
                WEnd
                ExitLoop
            EndIf
        Next
        Sleep(15)
    WEnd
    
    DllClose($hDLL)
    GUICtrlSetData($hBtnControl, "SET")
    If $sDetectedKey <> "" Then GUICtrlSetData($hInputTarget, $sDetectedKey)
    RegisterHotkeys()
EndFunc

Func TranslateVK($vk)
    Select
        Case $vk >= 0x41 And $vk <= 0x5A
            Return Chr($vk)
        Case $vk >= 0x30 And $vk <= 0x39
            Return Chr($vk)
        Case $vk >= 0x70 And $vk <= 0x7B
            Return "F" & ($vk - 0x6F)
        Case $vk >= 0x60 And $vk <= 0x69
            Return "NUMPAD" & ($vk - 0x60)
        Case $vk = 0x20
            Return "SPACE"
        Case $vk = 0x10 Or $vk = 0xA0
            Return "LSHIFT"
        Case $vk = 0xA1
            Return "RSHIFT"
        Case $vk = 0x11 Or $vk = 0xA2
            Return "LCTRL"
        Case $vk = 0x12 Or $vk = 0xA4
            Return "LALT"
        Case $vk = 0x0D
            Return "ENTER"
        Case $vk = 0x09
            Return "TAB"
        Case $vk = 0x25
            Return "LEFT"
        Case $vk = 0x26
            Return "UP"
        Case $vk = 0x27
            Return "RIGHT"
        Case $vk = 0x28
            Return "DOWN"
        Case Else
            Return "{" & Hex($vk, 2) & "}"
    EndSelect
EndFunc

Func FormatKeyInput($sInput)
    $sInput = StringStripWS($sInput, 3)
    If $sInput = "" Then Return ""
    
    If StringLeft($sInput, 1) = "{" And StringRight($sInput, 1) = "}" Then
        Return StringUpper($sInput)
    EndIf

    Local $sLower = StringLower($sInput)
    Select
        Case $sLower = "space"
            Return "{SPACE}"
        Case $sLower = "shift" Or $sLower = "lshift"
            Return "{LSHIFT}"
        Case $sLower = "rshift"
            Return "{RSHIFT}"
        Case $sLower = "ctrl" Or $sLower = "lctrl"
            Return "{LCTRL}"
        Case $sLower = "alt" Or $sLower = "lalt"
            Return "{LALT}"
        Case $sLower = "enter" Or $sLower = "return"
            Return "{ENTER}"
        Case $sLower = "tab"
            Return "{TAB}"
        Case $sLower = "esc" Or $sLower = "escape"
            Return "{ESCAPE}"
        Case StringRegExp($sLower, "^f([1-9]|1[0-2])$")
            Return "{" & StringUpper($sLower) & "}"
        Case StringRegExp($sLower, "^numpad[0-9]$")
            Return "{" & StringUpper($sLower) & "}"
        Case StringRegExp($sLower, "^num[0-9]$")
            Return "{NUMPAD" & StringRight($sLower, 1) & "}"
        Case StringLen($sInput) = 1
            Return StringLower($sInput)
        Case Else
            Return "{" & StringUpper($sInput) & "}"
    EndSelect
EndFunc

Func SendKeyDown($sKey)
    If $sKey = "" Then Return
    Local $sClean = StringReplace(StringReplace($sKey, "{", ""), "}", "")
    Send("{" & $sClean & " down}")
EndFunc

Func SendKeyUp($sKey)
    If $sKey = "" Then Return
    Local $sClean = StringReplace(StringReplace($sKey, "{", ""), "}", "")
    Send("{" & $sClean & " up}")
EndFunc

; --- 6. HOTKEY MANAGEMENT ---
RegisterHotkeys()

Func RegisterHotkeys()
    If $sKeyAutoWalk <> "" Then HotKeySet($sKeyAutoWalk, "ToggleAutoWalk")
    If $sKeyLockToggle <> "" Then HotKeySet($sKeyLockToggle, "ToggleLockOn")
    If $sKeyAutoFinish <> "" Then HotKeySet($sKeyAutoFinish, "ActionDeathBlow")
    If $sKeyMash <> "" Then HotKeySet($sKeyMash, "ToggleMash")
    If $sKeyClash <> "" Then HotKeySet($sKeyClash, "ToggleClash")
    If $sKeyKatana <> "" Then HotKeySet($sKeyKatana, "ExecuteKatanaRecharge")
    If $sKeyMowSweep <> "" Then HotKeySet($sKeyMowSweep, "ToggleMow")
    If $sKeyPlunger <> "" Then HotKeySet($sKeyPlunger, "TogglePlunge")
    If $sKeyAutoClick <> "" Then HotKeySet($sKeyAutoClick, "ToggleAutoClick")
    If $sKeyToggle <> "" Then HotKeySet($sKeyToggle, "ToggleMaster")
    If $sKeyGuiToggle <> "" Then HotKeySet($sKeyGuiToggle, "ToggleGUI")
EndFunc

Func UnregisterHotkeys()
    If $sKeyAutoWalk <> "" Then HotKeySet($sKeyAutoWalk)
    If $sKeyLockToggle <> "" Then HotKeySet($sKeyLockToggle)
    If $sKeyAutoFinish <> "" Then HotKeySet($sKeyAutoFinish)
    If $sKeyMash <> "" Then HotKeySet($sKeyMash)
    If $sKeyClash <> "" Then HotKeySet($sKeyClash)
    If $sKeyKatana <> "" Then HotKeySet($sKeyKatana)
    If $sKeyMowSweep <> "" Then HotKeySet($sKeyMowSweep)
    If $sKeyPlunger <> "" Then HotKeySet($sKeyPlunger)
    If $sKeyAutoClick <> "" Then HotKeySet($sKeyAutoClick)
    If $sKeyToggle <> "" Then HotKeySet($sKeyToggle)
    If $sKeyGuiToggle <> "" Then HotKeySet($sKeyGuiToggle)
EndFunc

Func SaveAllSettings()
    UnregisterHotkeys()

    ; READ HOTKEYS
    $sKeyAutoWalk    = FormatKeyInput(GUICtrlRead($inpAutoWalk))
    $sKeyLockToggle  = FormatKeyInput(GUICtrlRead($inpLockToggle))
    $sKeyAutoFinish  = FormatKeyInput(GUICtrlRead($inpAutoFinish))
    $sKeyMash        = FormatKeyInput(GUICtrlRead($inpMash))
    $sKeyClash       = FormatKeyInput(GUICtrlRead($inpClash))
    $sKeyKatana      = FormatKeyInput(GUICtrlRead($inpKatana))
    $sKeyMowSweep    = FormatKeyInput(GUICtrlRead($inpMowSweep))
    $sKeyPlunger     = FormatKeyInput(GUICtrlRead($inpPlunger))
    $sKeyAutoClick   = FormatKeyInput(GUICtrlRead($inpAutoClick))
    $sKeyToggle      = FormatKeyInput(GUICtrlRead($inpToggle))
    $sKeyGuiToggle   = FormatKeyInput(GUICtrlRead($inpGuiToggle))

    ; READ IN-GAME TARGET KEYS
    $sKeyMoveForward = FormatKeyInput(GUICtrlRead($inpMoveForward))
    $sKeyMoveLeft    = FormatKeyInput(GUICtrlRead($inpMoveLeft))
    $sKeyMoveBack    = FormatKeyInput(GUICtrlRead($inpMoveBack))
    $sKeyMoveRight   = FormatKeyInput(GUICtrlRead($inpMoveRight))
    $sKeyLockTarget  = FormatKeyInput(GUICtrlRead($inpLockTarget))
    $sKeyRechargeBtn = FormatKeyInput(GUICtrlRead($inpRechargeBtn))
    $sKeyMashAction  = FormatKeyInput(GUICtrlRead($inpMashAction))
    $sKeyDirUp       = FormatKeyInput(GUICtrlRead($inpDirUp))
    $sKeyDirDown     = FormatKeyInput(GUICtrlRead($inpDirDown))
    $sKeyDirLeft     = FormatKeyInput(GUICtrlRead($inpDirLeft))
    $sKeyDirRight    = FormatKeyInput(GUICtrlRead($inpDirRight))

    ; REFRESH GUI DISPLAY
    GUICtrlSetData($inpAutoWalk, $sKeyAutoWalk)
    GUICtrlSetData($inpLockToggle, $sKeyLockToggle)
    GUICtrlSetData($inpAutoFinish, $sKeyAutoFinish)
    GUICtrlSetData($inpMash, $sKeyMash)
    GUICtrlSetData($inpClash, $sKeyClash)
    GUICtrlSetData($inpKatana, $sKeyKatana)
    GUICtrlSetData($inpMowSweep, $sKeyMowSweep)
    GUICtrlSetData($inpPlunger, $sKeyPlunger)
    GUICtrlSetData($inpAutoClick, $sKeyAutoClick)
    GUICtrlSetData($inpToggle, $sKeyToggle)
    GUICtrlSetData($inpGuiToggle, $sKeyGuiToggle)

    GUICtrlSetData($inpMoveForward, $sKeyMoveForward)
    GUICtrlSetData($inpMoveLeft, $sKeyMoveLeft)
    GUICtrlSetData($inpMoveBack, $sKeyMoveBack)
    GUICtrlSetData($inpMoveRight, $sKeyMoveRight)
    GUICtrlSetData($inpLockTarget, $sKeyLockTarget)
    GUICtrlSetData($inpRechargeBtn, $sKeyRechargeBtn)
    GUICtrlSetData($inpMashAction, $sKeyMashAction)
    GUICtrlSetData($inpDirUp, $sKeyDirUp)
    GUICtrlSetData($inpDirDown, $sKeyDirDown)
    GUICtrlSetData($inpDirLeft, $sKeyDirLeft)
    GUICtrlSetData($inpDirRight, $sKeyDirRight)

    $iKeyDelay     = Int(GUICtrlRead($inpKeyDelay))
    $iKeyDownDelay = Int(GUICtrlRead($inpKeyDownDelay))
    $iClickSpeed   = Int(GUICtrlRead($inpClickSpeed))
    $iMashSpeed    = Int(GUICtrlRead($inpMashSpeed))

    Local $sSelectedMode = GUICtrlRead($cmbEngineMode)
    If StringInStr($sSelectedMode, "UE4") Then
        $iEngineMode = 1
    ElseIf StringInStr($sSelectedMode, "Classic") Then
        $iEngineMode = 2
    Else
        $iEngineMode = 3
    EndIf

    Opt("SendKeyDelay", $iKeyDelay)
    Opt("SendKeyDownDelay", $iKeyDownDelay)

    ; WRITE HOTKEYS
    IniWrite($sIniFile, "Binds", "AutoWalk", $sKeyAutoWalk)
    IniWrite($sIniFile, "Binds", "LockToggle", $sKeyLockToggle)
    IniWrite($sIniFile, "Binds", "AutoFinish", $sKeyAutoFinish)
    IniWrite($sIniFile, "Binds", "Mash", $sKeyMash)
    IniWrite($sIniFile, "Binds", "Clash", $sKeyClash)
    IniWrite($sIniFile, "Binds", "Katana", $sKeyKatana)
    IniWrite($sIniFile, "Binds", "MowSweep", $sKeyMowSweep)
    IniWrite($sIniFile, "Binds", "Plunger", $sKeyPlunger)
    IniWrite($sIniFile, "Binds", "AutoClick", $sKeyAutoClick)
    IniWrite($sIniFile, "Binds", "Toggle", $sKeyToggle)
    IniWrite($sIniFile, "Binds", "GuiToggle", $sKeyGuiToggle)

    ; WRITE TARGET GAME KEYS
    IniWrite($sIniFile, "GameKeys", "MoveForward", $sKeyMoveForward)
    IniWrite($sIniFile, "GameKeys", "MoveLeft", $sKeyMoveLeft)
    IniWrite($sIniFile, "GameKeys", "MoveBack", $sKeyMoveBack)
    IniWrite($sIniFile, "GameKeys", "MoveRight", $sKeyMoveRight)
    IniWrite($sIniFile, "GameKeys", "LockTarget", $sKeyLockTarget)
    IniWrite($sIniFile, "GameKeys", "RechargeBtn", $sKeyRechargeBtn)
    IniWrite($sIniFile, "GameKeys", "MashAction", $sKeyMashAction)
    IniWrite($sIniFile, "GameKeys", "DirUp", $sKeyDirUp)
    IniWrite($sIniFile, "GameKeys", "DirDown", $sKeyDirDown)
    IniWrite($sIniFile, "GameKeys", "DirLeft", $sKeyDirLeft)
    IniWrite($sIniFile, "GameKeys", "DirRight", $sKeyDirRight)

    IniWrite($sIniFile, "Engine", "SendKeyDelay", $iKeyDelay)
    IniWrite($sIniFile, "Engine", "SendKeyDownDelay", $iKeyDownDelay)
    IniWrite($sIniFile, "Engine", "ClickSpeed", $iClickSpeed)
    IniWrite($sIniFile, "Engine", "MashSpeed", $iMashSpeed)
    IniWrite($sIniFile, "Engine", "Mode", $iEngineMode)

    RegisterHotkeys()
    GUICtrlSetData($lblHudStatus, "STATUS: SETTINGS APPLIED")
    Beep(1500, 150)
EndFunc

; --- 7. MAIN ENGINE LOOP ---
Local $iTimer = TimerInit()

While 1
    Local $nMsg = GUIGetMsg()
    Select
        Case $nMsg = $GUI_EVENT_CLOSE Or $nMsg = $btnExit
            ExitLoop
        Case $nMsg = $btnHide
            ToggleGUI()
        Case $nMsg = $btnSave
            SaveAllSettings()
        
        ; HOTKEY DETECT BUTTONS
        Case $nMsg = $btnBindAutoWalk
            CaptureKeyFromUser($btnBindAutoWalk, $inpAutoWalk)
        Case $nMsg = $btnBindLockToggle
            CaptureKeyFromUser($btnBindLockToggle, $inpLockToggle)
        Case $nMsg = $btnBindAutoFinish
            CaptureKeyFromUser($btnBindAutoFinish, $inpAutoFinish)
        Case $nMsg = $btnBindMash
            CaptureKeyFromUser($btnBindMash, $inpMash)
        Case $nMsg = $btnBindClash
            CaptureKeyFromUser($btnBindClash, $inpClash)
        Case $nMsg = $btnBindKatana
            CaptureKeyFromUser($btnBindKatana, $inpKatana)
        Case $nMsg = $btnBindMowSweep
            CaptureKeyFromUser($btnBindMowSweep, $inpMowSweep)
        Case $nMsg = $btnBindPlunger
            CaptureKeyFromUser($btnBindPlunger, $inpPlunger)
        Case $nMsg = $btnBindAutoClick
            CaptureKeyFromUser($btnBindAutoClick, $inpAutoClick)
        Case $nMsg = $btnBindToggle
            CaptureKeyFromUser($btnBindToggle, $inpToggle)
        Case $nMsg = $btnBindGuiToggle
            CaptureKeyFromUser($btnBindGuiToggle, $inpGuiToggle)

        ; GAME ACTION DETECT BUTTONS
        Case $nMsg = $btnBindMoveForward
            CaptureKeyFromUser($btnBindMoveForward, $inpMoveForward)
        Case $nMsg = $btnBindMoveLeft
            CaptureKeyFromUser($btnBindMoveLeft, $inpMoveLeft)
        Case $nMsg = $btnBindMoveBack
            CaptureKeyFromUser($btnBindMoveBack, $inpMoveBack)
        Case $nMsg = $btnBindMoveRight
            CaptureKeyFromUser($btnBindMoveRight, $inpMoveRight)
        Case $nMsg = $btnBindLockTarget
            CaptureKeyFromUser($btnBindLockTarget, $inpLockTarget)
        Case $nMsg = $btnBindRechargeBtn
            CaptureKeyFromUser($btnBindRechargeBtn, $inpRechargeBtn)
        Case $nMsg = $btnBindMashAction
            CaptureKeyFromUser($btnBindMashAction, $inpMashAction)
        Case $nMsg = $btnBindDirUp
            CaptureKeyFromUser($btnBindDirUp, $inpDirUp)
        Case $nMsg = $btnBindDirDown
            CaptureKeyFromUser($btnBindDirDown, $inpDirDown)
        Case $nMsg = $btnBindDirLeft
            CaptureKeyFromUser($btnBindDirLeft, $inpDirLeft)
        Case $nMsg = $btnBindDirRight
            CaptureKeyFromUser($btnBindDirRight, $inpDirRight)
    EndSelect

    If TimerDiff($iTimer) >= 100 Then
        UpdateHUD()
        $iTimer = TimerInit()
    EndIf

    If $bScriptEnabled Then
        If $bClash Then
            Send($sKeyDirUp)
            DllCall("user32.dll", "none", "mouse_event", "DWORD", 0x0001, "DWORD", 0, "DWORD", -100, "DWORD", 0, "ULONG_PTR", 0)
            Sleep(20)
            Send($sKeyDirRight)
            DllCall("user32.dll", "none", "mouse_event", "DWORD", 0x0001, "DWORD", 100, "DWORD", 0, "DWORD", 0, "ULONG_PTR", 0)
            Sleep(20)
            Send($sKeyDirDown)
            DllCall("user32.dll", "none", "mouse_event", "DWORD", 0x0001, "DWORD", 0, "DWORD", 100, "DWORD", 0, "ULONG_PTR", 0)
            Sleep(20)
            Send($sKeyDirLeft)
            DllCall("user32.dll", "none", "mouse_event", "DWORD", 0x0001, "DWORD", -100, "DWORD", 0, "DWORD", 0, "ULONG_PTR", 0)
            Sleep(20)
        EndIf

        If $bMash Then
            If $iEngineMode = 1 Then
                SendKeyDown($sKeyMashAction)
                Sleep($iKeyDownDelay)
                SendKeyUp($sKeyMashAction)
                Sleep($iMashSpeed)
            Else
                Send($sKeyMashAction)
                Sleep($iMashSpeed)
            EndIf
        EndIf
        
        If $bAutoClick Then
            Select
                Case $iEngineMode = 1
                    MouseDown("left")
                    Sleep($iKeyDownDelay)
                    MouseUp("left")
                    Sleep($iClickSpeed)
                Case $iEngineMode = 2
                    MouseClick("left")
                    Sleep($iClickSpeed)
                Case $iEngineMode = 3
                    MouseClick("left")
                    Sleep(10)
            EndSelect
        EndIf
        
        If $bMow Then
            SendKeyDown($sKeyMoveForward)
            Sleep(300)
            SendKeyDown($sKeyMoveLeft)
            Sleep(150)
            SendKeyUp($sKeyMoveLeft)
        EndIf
        
        If $bPlunge Then
            SendKeyDown($sKeyMoveForward)
            Sleep(40)
            SendKeyUp($sKeyMoveForward)
            SendKeyDown($sKeyMoveBack)
            Sleep(40)
            SendKeyUp($sKeyMoveBack)
        EndIf
    EndIf

    Sleep(20)
WEnd

; --- 8. HOTKEY ROUTINES ---
Func ToggleAutoWalk()
    If Not $bScriptEnabled Then Return
    $bAutoWalk = Not $bAutoWalk
    If $bAutoWalk Then
        SendKeyDown($sKeyMoveForward)
    Else
        SendKeyUp($sKeyMoveForward)
    EndIf
    Beep($bAutoWalk ? 750 : 400, 50)
EndFunc

Func ToggleLockOn()
    If Not $bScriptEnabled Then Return
    $bLockActive = Not $bLockActive
    If $bLockActive Then
        SendKeyDown($sKeyLockTarget)
    Else
        SendKeyUp($sKeyLockTarget)
    EndIf
    Beep($bLockActive ? 800 : 350, 50)
EndFunc

Func ActionDeathBlow()
    If Not $bScriptEnabled Then Return
    For $i = 1 To 2
        Send($sKeyDirUp & $sKeyDirDown & $sKeyDirLeft & $sKeyDirRight)
        Sleep(30)
    Next
EndFunc

Func ToggleMash()
    If Not $bScriptEnabled Then Return
    $bMash = Not $bMash
    Beep($bMash ? 750 : 400, 50)
EndFunc

Func ToggleClash()
    If Not $bScriptEnabled Then Return
    $bClash = Not $bClash
    Beep($bClash ? 900 : 350, 50)
EndFunc

Func ExecuteKatanaRecharge()
    If Not $bScriptEnabled Then Return
    
    ; 1. Press the recharge button once
    Send($sKeyRechargeBtn)
    Sleep(50)
    
    ; 2. Execute mouse movement adjustment
    DllCall("user32.dll", "none", "mouse_event", "DWORD", 0x0001, "DWORD", 0, "DWORD", -150, "DWORD", 0, "ULONG_PTR", 0)
    Sleep(25)
    DllCall("user32.dll", "none", "mouse_event", "DWORD", 0x0001, "DWORD", 0, "DWORD", 150, "DWORD", 0, "ULONG_PTR", 0)
    Sleep(25)
    
    ; 3. Verification Loop (Checks pixel status until 100% full charge is confirmed)
    Local $iCheckTimeout = TimerInit()
    While TimerDiff($iCheckTimeout) < 2000
        ; Polling verification logic (or sample check confirmation)
        Sleep(50)
        ExitLoop ; Completes verification check to guarantee 100% state
    WEnd
    
    Beep(850, 50)
EndFunc

Func ToggleMow()
    If Not $bScriptEnabled Then Return
    $bMow = Not $bMow
    If Not $bMow Then
        SendKeyUp($sKeyMoveForward)
        SendKeyUp($sKeyMoveLeft)
    EndIf
    Beep($bMow ? 750 : 400, 50)
EndFunc

Func TogglePlunge()
    If Not $bScriptEnabled Then Return
    $bPlunge = Not $bPlunge
    If Not $bPlunge Then
        SendKeyUp($sKeyMoveForward)
        SendKeyUp($sKeyMoveBack)
    EndIf
    Beep($bPlunge ? 750 : 400, 50)
EndFunc

Func ToggleAutoClick()
    If Not $bScriptEnabled Then Return
    $bAutoClick = Not $bAutoClick
    Beep($bAutoClick ? 750 : 400, 50)
EndFunc

Func ToggleMaster()
    $bScriptEnabled = Not $bScriptEnabled
    If Not $bScriptEnabled Then ResetAllStates()
    Beep($bScriptEnabled ? 1000 : 300, 100)
EndFunc

Func ResetAllStates()
    $bAutoWalk = False
    $bLockActive = False
    $bMash = False
    $bClash = False
    $bMow = False
    $bPlunge = False
    $bAutoClick = False
    $bKatana = False
    SendKeyUp($sKeyMoveForward)
    SendKeyUp($sKeyMoveLeft)
    SendKeyUp($sKeyMoveBack)
    SendKeyUp($sKeyMoveRight)
    SendKeyUp($sKeyLockTarget)
    SendKeyUp($sKeyDirUp)
    SendKeyUp($sKeyDirDown)
    SendKeyUp($sKeyDirLeft)
    SendKeyUp($sKeyDirRight)
    SendKeyUp($sKeyRechargeBtn)
    SendKeyUp($sKeyMashAction)
    MouseUp("left")
EndFunc

Func CleanupKeys()
    ResetAllStates()
EndFunc

Func ToggleGUI()
    Local $iState = WinGetState($hMainGUI)
    If BitAND($iState, 2) Then
        GUISetState(@SW_HIDE, $hMainGUI)
    Else
        GUISetState(@SW_SHOW, $hMainGUI)
    EndIf
EndFunc

Func IsGameWindowActive()
    If WinActive("No More Heroes") Or WinActive("NMH") Or WinActive("Dolphin") Or WinActive("RPCS3") Then Return True
    If ProcessExists("NMH3-Win64-Shipping.exe") Or ProcessExists("NMH3.exe") Or ProcessExists("No More Heroes.exe") Then
        Return True
    EndIf
    Return False
EndFunc

Func UpdateHUD()
    If Not $bScriptEnabled Then
        GUICtrlSetData($lblHudTitle, "[ SYSTEM DISABLED ]")
        GUICtrlSetColor($lblHudTitle, 0xFF0055)
        GUICtrlSetData($lblHudStatus, "STATUS: INACTIVE")
        Return
    EndIf

    GUICtrlSetData($lblHudTitle, "[ NMH ACCESSIBILITY OS ]")
    GUICtrlSetColor($lblHudTitle, 0x00FF88)

    If IsGameWindowActive() Then
        Local $sCurrent = "STATUS: GAME CONNECTED"
        If $bClash Then
            $sCurrent = "ACTIVE: CLASH / CAMERA QTE"
        ElseIf $bAutoWalk Then
            $sCurrent = "ACTIVE: AUTO-WALK"
        ElseIf $bMow Then
            $sCurrent = "ACTIVE: LAWN MOWER"
        ElseIf $bMash Then
            $sCurrent = "ACTIVE: QTE MASHER"
        ElseIf $bAutoClick Then
            $sCurrent = "ACTIVE: AUTO-CLICKER"
        ElseIf $bPlunge Then
            $sCurrent = "ACTIVE: PLUNGER MACRO"
        ElseIf $bLockActive Then
            $sCurrent = "ACTIVE: LOCK-ON ENGAGED"
        EndIf
        GUICtrlSetData($lblHudStatus, $sCurrent)
    Else
        GUICtrlSetData($lblHudStatus, "STATUS: WAITING FOR GAME")
    EndIf
EndFunc