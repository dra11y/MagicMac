//
//  SpeakOnDemand.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import Cocoa
import Foundation

public class SpeechManager {
    static let shared = SpeechManager()

    private init() {}

    private let speechSynthesizer = NSSpeechSynthesizer()

    private let observer = PasteboardObserver()
    
    private let replacementsManager = ReplacementsManager.shared
    
    private func replaceText(_ text: String) -> String {
        let replacements = replacementsManager.replacements
        var replacedText = text
        
        // Apply replacements
        for replacement in replacements {
            if replacement.regex {
                // Replace using regex
                let regex = try! NSRegularExpression(pattern: replacement.pattern)
                replacedText = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement.replacement)
            } else {
                // Replace using plain text
                replacedText = text.replacingOccurrences(of: replacement.pattern, with: replacement.replacement)
            }
        }
        
        return replacedText
    }

    public func speakFrontmostSelection() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking()
            return
        }

        speechSynthesizer.setVoice(NSSpeechSynthesizer.defaultVoice)

        startCopyText()
    }

    private func startCopyText() {
        let archive = NSPasteboard.general.save()
        observer.startObserving(interval: 0.01) { [weak self] in
            guard
                let self = self,
                let text = NSPasteboard.general.string(forType: .string)
            else { return }

            self.observer.stopObserving()
            let replacedText = replaceText(text)
            self.speechSynthesizer.startSpeaking(replacedText)
            NSPasteboard.general.restore(archive: archive)
        }
        FakeKey.shared.send(fakeKey: "C", useCommandFlag: true)
    }
}

class PasteboardObserver {
    private var timer: Timer?
    private var lastChangeCount: Int

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startObserving(interval: TimeInterval = 0.01, timeout: TimeInterval = 1, handler: @escaping () -> Void) {
        lastChangeCount = NSPasteboard.general.changeCount
        timer?.invalidate()
        let startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let timer = timer, timer.isValid else { return }

            let elapsedTime = timer.fireDate.timeIntervalSince(startTime)
            guard elapsedTime < timeout else {
                self.timer?.invalidate()
                return
            }

            let changeCount = NSPasteboard.general.changeCount
            guard changeCount != self.lastChangeCount else { return }

            handler()
            self.lastChangeCount = changeCount
        }
        timer?.fire()
    }

    func stopObserving() {
        timer?.invalidate()
        timer = nil
    }
}

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
