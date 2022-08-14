//
//  ColorInverter.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import Foundation

/*
func getCurrentPolarity() -> (Bool, [CGGammaValue]) {
    
    let tableSize = 2
    var redTable = [CGGammaValue](repeating: 0, count: tableSize)
    var greenTable = [CGGammaValue](repeating: 0, count: tableSize)
    var blueTable = [CGGammaValue](repeating: 0, count: tableSize)
    var sampleCount: UInt32 = .zero
    
    CGGetDisplayTransferByTable(CGMainDisplayID(), UInt32(tableSize), &redTable, &greenTable, &blueTable, &sampleCount)
    
    let isInverted = redTable.first == 1

    return (isInverted, greenTable)
}

func setInitialAppearanceWhenUsingGamma() {
    let (isInverted, _) = getCurrentPolarity()
    SLSSetAppearanceThemeLegacy(!isInverted)
}

func setShutdownAppearance() {
    let isWhiteOnBlack = UAWhiteOnBlackIsEnabled()
    SLSSetAppearanceThemeLegacy(!isWhiteOnBlack)
}

func doInvertPolarityGammaTable() {
    let (wasInverted, greenTable) = getCurrentPolarity()
    
    let isWhiteOnBlack = UAWhiteOnBlackIsEnabled()

    let isInverted = (wasInverted && isWhiteOnBlack) || (!wasInverted && !isWhiteOnBlack)
    
    let newTable = greenTable.map { 1 - $0 }
    
    SLSSetAppearanceThemeLegacy(!isInverted)
    
    let delay = isInverted ? 0.12 : 0.08
    
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        CGSetDisplayTransferByTable(CGMainDisplayID(), UInt32(newTable.count), newTable, newTable, newTable)
    }
}
*/

func doInvertPolarityUniversalAccess(completion: (() -> Void)? = nil) {
    guard
        let defaults = UserDefaults(suiteName: "com.apple.universalaccess")
    else { return }

    let key = "whiteOnBlack"

    let isEnabled = !defaults.bool(forKey: key)
    defaults.set(isEnabled, forKey: key)
    
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
    
    // But setting the pref doesn't change it, so use the legacy API.
    // A nice side effect is that the popup does not seem to show anymore.
    UAWhiteOnBlackSetEnabled(isEnabled)
    SLSSetAppearanceThemeLegacy(!isEnabled)

    completion?()
}
