//
//  MagicMacApp.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import Cocoa
import ServiceManagement
import SwiftUI
import SettingsAccess
import AVFoundation


extension NSImage.Name {
    static let menuExtra = NSImage.Name("MenuExtra")
    static let menuExtraInverted = NSImage.Name("MenuExtraInverted")
}


@available(macOS 14.0, *)
struct MenuBarExtraIconView: View {
    @EnvironmentObject var invertedColorManager: InvertedColorManager

    var body: some View {
        Image(invertedColorManager.isInverted ? .menuExtraInverted : .menuExtra)
    }
}

enum StorageKeys: String, CaseIterable {
    case speechRate
    case slowSpeechRate
    case speechVolume
    case speechVoice
}

extension String {
    static let speechRate = StorageKeys.speechRate.rawValue
    static let slowSpeechRate = StorageKeys.slowSpeechRate.rawValue
    static let speechVolume = StorageKeys.speechVolume.rawValue
    static let speechVoice = StorageKeys.speechVoice.rawValue
}

extension UserDefaults {
    struct Suite {
        static let universalAccess = "com.apple.universalaccess"
    }
    
    struct UniversalAccess {
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
        
        static let defaultRate: Double = 0.5
        
        static var preferredSlowRate: Double {
            preferredRate / 2
        }
        
        static var preferredRate: Double {
            guard
                let voice = preferredVoice,
                let defaults = defaults
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
                let defaults = defaults
            else { return defaultVolume }
            
            guard
                let volumeDict = defaults.dictionary(forKey: UserDefaults.UniversalAccess.spokenContentSpeakingVolumeForVoice),
                let volume = volumeDict[voice] as? Double
            else { return defaultVolume }
            
            return volume
        }
    }
}

extension AVSpeechSynthesisVoice {
    static var voiceIdentifiers: [String] = Array(
        voices.sorted { $0.value < $1.value }.map { $0.key }
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


@available(macOS 14.0, *)
struct MenuExtraMenuContent: View {
    @Environment(\.openSettings) private var openSettings
    @AppStorage(.speechRate) var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) var speechVoice: String = UserDefaults.UniversalAccess.preferredVoice ?? ""

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

            Picker("Speech Voice", selection: $speechVoice) {
                ForEach(AVSpeechSynthesisVoice.voiceIdentifiers, id: \.self) { id in
                    Text(AVSpeechSynthesisVoice.voices[id]!).tag(id)
                }
            }
            .id(speechVoice)

            
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

@main
final class MagicMacApp: App {
    let invertedColorManager = InvertedColorManager()

    private var observers = [NSObjectProtocol]()
    private let dimmer = DisplayDimmer()

    lazy var keyboardShortcutsManager: KeyboardShortcutsManager = {
        KeyboardShortcutsManager(invertedColorManager: invertedColorManager, dimmer: dimmer)
    }()

    init() {
        keyboardShortcutsManager.enableShortcuts()
        // setInitialAppearanceWhenUsingGamma()
        addObservers()
        terminateLauncher()
    }
    
    var body: some Scene {
        @State var imageName: NSImage.Name = .menuExtra
        
        Settings {
            SettingsView()
                .environmentObject(keyboardShortcutsManager)
                .frame(alignment: .center)
        }
        
        
        if #available(macOS 14.0, *) {
            MenuBarExtra {
                MenuExtraMenuContent()
                    .openSettingsAccess()
            } label: {
                MenuBarExtraIconView()
                    .environmentObject(invertedColorManager)
            }
            .menuBarExtraStyle(.window)
        }
        
    }


    private func addObservers() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil, queue: .main
            ) { _ in
                // setShutdownAppearance()
            }
        )
        observers.append(terminalLaunchObserver())
        observers.append(terminalNewWindowObserver())
    }

    private func terminateLauncher() {
        let launcherAppId = "com.dra11y.MagicMacLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        let result = SMLoginItemSetEnabled(launcherAppId as CFString, true)

        if !result {
            fatalError("Could not add login item.")
        }

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }
}

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}
