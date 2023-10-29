//
//  Double+Extensions.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import Foundation

extension Double {
    func display(places: Int = 2) -> String {
        String(format: "%.\(places)f", self)
    }

    func displayPercent(places: Int = 0) -> String {
        String(format: "%.\(places)f %%", self * 100)
    }
}
