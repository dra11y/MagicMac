//
//  ReplacementsSettings.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct Replacement: Codable, Equatable, Identifiable, Transferable {
    var id: UUID = .init()
    var isEnabled: Bool = true
    var isRegex: Bool
    var ignoreCase: Bool = false
    var pattern: String
    var replacement: String

    static var transferRepresentation: CodableRepresentation<Replacement, JSONEncoder, JSONDecoder> {
        CodableRepresentation<Replacement, JSONEncoder, JSONDecoder>(for: Replacement.self, contentType: UTType.json)
    }

    typealias Representation = CodableRepresentation<Replacement, JSONEncoder, JSONDecoder>

    enum CodingKeys: CodingKey {
        case isEnabled
        case isRegex
        case ignoreCase
        case pattern
        case replacement
    }

    init(id: UUID? = nil, isEnabled: Bool? = nil, isRegex: Bool, ignoreCase: Bool? = nil, pattern: String, replacement: String) {
        if let id {
            self.id = id
        }
        if let isEnabled {
            self.isEnabled = isEnabled
        }
        self.isRegex = isRegex
        if let ignoreCase {
            self.ignoreCase = ignoreCase
        }
        self.pattern = pattern
        self.replacement = replacement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isRegex = try container.decode(Bool.self, forKey: .isRegex)
        ignoreCase = (try? container.decode(Bool.self, forKey: .ignoreCase)) ?? false
        pattern = try container.decode(String.self, forKey: .pattern)
        replacement = try container.decode(String.self, forKey: .replacement)
    }

    static func create(isRegex: Bool = false, ignoreCase: Bool = false) -> Replacement {
        Replacement(isRegex: isRegex, ignoreCase: ignoreCase, pattern: "", replacement: "")
    }
}
