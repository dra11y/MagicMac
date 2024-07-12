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

enum BatteryKind {
    case mouse
    case keyboard
}

struct BatteryView: View {
    let value: Int
    let isPresent: Bool
    let batteryPercent: BatteryPercent
    let kind: BatteryKind
    
    init(kind: BatteryKind, value: Int? = nil) {
        self.kind = kind
        self.isPresent = value != nil
        self.value = max(0, min((value ?? 0), 100))
        switch self.value {
        case 90...100:self.batteryPercent = .battery100
        case 65..<90: self.batteryPercent = .battery75
        case 40..<65: self.batteryPercent = .battery50
        case 15..<40: self.batteryPercent = .battery25
        default: self.batteryPercent = .battery0
        }
    }
    
    enum BatteryPercent {
        case battery0
        case battery25
        case battery50
        case battery75
        case battery100
        
        var systemName: String {
            switch self {
            case .battery0: "battery.0percent"
            case .battery25: "battery.25percent"
            case .battery50: "battery.50percent"
            case .battery75: "battery.75percent"
            case .battery100: "battery.100percent"
            }
        }
        
        var batteryColor: Color {
            switch self {
            case .battery0: .red
            case .battery25: .red
            case .battery50: .orange
            case .battery75: .yellow
            case .battery100: .green
            }
        }
        
        var textColor: Color {
            switch self {
            case .battery0: .white
            case .battery25: .white
            case .battery50: .white
            case .battery75: .black
            case .battery100: .black
            }
        }
    }
    
    var iconName: String {
        switch kind {
        case .mouse: "magicmouse.fill"
        case .keyboard: "keyboard.fill"
        }
    }
    
    var body: some View {
        HStack {
            if isPresent {
                ZStack {
                    Image(systemName: batteryPercent.systemName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(batteryPercent.batteryColor)
                        .frame(height: 30)
                    Text("\(value)%")
                        .foregroundStyle(batteryPercent.textColor)
                        .font(.system(size: 15, weight: .bold))
                        .offset(x: -4, y: -1)
                }
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
            }
        }
    }
}

struct MenuExtraMenuContent: View {
    @AppStorage(.speechRate) var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) var speechVoice: String = UserDefaults.UniversalAccess.preferredVoice ?? ""
    @AppStorage(.enableReplacements) var enableReplacements: Bool = true
    @AppStorage(.debugSpeechHUD) private var debugSpeechHUD: Bool = false

    @State private var mouseBatteryLevel: Int?
    @State private var keyboardBatteryLevel: Int?
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
                BatteryView(kind: .mouse, value: mouseBatteryLevel)
                Spacer()
                BatteryView(kind: .keyboard, value: keyboardBatteryLevel)
            }
            .onAppear(perform: fetchBatteryLevels)
            .onReceive(mouseBatteryDisplayTimer) { _ in
                fetchBatteryLevels()
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
                    wakeAudioInterfaces()
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

    private func fetchBatteryLevels() {
        (mouse: mouseBatteryLevel, keyboard: keyboardBatteryLevel) = getBatteryLevels()
    }
}
