#RequireAdmin
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <Misc.au3>
#include <File.au3>
#include <GuiEdit.au3>

; ============================================================================
;  NO MORE HEROES - ULTIMATE ACCESSIBILITY OS v7.1
;  Version-aware combat logic for NMH1, NMH2, and NMH3 on PC.
;
;  v7.1 FIXES (over the ported v7.0 AutoIt build):
;   1. IsGameActive() no longer self-matches the tool's OWN windows. The
;      main panel is literally titled "NMH Ultimate OS" and the HUD is
;      titled "NMH_HUD" - with substring window-title matching, focusing
;      either of those made the script think the GAME was focused, which
;      silently defeated the "only fire when NMH is focused" safety net.
;      Detection is now based on the foreground window's owning process.
;   2. Trigger hotkeys (e, w, a, s, d, q, j, k, l, LShift, etc. by default)
;      were captured system-wide at all times, which swallowed those keys
;      in every other application (typing, chat, browser) while the script
;      was running. Trigger hotkeys are now dynamically registered only
;      while a tracked NMH/emulator window is foreground (when "Only fire
;      macros when a NMH window is focused" is checked); the three utility
;      keys (Master Killswitch, Toggle Interface, Toggle HUD) stay global
;      on purpose so they always work as an emergency out.
;   3. Switching game version (via the dropdown or Auto-Detect) only ever
;      persisted/reloaded 9 of the ~46 per-version key bindings. Any other
;      customized binds for the version you were leaving were silently
;      discarded, and the live macros kept running on the OLD version's
;      keys until you happened to click SAVE & APPLY. Version switching is
;      now table-driven and covers every bind field on both save and load.
;   4. TranslateVK() (used by the key-capture/rebind flow) only recognized
;      a small set of virtual-key codes; anything else fell back to a
;      "{XX}" hex string that AutoIt's Send()/HotKeySet() cannot actually
;      use. Coverage has been extended to the common keys that were
;      missing (Esc, Backspace, Delete, Insert, Home/End, Page Up/Down,
;      Caps Lock, numpad operators, right-side modifiers, Windows key).
; ============================================================================

OnAutoItExitRegister("CleanupKeys")
Opt("WinTitleMatchMode", 2)
Opt("GUIOnEventMode", 0)
Opt("SendCapslockMode", 0)

Global $sIniFile = @ScriptDir & "\nmh_ultimate.ini"
Global $sProfileDir = @ScriptDir & "\nmh_profiles"
If Not FileExists($sProfileDir) Then DirCreate($sProfileDir)

; --- Version database: [Label, WindowTitle, ProcessName] ---
Global $aVersions[3][2] = [ _
    ["NMH1 (PC / Emulator)",  "No More Heroes.exe"], _
    ["NMH2 (PC / Emulator)",  "NMH2.exe"], _
    ["NMH3 (Steam / PC)",     "NMH3-Win64-Shipping.exe"] ]

; Process names IsGameActive() treats as "the game" - checked against the
; CURRENT FOREGROUND window's owning process (see IsGameActive() below),
; never against window titles, so the tool's own windows can't self-match.
Global $aGameProcs[6] = ["NMH3-Win64-Shipping.exe", "NMH3.exe", "NMH2.exe", _
    "No More Heroes.exe", "rpcs3.exe", "dolphin.exe"]

Global $iActiveVer = Int(IniRead($sIniFile, "Meta", "ActiveVersion", "2"))
If $iActiveVer < 0 Or $iActiveVer > 2 Then $iActiveVer = 2

Global $iKeyDelay     = Int(IniRead($sIniFile, "Meta", "SendKeyDelay", "25"))
Global $iKeyDownDelay = Int(IniRead($sIniFile, "Meta", "SendKeyDownDelay", "35"))
Global $iMashSpeed    = Int(IniRead($sIniFile, "Meta", "MashSpeed", "30"))
Global $iClickSpeed   = Int(IniRead($sIniFile, "Meta", "ClickSpeed", "50"))
Global $iEngineMode   = Int(IniRead($sIniFile, "Meta", "EngineMode", "1"))
Global $bRequireFocus = (IniRead($sIniFile, "Meta", "RequireFocus", "1") = "1")
Global $bAutoLoad     = (IniRead($sIniFile, "Meta", "AutoLoadProfile", "0") = "1")
Opt("SendKeyDelay", $iKeyDelay)
Opt("SendKeyDownDelay", $iKeyDownDelay)

Global $iMowHoldMs   = Int(IniRead($sIniFile, "Meta", "MowHoldMs",   "300"))
Global $iPlungeDelay = Int(IniRead($sIniFile, "Meta", "PlungeDelay", "40"))
Global $iRechargeMs  = Int(IniRead($sIniFile, "Meta", "RechargeMs",  "50"))
Global $iRchShakeMs  = Int(IniRead($sIniFile, "Meta", "RechargeShakeMs",  "900"))
Global $iRchShakeAmp = Int(IniRead($sIniFile, "Meta", "RechargeShakeAmp", "18"))
Global $iRchShakeStepMs = Int(IniRead($sIniFile, "Meta", "RechargeShakeStepMs", "16"))
Global $iJobWalkMs   = Int(IniRead($sIniFile, "Meta", "JobWalkMs",   "450"))
Global $iJobActMs    = Int(IniRead($sIniFile, "Meta", "JobActMs",    "300"))
Global $iBikeSlashMs = Int(IniRead($sIniFile, "Meta", "BikeSlashMs", "250"))

Func VSec()
    Return "V" & $iActiveVer
EndFunc
Func VRead($k, $d)
    Return IniRead($sIniFile, VSec(), $k, $d)
EndFunc
Func VWrite($k, $v)
    IniWrite($sIniFile, VSec(), $k, $v)
EndFunc

; --- Global Binds ---
Global $sKWalk    = VRead("Walk",       "{F1}")
Global $sKLock    = VRead("Lock",       "{LSHIFT}")
Global $sKFinish  = VRead("Finish",     "{F3}")
Global $sKMash    = VRead("Mash",       "e")
Global $sKClash   = VRead("Clash",      "{NUMPAD4}")
Global $sKKatana  = VRead("Katana",     "{NUMPAD3}")
Global $sKMow     = VRead("Mow",        "{NUMPAD1}")
Global $sKPlunge  = VRead("Plunge",     "{NUMPAD2}")
Global $sKClick   = VRead("Click",      "{F5}")
Global $sKToggle  = VRead("Toggle",     "{F2}")
Global $sKGuiTog  = VRead("GuiTog",     "{F4}")
Global $sKHudTog  = VRead("HudTog",     "{F8}")
Global $iHudAlpha = Int(VRead("HudAlpha", "255"))

; --- Game Action Keys ---
Global $sKFwd     = VRead("Fwd",        "w")
Global $sKBack    = VRead("Back",       "s")
Global $sKLeft    = VRead("Left",       "a")
Global $sKRight   = VRead("Right",      "d")
Global $sKLockTgt = VRead("LockTgt",    "{LSHIFT}")
Global $sKRech    = VRead("Recharge",   "q")   ; Default to Q for NMH3
Global $sKMashAct = VRead("MashAct",    "e")
Global $sKUp      = VRead("Up",         "{UP}")
Global $sKDown    = VRead("Down",       "{DOWN}")
Global $sKDirL    = VRead("DirLeft",    "{LEFT}")
Global $sKDirR    = VRead("DirRight",   "{RIGHT}")

; --- Job Binds ---
Global $sKJobAct  = VRead("JobAct",    "e")
Global $sKJobMove = VRead("JobMove",   "w")
Global $sKJobThrow= VRead("JobThrow",  "q")
Global $sKJobGar  = VRead("JobGar",    "{NUMPAD7}")
Global $sKJobCoc  = VRead("JobCoc",    "{NUMPAD8}")
Global $sKJobWin  = VRead("JobWin",    "{NUMPAD9}")
Global $sKJobMine = VRead("JobMine",   "{NUMPAD0}")
Global $sKJobChk  = VRead("JobChk",    "{NUMPADDIV}")

; --- Bike Binds ---
Global $sKBkAccel = VRead("BkAccel",   "w")
Global $sKBkBrake = VRead("BkBrake",   "s")
Global $sKBkL     = VRead("BkL",       "a")
Global $sKBkR     = VRead("BkR",       "d")
Global $sKBkAtkL  = VRead("BkAtkL",    "j")
Global $sKBkAtkR  = VRead("BkAtkR",    "k")
Global $sKBkBoost = VRead("BkBoost",   "{LSHIFT}")
Global $sKBkGuard = VRead("BkGuard",   "l")
Global $sKBkHold  = VRead("BkHold",    "{NUMPAD5}")
Global $sKBkSpam  = VRead("BkSpam",    "{NUMPAD6}")

; --- Emulator Save/Load ---
Global $sKEmuSaveTrg = VRead("EmuSaveTrg", "{F6}")
Global $sKEmuLoadTrg = VRead("EmuLoadTrg", "{F7}")
Global $sKEmuSaveKey = VRead("EmuSaveKey", "{F1}")
Global $sKEmuLoadKey = VRead("EmuLoadKey", "{F3}")

; --- Runtime State ---
Global $bScriptEnabled = True
Global $bAutoWalk = False, $bLockActive = False, $bMash = False, $bClash = False
Global $bMow = False, $bPlunge = False, $bClick = False
Global $bJobGar = False, $bJobCoc = False, $bJobWin = False, $bJobMine = False, $bJobChk = False
Global $bBikeHold = False, $bBikeSpam = False
Global $bGameConnected = False
Global $bHudVisible = True

Global $aCtrlMap[1][2], $iCtrlMapSize = 0, $iActiveTab = 0
Global $aTabButtons[4]
Global $aBindMap[1][2], $iBindCount = 0

Func RegCtrl($iTab, $ctrl)
    ReDim $aCtrlMap[$iCtrlMapSize + 1][2]
    $aCtrlMap[$iCtrlMapSize][0] = $iTab
    $aCtrlMap[$iCtrlMapSize][1] = $ctrl
    $iCtrlMapSize += 1
    Return $ctrl
EndFunc

Func RegBind($btnID, $inpID)
    ReDim $aBindMap[$iBindCount + 1][2]
    $aBindMap[$iBindCount][0] = $btnID
    $aBindMap[$iBindCount][1] = $inpID
    $iBindCount += 1
EndFunc

Func ShowTab($i)
    $iActiveTab = $i
    For $r = 0 To $iCtrlMapSize - 1
        If $aCtrlMap[$r][0] = $i Then
            GUICtrlSetState($aCtrlMap[$r][1], $GUI_SHOW)
        Else
            GUICtrlSetState($aCtrlMap[$r][1], $GUI_HIDE)
        EndIf
    Next
    For $t = 0 To 3
        If $t = $i Then
            GUICtrlSetBkColor($aTabButtons[$t], 0x1F2330)
            GUICtrlSetColor($aTabButtons[$t], 0x00FF88)
        Else
            GUICtrlSetBkColor($aTabButtons[$t], 0x14161C)
            GUICtrlSetColor($aTabButtons[$t], 0x555555)
        EndIf
    Next
EndFunc

Func SetDark($hCtrl)
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hCtrl), "wstr", "", "wstr", "")
EndFunc

