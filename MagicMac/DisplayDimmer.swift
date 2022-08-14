//
//  DisplayDimmer.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/14/22.
//

import Foundation

final class DisplayDimmer {
    func increase() {
        brightness += 0.1
    }

    func decrease() {
        brightness -= 0.1
    }

    public func updateGamma() {
        let isWhiteOnBlack = UAWhiteOnBlackIsEnabled()
        let table: [CGGammaValue] = isWhiteOnBlack ? [1 - brightness, 1] : [0, brightness]
        CGSetDisplayTransferByTable(CGMainDisplayID(), UInt32(table.count), table, table, table)
    }

    private var brightness: CGGammaValue = 1.0 {
        didSet {
            brightness = max(0, min(1, brightness))
            updateGamma()
        }
    }
}
