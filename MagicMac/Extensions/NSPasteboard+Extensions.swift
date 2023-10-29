//
//  NSPasteboard+Extensions.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import Foundation

extension NSPasteboard {
    func save() -> [NSPasteboardItem] {
        var archive = [NSPasteboardItem]()
        for item in pasteboardItems ?? [] {
            let archivedItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    archivedItem.setData(data, forType: type)
                }
            }
            archive.append(archivedItem)
        }
        return archive
    }

    func restore(archive: [NSPasteboardItem]) {
        clearContents()
        writeObjects(archive)
    }
}
