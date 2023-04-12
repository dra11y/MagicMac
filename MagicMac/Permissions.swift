//
//  Permissions.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/13/22.
//

import ApplicationServices
import Foundation

func trustForAccessibility() {
    let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
    let options: CFDictionary = NSDictionary(dictionary: [promptFlag: true])
    AXIsProcessTrustedWithOptions(options)
}