; ================= GUI =================
Global $hMainGUI = GUICreate("NMH Ultimate OS v7.1", 920, 720, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), -1)
GUISetBkColor(0x0B0C10, $hMainGUI)

GUICtrlCreateLabel("NO MORE HEROES  -  ULTIMATE ACCESSIBILITY OS", 0, 10, 920, 22, $SS_CENTER)
GUICtrlSetFont(-1, 12, 800, 0, "Consolas")
GUICtrlSetColor(-1, 0x00FF88)
GUICtrlCreateLabel("=========================================================================================================", 0, 32, 920, 12, $SS_CENTER)
GUICtrlSetFont(-1, 9, 400, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

GUICtrlCreateLabel("ACTIVE VERSION:", 20, 52, 120, 20)
GUICtrlSetFont(-1, 9, 800, 0, "Consolas")
GUICtrlSetColor(-1, 0x00FF88)
Global $cmbVersion = GUICtrlCreateCombo("", 140, 50, 430, 24)
GUICtrlSetData($cmbVersion, "NMH1 (PC / Emulator)|NMH2 (PC / Emulator)|NMH3 (Steam / PC)", $aVersions[$iActiveVer][0])
GUICtrlSetFont($cmbVersion, 9, 600, 0, "Consolas")
SetDark($cmbVersion)
Global $lblVer = GUICtrlCreateLabel("", 590, 52, 310, 20)
GUICtrlSetFont($lblVer, 9, 600, 0, "Consolas")
GUICtrlSetColor($lblVer, 0x00FF88)

Local $sTabs[4] = ["  Controls  ", "  Jobs & Bike  ", "  Macros  ", "  Engine & Log  "]
For $i = 0 To 3
    $aTabButtons[$i] = GUICtrlCreateButton($sTabs[$i], 15 + $i * 225, 84, 215, 32)
    GUICtrlSetFont($aTabButtons[$i], 10, 800, 0, "Consolas")
    GUICtrlSetBkColor($aTabButtons[$i], 0x14161C)
    GUICtrlSetColor($aTabButtons[$i], 0x555555)
Next
GUICtrlCreateLabel("", 15, 120, 890, 2, $SS_ETCHEDHORZ)
GUICtrlSetBkColor(-1, 0x1F2330)

; ---- TAB 0: CONTROLS ----
RegCtrl(0, GUICtrlCreateLabel("[ HOTKEYS ]", 30, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Local $yL = 160
Global $iWalk = MkBind(0, "Auto-Walk",         $sKWalk,   30, $yL)
Global $iLock = MkBind(0, "Lock-On",           $sKLock,   30, $yL + 22)
Global $iFin  = MkBind(0, "Death Blow",        $sKFinish, 30, $yL + 44)
Global $iMash = MkBind(0, "QTE Masher",        $sKMash,   30, $yL + 66)
Global $iClsh = MkBind(0, "Clash/Camera",      $sKClash,  30, $yL + 88)
Global $iKat  = MkBind(0, "Recharge",          $sKKatana, 30, $yL + 110)
Global $iMow  = MkBind(0, "Lawn Mower",        $sKMow,    30, $yL + 132)
Global $iPlg  = MkBind(0, "Toilet Plunger",    $sKPlunge, 30, $yL + 154)
Global $iClk  = MkBind(0, "Part-Time Clicker", $sKClick,  30, $yL + 176)
Global $iTog  = MkBind(0, "Master Killswitch", $sKToggle, 30, $yL + 198, 0xFFFF00)
Global $iGui  = MkBind(0, "Toggle Interface",  $sKGuiTog, 30, $yL + 220, 0xFFFF00)
Global $iHudT = MkBind(0, "Toggle HUD",        $sKHudTog, 30, $yL + 242, 0xFFFF00)

RegCtrl(0, GUICtrlCreateLabel("[ GAME KEYS ]", 490, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $iFwd   = MkBind(0, "Move Forward",  $sKFwd,     490, $yL,       0x00E5FF)
Global $iBck   = MkBind(0, "Move Backward", $sKBack,    490, $yL + 22,  0x00E5FF)
Global $iLft   = MkBind(0, "Move Left",     $sKLeft,    490, $yL + 44,  0x00E5FF)
Global $iRgt   = MkBind(0, "Move Right",    $sKRight,   490, $yL + 66,  0x00E5FF)
Global $iLkTgt = MkBind(0, "Lock Target",   $sKLockTgt, 490, $yL + 88,  0x00E5FF)
Global $iRchg  = MkBind(0, "Recharge Btn",  $sKRech,    490, $yL + 110, 0x00E5FF)
Global $iMshA  = MkBind(0, "Mash Action",   $sKMashAct, 490, $yL + 132, 0x00E5FF)
Global $iUp    = MkBind(0, "QTE Up",        $sKUp,      490, $yL + 154, 0x00E5FF)
Global $iDwn   = MkBind(0, "QTE Down",      $sKDown,    490, $yL + 176, 0x00E5FF)
Global $iDL    = MkBind(0, "QTE Left",      $sKDirL,    490, $yL + 198, 0x00E5FF)
Global $iDR    = MkBind(0, "QTE Right",     $sKDirR,    490, $yL + 220, 0x00E5FF)

RegCtrl(0, GUICtrlCreateLabel("HUD Transparency (30-255)", 30, $yL + 272, 200, 18))
GUICtrlSetFont(-1, 8, 600, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)
Global $iHudA = RegCtrl(0, GUICtrlCreateInput($iHudAlpha, 240, $yL + 270, 120, 20))
GUICtrlSetFont($iHudA, 8, 800, 0, "Consolas")
GUICtrlSetBkColor($iHudA, 0x1A1C23)
GUICtrlSetColor($iHudA, 0xFFCC00)

RegCtrl(0, GUICtrlCreateLabel("255 = solid, 128 = half, 30 = barely visible", 30, $yL + 294, 500, 16))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

; ---- TAB 1: JOBS & BIKE ----
RegCtrl(1, GUICtrlCreateLabel("[ JOB CENTER - SHARED KEYS ]", 30, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Local $yj = 160
Global $iJobAct  = MkBind(1, "Action (pick/confirm)", $sKJobAct,   30, $yj,      0x00E5FF)
Global $iJobMove = MkBind(1, "Move (walk fwd)",        $sKJobMove,  30, $yj + 22, 0x00E5FF)
Global $iJobThr  = MkBind(1, "Throw / Scrub",          $sKJobThrow, 30, $yj + 44, 0x00E5FF)

RegCtrl(1, GUICtrlCreateLabel("[ JOB TRIGGERS ]", 490, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $iJG = MkBind(1, "Garbage Collection", $sKJobGar,  490, $yj,       0x00FF88)
Global $iJC = MkBind(1, "Coconut Gathering",  $sKJobCoc,  490, $yj + 22,  0x00FF88)
Global $iJW = MkBind(1, "Window Washing",     $sKJobWin,  490, $yj + 44,  0x00FF88)
Global $iJM = MkBind(1, "Mine Sweeping",      $sKJobMine, 490, $yj + 66,  0x00FF88)
Global $iJK = MkBind(1, "Chicken Catching",   $sKJobChk,  490, $yj + 88,  0x00FF88)

RegCtrl(1, GUICtrlCreateLabel("[ BIKE MISSION ]", 30, 250, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Local $yb = 275
Global $iBkA = MkBind(1, "Accelerate",    $sKBkAccel, 30, $yb,       0x00E5FF)
Global $iBkB = MkBind(1, "Brake",         $sKBkBrake, 30, $yb + 22,  0x00E5FF)
Global $iBkL = MkBind(1, "Steer Left",    $sKBkL,     30, $yb + 44,  0x00E5FF)
Global $iBkR = MkBind(1, "Steer Right",   $sKBkR,     30, $yb + 66,  0x00E5FF)
Global $iBkAL= MkBind(1, "Attack Left",   $sKBkAtkL,  30, $yb + 88,  0x00E5FF)
Global $iBkAR= MkBind(1, "Attack Right",  $sKBkAtkR,  30, $yb + 110, 0x00E5FF)
Global $iBkBst=MkBind(1, "Boost",         $sKBkBoost, 30, $yb + 132, 0x00E5FF)
Global $iBkGd =MkBind(1, "Guard",         $sKBkGuard, 30, $yb + 154, 0x00E5FF)

RegCtrl(1, GUICtrlCreateLabel("[ BIKE TOGGLE TRIGGERS ]", 490, 250, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $iBkHold = MkBind(1, "Hold-Accelerate", $sKBkHold, 490, $yb,      0x00FF88)
Global $iBkSpam = MkBind(1, "Slash Spam",      $sKBkSpam, 490, $yb + 22, 0x00FF88)

; ---- TAB 2: MACROS ----
RegCtrl(2, GUICtrlCreateLabel("[ MACRO TUNING ]", 30, 135, 860, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $iMowMs  = MkNum(2, "Mow hold time (ms)",        $iMowHoldMs,   60, 175)
Global $iPlgMs  = MkNum(2, "Plunger delay (ms)",        $iPlungeDelay, 60, 203)
Global $iRchMs  = MkNum(2, "Recharge post-delay (ms)",  $iRechargeMs,  60, 231)
Global $iRchShkMs  = MkNum(2, "NMH3 shake duration (ms)",  $iRchShakeMs,      490, 175)
Global $iRchShkAmp = MkNum(2, "NMH3 shake amplitude (px)", $iRchShakeAmp,     490, 203)
Global $iRchShkStp = MkNum(2, "NMH3 shake step interval (ms)", $iRchShakeStepMs, 490, 231)
Global $iJbWkMs = MkNum(2, "Job walk hold (ms)",        $iJobWalkMs,   60, 259)
Global $iJbAcMs = MkNum(2, "Job action gap (ms)",       $iJobActMs,    60, 287)
Global $iBkSlMs = MkNum(2, "Bike slash gap (ms)",       $iBikeSlashMs, 60, 315)

Global $chkFocus = RegCtrl(2, GUICtrlCreateCheckbox("Only fire macros when a NMH window is focused", 60, 360, 600, 22))
GUICtrlSetFont($chkFocus, 9, 600, 0, "Consolas")
GUICtrlSetColor($chkFocus, 0x8AB4FF)
If $bRequireFocus Then GUICtrlSetState($chkFocus, $GUI_CHECKED)
SetDark($chkFocus)

RegCtrl(2, GUICtrlCreateLabel("[ EMULATOR SAVE / LOAD STATE ]", 30, 405, 860, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Local $ye = 430
Global $iEmuST = MkBind(2, "Save-State trigger", $sKEmuSaveTrg, 60, $ye,      0xFFFF00)
Global $iEmuLT = MkBind(2, "Load-State trigger", $sKEmuLoadTrg, 60, $ye + 22, 0xFFFF00)
Global $iEmuSK = MkBind(2, "Emulator SAVE key",  $sKEmuSaveKey, 490, $ye,      0x00E5FF)
Global $iEmuLK = MkBind(2, "Emulator LOAD key",  $sKEmuLoadKey, 490, $ye + 22, 0x00E5FF)

; ---- TAB 3: ENGINE & LOG ----
RegCtrl(3, GUICtrlCreateLabel("[ ENGINE ]", 30, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

RegCtrl(3, GUICtrlCreateLabel("Input profile:", 30, 165, 120, 20))
GUICtrlSetFont(-1, 9, 600, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)
Global $cmbEngine = RegCtrl(3, GUICtrlCreateCombo("", 160, 163, 260, 22))
GUICtrlSetData($cmbEngine, "UE4 Frame-Safe (NMH3)|Classic Direct (NMH1/2)|High-Speed Turbo", "UE4 Frame-Safe (NMH3)")
GUICtrlSetFont($cmbEngine, 9, 600, 0, "Consolas")
SetDark($cmbEngine)

Global $iKD = MkNum(3, "Send Key Delay (ms)", $iKeyDelay,     60, 200)
Global $iKDD = MkNum(3, "Key Hold Time (ms)", $iKeyDownDelay, 60, 228)
Global $iMS = MkNum(3, "Mash Delay (ms)",     $iMashSpeed,    60, 256)
Global $iCS = MkNum(3, "Click Speed (ms)",    $iClickSpeed,   60, 284)

RegCtrl(3, GUICtrlCreateLabel("[ PROFILE ]", 30, 320, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $chkAuto = RegCtrl(3, GUICtrlCreateCheckbox("Auto-load matching profile on startup", 60, 345, 600, 22))
GUICtrlSetFont($chkAuto, 9, 600, 0, "Consolas")
GUICtrlSetColor($chkAuto, 0x8AB4FF)
If $bAutoLoad Then GUICtrlSetState($chkAuto, $GUI_CHECKED)
SetDark($chkAuto)
Global $btnSaveProf = RegCtrl(3, GUICtrlCreateButton("SAVE PROFILE AS...", 60, 375, 260, 34))
GUICtrlSetFont($btnSaveProf, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($btnSaveProf, 0x1A1C23)
GUICtrlSetColor($btnSaveProf, 0x00E5FF)
Global $btnLoadProf = RegCtrl(3, GUICtrlCreateButton("LOAD PROFILE...", 330, 375, 260, 34))
GUICtrlSetFont($btnLoadProf, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($btnLoadProf, 0x1A1C23)
GUICtrlSetColor($btnLoadProf, 0x00E5FF)

RegCtrl(3, GUICtrlCreateLabel("[ LOG ]", 30, 425, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $edtLog = RegCtrl(3, GUICtrlCreateEdit("", 30, 450, 620, 135, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL)))
GUICtrlSetFont($edtLog, 9, 400, 0, "Consolas")
GUICtrlSetBkColor($edtLog, 0x101218)
GUICtrlSetColor($edtLog, 0x00FF88)
Global $btnClr = RegCtrl(3, GUICtrlCreateButton("CLEAR", 670, 450, 200, 40))
GUICtrlSetFont($btnClr, 10, 800, 0, "Consolas")
GUICtrlSetBkColor($btnClr, 0x1A1C23)
GUICtrlSetColor($btnClr, 0xFF0055)

Global $btnSave = GUICtrlCreateButton("SAVE & APPLY", 30, 645, 260, 42)
GUICtrlSetFont($btnSave, 11, 800, 0, "Consolas")
GUICtrlSetBkColor($btnSave, 0x1A1C23)
GUICtrlSetColor($btnSave, 0x00E5FF)
Global $btnHide = GUICtrlCreateButton("HIDE DASHBOARD", 330, 645, 260, 42)
GUICtrlSetFont($btnHide, 11, 800, 0, "Consolas")
GUICtrlSetBkColor($btnHide, 0x1A1C23)
GUICtrlSetColor($btnHide, 0x00FF88)
Global $btnExit = GUICtrlCreateButton("EXIT PROGRAM", 630, 645, 260, 42)
GUICtrlSetFont($btnExit, 11, 800, 0, "Consolas")
GUICtrlSetBkColor($btnExit, 0x1A1C23)
GUICtrlSetColor($btnExit, 0xFF0055)

ShowTab(0)
GUISetState(@SW_SHOW, $hMainGUI)

; ================= HUD =================
Global $hHUD = GUICreate("NMH_HUD", 400, 62, 30, @DesktopHeight - 120, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
GUISetBkColor(0x050608, $hHUD)
Global $lblHT = GUICtrlCreateLabel("[ NMH ACCESSIBILITY ]", 10, 5, 200, 16)
GUICtrlSetFont($lblHT, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHT, 0x00FF88)
Global $lblHC = GUICtrlCreateLabel("DISCONNECTED", 220, 5, 170, 16, $SS_RIGHT)
GUICtrlSetFont($lblHC, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHC, 0xFF0055)
Global $lblHS = GUICtrlCreateLabel("STATUS: READY", 10, 24, 380, 16)
GUICtrlSetFont($lblHS, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHS, 0x00E5FF)
Global $aLEDs[7]
Local $aLbl[7] = ["WALK","MASH","CLASH","MOW","PLUNGE","BIKE","JOB"]
For $i = 0 To 6
    $aLEDs[$i] = GUICtrlCreateLabel($aLbl[$i], 12 + $i * 55, 43, 50, 14, $SS_CENTER)
    GUICtrlSetFont($aLEDs[$i], 7, 800, 0, "Consolas")
    GUICtrlSetBkColor($aLEDs[$i], 0x1A1C23)
    GUICtrlSetColor($aLEDs[$i], 0x555555)
Next
GUISetState(@SW_SHOWNOACTIVATE, $hHUD)

If $iHudAlpha < 30 Then $iHudAlpha = 255
If $iHudAlpha > 255 Then $iHudAlpha = 255
WinSetTrans($hHUD, "", $iHudAlpha)

; ================= HELPERS =================
Func MkBind($iTab, $sTitle, $sValue, $x, $y, $iColor = 0x00FF88)
    Local $lbl = GUICtrlCreateLabel($sTitle, $x, $y, 200, 18)
    GUICtrlSetFont($lbl, 8, 600, 0, "Consolas")
    GUICtrlSetColor($lbl, 0x66FCF1)
    RegCtrl($iTab, $lbl)
    Local $inp = GUICtrlCreateInput($sValue, $x + 210, $y - 2, 120, 20)
    GUICtrlSetFont($inp, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($inp, 0x1A1C23)
    GUICtrlSetColor($inp, $iColor)
    RegCtrl($iTab, $inp)
    Local $btn = GUICtrlCreateButton("SET", $x + 340, $y - 2, 55, 20)
    GUICtrlSetFont($btn, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($btn, 0x1A1C23)
    GUICtrlSetColor($btn, 0x00E5FF)
    RegCtrl($iTab, $btn)
    RegBind($btn, $inp)
    Return $inp
EndFunc

Func MkNum($iTab, $sTitle, $iVal, $x, $y)
    Local $lbl = GUICtrlCreateLabel($sTitle, $x, $y, 300, 18)
    GUICtrlSetFont($lbl, 9, 600, 0, "Consolas")
    GUICtrlSetColor($lbl, 0x66FCF1)
    RegCtrl($iTab, $lbl)
    Local $inp = GUICtrlCreateInput($iVal, $x + 320, $y - 2, 80, 20)
    GUICtrlSetFont($inp, 9, 800, 0, "Consolas")
    GUICtrlSetBkColor($inp, 0x1A1C23)
    GUICtrlSetColor($inp, 0xFFCC00)
    RegCtrl($iTab, $inp)
    Return $inp
EndFunc

Func LogLine($m)
    _GUICtrlEdit_AppendText($edtLog, "[" & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $m & @CRLF)
EndFunc

Func ClampInt($s, $iMin, $iMax, $iDef)
    Local $t = StringStripWS($s, 8)
    If $t = "" Or Not StringRegExp($t, "^-?\d+$") Then Return $iDef
    Local $v = Int($t)
    If $v < $iMin Then Return $iMin
    If $v > $iMax Then Return $iMax
    Return $v
EndFunc

Func SplitKey($s)
    Local $t = StringStripWS($s, 3)
    Local $a[2]
    If StringLeft($t, 1) = "{" And StringRight($t, 1) = "}" Then
        Local $inner = StringMid($t, 2, StringLen($t) - 2)
        If StringInStr($inner, "{") Or StringInStr($inner, "^") Or StringInStr($inner, "!") Or StringInStr($inner, "+") Then
            $a[0] = $t
            $a[1] = 1
            Return $a
        EndIf
        $a[0] = $inner
        $a[1] = 0
        Return $a
    EndIf
    $a[0] = $t
    $a[1] = 0
    Return $a
EndFunc

Func SendDown($k)
    If $k = "" Then Return
    Local $a = SplitKey($k)
    If $a[1] Then
        Send($k)
    Else
        Send("{" & $a[0] & " down}")
    EndIf
EndFunc

Func SendUp($k)
    If $k = "" Then Return
    Local $a = SplitKey($k)
    If $a[1] Then
        Send($k)
    Else
        Send("{" & $a[0] & " up}")
    EndIf
EndFunc

Func CaptureKey($hBtn, $hInp)
    UnregisterHotkeys()
    GUICtrlSetData($hBtn, "PRESS")
    Local $hDLL = DllOpen("user32.dll")
    Local $t = TimerInit()
    While _IsPressed("01", $hDLL) And TimerDiff($t) < 1000
        Sleep(10)
    WEnd
    Local $det = "", $found = False
    Local $tm = TimerInit()
    While Not $found And TimerDiff($tm) < 5000
        Local $m = GUIGetMsg()
        If $m = $GUI_EVENT_CLOSE Or $m = $btnExit Then
            DllClose($hDLL)
            GUICtrlSetData($hBtn, "SET")
            RegisterHotkeys()
            Return
        EndIf
        If _IsPressed("1B", $hDLL) Then ExitLoop
        For $vk = 0x08 To 0x91
            If $vk = 0x01 Or $vk = 0x02 Or $vk = 0x04 Then ContinueLoop
            If _IsPressed(Hex($vk, 2), $hDLL) Then
                $det = TranslateVK($vk)
                $found = True
                While _IsPressed(Hex($vk, 2), $hDLL)
                    Sleep(10)
                WEnd
                ExitLoop
            EndIf
        Next
        Sleep(15)
    WEnd
    DllClose($hDLL)
    GUICtrlSetData($hBtn, "SET")
    If $det <> "" Then
        GUICtrlSetData($hInp, $det)
        LogLine("Rebound key -> " & $det)
    EndIf
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
        Case $vk = 0x1B
            Return "ESC"
        Case $vk = 0x08
            Return "BACKSPACE"
        Case $vk = 0x2E
            Return "DELETE"
        Case $vk = 0x2D
            Return "INSERT"
        Case $vk = 0x24
            Return "HOME"
        Case $vk = 0x23
            Return "END"
        Case $vk = 0x21
            Return "PGUP"
        Case $vk = 0x22
            Return "PGDN"
        Case $vk = 0x14
            Return "CAPSLOCK"
        Case $vk = 0x6A
            Return "NUMPADMULT"
        Case $vk = 0x6B
            Return "NUMPADADD"
        Case $vk = 0x6D
            Return "NUMPADSUB"
        Case $vk = 0x6E
            Return "NUMPADDOT"
        Case $vk = 0x6F
            Return "NUMPADDIV"
        Case $vk = 0xA1
            Return "RSHIFT"
        Case $vk = 0xA3
            Return "RCTRL"
        Case $vk = 0xA5
            Return "RALT"
        Case $vk = 0x5B Or $vk = 0x5C
            Return "LWIN"
        Case $vk = 0xBA
            Return ";" ; VK_OEM_1 (US layout)
        Case $vk = 0xBB
            Return "="
        Case $vk = 0xBC
            Return ","
        Case $vk = 0xBD
            Return "-"
        Case $vk = 0xBE
            Return "."
        Case $vk = 0xBF
            Return "/"
        Case $vk = 0xDE
            Return "'"
        Case Else
            ; No known mapping - AutoIt's Send()/HotKeySet() cannot use a raw
            ; hex VK code, so surface this plainly instead of silently
            ; producing an unusable "{XX}" bind.
            Return ""
    EndSelect
EndFunc

Func FmtKey($s)
    $s = StringStripWS($s, 3)
    If $s = "" Then Return ""
    If StringLeft($s, 1) = "{" And StringRight($s, 1) = "}" Then Return StringUpper($s)
    Local $l = StringLower($s)
    If $l = "space" Then Return "{SPACE}"
    If $l = "shift" Or $l = "lshift" Then Return "{LSHIFT}"
    If $l = "ctrl" Or $l = "lctrl" Then Return "{LCTRL}"
    If $l = "alt" Or $l = "lalt" Then Return "{LALT}"
    If $l = "enter" Or $l = "return" Then Return "{ENTER}"
    If $l = "tab" Then Return "{TAB}"
    If $l = "esc" Or $l = "escape" Then Return "{ESC}"
    If StringRegExp($l, "^f([1-9]|1[0-2])$") Then Return "{" & StringUpper($l) & "}"
    If StringLen($s) = 1 Then Return StringLower($s)
    Return "{" & StringUpper($s) & "}"
EndFunc

; ================= HOTKEYS =================
RegisterHotkeys()

Func SyncBindsFromGUI()
    $sKWalk       = FmtKey(GUICtrlRead($iWalk))
    $sKLock       = FmtKey(GUICtrlRead($iLock))
    $sKFinish     = FmtKey(GUICtrlRead($iFin))
    $sKMash       = FmtKey(GUICtrlRead($iMash))
    $sKClash      = FmtKey(GUICtrlRead($iClsh))
    $sKKatana     = FmtKey(GUICtrlRead($iKat))
    $sKMow        = FmtKey(GUICtrlRead($iMow))
    $sKPlunge     = FmtKey(GUICtrlRead($iPlg))
    $sKClick      = FmtKey(GUICtrlRead($iClk))
    $sKToggle     = FmtKey(GUICtrlRead($iTog))
    $sKGuiTog     = FmtKey(GUICtrlRead($iGui))
    $sKHudTog     = FmtKey(GUICtrlRead($iHudT))
    $sKJobGar     = FmtKey(GUICtrlRead($iJG))
    $sKJobCoc     = FmtKey(GUICtrlRead($iJC))
    $sKJobWin     = FmtKey(GUICtrlRead($iJW))
    $sKJobMine    = FmtKey(GUICtrlRead($iJM))
    $sKJobChk     = FmtKey(GUICtrlRead($iJK))
    $sKBkHold     = FmtKey(GUICtrlRead($iBkHold))
    $sKBkSpam     = FmtKey(GUICtrlRead($iBkSpam))
    $sKEmuSaveTrg = FmtKey(GUICtrlRead($iEmuST))
    $sKEmuLoadTrg = FmtKey(GUICtrlRead($iEmuLT))
EndFunc

; These three are the emergency/utility keys (killswitch, panel toggle, HUD
; toggle) - they stay registered system-wide at ALL times, on purpose, so
; they still work even when the game window isn't focused.
Global $bScopedHotkeysActive = False

Func AlwaysKeys()
    Local $a[3] = [$sKToggle, $sKGuiTog, $sKHudTog]
    Return $a
EndFunc

; Every other trigger is a "game action" key - many default to plain
; letters (e/w/a/s/d/q/j/k/l) or LShift, which are keys people need to
; type/use normally in every other window. These are only captured while
; a tracked game/emulator window is actually focused (see ManageHotkeyScope).
Func ScopedKeys()
    Local $a[18] = [$sKWalk, $sKLock, $sKFinish, $sKMash, $sKClash, $sKKatana, _
        $sKMow, $sKPlunge, $sKClick, $sKJobGar, $sKJobCoc, $sKJobWin, $sKJobMine, _
        $sKJobChk, $sKBkHold, $sKBkSpam, $sKEmuSaveTrg, $sKEmuLoadTrg]
    Return $a
EndFunc

Func ScopedKeyFuncs()
    Local $a[18] = ["ToggleWalk", "ToggleLock", "ActionDeathBlow", "ToggleMash", _
        "ToggleClash", "ExecuteRecharge", "ToggleMow", "TogglePlunge", "ToggleClick", _
        "ToggleJobGar", "ToggleJobCoc", "ToggleJobWin", "ToggleJobMine", "ToggleJobChk", _
        "ToggleBikeHold", "ToggleBikeSpam", "EmuSave", "EmuLoad"]
    Return $a
EndFunc

Func RegisterAlwaysKeys()
    Local $a = AlwaysKeys()
    If $a[0] <> "" Then HotKeySet($a[0], "ToggleMaster")
    If $a[1] <> "" Then HotKeySet($a[1], "ToggleGUI")
    If $a[2] <> "" Then HotKeySet($a[2], "ToggleHUD")
EndFunc

Func UnregisterAlwaysKeys()
    Local $a = AlwaysKeys()
    For $i = 0 To UBound($a) - 1
        If $a[$i] <> "" Then HotKeySet($a[$i])
    Next
EndFunc

Func RegisterScopedKeys()
    Local $aKeys = ScopedKeys()
    Local $aFuncs = ScopedKeyFuncs()
    For $i = 0 To UBound($aKeys) - 1
        If $aKeys[$i] <> "" Then HotKeySet($aKeys[$i], $aFuncs[$i])
    Next
    $bScopedHotkeysActive = True
EndFunc

Func UnregisterScopedKeys()
    Local $aKeys = ScopedKeys()
    For $i = 0 To UBound($aKeys) - 1
        If $aKeys[$i] <> "" Then HotKeySet($aKeys[$i])
    Next
    $bScopedHotkeysActive = False
EndFunc

; Full (re)registration used at startup and whenever bindings change
; (Save & Apply, version switch, rebind capture). Always-on keys are
; always active; scoped keys are only active immediately if focus-gating
; is off or the game is currently focused - otherwise ManageHotkeyScope()
; will pick them up the moment the game window comes to the front.
Func RegisterHotkeys()
    SyncBindsFromGUI()
    RegisterAlwaysKeys()
    If Not $bRequireFocus Or IsGameActive() Then
        RegisterScopedKeys()
    Else
        $bScopedHotkeysActive = False
    EndIf
EndFunc

Func UnregisterHotkeys()
    UnregisterAlwaysKeys()
    UnregisterScopedKeys()
EndFunc

; Called on a timer (see main loop) so scoped keys only capture input while
; a tracked NMH/emulator window is actually foreground. When focus-gating
; is switched off, the scoped set simply stays registered permanently.
Func ManageHotkeyScope()
    If Not $bRequireFocus Then
        If Not $bScopedHotkeysActive Then RegisterScopedKeys()
        Return
    EndIf
    Local $bActive = IsGameActive()
    If $bActive And Not $bScopedHotkeysActive Then
        RegisterScopedKeys()
    ElseIf Not $bActive And $bScopedHotkeysActive Then
        UnregisterScopedKeys()
        ResetAll() ; release any keys/mouse buttons the macros were holding down
    EndIf
EndFunc

; ================= SAVE / RELOAD =================
Func SaveAllSettings()
    UnregisterHotkeys()
    $sKWalk   = FmtKey(GUICtrlRead($iWalk))
    $sKLock   = FmtKey(GUICtrlRead($iLock))
    $sKFinish = FmtKey(GUICtrlRead($iFin))
    $sKMash   = FmtKey(GUICtrlRead($iMash))
    $sKClash  = FmtKey(GUICtrlRead($iClsh))
    $sKKatana = FmtKey(GUICtrlRead($iKat))
    $sKMow    = FmtKey(GUICtrlRead($iMow))
    $sKPlunge = FmtKey(GUICtrlRead($iPlg))
    $sKClick  = FmtKey(GUICtrlRead($iClk))
    $sKToggle = FmtKey(GUICtrlRead($iTog))
    $sKGuiTog = FmtKey(GUICtrlRead($iGui))
    $sKHudTog = FmtKey(GUICtrlRead($iHudT))
    $sKFwd    = FmtKey(GUICtrlRead($iFwd))
    $sKBack   = FmtKey(GUICtrlRead($iBck))
    $sKLeft   = FmtKey(GUICtrlRead($iLft))
    $sKRight  = FmtKey(GUICtrlRead($iRgt))
    $sKLockTgt= FmtKey(GUICtrlRead($iLkTgt))
    $sKRech   = FmtKey(GUICtrlRead($iRchg))
    $sKMashAct= FmtKey(GUICtrlRead($iMshA))
    $sKUp     = FmtKey(GUICtrlRead($iUp))
    $sKDown   = FmtKey(GUICtrlRead($iDwn))
    $sKDirL   = FmtKey(GUICtrlRead($iDL))
    $sKDirR   = FmtKey(GUICtrlRead($iDR))
    $sKJobAct = FmtKey(GUICtrlRead($iJobAct))
    $sKJobMove= FmtKey(GUICtrlRead($iJobMove))
    $sKJobThrow=FmtKey(GUICtrlRead($iJobThr))
    $sKJobGar = FmtKey(GUICtrlRead($iJG))
    $sKJobCoc = FmtKey(GUICtrlRead($iJC))
    $sKJobWin = FmtKey(GUICtrlRead($iJW))
    $sKJobMine= FmtKey(GUICtrlRead($iJM))
    $sKJobChk = FmtKey(GUICtrlRead($iJK))
    $sKBkAccel= FmtKey(GUICtrlRead($iBkA))
    $sKBkBrake= FmtKey(GUICtrlRead($iBkB))
    $sKBkL    = FmtKey(GUICtrlRead($iBkL))
    $sKBkR    = FmtKey(GUICtrlRead($iBkR))
    $sKBkAtkL = FmtKey(GUICtrlRead($iBkAL))
    $sKBkAtkR = FmtKey(GUICtrlRead($iBkAR))
    $sKBkBoost= FmtKey(GUICtrlRead($iBkBst))
    $sKBkGuard= FmtKey(GUICtrlRead($iBkGd))
    $sKBkHold = FmtKey(GUICtrlRead($iBkHold))
    $sKBkSpam = FmtKey(GUICtrlRead($iBkSpam))
    $sKEmuSaveTrg = FmtKey(GUICtrlRead($iEmuST))
    $sKEmuLoadTrg = FmtKey(GUICtrlRead($iEmuLT))
    $sKEmuSaveKey = FmtKey(GUICtrlRead($iEmuSK))
    $sKEmuLoadKey = FmtKey(GUICtrlRead($iEmuLK))

    $iMowHoldMs   = ClampInt(GUICtrlRead($iMowMs),  10, 5000, 300)
    $iPlungeDelay = ClampInt(GUICtrlRead($iPlgMs),   5, 2000, 40)
    $iRechargeMs  = ClampInt(GUICtrlRead($iRchMs),   5, 5000, 50)
    $iRchShakeMs     = ClampInt(GUICtrlRead($iRchShkMs),  100, 5000, 900)
    $iRchShakeAmp    = ClampInt(GUICtrlRead($iRchShkAmp),   1,  200, 18)
    $iRchShakeStepMs = ClampInt(GUICtrlRead($iRchShkStp),   5,  200, 16)
    $iJobWalkMs   = ClampInt(GUICtrlRead($iJbWkMs), 50, 5000, 450)
    $iJobActMs    = ClampInt(GUICtrlRead($iJbAcMs), 20, 5000, 300)
    $iBikeSlashMs = ClampInt(GUICtrlRead($iBkSlMs), 20, 5000, 250)
    $iKeyDelay    = ClampInt(GUICtrlRead($iKD),      0, 500,  25)
    $iKeyDownDelay= ClampInt(GUICtrlRead($iKDD),     0, 500,  35)
    $iMashSpeed   = ClampInt(GUICtrlRead($iMS),      1, 5000, 30)
    $iClickSpeed  = ClampInt(GUICtrlRead($iCS),      1, 5000, 50)
    $iHudAlpha    = ClampInt(GUICtrlRead($iHudA),   30, 255, 255)

    GUICtrlSetData($iMowMs, $iMowHoldMs)
    GUICtrlSetData($iPlgMs, $iPlungeDelay)
    GUICtrlSetData($iRchMs, $iRechargeMs)
    GUICtrlSetData($iRchShkMs, $iRchShakeMs)
    GUICtrlSetData($iRchShkAmp, $iRchShakeAmp)
    GUICtrlSetData($iRchShkStp, $iRchShakeStepMs)
    GUICtrlSetData($iJbWkMs, $iJobWalkMs)
    GUICtrlSetData($iJbAcMs, $iJobActMs)
    GUICtrlSetData($iBkSlMs, $iBikeSlashMs)
    GUICtrlSetData($iKD, $iKeyDelay)
    GUICtrlSetData($iKDD, $iKeyDownDelay)
    GUICtrlSetData($iMS, $iMashSpeed)
    GUICtrlSetData($iCS, $iClickSpeed)
    GUICtrlSetData($iHudA, $iHudAlpha)

    WinSetTrans($hHUD, "", $iHudAlpha)

    $bRequireFocus = (GUICtrlRead($chkFocus) = $GUI_CHECKED)
    $bAutoLoad     = (GUICtrlRead($chkAuto)  = $GUI_CHECKED)

    Local $sEng = GUICtrlRead($cmbEngine)
    If StringInStr($sEng, "UE4") Then
        $iEngineMode = 1
    ElseIf StringInStr($sEng, "Classic") Then
        $iEngineMode = 2
    Else
        $iEngineMode = 3
    EndIf

    Opt("SendKeyDelay", $iKeyDelay)
    Opt("SendKeyDownDelay", $iKeyDownDelay)

    VWrite("Walk", $sKWalk)
    VWrite("Lock", $sKLock)
    VWrite("Finish", $sKFinish)
    VWrite("Mash", $sKMash)
    VWrite("Clash", $sKClash)
    VWrite("Katana", $sKKatana)
    VWrite("Mow", $sKMow)
    VWrite("Plunge", $sKPlunge)
    VWrite("Click", $sKClick)
    VWrite("Toggle", $sKToggle)
    VWrite("GuiTog", $sKGuiTog)
    VWrite("HudTog", $sKHudTog)
    VWrite("HudAlpha", $iHudAlpha)
    VWrite("Fwd", $sKFwd)
    VWrite("Back", $sKBack)
    VWrite("Left", $sKLeft)
    VWrite("Right", $sKRight)
    VWrite("LockTgt", $sKLockTgt)
    VWrite("Recharge", $sKRech)
    VWrite("MashAct", $sKMashAct)
    VWrite("Up", $sKUp)
    VWrite("Down", $sKDown)
    VWrite("DirLeft", $sKDirL)
    VWrite("DirRight", $sKDirR)
    VWrite("JobAct", $sKJobAct)
    VWrite("JobMove", $sKJobMove)
    VWrite("JobThrow", $sKJobThrow)
    VWrite("JobGar", $sKJobGar)
    VWrite("JobCoc", $sKJobCoc)
    VWrite("JobWin", $sKJobWin)
    VWrite("JobMine", $sKJobMine)
    VWrite("JobChk", $sKJobChk)
    VWrite("BkAccel", $sKBkAccel)
    VWrite("BkBrake", $sKBkBrake)
    VWrite("BkL", $sKBkL)
    VWrite("BkR", $sKBkR)
    VWrite("BkAtkL", $sKBkAtkL)
    VWrite("BkAtkR", $sKBkAtkR)
    VWrite("BkBoost", $sKBkBoost)
    VWrite("BkGuard", $sKBkGuard)
    VWrite("BkHold", $sKBkHold)
    VWrite("BkSpam", $sKBkSpam)
    VWrite("EmuSaveTrg", $sKEmuSaveTrg)
    VWrite("EmuLoadTrg", $sKEmuLoadTrg)
    VWrite("EmuSaveKey", $sKEmuSaveKey)
    VWrite("EmuLoadKey", $sKEmuLoadKey)
    IniWrite($sIniFile, "Meta", "ActiveVersion", $iActiveVer)
    IniWrite($sIniFile, "Meta", "SendKeyDelay", $iKeyDelay)
    IniWrite($sIniFile, "Meta", "SendKeyDownDelay", $iKeyDownDelay)
    IniWrite($sIniFile, "Meta", "MashSpeed", $iMashSpeed)
    IniWrite($sIniFile, "Meta", "ClickSpeed", $iClickSpeed)
    IniWrite($sIniFile, "Meta", "EngineMode", $iEngineMode)
    IniWrite($sIniFile, "Meta", "RequireFocus", $bRequireFocus ? "1" : "0")
    IniWrite($sIniFile, "Meta", "AutoLoadProfile", $bAutoLoad ? "1" : "0")
    IniWrite($sIniFile, "Meta", "MowHoldMs", $iMowHoldMs)
    IniWrite($sIniFile, "Meta", "PlungeDelay", $iPlungeDelay)
    IniWrite($sIniFile, "Meta", "RechargeMs", $iRechargeMs)
    IniWrite($sIniFile, "Meta", "RechargeShakeMs", $iRchShakeMs)
    IniWrite($sIniFile, "Meta", "RechargeShakeAmp", $iRchShakeAmp)
    IniWrite($sIniFile, "Meta", "RechargeShakeStepMs", $iRchShakeStepMs)
    IniWrite($sIniFile, "Meta", "JobWalkMs", $iJobWalkMs)
    IniWrite($sIniFile, "Meta", "JobActMs", $iJobActMs)
    IniWrite($sIniFile, "Meta", "BikeSlashMs", $iBikeSlashMs)

    RegisterHotkeys()
    GUICtrlSetData($lblHS, "STATUS: SETTINGS APPLIED")
    LogLine("Settings saved (V" & $iActiveVer & ")")
    Beep(1500, 150)
EndFunc

; ================= PER-VERSION BIND TABLE =================
; [ IniKey, RuntimeVarName, ControlVarName, Default ]
; This ONE table now drives both SaveAllSettings' per-version writes and
; SwitchVersion's persist/reload, so the two can no longer drift apart
; (previously SwitchVersion only handled 9 of these 46 fields and quietly
; dropped the rest of your custom binds whenever you changed game version).
Global $aBindTable[46][4] = [ _
    ["Walk",       "sKWalk",      "iWalk",     "{F1}"], _
    ["Lock",       "sKLock",      "iLock",     "{LSHIFT}"], _
    ["Finish",     "sKFinish",    "iFin",      "{F3}"], _
    ["Mash",       "sKMash",      "iMash",     "e"], _
    ["Clash",      "sKClash",     "iClsh",     "{NUMPAD4}"], _
    ["Katana",     "sKKatana",    "iKat",      "{NUMPAD3}"], _
    ["Mow",        "sKMow",       "iMow",      "{NUMPAD1}"], _
    ["Plunge",     "sKPlunge",    "iPlg",      "{NUMPAD2}"], _
    ["Click",      "sKClick",     "iClk",      "{F5}"], _
    ["Toggle",     "sKToggle",    "iTog",      "{F2}"], _
    ["GuiTog",     "sKGuiTog",    "iGui",      "{F4}"], _
    ["HudTog",     "sKHudTog",    "iHudT",     "{F8}"], _
    ["HudAlpha",   "iHudAlpha",   "iHudA",     "255"], _
    ["Fwd",        "sKFwd",       "iFwd",      "w"], _
    ["Back",       "sKBack",      "iBck",      "s"], _
    ["Left",       "sKLeft",      "iLft",      "a"], _
    ["Right",      "sKRight",     "iRgt",      "d"], _
    ["LockTgt",    "sKLockTgt",   "iLkTgt",    "{LSHIFT}"], _
    ["Recharge",   "sKRech",      "iRchg",     "q"], _
    ["MashAct",    "sKMashAct",   "iMshA",     "e"], _
    ["Up",         "sKUp",        "iUp",       "{UP}"], _
    ["Down",       "sKDown",      "iDwn",      "{DOWN}"], _
    ["DirLeft",    "sKDirL",      "iDL",       "{LEFT}"], _
    ["DirRight",   "sKDirR",      "iDR",       "{RIGHT}"], _
    ["JobAct",     "sKJobAct",    "iJobAct",   "e"], _
    ["JobMove",    "sKJobMove",   "iJobMove",  "w"], _
    ["JobThrow",   "sKJobThrow",  "iJobThr",   "q"], _
    ["JobGar",     "sKJobGar",    "iJG",       "{NUMPAD7}"], _
    ["JobCoc",     "sKJobCoc",    "iJC",       "{NUMPAD8}"], _
    ["JobWin",     "sKJobWin",    "iJW",       "{NUMPAD9}"], _
    ["JobMine",    "sKJobMine",   "iJM",       "{NUMPAD0}"], _
    ["JobChk",     "sKJobChk",    "iJK",       "{NUMPADDIV}"], _
    ["BkAccel",    "sKBkAccel",   "iBkA",      "w"], _
    ["BkBrake",    "sKBkBrake",   "iBkB",      "s"], _
    ["BkL",        "sKBkL",       "iBkL",      "a"], _
    ["BkR",        "sKBkR",       "iBkR",      "d"], _
    ["BkAtkL",     "sKBkAtkL",    "iBkAL",     "j"], _
    ["BkAtkR",     "sKBkAtkR",    "iBkAR",     "k"], _
    ["BkBoost",    "sKBkBoost",   "iBkBst",    "{LSHIFT}"], _
    ["BkGuard",    "sKBkGuard",   "iBkGd",     "l"], _
    ["BkHold",     "sKBkHold",    "iBkHold",   "{NUMPAD5}"], _
    ["BkSpam",     "sKBkSpam",    "iBkSpam",   "{NUMPAD6}"], _
    ["EmuSaveTrg", "sKEmuSaveTrg","iEmuST",    "{F6}"], _
    ["EmuLoadTrg", "sKEmuLoadTrg","iEmuLT",    "{F7}"], _
    ["EmuSaveKey", "sKEmuSaveKey","iEmuSK",    "{F1}"], _
    ["EmuLoadKey", "sKEmuLoadKey","iEmuLK",    "{F3}"] ]

; Writes EVERY field currently shown in the GUI into the CURRENT version's
; ini section. Called before switching versions so nothing you've typed
; in gets lost, even if you never clicked SAVE & APPLY.
Func PersistCurrentVersionBinds()
    For $i = 0 To UBound($aBindTable) - 1
        Local $hCtrl = Eval($aBindTable[$i][2])
        Local $sRaw = GUICtrlRead($hCtrl)
        If $aBindTable[$i][0] = "HudAlpha" Then
            IniWrite($sIniFile, VSec(), "HudAlpha", ClampInt($sRaw, 30, 255, 255))
        Else
            IniWrite($sIniFile, VSec(), $aBindTable[$i][0], FmtKey($sRaw))
        EndIf
    Next
EndFunc

; Reloads EVERY field for the (now-active) version from ini into both the
; live runtime variable the macros actually use AND the GUI control that
; displays it - so the two can never show/behave differently after a switch.
Func RefreshAllVersionBindsIntoRuntimeAndGUI()
    For $i = 0 To UBound($aBindTable) - 1
        Local $sVal = VRead($aBindTable[$i][0], $aBindTable[$i][3])
        If $aBindTable[$i][0] = "HudAlpha" Then
            $sVal = ClampInt($sVal, 30, 255, 255)
        Else
            $sVal = FmtKey($sVal)
        EndIf
        Assign($aBindTable[$i][1], $sVal)
        GUICtrlSetData(Eval($aBindTable[$i][2]), $sVal)
    Next
EndFunc

Func SwitchVersion($iNew, $bForce = False)
    If $iNew = $iActiveVer And Not $bForce Then Return
    PersistCurrentVersionBinds() ; save EVERY current field, not just 9 of them
    UnregisterHotkeys()
    $iActiveVer = $iNew
    RefreshAllVersionBindsIntoRuntimeAndGUI() ; load EVERY field for the new version
    WinSetTrans($hHUD, "", $iHudAlpha)
    IniWrite($sIniFile, "Meta", "ActiveVersion", $iActiveVer)
    RegisterHotkeys()
    GUICtrlSetData($lblVer, "Active: " & $aVersions[$iActiveVer][0])
    LogLine("Switched to " & $aVersions[$iActiveVer][0])
    Beep(900, 60)
EndFunc

Func AutoLoadVersionProfile()
    If Not $bAutoLoad Then Return
    Local $name = ""
    If ProcessExists("NMH3-Win64-Shipping.exe") Or ProcessExists("NMH3.exe") Then
        $name = "NMH3"
    ElseIf ProcessExists("NMH2.exe") Then
        $name = "NMH2"
    ElseIf ProcessExists("No More Heroes.exe") Then
        $name = "NMH1"
    EndIf
    If $name = "" Then Return
    Local $p = $sProfileDir & "\" & $name & ".ini"
    If FileExists($p) Then
        FileCopy($p, $sIniFile, 9)
        LogLine("Auto-loaded profile: " & $name)
    EndIf
EndFunc

Func SaveProfileAs()
    Local $n = InputBox("Save Profile", "Profile name:", "Profile_" & @YEAR & @MON & @DAY)
    If $n = "" Then Return
    $n = StringRegExpReplace($n, '[\\/:*?"<>|]', "_")
    Local $dst = $sProfileDir & "\" & $n & ".ini"
    If FileExists($dst) Then
        If MsgBox(BitOR(4, 32), "Overwrite?", "Exists. Overwrite?") <> 6 Then Return
    EndIf
    SaveAllSettings()
    FileCopy($sIniFile, $dst, 9)
    LogLine("Saved profile " & $n)
EndFunc

Func LoadProfile()
    Local $f = FileOpenDialog("Load Profile", $sProfileDir, "INI (*.ini)")
    If @error Then Return
    FileCopy($f, $sIniFile, 9)
    LogLine("Loaded profile " & $f)
    Beep(1000, 80)
EndFunc

; ================= MAIN LOOP =================
AutoLoadVersionProfile()

Local $iTimer = TimerInit()

While 1
    Local $n = GUIGetMsg()
    Select
        Case $n = $GUI_EVENT_CLOSE Or $n = $btnExit
            ExitLoop
        Case $n = $btnHide
            ToggleGUI()
        Case $n = $btnSave
            SaveAllSettings()
        Case $n = $btnClr
            GUICtrlSetData($edtLog, "")
        Case $n = $btnSaveProf
            SaveProfileAs()
        Case $n = $btnLoadProf
            LoadProfile()
        Case $n = $aTabButtons[0]
            ShowTab(0)
        Case $n = $aTabButtons[1]
            ShowTab(1)
        Case $n = $aTabButtons[2]
            ShowTab(2)
        Case $n = $aTabButtons[3]
            ShowTab(3)
        Case $n = $cmbVersion
            Local $sel = GUICtrlRead($cmbVersion)
            For $i = 0 To 2
                If $aVersions[$i][0] = $sel Then
                    SwitchVersion($i)
                    ExitLoop
                EndIf
            Next
        Case Else
            If $n > 0 Then
                For $k = 0 To $iBindCount - 1
                    If $n = $aBindMap[$k][0] Then
                        CaptureKey($aBindMap[$k][0], $aBindMap[$k][1])
                        ExitLoop
                    EndIf
                Next
            EndIf
    EndSelect

    If TimerDiff($iTimer) >= 100 Then
        UpdateHUD()
        ManageHotkeyScope()
        $iTimer = TimerInit()
    EndIf

    Local $can = $bScriptEnabled
    If $bRequireFocus Then $can = $can And IsGameActive()

    If $can Then
        ; --- Version-Aware Combat Macros ---
        If $bClash Then
            ; NMH1 / NMH2 / NMH3: Directional QTE using arrow keys.
            Send($sKUp)
            Sleep(30)
            Send($sKDirR)
            Sleep(30)
            Send($sKDown)
            Sleep(30)
            Send($sKDirL)
            Sleep(30)
        EndIf
        If $bMash Then
            If $iEngineMode = 1 Then
                SendDown($sKMashAct)
                Sleep($iKeyDownDelay)
                SendUp($sKMashAct)
                Sleep($iMashSpeed)
            Else
                Send($sKMashAct)
                Sleep($iMashSpeed)
            EndIf
        EndIf
        If $bClick Then
            If $iEngineMode = 1 Then
                MouseDown("left")
                Sleep($iKeyDownDelay)
                MouseUp("left")
                Sleep($iClickSpeed)
            Else
                MouseClick("left")
                Sleep($iClickSpeed)
            EndIf
        EndIf
        If $bMow Then
            SendDown($sKFwd)
            Sleep($iMowHoldMs)
            SendDown($sKLeft)
            Sleep(Int($iMowHoldMs / 2))
            SendUp($sKLeft)
        EndIf
        If $bPlunge Then
            SendDown($sKFwd)
            Sleep($iPlungeDelay)
            SendUp($sKFwd)
            SendDown($sKBack)
            Sleep($iPlungeDelay)
            SendUp($sKBack)
        EndIf
        If $bJobGar Then
            SendDown($sKJobMove)
            Sleep($iJobWalkMs)
            SendUp($sKJobMove)
            Sleep(80)
            Send($sKJobAct)
            Sleep($iJobActMs)
            Send($sKJobThrow)
            Sleep($iJobActMs)
        EndIf
        If $bJobCoc Then
            SendDown($sKJobMove)
            Sleep(Int($iJobWalkMs * 0.6))
            SendUp($sKJobMove)
            Send($sKJobAct)
            Sleep($iJobActMs)
        EndIf
        If $bJobWin Then
            SendDown($sKJobThrow)
            Sleep(120)
            SendUp($sKJobThrow)
            Send($sKJobAct)
            Sleep($iJobActMs)
        EndIf
        If $bJobMine Then
            SendDown($sKJobMove)
            Sleep(Int($iJobWalkMs * 1.5))
            SendUp($sKJobMove)
            Send($sKJobAct)
            Sleep($iJobActMs)
        EndIf
        If $bJobChk Then
            Send($sKJobAct)
            Sleep(60)
            Send($sKJobThrow)
            Sleep($iJobActMs)
        EndIf
        If $bBikeSpam Then
            SendDown($sKBkAtkL)
            Sleep(30)
            SendUp($sKBkAtkL)
            SendDown($sKBkAtkR)
            Sleep(30)
            SendUp($sKBkAtkR)
            Sleep($iBikeSlashMs)
        EndIf
    EndIf
    Sleep(20)
WEnd

; ================= TOGGLES =================
Func Gate()
    If Not $bScriptEnabled Then Return False
    If $bRequireFocus And Not IsGameActive() Then Return False
    Return True
EndFunc

Func ToggleWalk()
    If Not Gate() Then Return
    $bAutoWalk = Not $bAutoWalk
    If $bAutoWalk Then SendDown($sKFwd)
    If Not $bAutoWalk Then SendUp($sKFwd)
    Beep($bAutoWalk ? 750 : 400, 50)
EndFunc

Func ToggleLock()
    If Not Gate() Then Return
    $bLockActive = Not $bLockActive
    If $bLockActive Then SendDown($sKLockTgt)
    If Not $bLockActive Then SendUp($sKLockTgt)
    Beep($bLockActive ? 800 : 350, 50)
EndFunc

Func ActionDeathBlow()
    If Not Gate() Then Return
    For $i = 1 To 2
        Send($sKUp & $sKDown & $sKDirL & $sKDirR)
        Sleep(30)
    Next
EndFunc

Func ToggleMash()
    If Not Gate() Then Return
    $bMash = Not $bMash
    Beep($bMash ? 750 : 400, 50)
EndFunc

Func ToggleClash()
    If Not Gate() Then Return
    $bClash = Not $bClash
    Beep($bClash ? 900 : 350, 50)
EndFunc

; --- Version-Aware Recharge Macro ---
Func ExecuteRecharge()
    If Not Gate() Then Return
    If $iActiveVer = 2 Then
        ; NMH3 (Steam/PC): Press Q to enter Charge Stance, then continuously
        ; shake the mouse up/down using raw relative Win32 mouse_event moves
        ; in a timed loop - this mirrors the actual controller-shake motion
        ; the game expects far better than a handful of discrete wheel ticks.
        Send($sKRech)          ; $sKRech should be bound to Q
        Sleep(200)             ; give the stance animation time to start
        Local $tShake = TimerInit()
        Local $iDir = 1
        While TimerDiff($tShake) < $iRchShakeMs
            MouseShakeStep($iDir * $iRchShakeAmp)
            $iDir = -$iDir
            Sleep($iRchShakeStepMs)
        WEnd
        Beep(850, 50)
    Else
        ; NMH1 / NMH2 (PC / Emulator):
        ; These versions use a controller shake for recharge.
        ; The key below must be mapped in the emulator or game launcher
        ; to the motion/shake input.
        Send($sKRech)
        Sleep($iRechargeMs)
        Beep(850, 50)
    EndIf
EndFunc

; Raw relative mouse move via user32.dll mouse_event (MOUSEEVENTF_MOVE).
; $iDy is signed pixels - negative moves the cursor up, positive moves it
; down, relative to its current position. This is a real Win32 hardware-
; level input event, not a cursor-position teleport, so it registers the
; same way continuous controller/mouse motion would.
Func MouseShakeStep($iDy)
    Local Const $MOUSEEVENTF_MOVE = 0x0001
    DllCall("user32.dll", "int", "mouse_event", _
        "dword", $MOUSEEVENTF_MOVE, "long", 0, "long", $iDy, "dword", 0, "ptr", 0)
EndFunc

Func ToggleMow()
    If Not Gate() Then Return
    $bMow = Not $bMow
    If Not $bMow Then
        SendUp($sKFwd)
        SendUp($sKLeft)
    EndIf
    Beep($bMow ? 750 : 400, 50)
EndFunc

Func TogglePlunge()
    If Not Gate() Then Return
    $bPlunge = Not $bPlunge
    If Not $bPlunge Then
        SendUp($sKFwd)
        SendUp($sKBack)
    EndIf
    Beep($bPlunge ? 750 : 400, 50)
EndFunc

Func ToggleClick()
    If Not Gate() Then Return
    $bClick = Not $bClick
    Beep($bClick ? 750 : 400, 50)
EndFunc

Func ToggleJobGar()
    If Not Gate() Then Return
    $bJobGar = Not $bJobGar
    LogLine("Job Garbage " & ($bJobGar ? "ON" : "OFF"))
    Beep($bJobGar ? 800 : 400, 50)
EndFunc
Func ToggleJobCoc()
    If Not Gate() Then Return
    $bJobCoc = Not $bJobCoc
    LogLine("Job Coconut " & ($bJobCoc ? "ON" : "OFF"))
    Beep($bJobCoc ? 800 : 400, 50)
EndFunc
Func ToggleJobWin()
    If Not Gate() Then Return
    $bJobWin = Not $bJobWin
    LogLine("Job Window " & ($bJobWin ? "ON" : "OFF"))
    Beep($bJobWin ? 800 : 400, 50)
EndFunc
Func ToggleJobMine()
    If Not Gate() Then Return
    $bJobMine = Not $bJobMine
    LogLine("Job Mine " & ($bJobMine ? "ON" : "OFF"))
    Beep($bJobMine ? 800 : 400, 50)
EndFunc
Func ToggleJobChk()
    If Not Gate() Then Return
    $bJobChk = Not $bJobChk
    LogLine("Job Chicken " & ($bJobChk ? "ON" : "OFF"))
    Beep($bJobChk ? 800 : 400, 50)
EndFunc

Func ToggleBikeHold()
    If Not Gate() Then Return
    $bBikeHold = Not $bBikeHold
    If $bBikeHold Then
        SendDown($sKBkAccel)
    Else
        SendUp($sKBkAccel)
    EndIf
    Beep($bBikeHold ? 800 : 400, 50)
EndFunc

Func ToggleBikeSpam()
    If Not Gate() Then Return
    $bBikeSpam = Not $bBikeSpam
    Beep($bBikeSpam ? 800 : 400, 50)
EndFunc

Func EmuSave()
    If Not $bScriptEnabled Then Return
    Send($sKEmuSaveKey)
    LogLine("Emu save -> " & $sKEmuSaveKey)
    Beep(1200, 50)
EndFunc

Func EmuLoad()
    If Not $bScriptEnabled Then Return
    Send($sKEmuLoadKey)
    LogLine("Emu load -> " & $sKEmuLoadKey)
    Beep(600, 50)
EndFunc

Func ToggleHUD()
    $bHudVisible = Not $bHudVisible
    If $bHudVisible Then
        GUISetState(@SW_SHOWNOACTIVATE, $hHUD)
        WinSetTrans($hHUD, "", $iHudAlpha)
    Else
        GUISetState(@SW_HIDE, $hHUD)
    EndIf
    LogLine("HUD " & ($bHudVisible ? "shown" : "hidden"))
    Beep($bHudVisible ? 900 : 400, 50)
EndFunc

Func ToggleMaster()
    $bScriptEnabled = Not $bScriptEnabled
    If Not $bScriptEnabled Then ResetAll()
    Beep($bScriptEnabled ? 1000 : 300, 100)
EndFunc

Func ToggleGUI()
    Local $s = WinGetState($hMainGUI)
    If BitAND($s, 2) Then
        GUISetState(@SW_HIDE, $hMainGUI)
    Else
        GUISetState(@SW_SHOW, $hMainGUI)
    EndIf
EndFunc

Func ResetAll()
    $bAutoWalk = False
    $bLockActive = False
    $bMash = False
    $bClash = False
    $bMow = False
    $bPlunge = False
    $bClick = False
    $bJobGar = False
    $bJobCoc = False
    $bJobWin = False
    $bJobMine = False
    $bJobChk = False
    $bBikeHold = False
    $bBikeSpam = False
    SendUp($sKFwd)
    SendUp($sKBack)
    SendUp($sKLeft)
    SendUp($sKRight)
    SendUp($sKLockTgt)
    SendUp($sKUp)
    SendUp($sKDown)
    SendUp($sKDirL)
    SendUp($sKDirR)
    SendUp($sKRech)
    SendUp($sKMashAct)
    SendUp($sKJobMove)
    SendUp($sKJobThrow)
    SendUp($sKJobAct)
    SendUp($sKBkAccel)
    SendUp($sKBkAtkL)
    SendUp($sKBkAtkR)
    MouseUp("left")
EndFunc

Func CleanupKeys()
    ResetAll()
EndFunc

; ================= HUD =================
; Returns True only when the CURRENTLY FOREGROUND window belongs to a
; tracked game/emulator process. Deliberately does NOT use WinActive() on
; a title substring like "NMH" - this script's own control panel window
; ("NMH Ultimate OS v7.1") and HUD window ("NMH_HUD") both contain that
; substring, so a title match would make the tool think the game was
; focused any time you were just clicking around your own settings panel.
Func IsGameActive()
    Local $hFg = WinGetHandle("[ACTIVE]")
    If @error Then Return False
    ; Never treat our own windows as "the game", regardless of title.
    If $hFg = $hMainGUI Or $hFg = $hHUD Then Return False
    Local $sProc = WinGetProcess($hFg)
    If @error Or $sProc = "" Then Return False
    For $i = 0 To UBound($aGameProcs) - 1
        If StringLower($sProc) = StringLower($aGameProcs[$i]) Then Return True
    Next
    Return False
EndFunc

Func SetLED($i, $on)
    If $on Then
        GUICtrlSetBkColor($aLEDs[$i], 0x00FF88)
        GUICtrlSetColor($aLEDs[$i], 0x0B0C10)
    Else
        GUICtrlSetBkColor($aLEDs[$i], 0x1A1C23)
        GUICtrlSetColor($aLEDs[$i], 0x555555)
    EndIf
EndFunc

Func UpdateHUD()
    $bGameConnected = IsGameActive()
    If Not $bScriptEnabled Then
        GUICtrlSetData($lblHT, "[ SYSTEM DISABLED ]")
        GUICtrlSetColor($lblHT, 0xFF0055)
    Else
        GUICtrlSetData($lblHT, "[ NMH ACCESSIBILITY ]")
        GUICtrlSetColor($lblHT, 0x00FF88)
    EndIf
    If $bGameConnected Then
        GUICtrlSetData($lblHC, "GAME OK")
        GUICtrlSetColor($lblHC, 0x00FF88)
    Else
        GUICtrlSetData($lblHC, "WAITING")
        GUICtrlSetColor($lblHC, 0xFFCC00)
    EndIf
    Local $s = "STATUS: READY"
    If Not $bScriptEnabled Then
        $s = "STATUS: INACTIVE"
    ElseIf $bClash Then
        $s = "ACTIVE: CLASH/CAMERA"
    ElseIf $bMow Then
        $s = "ACTIVE: LAWN MOWER"
    ElseIf $bMash Then
        $s = "ACTIVE: QTE MASHER"
    ElseIf $bPlunge Then
        $s = "ACTIVE: PLUNGER"
    ElseIf $bClick Then
        $s = "ACTIVE: AUTO-CLICK"
    ElseIf $bJobGar Or $bJobCoc Or $bJobWin Or $bJobMine Or $bJobChk Then
        $s = "ACTIVE: JOB MACRO"
    ElseIf $bBikeSpam Then
        $s = "ACTIVE: BIKE SPAM"
    ElseIf $bBikeHold Then
        $s = "ACTIVE: BIKE HOLD"
    ElseIf $bAutoWalk Then
        $s = "ACTIVE: AUTO-WALK"
    ElseIf $bLockActive Then
        $s = "ACTIVE: LOCK-ON"
    EndIf
    GUICtrlSetData($lblHS, $s)
    Local $on = $bScriptEnabled
    Local $anyJob = $bJobGar Or $bJobCoc Or $bJobWin Or $bJobMine Or $bJobChk
    Local $anyBike = $bBikeHold Or $bBikeSpam
    SetLED(0, $on And $bAutoWalk)
    SetLED(1, $on And $bMash)
    SetLED(2, $on And $bClash)
    SetLED(3, $on And $bMow)
    SetLED(4, $on And $bPlunge)
    SetLED(5, $on And $anyBike)
    SetLED(6, $on And $anyJob)
EndFunc

GUICtrlSetData($lblVer, "Active: " & $aVersions[$iActiveVer][0])
LogLine("NMH Ultimate OS v7.1 loaded - waiting for game window")