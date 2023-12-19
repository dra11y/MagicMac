//
//  ReplacementsView.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

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
                        .onChange(of: row.isEnabled) {
                            onSubmitHandler()
                        }
                    }
                    .width(50)

                    TableColumn("Pattern") { $row in
                        TextField("", text: $row.pattern, onEditingChanged: { editing in
                            if !editing {
                                print("SAVED ... edit pattern")
                                onSubmitHandler()
                            }
                        })
                            .onSubmit(onSubmitHandler)
                            .accessibilityTextContentType(.sourceCode)
                    }

                    TableColumn("Replacement") { $row in
                        TextField("", text: $row.replacement, onEditingChanged: { editing in
                            if !editing {
                                print("SAVED ... edit replacement")
                                onSubmitHandler()
                            }
                        })
                            .accessibilityTextContentType(.sourceCode)
                            .onSubmit(onSubmitHandler)
                    }

                    TableColumn("Regex") { $row in
                        Toggle(isOn: $row.isRegex) {
                            EmptyView()
                        }
                        .onChange(of: row.isRegex) {
                            onSubmitHandler()
                        }
                    }

                    TableColumn("Ignore Case") { $row in
                        Toggle(isOn: $row.ignoreCase) {
                            EmptyView()
                        }
                        .onChange(of: row.ignoreCase) {
                            onSubmitHandler()
                        }
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
        .tabItem {
            Image(systemName: "textformat.abc.dottedunderline")
            Text("Substitutions")
        }
    }
}
