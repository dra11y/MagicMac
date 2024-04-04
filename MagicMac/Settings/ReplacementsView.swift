//
//  ReplacementsView.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

struct ReplacementsView: View {
    var body: some View {
        VStack {
            searchField
            replacementsTable
            actionButtons
        }
        .onAppear(perform: filterReplacements)
        .onChange(of: replacementsManager.replacements, filterReplacements)
        .tabItem {
            Label("Substitutions", systemImage: "textformat.abc.dottedunderline")
        }
    }

    @StateObject private var replacementsManager = ReplacementsManager.shared
    @State private var selection = Set<UUID>()

    enum FieldType { case pattern, replacement, regex, caseSensitive }
    struct FocusIdentifier: Hashable {
        let id: UUID
        let field: FieldType

        init(_ id: UUID, _ field: FieldType) {
            self.id = id
            self.field = field
        }
    }

    @FocusState private var focused: FocusIdentifier?

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
            return
        }
        filteredReplacements = replacementsManager.replacements.filter { replacement in
            replacement.pattern.lowercased().contains(searchQuery.lowercased()) ||
                replacement.replacement.lowercased().contains(searchQuery.lowercased())
        }
    }

    private var searchField: some View {
        TextField("Search...", text: $searchQuery)
            .textFieldStyle(.roundedBorder)
            .padding([.top, .leading, .trailing])
            .onChange(of: searchQuery) {
                filterReplacements()
            }
    }

    private var replacementsTable: some View {
        ScrollViewReader { proxy in
            Table($filteredReplacements, selection: $selection) {
                TableColumn("Enabled") { $row in
                    EnabledToggleView(row: $row, updateHandler: update)
                }
                .width(50)
                
                TableColumn("Regex") { $row in
                    Toggle(isOn: $row.isRegex) {
                        EmptyView()
                    }
                    .focusable()
                    .focused($focused, equals: FocusIdentifier(row.id, .regex))
                    .onChange(of: row.isRegex) {
                        update(row)
                    }
                }
                .width(50)

                TableColumn("Case Sensitive") { $row in
                    Toggle(isOn: $row.caseSensitive) {
                        EmptyView()
                    }
                    .focusable()
                    .focused($focused, equals: FocusIdentifier(row.id, .caseSensitive))
                    .onChange(of: row.caseSensitive) {
                        update(row)
                    }
                }
                .width(50)

                TableColumn("Pattern") { $row in
                    TextField("", text: $row.pattern, onEditingChanged: { editing in
                        if !editing {
                            update(row)
                        }
                    })
                    .fontDesign(.monospaced)
                    .font(.system(size: 20))
                    .focused($focused, equals: FocusIdentifier(row.id, .pattern))
                    .onSubmit { update(row) }
                    .accessibilityTextContentType(.sourceCode)
                }

                TableColumn("Replacement") { $row in
                    TextField("", text: $row.replacement, onEditingChanged: { editing in
                        if !editing {
                            update(row)
                        }
                    })
                    .fontDesign(.monospaced)
                    .font(.system(size: 20))
                    .focused($focused, equals: FocusIdentifier(row.id, .replacement))
                    .accessibilityTextContentType(.sourceCode)
                    .onSubmit {
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
    }

    var actionButtons: some View {
        HStack {
            MomentaryButtons(
                segments: [
                    ButtonSegment(view: AnyView(Image(systemName: "chevron.up").accessibilityLabel("Up")), action: {
                        if let id = focused?.id {
                            update(filteredReplacements.first(where: { $0.id == id })!)
                        }
                        replacementsManager.moveUp(selection)
                    }),
                    ButtonSegment(view: AnyView(Image(systemName: "chevron.down").accessibilityLabel("Down")), action: {
                        if let id = focused?.id {
                            update(filteredReplacements.first(where: { $0.id == id })!)
                        }
                        replacementsManager.moveDown(selection)
                    }),
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focused = FocusIdentifier(newRow.id, .pattern)
                        }
                    }),
                ].compactMap { $0 }
            )
            .frame(width: selection.isEmpty ? 44 : 80)
            .padding()
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
        .onChange(of: row.isEnabled) {
            updateHandler(row)
        }
    }
}
