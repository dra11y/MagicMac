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

let replacementsKey = "replacements"

struct RegexListView: View {

    // Use a computed property to retrieve the saved data from UserDefaults
    @State private var data: [Replacement] = {
        guard let data = UserDefaults.standard.data(forKey: replacementsKey),
              let decodedData = try? JSONDecoder().decode([Replacement].self, from: data)
        else {
            return []
        }
        return decodedData
    }()
    
    // Save the updated data to UserDefaults when the user makes changes
    private func saveData() {
        guard let encodedData = try? JSONEncoder().encode(data)
        else { return }
        UserDefaults.standard.set(encodedData, forKey: replacementsKey)
    }

    @State private var selection: Int?

    private func index(of row: Replacement) -> Int {
        $data.firstIndex(where: { $0.id == row.id })!
    }
    
    var body: some View {
        VStack {
            Table(data, selection: $selection) {
                TableColumn("Pattern") { row in
                    TextField("", text: $data[index(of: row)].pattern)
                        .onChange(of: data) { _ in saveData() }
                }
                
                TableColumn("Replacement") { row in
                    TextField("", text: $data[index(of: row)].replacement)
                        .onChange(of: data) { _ in saveData() }
                }
                
                TableColumn("Regex") { row in
                    Toggle(isOn: $data[index(of: row)].regex) {
                        EmptyView()
                    }
                        .onChange(of: data) { _ in saveData() }
                }
            }
            
            HStack(spacing: 0) {
                
                Button(action: {
                    data.append(Replacement.create(data.count + 1))
                }, label: {
                    Text("+").frame(width: 25)
                })

                Button(action: {
                    data.removeAll(where: { $0.id == selection })
                    selection = nil
                    saveData()
                }, label: {
                    Text("-").frame(width: 25)
                })
                    .disabled(selection == nil)
                
                Spacer()

            }.padding()
            
        }
    }
}
