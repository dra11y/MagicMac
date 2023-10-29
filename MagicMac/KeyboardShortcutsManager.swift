//
//  KeyboardShortcutsManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/26/23.
//

import KeyboardShortcuts
import SwiftUI

class KeyboardShortcutsManager: ObservableObject {
    let invertedColorManager: InvertedColorManager
    let dimmer: DisplayDimmer

    init(invertedColorManager: InvertedColorManager, dimmer: DisplayDimmer) {
        self.invertedColorManager = invertedColorManager
        self.dimmer = dimmer
    }

    public func enableShortcuts() {
        KeyboardShortcuts.onKeyDown(
            for: .toggleAppearance) {
            doToggleAppearance()
        }
        KeyboardShortcuts.onKeyDown(
            for: .invertColors) { [weak self] in
            guard let self else { return }
            invertedColorManager.toggle { _ in
                self.dimmer.updateGamma()
            }
        }
        KeyboardShortcuts.onKeyDown(
            for: .hoverSpeech,
            action: toggleHoverSpeech
        )
        KeyboardShortcuts.onKeyDown(
            for: .maximizeFrontWindow,
            action: doMaximizeFrontWindow
        )
        KeyboardShortcuts.onKeyDown(
            for: .increaseBrightness,
            action: dimmer.increase
        )
        KeyboardShortcuts.onKeyDown(
            for: .decreaseBrightness,
            action: dimmer.decrease
        )
        KeyboardShortcuts.onKeyDown(
            for: .speakSelection,
            action: SpeechManager.shared.speakSelection
        )
        KeyboardShortcuts.onKeyDown(
            for: .speakSelectionSlowly,
            action: SpeechManager.shared.speakSelectionSlowly
        )
    }
}
