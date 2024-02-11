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
    let speechManager: SpeechManager
    let dimmer: DisplayDimmer

    init(invertedColorManager: InvertedColorManager, speechManager: SpeechManager, dimmer: DisplayDimmer) {
        self.invertedColorManager = invertedColorManager
        self.speechManager = speechManager
        self.dimmer = dimmer
    }

    public func enableShortcuts() {
        KeyboardShortcuts.onKeyDown(
            for: .toggleAppearance)
        {
            doToggleAppearance()
        }
        KeyboardShortcuts.onKeyDown(
            for: .invertColors)
        { [weak self] in
            guard let self else { return }
            invertedColorManager.toggle { _ in
                print("Should update dimmer due to inverted color")
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
            action: speechManager.speakSelection
        )
        KeyboardShortcuts.onKeyDown(
            for: .speakSelectionSlowly,
            action: speechManager.speakSelectionSlowly
        )
    }
}
