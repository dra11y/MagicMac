//
//  getMouseBatteryLevel.swift
//  MagicMac
//
//  Created by Tom Grushka on 2/6/24.
//

import Foundation
import IOKit

func getMouseBatteryLevel() -> Int? {
    let matchingDict = IOServiceMatching("AppleDeviceManagementHIDEventService")
    var entry: io_iterator_t = 0
    let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &entry)
    guard result == KERN_SUCCESS else { return nil }

    var batteryLevel: Int?
    while case let service = IOIteratorNext(entry), service != 0 {
        var properties: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
            == KERN_SUCCESS, let propertiesDict = properties?.takeRetainedValue() as? [String: Any]
        {
            if let product = propertiesDict["Product"] as? String,
               product.lowercased().contains("mouse") {
                if let batteryPercent = propertiesDict["BatteryPercent"] as? Int {
                    batteryLevel = batteryPercent
                }
            }
        }
        IOObjectRelease(service)
    }
    IOObjectRelease(entry)
    return batteryLevel
}
