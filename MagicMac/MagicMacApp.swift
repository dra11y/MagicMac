//
//  MagicMacApp.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import AVFoundation
import Cocoa
import OSLog
import ServiceManagement
import SwiftUI
import WakeAudio

@main
struct MagicMacApp: App {
    @ObservedObject private var appState = MagicMacAppState()

    var body: some Scene {
        @State var imageName: NSImage.Name = .menuExtra
        
        MenuBarExtra {
            MenuExtraMenuContent()
        } label: {
            MenuBarExtraIconView()
                .environmentObject(appState.invertedColorManager)
                .environmentObject(appState.speechManager)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(appState.keyboardShortcutsManager)
                .frame(alignment: .center)
        }

    }

    init() {
        // Initialize shortcuts and observers here.
        addObservers()
        terminateLauncher()
        SpeechManager.wakeAudio()
        appState.mouseBatteryWarnTimer.fire()
    }

    private func addObservers() {
        appState.observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil, queue: .main
            ) { _ in
                // setShutdownAppearance()
            }
        )
        appState.observers.append(terminalLaunchObserver())
        appState.observers.append(terminalNewWindowObserver())
    }

    private func terminateLauncher() {
        let launcherAppId: String = "com.dra11y.MagicMacLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        let service = SMAppService.loginItem(identifier: launcherAppId)
        do {
            try service.register()
        } catch {
            fatalError("Failed to add login item: \(error)")
        }

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }
}
