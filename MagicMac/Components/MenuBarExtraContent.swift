//
//  MenuBarExtraContent.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

@available(macOS 14.0, *)
struct MenuExtraMenuContent: View {
    @Environment(\.openSettings) private var openSettings
    @AppStorage(.speechRate) var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) var speechVoice: String = UserDefaults.UniversalAccess.preferredVoice ?? ""
    @AppStorage(.enableReplacements) var enableReplacements: Bool = true
    @AppStorage(.debugSpeechHUD) private var debugSpeechHUD: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Slider(value: $speechRate) {
                Text("Rate")
            }
            Slider(value: $slowSpeechRate) {
                Text("Slow Rate")
            }
            Slider(value: $speechVolume) {
                Text("Volume")
            }

            VoicePicker("Voice", selection: $speechVoice)
                .id(speechVoice)

            HStack {
                Text("Substitutions")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Toggle("", isOn: $enableReplacements)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack {
                Text("Debug Speech HUD")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Toggle("", isOn: $debugSpeechHUD)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                }

                Spacer()

                Button("Settings") {
                    for window in NSApplication.shared.windows {
                        if window.level == NSWindow.Level.popUpMenu {
                            window.close()
                            break
                        }
                    }

                    try? openSettings()
                }
            }
        }
        .scenePadding()
    }
}
