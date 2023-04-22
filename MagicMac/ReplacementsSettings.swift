//
//  ReplacementsSettings.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import SwiftUI

struct Replacement: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var isRegex: Bool
    var pattern: String
    var replacement: String
    
    enum CodingKeys: CodingKey {
        case isRegex
        case pattern
        case replacement
    }

    static func create(isRegex: Bool = false) -> Replacement {
        Replacement(isRegex: isRegex, pattern: "", replacement: "")
    }
}

struct RegexListView: View {
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

            /// Review this tutorial for potential drag-drop solution:
            /// https://www.kodeco.com/22408716-drag-and-drop-editable-lists-tutorial-for-swiftui

            Table(replacementsManager.replacements, selection: $selection) {
                TableColumn("Pattern") { row in
                    TextField("", text: $replacementsManager.replacements[index(of: row)].pattern)
                        .focused($focused, equals: row.id)
                        .onSubmit(onSubmitHandler)
                        .onAppear {
                            if focused != row.id && row.id == replacementsManager.replacements.last?.id {
                                focused = row.id
                            }
                        }
                }

                TableColumn("Replacement") { row in
                    TextField("", text: $replacementsManager.replacements[index(of: row)].replacement)
                        .onSubmit(onSubmitHandler)
                }

                TableColumn("Regex") { row in
                    Toggle(isOn: $replacementsManager.replacements[index(of: row)].isRegex) {
                        EmptyView()
                    }
                    .onSubmit(onSubmitHandler)
                }
            }

            HStack(spacing: 0) {
                Button(action: {
                    let newRow = Replacement.create()
                    replacementsManager.replacements.append(newRow)
                    selection = [newRow.id]
                }, label: {
                    Text("+").frame(width: 25)
                })

                Button(action: {
                    replacementsManager.replacements.removeAll(where: { selection.contains($0.id) })
                    selection = []
                    onSubmitHandler()
                }, label: {
                    Text("-").frame(width: 25)
                })
                .disabled(selection.isEmpty)

                Spacer()

            }.padding()
        }
    }
}
