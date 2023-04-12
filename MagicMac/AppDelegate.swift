//
//  AppDelegate.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/14/22.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let menuIcon = NSImage(named: .menuIcon)

    func applicationDidFinishLaunching(_: Notification) {
        setUpMenuBarItem()
    }

    private func setUpMenuBarItem() {
        let thickness = NSStatusBar.system.thickness
        let iconSize = NSSize(width: thickness, height: thickness)
        menuIcon?.size = iconSize

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(doMenu)
            button.sendAction(on: [.leftMouseDown, .rightMouseUp])
            button.image = menuIcon
        }
    }

    // https://stackoverflow.com/questions/65355696/how-to-programatically-open-settings-window-in-a-macos-swiftui-app
    @objc private func doMenu(sender _: NSStatusItem) {
        if let window = NSApp.mainWindow, window.isVisible {
            window.close()
            return
        }
        let selector: Selector
        if #available(macOS 13, *) {
            selector = Selector(("showSettingsWindow:"))
        } else {
            selector = Selector(("showPreferencesWindow:"))
        }
        NSApp.sendAction(selector, to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension NSImage.Name {
    static let menuIcon = NSImage.Name("AppIcon")
}
