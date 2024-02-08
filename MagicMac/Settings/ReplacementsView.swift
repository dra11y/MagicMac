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
    @State private var searchQuery = ""
    @State private var filteredReplacements: [Replacement] = []

    private func index(of row: Replacement) -> Int? {
        replacementsManager.replacements.firstIndex(where: { $0.id == row.id })
    }

    private func update(_ row: Replacement) {
        replacementsManager.update(row)
    }

    private func filterReplacements() {
        if searchQuery.isEmpty {
            filteredReplacements = replacementsManager.replacements
        } else {
            filteredReplacements = replacementsManager.replacements.filter { replacement in
                replacement.pattern.lowercased().contains(searchQuery.lowercased()) ||
                replacement.replacement.lowercased().contains(searchQuery.lowercased())
            }
        }
    }

    var body: some View {
        VStack {
            TextField("Search...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding([.top, .leading, .trailing])
                .onChange(of: searchQuery, filterReplacements)

            ScrollViewReader { proxy in
                Table($filteredReplacements, selection: $selection) {
                    TableColumn("Enabled") { $row in
                        EnabledToggleView(row: $row, updateHandler: update)
                    }
                    .width(50)

                    TableColumn("Pattern") { $row in
                        TextField("", text: $row.pattern, onEditingChanged: { editing in
                            if !editing {
                                update(row)
                            }
                        })
                            .onSubmit {
                                update(row)
                            }
                            .accessibilityTextContentType(.sourceCode)
                    }

                    TableColumn("Replacement") { $row in
                        TextField("", text: $row.replacement, onEditingChanged: { editing in
                            if !editing {
                                print("SAVED ... edit replacement")
                                update(row)
                            }
                        })
                            .accessibilityTextContentType(.sourceCode)
                            .onSubmit {
                                update(row)
                            }
                    }

                    TableColumn("Regex") { $row in
                        Toggle(isOn: $row.isRegex) {
                            EmptyView()
                        }
                        .onChange(of: row.isRegex) {
                            update(row)
                        }
                    }

                    TableColumn("Ignore Case") { $row in
                        Toggle(isOn: $row.ignoreCase) {
                            EmptyView()
                        }
                        .onChange(of: row.ignoreCase) {
                            update(row)
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
                                replacementsManager.delete(selection)
                                selection = []
                            })
                            : nil,
                        ButtonSegment(view: AnyView(Text("+")), action: {
                            let newRow = Replacement.create()
                            let offsets = replacementsManager.getOffsets(selection)
                            let offset = offsets.first ?? replacementsManager.replacements.count - 1
                            replacementsManager.add(newRow, at: offset)
                            selection = [newRow.id]
                            filterReplacements()
                        })
                    ].compactMap { $0 }
                )
                .frame(width: selection.isEmpty ? 44 : 80)
                .padding()
            }
        }
        .onAppear(perform: filterReplacements)
        .onChange(of: replacementsManager.replacements, filterReplacements)
        .tabItem {
            Label("Substitutions", systemImage: "textformat.abc.dottedunderline")
        }
    }
}

struct EnabledToggleView: View {
    @Binding var row: Replacement
    var updateHandler: (_ row: Replacement) -> Void

    var body: some View {
        Toggle(isOn: $row.isEnabled) {
            EmptyView()
        }
        .onChange(of: row.isEnabled) { _ in
            updateHandler(row)
        }
    }
}
