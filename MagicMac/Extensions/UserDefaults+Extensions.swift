//
//  UserDefaults+Extensions.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import AVFoundation

enum StorageKeys: String, CaseIterable {
    case speechRate
    case slowSpeechRate
    case speechVolume
    case speechVoice
    case enableReplacements
    case invertColorsDelay
    case switchThemeDelay
    case debugSpeechHUD
}

extension String {
    static let speechRate = StorageKeys.speechRate.rawValue
    static let slowSpeechRate = StorageKeys.slowSpeechRate.rawValue
    static let speechVolume = StorageKeys.speechVolume.rawValue
    static let speechVoice = StorageKeys.speechVoice.rawValue
    static let enableReplacements = StorageKeys.enableReplacements.rawValue
    static let invertColorsDelay = StorageKeys.invertColorsDelay.rawValue
    static let switchThemeDelay = StorageKeys.switchThemeDelay.rawValue
    static let debugSpeechHUD = StorageKeys.debugSpeechHUD.rawValue
}

extension UserDefaults {
    enum Suite {
        static let universalAccess = "com.apple.universalaccess"
    }

    enum UniversalAccess {
        static let whiteOnBlack = "whiteOnBlack"
        static let spokenContentPreferredVoiceForLanguage = "spokenContentPreferredVoiceForLanguage"
        static let spokenContentSpeakingRateForVoice = "spokenContentSpeakingRateForVoice"
        static let spokenContentSpeakingVolumeForVoice = "spokenContentSpeakingVolumeForVoice"

        static var defaults: UserDefaults? {
            UserDefaults(suiteName: UserDefaults.Suite.universalAccess)
        }

        static var preferredVoice: String? {
            guard
                let languageCode = Locale.current.language.languageCode?.identifier,
                let preferredVoiceDict = defaults?.dictionary(forKey: UserDefaults.UniversalAccess.spokenContentPreferredVoiceForLanguage),
                let preferredVoice = preferredVoiceDict[languageCode] as? String
            else { return nil }

            return preferredVoice
        }

        static var preferredVoiceName: String {
            guard let preferredVoice = preferredVoice else { return "" }
            return AVSpeechSynthesisVoice.voices[preferredVoice] ?? ""
        }

        static let defaultRate: Double = 0.5

        static var preferredSlowRate: Double {
            preferredRate / 2
        }

        static var preferredRate: Double {
            guard
                let voice = preferredVoice,
                let defaults
            else { return defaultRate }

            guard
                let rateDict = defaults.dictionary(forKey: UserDefaults.UniversalAccess.spokenContentSpeakingRateForVoice),
                let rawRate = rateDict[voice] as? Double
            else { return defaultRate }

            return (rawRate - 50.0) / 250.0
        }

        static let defaultVolume: Double = 1.0

        static var preferredVolume: Double {
            guard
                let voice = preferredVoice,
                let defaults
            else { return defaultVolume }

            guard
                let volumeDict = defaults.dictionary(forKey: UserDefaults.UniversalAccess.spokenContentSpeakingVolumeForVoice),
                let volume = volumeDict[voice] as? Double
            else { return defaultVolume }

            return volume
        }
    }
}
