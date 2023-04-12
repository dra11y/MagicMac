//
//  AppDelegate.swift
//  MagicMacLauncher
//
//  Created by Tom Grushka on 8/13/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @objc func terminate() {
        NSApp.terminate(nil)
    }

    // TUTORIAL: How to launch a macOS app at login?
    // https://theswiftdev.com/how-to-launch-a-macos-app-at-login/
    func applicationDidFinishLaunching(_: Notification) {
        let bundleID = "com.dra11y.MagicMac"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == bundleID }.isEmpty

        if isRunning {
            terminate()
            return
        }

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(terminate), name: .killLauncher, object: bundleID)

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { fatalError("cannot find main app url!") }

        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}
