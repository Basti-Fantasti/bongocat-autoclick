#NoTrayIcon
#AutoIt3Wrapper_UseX64=y
; BongoCatAutoClick
; Klickt die Belohnungs-Popups (Sprechblasen mit Kiste) ueber der BongoCat-Katze automatisch weg.
; Popup-Positionen werden aus der Katzenposition in der Registry berechnet.
; Erkennung per Pixelfarbe, Klick als echter Mausklick (Unity ignoriert ControlClick),
; danach werden Mausposition und aktives Fenster wiederhergestellt.
; Bedienung: Tray-Menue (Pause/Beenden) und Hotkey Strg+Alt+B (Pause umschalten).

#include <Misc.au3>
#include <TrayConstants.au3>

; ---------------------------------------------------------------------------
; Konfiguration
; ---------------------------------------------------------------------------
Global Const $PROCESS_NAME = "BongoCat.exe"
Global Const $REG_KEY = "HKCU\Software\Irox Games\BongoCat"
Global Const $REG_SUBKEY = "Software\Irox Games\BongoCat"
Global Const $REG_PREFIX_X = "BongoMenuPosXRel_h" ; X-Mitte der Katze, relativ zur Fensterbreite
Global Const $REG_PREFIX_Y = "BongoMenuPosYRel_h" ; Abstand vom unteren Rand, relativ zur Fensterhoehe
Global Const $CHECK_INTERVAL_MS = 1000  ; Pruefintervall
Global Const $CLICK_DELAY_MS = 150      ; Unity braucht Pausen zwischen Setzen, Druecken, Loslassen
Global Const $COLOR_TOLERANCE = 16      ; erlaubte Abweichung pro Farbkanal
Global Const $COLOR_BUBBLE = 0xECEBEC   ; weisser Blasenhintergrund
Global Const $MIN_MATCHES = 3           ; so viele Pruefpunkte muessen weiss sein
Global Const $HOTKEY_PAUSE = "^!b"      ; Strg+Alt+B

; Klickpunkt pro Popup (Mitte des Motivs) relativ zum Ankerpunkt der Katze.
; Der Ankerpunkt ist die X-Mitte der Katze auf Hoehe ihres Registry-Y-Werts.
Global Const $POPUPS[2][2] = [[-51, -32], [54, -32]]

; Pruefpunkte relativ zum Klickpunkt. Sie liegen im weissen Blasenhintergrund
; um das Motiv herum, denn das Motiv selbst wechselt von Popup zu Popup.
Global Const $CHECK_OFFSETS[4][2] = [ _
		[-10, -15], _  ; oben links
		[14, -15], _   ; oben rechts
		[-12, 2], _    ; Rand links
		[17, 0]]       ; Rand rechts

; ---------------------------------------------------------------------------
; Zustand
; ---------------------------------------------------------------------------
Global $g_bPaused = False
Global $g_iClickCount = 0
Global $g_idTrayPause, $g_idTrayCount, $g_idTrayExit

Main()

Func Main()
	; Nur eine Instanz zulassen
	If _Singleton("BongoCatAutoClick", 1) = 0 Then Exit

	; Echte Pixelkoordinaten auch bei Windows-Skalierung
	DllCall("user32.dll", "bool", "SetProcessDPIAware")

	Opt("MouseCoordMode", 1)
	Opt("PixelCoordMode", 1)

	InitTray()
	HotKeySet($HOTKEY_PAUSE, "TogglePause")

	Local $hTimer = TimerInit()
	While True
		HandleTrayEvents()
		If TimerDiff($hTimer) >= $CHECK_INTERVAL_MS Then
			CheckAndClick()
			$hTimer = TimerInit()
		EndIf
	WEnd
EndFunc   ;==>Main

; ---------------------------------------------------------------------------
; Tray
; ---------------------------------------------------------------------------
Func InitTray()
	Opt("TrayMenuMode", 3) ; keine Standardeintraege, kein automatisches Haekchen
	Opt("TrayOnEventMode", 0)
	$g_idTrayPause = TrayCreateItem("Pause")
	$g_idTrayCount = TrayCreateItem("Weggeklickt: 0")
	TrayItemSetState($g_idTrayCount, $TRAY_DISABLE)
	TrayCreateItem("")
	$g_idTrayExit = TrayCreateItem("Beenden")
	TraySetState($TRAY_ICONSTATE_SHOW)
	UpdateTray()
