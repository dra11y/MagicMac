//
//  SpeechManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import AVFoundation
import Cocoa
import Foundation
import SwiftUI
import Security
import WakeAudio

public class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance _: AVSpeechUtterance) {
        currentCharacterIndex = characterRange.location
    }

    public func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        if !didChangeRate {
            speechString = ""
            currentCharacterIndex = 0
        }
        didChangeRate = false
    }

    var lastSpeechRate: Double?
    var lastSpeechVolume: Double?

    var didChangeRate: Bool = false
    var speakSlowly: Bool = false

    @AppStorage(.speechRate) private var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) private var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) private var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) private var speechVoice: String = ""
    @AppStorage(.enableReplacements) private var enableReplacements: Bool = true

    static let shared = SpeechManager()

    override private init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(speechRateChanged), name: UserDefaults.didChangeNotification, object: nil)

        startBackgroundSilence()
        observeSleepWakeNotifications()
        observeAudioConfigurationChanges()
        speechSynthesizer.delegate = self
    }

    @objc private func speechRateChanged(notification _: NSNotification) {
        if speechRate == lastSpeechRate, speechVolume == lastSpeechVolume {
            return
        }

        speechRateChangeTimer?.invalidate()
        speechRateChangeTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(changeSpeechRate), userInfo: nil, repeats: false)
    }

    @objc private func changeSpeechRate() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        didChangeRate = true

        startSpeaking()
    }

    private func observeSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
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

    @objc private func systemWillSleep(notification _: NSNotification) {
        stopBackgroundSilence()
    }

    @objc private func systemDidWake(notification _: NSNotification) {
        print("systemDidWake \(Date.now)")
    }

    @objc private func screenDidWake(notification _: NSNotification) {
        print("screenDidWake \(Date.now)")

        print("wake getting isAudioAsleep \(Date.now)")
        let asleep = isAudioAsleep()
        print("wake isAudioAsleep = \(asleep) \(Date.now)")

        if asleep {
            print("wake audio interfaces... \(Date.now)")
            wakeAudioInterfaces()
            print("wake done! \(Date.now)")
        }

        startBackgroundSilence()
    }

    @objc private func audioConfigurationDidChange(notification _: NSNotification) {
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

        for channel in 0 ..< channelCount {
            let channelData = floatChannelData[channel]
            for frame in 0 ..< frames {
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
        if !enableReplacements {
            return text
        }

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

        speakSlowly = slow
        startCopyText()
    }

    private func startCopyText() {
        let archive = NSPasteboard.general.save()
        pasteboardObserver.startObserving(interval: 0.01) { [weak self] in
            guard
                let self,
                let text = NSPasteboard.general.string(forType: .string)
            else { return }

            pasteboardObserver.stopObserving()
            speechString = replaceText(text)
            currentCharacterIndex = 0
            startSpeaking()
            NSPasteboard.general.restore(archive: archive)
        }
        FakeKey.shared.send(fakeKey: "C", useCommandFlag: true)
    }

    private func startSpeaking() {
        guard currentCharacterIndex < speechString.count else { return }

        let startIndex = speechString.index(speechString.startIndex, offsetBy: currentCharacterIndex)
        let substring = String(speechString[startIndex...])
        speechString = substring
        currentCharacterIndex = 0

        let rate = speakSlowly ? slowSpeechRate : speechRate

        lastSpeechRate = rate
        lastSpeechVolume = speechVolume
        let utterance = AVSpeechUtterance(string: speechString)
        utterance.rate = Float(rate)
        utterance.volume = Float(speechVolume)
        if !speechVoice.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: speechVoice)
        }
        speechSynthesizer.speak(utterance)
    }
}
