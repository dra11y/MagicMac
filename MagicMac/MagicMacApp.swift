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


@available(macOS 14.0, *)
struct MenuExtraMenuContent: View {
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        @AppStorage("speechRate") var speechRate: Double = 100.0
        @AppStorage("speechVolume") var speechVolume: Double = 1.0
        
        VStack(spacing: 20) {
            Slider(value: $speechRate) {
                Text("Rate")
            }
            Slider(value: $speechVolume) {
                Text("Volume")
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
                        // print("window level = \(window.level), window = \(window)")
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
