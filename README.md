# UASwitcher

Place `icon.ico` in the same folder as `UaSwitcher.ahk`. The script uses it
for the tray and desktop/startup shortcuts when present; compiled builds also
use it as their main icon. If the file is absent, the tray uses AutoHotkey's
default icon and shortcuts use the script or executable icon.

On launch, the script creates `UASwitcherPro.lnk` on the desktop and in the
user's Startup folder, and applies the icon to those shortcuts. Right-clicking
the tray icon opens the menu with Settings, Open Log, and Exit.