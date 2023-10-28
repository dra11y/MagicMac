//
//  ReplacementsManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/12/23.
//

import Foundation

class ReplacementsManager: ObservableObject {
    static let shared = ReplacementsManager()

    private init() {
        self.replacements = []
        self.reloadReplacements()
    }

    private static let replacementsFilename = "replacements.json"
    
    private static var replacementsURL: URL {
        guard
            let productName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
            let appSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?
            .appendingPathComponent(productName)
        else {
            fatalError("Could not produce App Support URL.")
        }

        do {
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            fatalError("Unable to create app support directory at \(appSupportURL)")
        }

        let replacementsURL = appSupportURL.appendingPathComponent(replacementsFilename)

        if !FileManager.default.fileExists(atPath: replacementsURL.path) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            do {
                let replacements = [Replacement]()
                let data = try encoder.encode(replacements)
                try data.write(to: replacementsURL)
            } catch {
                fatalError("Error creating JSON replacements file: \(error)")
            }
        }

        return replacementsURL
    }

    @Published var replacements: [Replacement]
    
    public func getOffsets(_ selection: Set<UUID>) -> IndexSet {
        IndexSet(replacements.enumerated().compactMap { index, element in
            selection.contains(element.id) ? index : nil
        })
    }
    
    public func moveDown(_ selection: Set<UUID>) {
        let offsets = getOffsets(selection)
        let offset = min(offsets.max()!, replacements.count - 2) + 2
        replacements.move(fromOffsets: offsets, toOffset: offset)
    }
    
    public func moveUp(_ selection: Set<UUID>) {
        let offsets = getOffsets(selection)
        let offset = max(offsets.min()!, 1) - 1
        replacements.move(fromOffsets: offsets, toOffset: offset)
    }

    public func reloadReplacements() {
        do {
            let data = try Data(contentsOf: ReplacementsManager.replacementsURL)
            let replacements = try JSONDecoder().decode([Replacement].self, from: data)
            self.replacements = replacements
        } catch {
            fatalError("Can't decode: \(error)")
        }
    }

    func saveData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(replacements)
            try data.write(to: ReplacementsManager.replacementsURL)
        } catch {
            fatalError("Error encoding JSON: \(error)")
        }
    }
}
