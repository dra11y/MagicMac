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

    @AppStorage("speechRate") private var speechRate: Double = 100.0

    func applicationDidFinishLaunching(_: Notification) {
        setUpMenuBarItem()
    }

    private func setUpMenuBarItem() {
        let thickness = NSStatusBar.system.thickness
        let iconSize = NSSize(width: thickness, height: thickness)
        menuIcon?.size = iconSize

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem?.button?.image = menuIcon

        let menu = NSMenu()
        
        let sliderItem = NSMenuItem()
        let slider = NSSlider(value: speechRate, minValue: 100.0, maxValue: 300.0, target: self, action: #selector(sliderChanged))
        slider.frame.size.width = 200
        sliderItem.view = slider
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: ""))
        
        statusItem?.menu = menu
    }
    
    @objc private func sliderChanged(sender: NSSlider) {
        speechRate = sender.doubleValue
    }
    
    @objc private func openSettings() {
        let selector: Selector
        if #available(macOS 13, *) {
            selector = Selector(("showSettingsWindow:"))
        } else {
            selector = Selector(("showPreferencesWindow:"))
        }
        NSApp.sendAction(selector, to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

}

extension NSImage.Name {
    static let menuIcon = NSImage.Name("AppIcon")
}