EndFunc   ;==>InitTray

Func HandleTrayEvents()
	; TrayGetMsg wartet intern kurz und haelt damit die CPU-Last niedrig
	Switch TrayGetMsg()
		Case $g_idTrayPause
			TogglePause()
		Case $g_idTrayExit
			Exit
	EndSwitch
EndFunc   ;==>HandleTrayEvents

Func TogglePause()
	$g_bPaused = Not $g_bPaused
	UpdateTray()
EndFunc   ;==>TogglePause

Func UpdateTray()
	TrayItemSetText($g_idTrayPause, $g_bPaused ? "Fortsetzen" : "Pause")
	TrayItemSetText($g_idTrayCount, "Weggeklickt: " & $g_iClickCount)
	TraySetToolTip("BongoCat AutoClick: " & ($g_bPaused ? "pausiert" : "aktiv") & _
			" (" & $g_iClickCount & " weggeklickt, Strg+Alt+B = Pause)")
EndFunc   ;==>UpdateTray

; ---------------------------------------------------------------------------
; Erkennung und Klick
; ---------------------------------------------------------------------------
Func CheckAndClick()
	If $g_bPaused Then Return
	If Not ProcessExists($PROCESS_NAME) Then Return
	; Laufenden Drag des Benutzers nicht unterbrechen
	If _IsPressed("01") Or _IsPressed("02") Then Return

	Local $aAnchor = GetCatAnchor()
	If @error Then Return

	; Absolute Klickpunkte aus Ankerpunkt und Offsets
	Local $aPoints[UBound($POPUPS)][2]
	For $i = 0 To UBound($POPUPS) - 1
		$aPoints[$i][0] = $aAnchor[0] + $POPUPS[$i][0]
		$aPoints[$i][1] = $aAnchor[1] + $POPUPS[$i][1]
	Next

	Local $aFound[UBound($POPUPS)]
	Local $iFound = 0
	For $i = 0 To UBound($POPUPS) - 1
		If IsPopupVisible($aPoints[$i][0], $aPoints[$i][1]) Then
			$aFound[$iFound] = $i
			$iFound += 1
		EndIf
	Next
	If $iFound = 0 Then Return

	Local $aMousePos = MouseGetPos()
	Local $hActiveWin = WinGetHandle("[ACTIVE]")

	For $j = 0 To $iFound - 1
		ClickAt($aPoints[$aFound[$j]][0], $aPoints[$aFound[$j]][1])
		$g_iClickCount += 1
	Next

	MouseMove($aMousePos[0], $aMousePos[1], 0)
	If $hActiveWin <> "" Then WinActivate($hActiveWin)
	UpdateTray()
EndFunc   ;==>CheckAndClick

; ---------------------------------------------------------------------------
; Katzenposition
; ---------------------------------------------------------------------------
; Liefert [X, Y] des Ankerpunkts der Katze in Bildschirmkoordinaten.
; Setzt @error, wenn Fenster oder Registry-Werte nicht verfuegbar sind.
Func GetCatAnchor()
	Local $hWnd = FindCatWindow()
	If $hWnd = 0 Then Return SetError(1, 0, 0)
	Local $aWin = WinGetPos($hWnd)
	If @error Or $aWin[2] <= 0 Or $aWin[3] <= 0 Then Return SetError(2, 0, 0)

	Local $fRelX = ReadUnityDouble($REG_PREFIX_X)
	If @error Then Return SetError(3, 0, 0)
	Local $fRelY = ReadUnityDouble($REG_PREFIX_Y)
	If @error Then Return SetError(4, 0, 0)

	Local $aAnchor[2]
	$aAnchor[0] = Round($aWin[0] + $fRelX * $aWin[2])
	$aAnchor[1] = Round($aWin[1] + $aWin[3] - $fRelY * $aWin[3])
	Return $aAnchor
EndFunc   ;==>GetCatAnchor

