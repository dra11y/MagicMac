//
//  MagicMacApp.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import AVFoundation
import Cocoa
import ServiceManagement
import SwiftUI
import WakeAudio

@main
final class MagicMacApp: App {
    let invertedColorManager = InvertedColorManager()

    lazy var speechManager = SpeechManager(invertedColorManager: invertedColorManager)

    private var observers = [NSObjectProtocol]()
    private let dimmer = DisplayDimmer()

    @AppStorage(.speechRate) var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.speechVolume) var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) var speechVoice: String = UserDefaults.UniversalAccess.preferredVoice ?? ""

    lazy var keyboardShortcutsManager = KeyboardShortcutsManager(
        invertedColorManager: invertedColorManager,
        speechManager: speechManager,
        dimmer: dimmer
    )

    private lazy var mouseBatteryWarnTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
        self?.warnMouseBatteryLevel()
    }

    private lazy var synth = AVSpeechSynthesizer()

    private func warnMouseBatteryLevel() {
        if let percent = getMouseBatteryLevel(),
           percent < 50
        {
            print("WARN MOUSE BATTERY \(percent) \(synth.debugDescription)")
            let speechString = "Mouse battery at \(percent) percent."
            let utterance = AVSpeechUtterance(string: speechString)
            utterance.rate = Float(speechRate)
            utterance.volume = Float(speechVolume)
            if !speechVoice.isEmpty {
                utterance.voice = AVSpeechSynthesisVoice(identifier: speechVoice)
            }
            DispatchQueue.main.async { [weak self] in
                self?.synth.speak(utterance)
            }
        }
    }

    init() {
        keyboardShortcutsManager.enableShortcuts()
        // setInitialAppearanceWhenUsingGamma()
        addObservers()
        terminateLauncher()
        SpeechManager.wakeAudio()
        mouseBatteryWarnTimer.fire()
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
            } label: {
                MenuBarExtraIconView()
                    .environmentObject(invertedColorManager)
                    .environmentObject(speechManager)
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

        let service = SMAppService.loginItem(identifier: launcherAppId)
        do {
            try service.register()
        } catch {
            fatalError("Could not add login item.")
        }

//        let result = SMLoginItemSetEnabled(launcherAppId as CFString, true)

//        if !result {
//            fatalError("Could not add login item.")
//        }

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }
}
