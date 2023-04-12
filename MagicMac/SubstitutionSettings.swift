//
//  SubstitutionSettings.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import SwiftUI

struct Replacement: Codable, Equatable, Identifiable {
    var id: Int
    var pattern: String
    var replacement: String
    var regex: Bool

    static func create(_ id: Int) -> Replacement {
        Replacement(id: id, pattern: "", replacement: "", regex: true)
    }
}

struct RegexListView: View {
    @StateObject private var replacementsManager = ReplacementsManager()
    @State private var selection: Int?

    private func index(of row: Replacement) -> Int {
        replacementsManager.replacements.firstIndex(where: { $0.id == row.id })!
    }

    var body: some View {
        VStack {
            Table(replacementsManager.replacements, selection: $selection) {
                TableColumn("Pattern") { row in
                    TextField("", text: $replacementsManager.replacements[index(of: row)].pattern)
                        .onChange(of: replacementsManager.replacements) { _ in replacementsManager.saveData() }
                }

                TableColumn("Replacement") { row in
                    TextField("", text: $replacementsManager.replacements[index(of: row)].replacement)
                        .onChange(of: replacementsManager.replacements) { _ in replacementsManager.saveData() }
                }

                TableColumn("Regex") { row in
                    Toggle(isOn: $replacementsManager.replacements[index(of: row)].regex) {
                        EmptyView()
                    }
                    .onChange(of: replacementsManager.replacements) { _ in replacementsManager.saveData() }
                }
            }

            HStack(spacing: 0) {
                Button(action: {
                    let id = replacementsManager.replacements.count + 1
                    replacementsManager.replacements.append(
                        Replacement.create(id))
                }, label: {
                    Text("+").frame(width: 25)
                })

                Button(action: {
                    replacementsManager.replacements.removeAll(where: { $0.id == selection })
                    selection = nil
                    replacementsManager.saveData()
                }, label: {
                    Text("-").frame(width: 25)
                })
                .disabled(selection == nil)

                Spacer()

            }.padding()
        }
    }
}
