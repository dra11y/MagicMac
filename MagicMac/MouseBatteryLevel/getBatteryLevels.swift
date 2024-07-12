//
//  getBatteryLevels.swift
//  MagicMac
//
//  Created by Tom Grushka on 2/6/24.
//

import Foundation
import IOKit
import OSLog

fileprivate let logger = Logger(subsystem: "MagicMac", category: "getBatteryLevels")

func getBatteryLevels() -> (mouse: Int?, keyboard: Int?) {
    let matchingDict = IOServiceMatching("AppleDeviceManagementHIDEventService")
    var entry: io_iterator_t = 0
    let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &entry)
    guard result == KERN_SUCCESS else { return (nil, nil) }

    var mouse: Int?
    var keyboard: Int?
    while case let service = IOIteratorNext(entry), service != 0 {
        var properties: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
            == KERN_SUCCESS, let propertiesDict = properties?.takeRetainedValue() as? [String: Any]
        {
            if let product = propertiesDict["Product"] as? String {
                if
                    product.lowercased().contains("mouse"),
                    let batteryPercent = propertiesDict["BatteryPercent"] as? Int {
                    mouse = batteryPercent
                }
                if
                    product.lowercased().contains("keyboard"),
                    let batteryPercent = propertiesDict["BatteryPercent"] as? Int {
                    keyboard = batteryPercent
                }
            }
        }
        IOObjectRelease(service)
    }
    IOObjectRelease(entry)
    return (mouse: mouse, keyboard: keyboard)
}
