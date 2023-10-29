//
//  KeyboardShortcuts.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import Foundation

extension String {
    var sentenceCased: String {
        let regex = try? NSRegularExpression(pattern: "([a-z0-9])([A-Z])", options: [])
        let modifiedString = regex?.stringByReplacingMatches(in: self, options: [], range: NSRange(location: 0, length: self.count), withTemplate: "$1 $2") ?? self
        let first = modifiedString.prefix(1).uppercased()
        let rest = modifiedString.dropFirst().lowercased()
        return first + rest
    }
}
