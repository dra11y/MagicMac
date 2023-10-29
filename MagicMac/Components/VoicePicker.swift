//
//  VoicePicker.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI
import AVFoundation

struct VoicePicker: View {
    var label: String?
    @Binding var speechVoice: String
    var systemDefaultLabel: String

    public init(_ label: String?, selection speechVoice: Binding<String>, systemDefaultLabel: String = "Default: ") {
        self.label = label
        self._speechVoice = speechVoice
        self.systemDefaultLabel = systemDefaultLabel
    }

    var body: some View {
        Picker(selection: $speechVoice) {
            Text("\(systemDefaultLabel)\(UserDefaults.UniversalAccess.preferredVoiceName)").tag("")
            Divider()
            ForEach(AVSpeechSynthesisVoice.voiceIdentifiers, id: \.self) { id in
                Text(AVSpeechSynthesisVoice.voices[id]!).tag(id)
            }
        } label: {
            if let label = label {
                Text(label)
            }
        }
    }
}
