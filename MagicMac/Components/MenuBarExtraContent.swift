//
//  MenuBarExtraContent.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import AVFoundation
import SettingsAccess
import SwiftUI
import WakeAudio

@available(macOS 14.0, *)
struct MenuExtraMenuContent: View {
    @AppStorage(.speechRate) var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) var speechVoice: String = UserDefaults.UniversalAccess.preferredVoice ?? ""
    @AppStorage(.enableReplacements) var enableReplacements: Bool = true
    @AppStorage(.debugSpeechHUD) private var debugSpeechHUD: Bool = false

    @State private var mouseBatteryLevel: Int?
    let mouseBatteryDisplayTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
                Text("Mouse Battery Level")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("\(mouseBatteryLevel ?? 0)%")
                    .frame(alignment: .trailing)
            }
            .onAppear(perform: fetchMouseBatteryLevel)
            .onReceive(mouseBatteryDisplayTimer) { _ in
                fetchMouseBatteryLevel()
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
                SettingsLink {
                    Text("Settings")
                } preAction: {
                    NSApp.activate(ignoringOtherApps: true)
                } postAction: {
                    for window in NSApplication.shared.windows {
                        if window.level == NSWindow.Level.popUpMenu {
                            window.close()
                            break
                        }
                    }
                }

                Spacer()

                Button {
                    wakeAudioInterfaces(true)
                } label: {
                    Text("Reset Audio")
                }

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                }
            }
        }
        .scenePadding()
    }

    private func fetchMouseBatteryLevel() {
        mouseBatteryLevel = getMouseBatteryLevel()
    }
}