; Sucht das Hauptfenster des BongoCat-Prozesses (Ergebnis wird zwischengespeichert)
Func FindCatWindow()
	Static $hCached = 0
	If $hCached <> 0 And WinExists($hCached) Then Return $hCached
	$hCached = 0
	Local $iPid = ProcessExists($PROCESS_NAME)
	If $iPid = 0 Then Return 0
	Local $aList = WinList()
	For $i = 1 To $aList[0][0]
		If WinGetProcess($aList[$i][1]) = $iPid And BitAND(WinGetState($aList[$i][1]), 2) Then
			Local $aPos = WinGetPos($aList[$i][1])
			If Not @error And $aPos[2] > 100 And $aPos[3] > 100 Then
				$hCached = $aList[$i][1]
				ExitLoop
			EndIf
		EndIf
	Next
	Return $hCached
EndFunc   ;==>FindCatWindow

; Liefert den vollstaendigen Wertnamen zu einem Praefix (Unity haengt einen Hash an)
Func FindRegValueName($sPrefix)
	Local $sName
	For $i = 1 To 1000
		$sName = RegEnumVal($REG_KEY, $i)
		If @error Then Return SetError(1, 0, "")
		If StringLeft($sName, StringLen($sPrefix)) = $sPrefix Then Return $sName
	Next
	Return SetError(1, 0, "")
EndFunc   ;==>FindRegValueName

; Liest einen Unity-PlayerPrefs-Double. Unity speichert ihn als REG_DWORD mit
; 8 Byte Daten, RegRead liefert davon nur 4 Byte. Deshalb RegQueryValueExW.
Func ReadUnityDouble($sPrefix)
	Local $sName = FindRegValueName($sPrefix)
	If @error Then Return SetError(1, 0, 0)

	Local $aOpen = DllCall("advapi32.dll", "long", "RegOpenKeyExW", "handle", 0x80000001, _
			"wstr", $REG_SUBKEY, "dword", 0, "dword", 0x20019, "handle*", 0) ; KEY_READ
	If @error Or $aOpen[0] <> 0 Then Return SetError(2, 0, 0)
	Local $hKey = $aOpen[5]

	Local $tData = DllStructCreate("byte[8]")
	Local $aQuery = DllCall("advapi32.dll", "long", "RegQueryValueExW", "handle", $hKey, _
			"wstr", $sName, "ptr", 0, "dword*", 0, "struct*", $tData, "dword*", 8)
	Local $iErr = @error
	DllCall("advapi32.dll", "long", "RegCloseKey", "handle", $hKey)
	If $iErr Or $aQuery[0] <> 0 Or $aQuery[6] <> 8 Then Return SetError(3, 0, 0)

	Local $tDouble = DllStructCreate("double", DllStructGetPtr($tData))
	Return DllStructGetData($tDouble, 1)
EndFunc   ;==>ReadUnityDouble

; ---------------------------------------------------------------------------
; Pixelpruefung
; ---------------------------------------------------------------------------
Func IsPopupVisible($iX, $iY)
	Local $iMatches = 0
	For $k = 0 To UBound($CHECK_OFFSETS) - 1
		Local $iColor = PixelGetColor($iX + $CHECK_OFFSETS[$k][0], $iY + $CHECK_OFFSETS[$k][1])
		If ColorMatches($iColor, $COLOR_BUBBLE) Then $iMatches += 1
	Next
	Return $iMatches >= $MIN_MATCHES
EndFunc   ;==>IsPopupVisible

Func ColorMatches($iColor, $iExpected)
	If $iColor < 0 Then Return False ; PixelGetColor fehlgeschlagen
	For $iShift = 0 To 16 Step 8
		Local $iDiff = Abs(BitAND(BitShift($iColor, $iShift), 0xFF) - BitAND(BitShift($iExpected, $iShift), 0xFF))
		If $iDiff > $COLOR_TOLERANCE Then Return False
	Next
	Return True
EndFunc   ;==>ColorMatches

Func ClickAt($iX, $iY)
	MouseMove($iX, $iY, 0)
	Sleep($CLICK_DELAY_MS)
	MouseDown("left")
	Sleep($CLICK_DELAY_MS)
	MouseUp("left")
	Sleep($CLICK_DELAY_MS)
EndFunc   ;==>ClickAt
