//
//  MagicMacApp.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import SwiftUI
import KeyboardShortcuts
import Cocoa
import ServiceManagement

@main
final class MagicMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    private var observers = [NSObjectProtocol]()
    private let dimmer = DisplayDimmer()

    init() {
        setUpShortcuts()
        // setInitialAppearanceWhenUsingGamma()
        addObservers()
        terminateLauncher()
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 450, height: 350, alignment: .center)
        }
    }

    private func setUpShortcuts() {
        KeyboardShortcuts.onKeyDown(
            for: .invertColors,
            action: {
                doInvertPolarityUniversalAccess { isInverted in
                    self.dimmer.updateGamma()
                    if
                        let menuIcon = self.delegate.menuIcon,
                        let statusItem = self.delegate.statusItem
                    {
                        statusItem.button?.image = isInverted ? menuIcon.inverted() : menuIcon
                    }
                }
            })
        KeyboardShortcuts.onKeyDown(
            for: .hoverSpeech,
            action: toggleHoverSpeech)
        KeyboardShortcuts.onKeyDown(
            for: .maximizeFrontWindow,
            action: doMaximizeFrontWindow)
        KeyboardShortcuts.onKeyDown(
            for: .increaseBrightness,
            action: dimmer.increase)
        KeyboardShortcuts.onKeyDown(
            for: .decreaseBrightness,
            action: dimmer.decrease)
    }
    
    private func addObservers() {
        observers.append(
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                // setShutdownAppearance()
            }
        )
        observers.append(terminalLaunchObserver())
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
