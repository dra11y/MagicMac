//
//  KeyboardShortcuts.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name: CaseIterable {
    public static var allCases: [KeyboardShortcuts.Name] {
        [
            toggleAppearance,
            invertColors,
            hoverSpeech,
            maximizeFrontWindow,
            increaseBrightness,
            decreaseBrightness,
            speakSelection,
            speakSelectionSlowly,
        ]
    }
    
    static let toggleAppearance = Self("toggleAppearance")
    static let invertColors = Self("invertColors")
    static let hoverSpeech = Self("hoverSpeech")
    static let maximizeFrontWindow = Self("maximizeFrontWindow")
    static let increaseBrightness = Self("increaseBrightness")
    static let decreaseBrightness = Self("decreaseBrightness")
    static let speakSelection = Self("speakSelection")
    static let speakSelectionSlowly = Self("speakSelectionSlowly")
}
