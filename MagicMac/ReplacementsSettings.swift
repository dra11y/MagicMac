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

struct ReplacementsView: View {
    @StateObject private var replacementsManager = ReplacementsManager.shared
    @State private var selection = Set<UUID>()
    @FocusState private var focused: UUID?

    private func index(of row: Replacement) -> Int {
        replacementsManager.replacements.firstIndex(where: { $0.id == row.id })!
    }

    private func onSubmitHandler() {
        replacementsManager.saveData()
    }

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                Table($replacementsManager.replacements, selection: $selection) {
                    TableColumn("Enabled") { $row in
                        Toggle(isOn: $row.isEnabled) {
                            EmptyView()
                        }
                        .onSubmit(onSubmitHandler)
                    }
                    .width(50)

                    TableColumn("Pattern") { $row in
                        TextField("", text: $row.pattern)
                            .onSubmit(onSubmitHandler)
                            .accessibilityTextContentType(.sourceCode)
                    }

                    TableColumn("Replacement") { $row in
                        TextField("", text: $row.replacement)
                            .accessibilityTextContentType(.sourceCode)
                            .onSubmit(onSubmitHandler)
                    }

                    TableColumn("Regex") { $row in
                        Toggle(isOn: $row.isRegex) {
                            EmptyView()
                        }
                        .onSubmit(onSubmitHandler)
                    }

                    TableColumn("Ignore Case") { $row in
                        Toggle(isOn: $row.ignoreCase) {
                            EmptyView()
                        }
                        .onSubmit(onSubmitHandler)
                    }
                }
                .onChange(of: selection) { _, newValue in
                    if let first = newValue.first {
                        proxy.scrollTo(first)
                    }
                }
            }

            HStack {
                MomentaryButtons(
                    segments: [
                        ButtonSegment(view: AnyView(Image(systemName: "chevron.up").accessibilityLabel("Up")), action: {
                            replacementsManager.moveUp(selection)
                        }),
                        ButtonSegment(view: AnyView(Image(systemName: "chevron.down").accessibilityLabel("Down")), action: {
                            replacementsManager.moveDown(selection)
                        })
                    ]
                )
                .frame(width: 80)
                .padding()
                .disabled(selection.isEmpty)

                Spacer()

                MomentaryButtons(
                    segments: [
                        !selection.isEmpty
                            ? ButtonSegment(view: AnyView(Text("-")), action: {
                                replacementsManager.replacements.removeAll(where: { selection.contains($0.id) })
                                selection = []
                                onSubmitHandler()
                            })
                            : nil,
                        ButtonSegment(view: AnyView(Text("+")), action: {
                            let newRow = Replacement.create()
                            let offsets = replacementsManager.getOffsets(selection)
                            let offset = offsets.first ?? replacementsManager.replacements.count - 1
                            replacementsManager.replacements.insert(newRow, at: offset + 1)
                            selection = [newRow.id]
                        })
                    ].compactMap { $0 }
                )
                .frame(width: selection.isEmpty ? 44 : 80)
                .padding()
            }
        }
    }
}
