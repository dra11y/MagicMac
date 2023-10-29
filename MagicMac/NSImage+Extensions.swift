//
//  NSImage.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/14/22.
//

import AppKit
import Foundation
import os
import SwiftUI

extension NSImage.Name {
    static let menuExtra = NSImage.Name("MenuExtra")
    static let menuExtraInverted = NSImage.Name("MenuExtraInverted")
}

// https://stackoverflow.com/questions/2137744/draw-standard-nsimage-inverted-white-instead-of-black
public extension NSImage {
    var inverted: NSImage {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            os_log("Could not create CGImage from NSImage")
            return self
        }

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorInvert") else {
            os_log(.error, "Could not create CIColorInvert filter")
            return self
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage else {
            os_log(.error, "Could not obtain output CIImage from filter")
            return self
        }

        guard let outputCgImage = outputImage.cgImage else {
            os_log(.error, "Could not create CGImage from CIImage")
            return self
        }

        return NSImage(cgImage: outputCgImage, size: size)
    }
}
