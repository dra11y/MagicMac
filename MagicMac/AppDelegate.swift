//
//  AppDelegate.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/14/22.
//

import SwiftUI

class MenuSlider: NSSlider {
    private var onChanged: ((Double) -> Void)?

    public convenience init(value: Double, minValue: Double, maxValue: Double, onChanged: @escaping (Double) -> Void) {
        self.init(value: value, minValue: minValue, maxValue: maxValue, target: nil, action: nil)
        self.onChanged = onChanged
    }

    override var action: Selector? {
        get { nil }
        set { }
    }
    
    override var target: AnyObject? {
        get { nil }
        set { }
    }
    
    /// This is effectively a mouseUp when in an NSMenu.
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onChanged?(doubleValue)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let menuIcon = NSImage(named: .menuIcon)

    @AppStorage("speechRate") private var speechRate: Double = 100.0

    @AppStorage("speechVolume") private var speechVolume: Double = 1.0

    func applicationDidFinishLaunching(_: Notification) {
        setUpMenuBarItem()
    }
    
    func createSliderItem(labelText: String, sliderValue: Double, minValue: Double, maxValue: Double, onChange: @escaping (Double) -> Void) -> NSMenuItem {
        let menuItem = NSMenuItem()
        
        let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        
        let padding: CGFloat = 10.0
        
        let itemLabel = NSTextField(labelWithString: labelText)
        itemLabel.frame = NSRect(x: padding, y: 25, width: 200 - 2 * padding, height: 20)
        
        let itemSlider = MenuSlider(value: sliderValue, minValue: minValue, maxValue: maxValue, onChanged: onChange)
        itemSlider.frame = NSRect(x: padding, y: 0, width: 200 - 2 * padding, height: 30)
        
        itemView.addSubview(itemLabel)
        itemView.addSubview(itemSlider)
        
        menuItem.view = itemView
        
        return menuItem
    }

    
    private func setUpMenuBarItem() {
        let thickness = NSStatusBar.system.thickness
        let iconSize = NSSize(width: thickness, height: thickness)
        menuIcon?.size = iconSize

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem?.button?.image = menuIcon

        let menu = NSMenu()
        
        let rateItem = createSliderItem(
            labelText: "Rate:",
            sliderValue: speechRate,
            minValue: 100.0,
            maxValue: 300.0
        ) { [weak self] value in
            menu.cancelTracking()
            self?.speechRate = value
        }
        menu.addItem(rateItem)

        let volumeItem = createSliderItem(
            labelText: "Volume:",
            sliderValue: speechVolume,
            minValue: 0.0,
            maxValue: 1.0
        ) { [weak self] value in
            menu.cancelTracking()
            self?.speechVolume = value
        }
        menu.addItem(volumeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: ""))
        
        statusItem?.menu = menu
    }
    
    @objc private func rateChanged(sender: NSSlider) {
        speechRate = sender.doubleValue
    }
    
    @objc private func volumeChanged(sender: NSSlider) {
        speechVolume = sender.doubleValue
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
