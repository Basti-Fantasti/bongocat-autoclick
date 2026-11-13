#NoTrayIcon
#AutoIt3Wrapper_UseX64=y
; BongoCatAutoClick
; Klickt die Belohnungs-Popups (Sprechblasen mit Kiste) ueber der BongoCat-Katze automatisch weg.
; Erkennung per Pixelfarbe, Klick als echter Mausklick (Unity ignoriert ControlClick),
; danach werden Mausposition und aktives Fenster wiederhergestellt.
; Bedienung: Tray-Menue (Pause/Beenden) und Hotkey Strg+Alt+B (Pause umschalten).

#include <Misc.au3>
#include <TrayConstants.au3>

; ---------------------------------------------------------------------------
; Konfiguration (absolute Bildschirmkoordinaten)
; ---------------------------------------------------------------------------
Global Const $PROCESS_NAME = "BongoCat.exe"
Global Const $CHECK_INTERVAL_MS = 1000  ; Pruefintervall
Global Const $CLICK_DELAY_MS = 150      ; Unity braucht Pausen zwischen Setzen, Druecken, Loslassen
Global Const $COLOR_TOLERANCE = 16      ; erlaubte Abweichung pro Farbkanal
Global Const $COLOR_BUBBLE = 0xECEBEC   ; weisser Blasenhintergrund
Global Const $MIN_MATCHES = 3           ; so viele Pruefpunkte muessen weiss sein
Global Const $HOTKEY_PAUSE = "^!b"      ; Strg+Alt+B

; Klickpunkt pro Popup (Mitte des Motivs)
Global Const $POPUPS[2][2] = [[40, 1360], [140, 1360]]

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

	Local $aFound[UBound($POPUPS)]
	Local $iFound = 0
	For $i = 0 To UBound($POPUPS) - 1
		If IsPopupVisible($i) Then
			$aFound[$iFound] = $i
			$iFound += 1
		EndIf
	Next
	If $iFound = 0 Then Return

	Local $aMousePos = MouseGetPos()
	Local $hActiveWin = WinGetHandle("[ACTIVE]")

	For $j = 0 To $iFound - 1
		ClickAt($POPUPS[$aFound[$j]][0], $POPUPS[$aFound[$j]][1])
		$g_iClickCount += 1
	Next

	MouseMove($aMousePos[0], $aMousePos[1], 0)
	If $hActiveWin <> "" Then WinActivate($hActiveWin)
	UpdateTray()
EndFunc   ;==>CheckAndClick

Func IsPopupVisible($iIndex)
	Local $iMatches = 0
	For $k = 0 To UBound($CHECK_OFFSETS) - 1
		Local $iColor = PixelGetColor($POPUPS[$iIndex][0] + $CHECK_OFFSETS[$k][0], _
				$POPUPS[$iIndex][1] + $CHECK_OFFSETS[$k][1])
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
