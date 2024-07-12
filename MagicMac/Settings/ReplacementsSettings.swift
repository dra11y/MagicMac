//
//  ReplacementsSettings.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct Replacement: Codable, Equatable, Identifiable, Transferable {
    var id: UUID
    var isEnabled: Bool
    var isRegex: Bool
    var caseSensitive: Bool
    var pattern: String
    var replacement: String
    var addSpace: Bool

    static var transferRepresentation: CodableRepresentation<Replacement, JSONEncoder, JSONDecoder> {
        CodableRepresentation<Replacement, JSONEncoder, JSONDecoder>(for: Replacement.self, contentType: UTType.json)
    }

    typealias Representation = CodableRepresentation<Replacement, JSONEncoder, JSONDecoder>

    enum CodingKeys: CodingKey {
        case isEnabled
        case isRegex
        case caseSensitive
        case pattern
        case replacement
        case addSpace
    }

    init(id: UUID, isEnabled: Bool, isRegex: Bool, caseSensitive: Bool, pattern: String, replacement: String, addSpace: Bool) {
        self.id = id
        self.isEnabled = isEnabled
        self.isRegex = isRegex
        self.caseSensitive = caseSensitive
        self.pattern = pattern
        self.replacement = replacement
        self.addSpace = addSpace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isRegex = try container.decode(Bool.self, forKey: .isRegex)
        caseSensitive = (try? container.decode(Bool.self, forKey: .caseSensitive)) ?? true
        pattern = try container.decode(String.self, forKey: .pattern)
        replacement = try container.decode(String.self, forKey: .replacement)
        addSpace = (try? container.decode(Bool.self, forKey: .addSpace)) ?? true
    }

    static func create() -> Replacement {
        Replacement(
            id: UUID(),
            isEnabled: true,
            isRegex: true,
            caseSensitive: false,
            pattern: "",
            replacement: "",
            addSpace: true)
    }
}
