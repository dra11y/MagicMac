//
//  SpeechTab.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

struct SpeechTab: View {
    @AppStorage(.speechRate) private var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) private var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) private var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) private var speechVoice: String = ""
    @AppStorage(.enableReplacements) private var enableReplacements: Bool = true

    var body: some View {
        Form {
            VStack(spacing: 20) {
                CustomGroupBox(label: "Speech Rate", resetAction: { speechRate = UserDefaults.UniversalAccess.preferredRate }) {
                    Slider(value: $speechRate)
                    Text(speechRate.displayPercent())
                }

                CustomGroupBox(label: "Slow Speech Rate", resetAction: { slowSpeechRate = UserDefaults.UniversalAccess.preferredSlowRate }) {
                    Slider(value: $slowSpeechRate)
                    Text(slowSpeechRate.displayPercent())
                }

                HStack {
                    CustomGroupBox(label: "Speech Volume", resetAction: { speechVolume = UserDefaults.UniversalAccess.preferredVolume }) {
                        Slider(value: $speechVolume)
                        Text(speechVolume.displayPercent())
                    }

                    CustomGroupBox(label: "Substitutions") {
                        Toggle("Enabled", isOn: $enableReplacements)
                            .toggleStyle(.switch)
                    }
                }

                CustomGroupBox(label: "Speech Voice", resetAction: { speechVoice = "" }) {
                    VoicePicker(nil, selection: $speechVoice)
                }
            }
        }
        .scenePadding()
        .tabItem {
            Image(systemName: "speaker.wave.3")
            Text("Speech")
        }
    }
}
