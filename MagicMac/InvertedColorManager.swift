//
//  InvertedColorManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/25/23.
//

import Combine
import SwiftUI

class InvertedColorManager: ObservableObject {
    @Published public var isInverted: Bool = false

    init() {
        self.isInverted = getInvertedStatus()
    }

    private func getInvertedStatus() -> Bool {
        guard let defaults = UserDefaults(suiteName: UserDefaults.Suite.universalAccess) else { return false }
        return defaults.bool(forKey: UserDefaults.UniversalAccess.whiteOnBlack)
    }

    public func toggle(completion: ((Bool) -> Void)? = nil) {
        guard
            let defaults = UserDefaults(suiteName: UserDefaults.Suite.universalAccess)
        else { return }
        
        let newInverted = !isInverted
        
        defaults.set(newInverted, forKey: UserDefaults.UniversalAccess.whiteOnBlack)

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

        SLSSetAppearanceThemeLegacy(!newInverted)

        let delay = newInverted ? 0.13 : 0.13

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            // But setting the pref doesn't change it, so use the legacy API.
            // A nice side effect is that the popup does not seem to show anymore.
            UAWhiteOnBlackSetEnabled(newInverted)

            doSwitchTerminalTheme(newInverted)

            self?.isInverted = newInverted

            completion?(newInverted)
        }
    }

}
