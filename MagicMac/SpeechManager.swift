//
//  SpeakOnDemand.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import Cocoa
import Foundation
import AVFoundation

public class SpeechManager {
    static let shared = SpeechManager()

    private init() {
        startBackgroundSilence()
        observeSleepWakeNotifications()
        observeAudioConfigurationChanges()
    }
    
    private func observeSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    private func observeAudioConfigurationChanges() {
        NotificationCenter.default.addObserver(self, selector: #selector(audioConfigurationDidChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: audioEngine)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioEngineConfigurationChange, object: audioEngine)
    }

    @objc private func systemWillSleep(notification: NSNotification) {
        print("systemWillSleep \(Date.now)")
        stopBackgroundSilence()
    }

    @objc private func systemDidWake(notification: NSNotification) {
        print("systemDidWake \(Date.now)")
        startBackgroundSilence()
    }
    
    @objc private func audioConfigurationDidChange(notification: NSNotification) {
        print("audioConfigurationDidChange \(Date.now)")
        // Stop and restart the background silence to accommodate the new audio configuration
        stopBackgroundSilence()
        startBackgroundSilence()
    }
    
    private func stopBackgroundSilence() {
        playerNode.stop()
        audioEngine.stop()
    }
    
    private func startBackgroundSilence() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        let sampleRate = 48000
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }
        let bufferDuration = 0.1
        let bufferSize = UInt32(bufferDuration * Double(sampleRate))

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        buffer.frameLength = bufferSize
        
        guard let floatChannelData = buffer.floatChannelData else {
            print("Failed to access channel data")
            return
        }

        let channelCount = Int(format.channelCount)
        let frames = Int(bufferSize)

        for channel in 0..<channelCount {
            let channelData = floatChannelData[channel]
            for frame in 0..<frames {
                channelData[frame] = 0.0
            }
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
    }

    // Silent audio:
    let audioEngine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    
    private let speechSynthesizer = NSSpeechSynthesizer()
    
    private let pasteboardObserver = PasteboardObserver()
    
    private let replacementsManager = ReplacementsManager.shared
    
    private func replaceText(_ text: String) -> String {
        replacementsManager.reloadReplacements()
        let replacements = replacementsManager.replacements.filter { replacement in
            replacement.isEnabled
        }
        /// test
        var replacedText = text
        
        // Apply replacements
        for replacement in replacements {
            if replacement.isRegex {
                /// Replace using regex
                guard
                    let regex = try? NSRegularExpression(pattern: replacement.pattern)
                else { continue }
                let range = NSRange(replacedText.startIndex..., in: replacedText)
                replacedText = regex.stringByReplacingMatches(in: replacedText, range: range, withTemplate: " \(replacement.replacement) ")
            } else {
                // Replace using plain text
                replacedText = replacedText.replacingOccurrences(of: replacement.pattern, with: " \(replacement.replacement) ", options: [.diacriticInsensitive, .caseInsensitive])
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
        pasteboardObserver.startObserving(interval: 0.01) { [weak self] in
            guard
                let self = self,
                let text = NSPasteboard.general.string(forType: .string)
            else { return }

            self.pasteboardObserver.stopObserving()
            let replacedText = "[[slnc 200]] " + replaceText(text)
            print("replacedText = \(replacedText)")
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
