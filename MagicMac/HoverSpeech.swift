//
//  HoverSpeech.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/13/22.
//

import Cocoa

// https://developer.apple.com/forums/thread/114452
func toggleHoverSpeech() {
    guard
        let defaults = UserDefaults(suiteName: "com.apple.universalaccess")
    else { return }

    let key = "speakItemUnderMouseEnabled"

    let isEnabled = !defaults.bool(forKey: key)
    isEnabled ? defaults.set(true, forKey: key) : defaults.removeObject(forKey: key)
    
    // `synchronize()` returns `true` if FDA (Full Disk Access) is granted, `false` otherwise.
    let result = defaults.synchronize()
    if !result {
        // https://stackoverflow.com/questions/52751941/how-to-launch-system-preferences-to-a-specific-preference-pane-using-bundle-iden
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        else { return }
        NSWorkspace.shared.open(url)
        return
    }
    
    guard let sound = NSSound(named: isEnabled ? .blow : .frog) else { return }
    sound.stop()
    sound.play()
}
