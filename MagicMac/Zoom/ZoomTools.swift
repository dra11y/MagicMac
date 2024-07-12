//
//  ZoomTools.swift
//  MagicMac
//
//  Created by Tom Grushka on 5/17/24.
//

import Carbon
import Cocoa
import OSLog

fileprivate let logger = Logger(subsystem: "MagicMac", category: "ZoomTools")

func zoomShareScreen() {
    let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kASAppleScriptSuite),
        eventID: AEEventID(kASSubroutineEvent),
        targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
    )

    event.setDescriptor(
        NSAppleEventDescriptor(
            string: "zoomShareScreen"),
        forKeyword: AEKeyword(keyASSubroutineName)
    )

    var error: NSDictionary?
    _ = zoomShareScript.executeAppleEvent(event, error: &error)
    
    logger.info("zoomShareScreen error: \(String(describing: error))")
}

let zoomShareScript: NSAppleScript = {
    let script = NSAppleScript(source: """
    on zoomShareScreen()
        tell application "System Events"
            set zoom_process to process "zoom.us"
            tell zoom_process
                click menu item "Start share" of menu "Meeting" of menu bar 1
                set share_window to window "Share screen window"
                tell share_window
                    set options_area to scroll area 2
                    set share_sound to first checkbox of options_area whose description is "Share sound"
                    if value of share_sound is 0 then
                        click share_sound
                    end if
                    tell options_area
                        click first button whose description is "share sound sub menu"
                        keystroke "s"
                        key code 36
                    end tell
                    set optimize to first checkbox of options_area whose description is "Optimize for video clip"
                    if value of optimize is 0 then
                        click optimize
                    end if
                    set share to first button whose description starts with "Share"
                    click share
                end tell

                repeat until exists (window "zoom share toolbar window")
                    delay 0.1
                end repeat
                tell window "zoom share toolbar window"
                    click first button whose description is "More"
                    keystroke "Hide floating"
                    key code 36
                end tell
            end tell
        end tell
    end zoomShareScreen
    """)!

    var error: NSDictionary?
    let success = script.compileAndReturnError(&error)
    assert(success)
    return script
}()

