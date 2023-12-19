//
//  PolarityInverter.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import Carbon
import Cocoa

/*
 func getCurrentPolarity() -> (Bool, [CGGammaValue]) {

 let tableSize = 2
 var redTable = [CGGammaValue](repeating: 0, count: tableSize)
 var greenTable = [CGGammaValue](repeating: 0, count: tableSize)
 var blueTable = [CGGammaValue](repeating: 0, count: tableSize)
 var sampleCount: UInt32 = .zero

 CGGetDisplayTransferByTable(CGMainDisplayID(), UInt32(tableSize), &redTable, &greenTable, &blueTable, &sampleCount)

 let isInverted = redTable.first == 1

 return (isInverted, greenTable)
 }

 func setInitialAppearanceWhenUsingGamma() {
 let (isInverted, _) = getCurrentPolarity()
 SLSSetAppearanceThemeLegacy(!isInverted)
 }

 func setShutdownAppearance() {
 let isWhiteOnBlack = UAWhiteOnBlackIsEnabled()
 SLSSetAppearanceThemeLegacy(!isWhiteOnBlack)
 }

 func doInvertPolarityGammaTable() {
 let (wasInverted, greenTable) = getCurrentPolarity()

 let isWhiteOnBlack = UAWhiteOnBlackIsEnabled()

 let isInverted = (wasInverted && isWhiteOnBlack) || (!wasInverted && !isWhiteOnBlack)

 let newTable = greenTable.map { 1 - $0 }

 SLSSetAppearanceThemeLegacy(!isInverted)

 let delay = isInverted ? 0.12 : 0.08

 DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
 CGSetDisplayTransferByTable(CGMainDisplayID(), UInt32(newTable.count), newTable, newTable, newTable)
 }
 }
 */

let invertTerminalColorsScript: NSAppleScript = {
    let script = NSAppleScript(source: """
    on invertTerminalColors(themeName)
        tell application "Terminal"
            set maxAttempts to 5
            
            -- Initially, all windows need to be tried.
            set windowsToRetry to every window
            repeat while maxAttempts > 0 and (count of windowsToRetry) > 0
                set maxAttempts to maxAttempts - 1
                set newWindowsToRetry to {}
                repeat with w in windowsToRetry
                    try
                        set current settings of w to (first settings set whose name is themeName)
                    on error
                        set end of newWindowsToRetry to w
                    end try
                end repeat
                set windowsToRetry to newWindowsToRetry
                if (count of windowsToRetry) > 0 and maxAttempts > 0 then delay 0.05
            end repeat
        end tell
    end invertTerminalColors
    """)!

    var error: NSDictionary?
    let success = script.compileAndReturnError(&error)
    assert(success)
    return script
}()

// Ensure the correct color scheme is selected on Terminal launch.
func terminalLaunchObserver() -> NSObjectProtocol {
    NSWorkspace.shared.notificationCenter
        .addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { notification in
            guard
                let app =
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier == "com.apple.Terminal"
            else { return }

            doSwitchTerminalTheme(UAWhiteOnBlackIsEnabled())
            app.activate()
            doMaximizeFrontWindow()
        }
}

// Ensure the correct color scheme is selected on Terminal new window.
func terminalNewWindowObserver() -> NSObjectProtocol {
    NSWorkspace.shared.notificationCenter
        .addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { notification in
            guard
                let app =
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier == "com.apple.Terminal"
            else { return }

            doSwitchTerminalTheme(UAWhiteOnBlackIsEnabled())
        }
}

func doSwitchTerminalTheme(_ isInverted: Bool) {
    if !NSWorkspace.shared.runningApplications.contains(where: { $0.localizedName == "Terminal" }) {
        return
    }

    let parameters = NSAppleEventDescriptor.list()
    parameters.insert(NSAppleEventDescriptor(string: isInverted ? "Inverted" : "Basic"), at: 0)

    let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kASAppleScriptSuite),
        eventID: AEEventID(kASSubroutineEvent),
        targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
    )

    event.setDescriptor(
        NSAppleEventDescriptor(
            string: "invertTerminalColors"),
        forKeyword: AEKeyword(keyASSubroutineName)
    )
    event.setDescriptor(parameters, forKeyword: AEKeyword(keyDirectObject))

    var error: NSDictionary?
    _ = invertTerminalColorsScript.executeAppleEvent(event, error: &error)
    //    if let error = error {
    //        let alert = NSAlert()
    //        alert.messageText = error.description
    //        alert.runModal()
    //    }
}

func doToggleAppearance(completion _: ((Bool) -> Void)? = nil) {
    let currentAppearance = SLSGetAppearanceThemeLegacy()
    SLSSetAppearanceThemeLegacy(!currentAppearance)
}
