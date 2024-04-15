//
//  InvertedColorManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/25/23.
//

import Combine
import CoreGraphics
import SwiftUI

class InvertedColorManager: ObservableObject {
    @Published public var isInverted: Bool
    @AppStorage(.invertColorsDelay) var invertColorsDelay: Double = 0
    @AppStorage(.switchThemeDelay) var switchThemeDelay: Double = 0

    init() {
        isInverted = Self.getInvertedStatus()
    }
    
    private static func getInvertedStatus() -> Bool {
        guard let defaults = UserDefaults(suiteName: UserDefaults.Suite.universalAccess) else { return false }
        return defaults.bool(forKey: UserDefaults.UniversalAccess.whiteOnBlack)
    }
    
    private func syncDefaults(_ defaults: UserDefaults) {
        // `synchronize()` returns `true` if FDA (Full Disk Access) is granted, `false` otherwise.
        let result = defaults.synchronize()
        if !result {
            // https://stackoverflow.com/questions/52751941/how-to-launch-system-preferences-to-a-specific-preference-pane-using-bundle-iden
            guard
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
            else { return }
            NSWorkspace.shared.open(url)
        }
    }

    public func toggle(completion: ((Bool) -> Void)? = nil) {
        guard
            let defaults = UserDefaults(suiteName: UserDefaults.Suite.universalAccess)
        else { return }

        let newInverted = !isInverted

        /// UAWhiteOnBlackSetEnabled(bool) legacy API does not require setting the
        /// Universal Access default. However, there is a nasty "Invert Display Color off/on"
        /// popup that pre-setting this default to the desired value helps to alleviate.
        defaults.set(newInverted, forKey: UserDefaults.UniversalAccess.whiteOnBlack)
        print("defaults.set(\(newInverted), forKey: \(UserDefaults.UniversalAccess.whiteOnBlack))")

        syncDefaults(defaults)

        DispatchQueue.global().asyncAfter(deadline: .now() + switchThemeDelay) {
            SLSSetAppearanceThemeLegacy(!newInverted)
            print("SLSSetAppearanceThemeLegacy(\(!newInverted))")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + invertColorsDelay) {
            UAWhiteOnBlackSetEnabled(newInverted)
            print("UAWhiteOnBlackSetEnabled(\(newInverted))")
        }

        doSwitchTerminalTheme(newInverted)

        isInverted = newInverted

        if let completion = completion {
            completion(newInverted)
            print("completion(\(newInverted))")
        }
    }
}
