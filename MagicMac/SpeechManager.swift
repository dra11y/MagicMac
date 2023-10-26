//
//  SpeakOnDemand.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import Cocoa
import Foundation
import AVFoundation
import SwiftUI

public class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        currentCharacterIndex = characterRange.location
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speechString = ""
        currentCharacterIndex = 0
    }
    
    var lastSpeechRate: Double?
    var lastSpeechVolume: Double?
    
    @AppStorage("speechRate") private var speechRate: Double = 100

    @AppStorage("speechVolume") private var speechVolume: Double = 1.0

    static let shared = SpeechManager()

    private override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(speechRateChanged), name: UserDefaults.didChangeNotification, object: nil)

        startBackgroundSilence()
        observeSleepWakeNotifications()
        observeAudioConfigurationChanges()
        speechSynthesizer.delegate = self
    }

    @objc private func speechRateChanged(notification: NSNotification) {
        if speechRate == lastSpeechRate && speechVolume == lastSpeechVolume {
            return
        }

        speechRateChangeTimer?.invalidate()
        speechRateChangeTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(startSpeaking), userInfo: nil, repeats: false)
    }

    private func observeSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    private func observeAudioConfigurationChanges() {
        NotificationCenter.default.addObserver(self, selector: #selector(audioConfigurationDidChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: audioEngine)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)

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
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private let pasteboardObserver = PasteboardObserver()
    
    private let replacementsManager = ReplacementsManager.shared
    
    private var speechString: String = ""
    private var currentCharacterIndex: Int = 0
    private var speechRateChangeTimer: Timer?

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
                    let regex = try? NSRegularExpression(pattern: replacement.pattern, options: [.caseInsensitive])
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
    
    public func speakSelection() {
        speakFrontmostSelection()
    }

    public func speakSelectionSlowly() {
        speakFrontmostSelection(slow: true)
    }

    private func speakFrontmostSelection(slow: Bool = false) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }
        // TODO: detect if we're resuming (same text selected)
        // else if speechSynthesizer.isPaused {
        //     speechSynthesizer.continueSpeaking()
        // }

//        speechSynthesizer.setVoice(NSSpeechSynthesizer.defaultVoice)

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
            self.speechString = self.replaceText(text)
            self.currentCharacterIndex = 0
            self.startSpeaking()
            NSPasteboard.general.restore(archive: archive)
        }
        FakeKey.shared.send(fakeKey: "C", useCommandFlag: true)
    }

    @objc private func startSpeaking() {
        guard currentCharacterIndex < speechString.count else { return }

        let startIndex = speechString.index(speechString.startIndex, offsetBy: currentCharacterIndex)
        let substring = String(speechString[startIndex...])
        currentCharacterIndex = 0
        speechString = [
//            lastSpeechRate != nil && lastSpeechRate != speechRate ? "Rate \(Int(speechRate))" : nil,
            substring,
        ].compactMap { $0 }.joined(separator: ", ")

        lastSpeechRate = speechRate
        lastSpeechVolume = speechVolume
        let utterance = AVSpeechUtterance(string: speechString)
        utterance.rate = Float(speechRate)
        utterance.volume = Float(speechVolume)
        speechSynthesizer.speak(utterance)
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
