# MagicMac

## Fixing Apple's macOS Monterey/Ventura Accessibility Oversights

This app provides the following accessibility shortcuts which are not natively keyboard assignable:

1. Invert Colors + Switch Appearance simultaneously

2. Toggle "hover speech" (System Preferences -> Accessibility -> Spoken Content -> "Speak items under the pointer")

3. "Maximize" window (without going into full screen mode)

4. Increase/decrease "virtual" brightness by adjusting gamma (for external displays)

## Required Permissions

### System Preferences -> Security & Privacy

- Accessibility

- Full Disk Access - for setting com.apple.universalaccess user defaults within the app ("shared preference" entitlement does not work)

## Launcher

- This app installs a launcher app (MagicMacLauncher), which does not show up in Login Items (verify using `lsregister -dump | grep MagicMac`)
