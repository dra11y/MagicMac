//
//  KeyboardShortcuts+Extensions.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
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
            togglePartialScreenRecording,
            toggleFullScreenRecording,
            zoomShareScreen,
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
    static let togglePartialScreenRecording = Self("togglePartialScreenRecording")
    static let toggleFullScreenRecording = Self("toggleFullScreenRecording")
    static let zoomShareScreen = Self("zoomShareScreen")

    var displayName: String {
        rawValue.sentenceCased
    }
}
