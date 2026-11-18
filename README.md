# BongoCat AutoClick

An AutoIt script that dismisses the reward popups in [BongoCat](https://store.steampowered.com/app/3419430/Bongo_Cat/) on Windows.

BongoCat shows up to two speech bubbles above the cat, each with a chest icon and a counter. The script watches both bubble positions once per second. When a bubble appears, it clicks it away. It then moves the mouse back to where it was and reactivates the previously active window.

## How it works

1. Every second the script reads the cat position from the registry and computes the bubble positions from it. See [Cat position](#cat-position).
2. The script reads four pixels around each bubble. These pixels lie in the white bubble background, outside the icon.
3. If at least three of the four pixels are white (`#ECEBEC`, tolerance 16 per channel), the bubble counts as visible.
4. The script stores the mouse position and the active window.
5. It moves the cursor to the bubble and presses the left button. It waits 150 ms between move, press and release.
6. It restores the mouse position and the active window.

The script skips a check while the left or right mouse button is held down. A drag in another application stays intact.

The click is a real mouse click. BongoCat is a Unity application and ignores window messages, so `ControlClick` and `PostMessage` have no effect. Unity also drops clicks that are shorter than about 150 ms.

### Cat position

The BongoCat window is a transparent overlay that covers the whole monitor. Dragging the cat does not move the window. The cat moves inside it.

BongoCat stores its settings as Unity PlayerPrefs in `HKCU\Software\Irox Games\BongoCat`. Two values describe the cat position:

| Value | Meaning |
|---|---|
| `BongoMenuPosXRel_h<hash>` | Horizontal center of the cat, relative to the window width (0 to 1) |
| `BongoMenuPosYRel_h<hash>` | Distance of the cat from the bottom edge, relative to the window height |

BongoCat writes both values right after the cat is dragged. The script finds them by name prefix, so the hash suffix is not hard-coded.

The script computes an anchor point from these values and the window rectangle:

```
X = WindowX + XRel * WindowWidth
Y = WindowY + WindowHeight - YRel * WindowHeight
```

The click points in `$POPUPS` are offsets from this anchor.

Unity stores these doubles as `REG_DWORD` entries with 8 bytes of data. `RegRead` returns only 4 of them. The script therefore reads the raw bytes with `RegQueryValueExW`.

## Usage

Start `BongoCatAutoClick.exe` or run the script with AutoIt:

```powershell
& "C:\Program Files (x86)\AutoIt3\AutoIt3_x64.exe" BongoCatAutoClick.au3
```

| Control | Function |
|---|---|
| Tray menu "Pause" / "Fortsetzen" | Stops or resumes the checks |
| Tray menu "Weggeklickt: N" | Shows the number of dismissed popups |
| Tray menu "Beenden" | Exits the script |
| `Ctrl+Alt+B` | Toggles pause |

Only one instance runs at a time. A second start exits immediately without a message.

## Customizing

All settings are constants at the top of `BongoCatAutoClick.au3`.

| Constant | Default | Meaning |
|---|---|---|
| `$POPUPS` | `[[-51, -32], [54, -32]]` | Click point of each bubble relative to the cat anchor |
| `$CHECK_OFFSETS` | four points | Check points relative to the click point |
| `$COLOR_BUBBLE` | `0xECEBEC` | Color of the bubble background |
| `$COLOR_TOLERANCE` | `16` | Allowed deviation per color channel |
| `$MIN_MATCHES` | `3` | Number of check points that must match |
| `$CHECK_INTERVAL_MS` | `1000` | Time between checks |
| `$CLICK_DELAY_MS` | `150` | Pause between move, press and release |
| `$HOTKEY_PAUSE` | `^!b` | Pause hotkey in AutoIt notation |

The offsets were measured at 100% scaling with `Scale` and `UiScale` set to 1 in BongoCat. Other scale settings change the bubble size and need new offsets.

### Points to check

- **Click points.** Use the AutoIt Window Info tool (`Au3Info_x64.exe`) to read the screen coordinates of the bubble centers. Subtract the cat anchor and enter the result in `$POPUPS`.
- **Check points must lie on the white background.** The icon inside the bubble changes with every reward. A check point on the icon matches one popup and misses the next. Take screenshots of several different popups and pick points that are white in all of them.
- **Counter check.** The check points must not be white when no bubble is shown. Compare against a screenshot without popups.
- **Flipped cat.** The offsets are untested with the BongoCat option `FLIP`. A mirrored cat may also mirror the bubbles.
- **Display scaling.** The script calls `SetProcessDPIAware` and works in physical pixels. Measure the coordinates in physical pixels too. Screenshot tools on a scaled display sometimes report scaled values.
- **Click delay.** Do not reduce `$CLICK_DELAY_MS` far below 150. In tests, Unity ignored clicks with 30 ms pauses.
- **Mouse movement.** The cursor jumps to the bubble for about half a second. An input at that moment lands on BongoCat.

## Building

Requirements:

- Windows
- [AutoIt v3](https://www.autoitscript.com/site/autoit/downloads/) (tested with 3.3.18.0). The installer includes the compiler `Aut2Exe` and the syntax checker `Au3Check`.
- Optional: the full SciTE4AutoIt3 editor package. It compiles with `F7`.

Syntax check:

```powershell
& "C:\Program Files (x86)\AutoIt3\Au3Check.exe" -q -d BongoCatAutoClick.au3
```

Build a 64-bit executable:

```powershell
& "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe_x64.exe" /in BongoCatAutoClick.au3 /out BongoCatAutoClick.exe /x64
```

Stop a running instance before you build. Aut2Exe cannot overwrite an executable that is in use. The repository does not contain the `.exe`. `.gitignore` excludes it.

## Files

| File | Content |
|---|---|
| `BongoCatAutoClick.au3` | The script |
| `README.md` | This file |
| `.gitignore` | Excludes the compiled `.exe` and local notes |
