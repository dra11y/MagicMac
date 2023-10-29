//
//  AVSpeechSynthesisVoice+Extensions.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import AVFoundation

extension AVSpeechSynthesisVoice {
    static var voiceIdentifiers: [String] = Array(
        voices.sorted { $0.value < $1.value }.map(\.key)
    )

    static var voices: [String: String] =
        Dictionary(
            uniqueKeysWithValues:
                AVSpeechSynthesisVoice.speechVoices()
                .filter {
                    $0.language.split(separator: "-").first ?? "" == Locale.current.language.languageCode?.identifier ?? ""
                }
                .map { ($0.identifier, "\($0.name) (\($0.language))") }
        )
}
