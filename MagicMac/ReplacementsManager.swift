//
//  ReplacementsManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/12/23.
//

import Foundation

class ReplacementsManager: ObservableObject {
    private static let replacementsFilename = "replacements.txt"
    private static let separator = "||||"
    private static let newline = "\n"

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
            let data = Data()
            do {
                try data.write(to: replacementsURL)
            } catch {
                fatalError("Unable to create file: \(replacementsURL)")
            }
        }

        return replacementsURL
    }

    @Published var replacements: [Replacement] = {
        guard
            let data = try? String(contentsOf: ReplacementsManager.replacementsURL),
            !data.isEmpty
        else {
            return []
        }
        let replacements = data.components(separatedBy: ReplacementsManager.newline)
            .compactMap { item -> Replacement? in
                let components = item.components(separatedBy: ReplacementsManager.separator)
                guard
                    components.count == 4,
                    let id = Int(components[0]),
                    let regex = Bool(components[3])
                else { return nil }
                return Replacement(
                    id: id,
                    pattern: components[1],
                    replacement: components[2],
                    regex: regex
                )
            }
        return replacements
    }()

    func saveData() {
        let data = replacements.map { replacement -> String in
            [
                String(replacement.id),
                replacement.pattern,
                replacement.replacement,
                String(replacement.regex),
            ]
            .joined(separator: ReplacementsManager.separator)
        }.joined(separator: ReplacementsManager.newline)
        try? data.write(to: ReplacementsManager.replacementsURL, atomically: true, encoding: .utf8)
    }
}
