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
            let bundleName = Bundle.main.bundleIdentifier,
            let appSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?
            .appendingPathComponent(bundleName)
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

    public func reloadReplacements() {
        // print("Loading replacements...")
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
