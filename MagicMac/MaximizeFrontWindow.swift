//
//  MaximizeFrontWindow.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/13/22.
//

import AppKit
import ApplicationServices
import AXSwift
import Cocoa

// Getting Window Number through OSX Accessibility API
// https://stackoverflow.com/questions/6178860/getting-window-number-through-osx-accessibility-api

func doMaximizeFrontWindow() {
    trustForAccessibility()
    guard
        let frontmostProcessID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    else { return }
    let frontApp = AXUIElementCreateApplication(frontmostProcessID)
    var frontWindow: CFTypeRef?

    AXUIElementCopyAttributeValue(frontApp, kAXFocusedWindowAttribute as CFString, &frontWindow)
    guard let frontWindow else { return }
    let axWindow = frontWindow as! AXUIElement

    var subrole: CFTypeRef?
    AXUIElementCopyAttributeValue(axWindow, kAXSubroleAttribute as CFString, &subrole)
    guard let subrole = subrole as? String else { return }
    if subrole != kAXStandardWindowSubrole { return }

    var windowID: CGWindowID = .zero
    _AXUIElementGetWindow(axWindow, &windowID)

    guard
        windowID != 0,
        let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[CFString: Any]],
        let window = windows.first,
        let boundsDict = window[kCGWindowBounds],
        let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary),
        let owningScreen = NSScreen.screens.max(by: { screen1, screen2 in
            let area1 = screen1.frame.intersection(bounds).area
            let area2 = screen2.frame.intersection(bounds).area
            return area1 < area2
        })
    else { return }

    var origin = owningScreen.visibleFrame.origin
    var size = owningScreen.visibleFrame.size

    guard
        let originValue = AXValueCreate(.cgPoint, &origin),
        let sizeValue = AXValueCreate(.cgSize, &size)
    else { return }

    var lastBounds = CGRect.zero
    var repeated = 0
    DispatchQueue.main.async {
        for _ in 1 ..< 100 {
            if repeated > 7 { break }
            Thread.sleep(forTimeInterval: 0.005)
            var theBounds = CGRect.zero
            SLSGetWindowBounds(SLSMainConnectionID(), windowID, &theBounds)
            if theBounds != lastBounds {
                repeated = 0
                lastBounds = theBounds
            }
            repeated += 1
        }

        AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
    }

    AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, originValue)
}

extension CGRect {
    var area: CGFloat {
        width * height
    }
}
