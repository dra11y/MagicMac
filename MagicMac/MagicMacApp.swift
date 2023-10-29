//
//  MagicMacApp.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import AVFoundation
import Cocoa
import ServiceManagement
import SettingsAccess
import SwiftUI

@main
final class MagicMacApp: App {
    let invertedColorManager = InvertedColorManager()

    private var observers = [NSObjectProtocol]()
    private let dimmer = DisplayDimmer()

    lazy var keyboardShortcutsManager: KeyboardShortcutsManager = .init(invertedColorManager: invertedColorManager, dimmer: dimmer)

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
