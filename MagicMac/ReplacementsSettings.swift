//
//  ReplacementsSettings.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct Replacement: Codable, Equatable, Identifiable, Transferable {
    var id: UUID = UUID()
    var isEnabled: Bool = true
    var isRegex: Bool
    var pattern: String
    var replacement: String
    
    static var transferRepresentation: CodableRepresentation<Replacement, JSONEncoder, JSONDecoder> {
        CodableRepresentation<Replacement, JSONEncoder, JSONDecoder>(for: Replacement.self, contentType: UTType.json)
    }
    
    typealias Representation = CodableRepresentation<Replacement, JSONEncoder, JSONDecoder>
    
    enum CodingKeys: CodingKey {
        case isEnabled
        case isRegex
        case pattern
        case replacement
    }
    
    static func create(isRegex: Bool = false) -> Replacement {
        Replacement(isRegex: isRegex, pattern: "", replacement: "")
    }
}

struct ReplacementsView: View {
    @StateObject private var replacementsManager = ReplacementsManager.shared
    @State private var selection = Set<UUID>()
    @FocusState private var focused: UUID?
    
    let rowHeight: CGFloat = 30
    
    private func index(of row: Replacement) -> Int {
        replacementsManager.replacements.firstIndex(where: { $0.id == row.id })!
    }
    
    private func onSubmitHandler() {
        print("onSubmitHandler \(Date.now)")
        replacementsManager.saveData()
    }
    
    var body: some View {
        VStack {
            
            Table($replacementsManager.replacements, selection: $selection) {
                
                TableColumn("Sort") { $row in
                    Image(systemName: "line.horizontal.3")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                        .onDrag {
                            let index = replacementsManager.replacements.firstIndex(where: { $0.id == row.id })!
                            return NSItemProvider(object: String(index) as NSString)
                        }
                }
                .width(50)
                
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
                }
                
                TableColumn("Replacement") { $row in
                    TextField("", text: $row.replacement)
                        .onSubmit(onSubmitHandler)
                }
                
                TableColumn("Regex") { $row in
                    Toggle(isOn: $row.isRegex) {
                        EmptyView()
                    }
                    .onSubmit(onSubmitHandler)
                }
            }
            .environment(\.defaultMinListRowHeight, rowHeight)
            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers, location in
                // Step 1: Retrieve the source index from the dragged item provider
                providers.first?.loadObject(ofClass: NSString.self) { (sourceIndexString, error) in
                    guard let sourceIndexString = sourceIndexString as? String,
                          let sourceIndex = Int(sourceIndexString) else {
                        return
                    }
                    
                    // Step 2: Calculate the destination index based on the drop location
                    // Note: In this example, we're using a simple method to calculate the destination index.
                    // You might need to adjust this to more accurately determine the destination index based on your UI.
                    let destinationIndex = min(max(Int(location.y / rowHeight), 0), replacementsManager.replacements.count - 1)
                    
                    // Step 3: Rearrange the items in your data array accordingly
                    if destinationIndex != sourceIndex {
                        let draggedItem = replacementsManager.replacements[sourceIndex]
                        replacementsManager.replacements.remove(at: sourceIndex)
                        replacementsManager.replacements.insert(draggedItem, at: destinationIndex)
                    }
                }
                
                return true
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
    
    private func toggleSelection(of row: Replacement) {
        if selection.contains(row.id) {
            print("UN-select \(row.id)")
            selection.remove(row.id)
        } else {
            print("select \(row.id)")
            selection.insert(row.id)
        }
    }

}
