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

class SpeechHUDWindow: NSWindow {
    private let invertedColorManager: InvertedColorManager
    private let textView: NSTextView
    private var utterance: AVSpeechUtterance?

    private func computeBackgroundColor() -> NSColor {
        (isInverted ? NSColor.white : NSColor.black).withAlphaComponent(0.5)
    }
    
    private var isInverted: Bool {
        invertedColorManager.isInverted
    }
    
    private var textColor: NSColor {
        isInverted ? .black : .white
    }

    private var highlightColor: NSColor {
        isInverted ? .blue : .yellow
    }
    
    // Custom initializer with dependency
    init(invertedColorManager: InvertedColorManager) {
        self.invertedColorManager = invertedColorManager
        self.textView = NSTextView()

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect.zero
        let windowSize = CGSize(width: screenRect.width * 0.8, height: screenRect.height * 0.5)
        let windowRect = NSRect(
            x: (screenRect.width - windowSize.width) / 2 + screenRect.minX,
            y: (screenRect.height - windowSize.height) / 2 + screenRect.minY,
            width: windowSize.width,
            height: windowSize.height
        )

        super.init(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: false)
        setupHUD()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHUD() {
        contentView!.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            textView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
        ])
        
        isOpaque = false
        level = .floating
        styleMask = [.borderless, .nonactivatingPanel]
        isMovableByWindowBackground = true

        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 30)
    }
    
    func update(range: NSRange, utterance: AVSpeechUtterance) {
        
        if !isVisible {
            show()
        }

        backgroundColor = computeBackgroundColor()

        if (utterance != self.utterance) {
            self.utterance = utterance
            textView.string = utterance.speechString
        }

        textView.scrollRangeToVisible(range)
        
        // Remove existing highlights
        let entireRange = NSRange(location: 0, length: textView.string.count)
        textView.textStorage?.removeAttribute(.backgroundColor, range: entireRange)
        textView.textStorage?.removeAttribute(.foregroundColor, range: entireRange)

        textView.textColor = textColor

        // Apply custom highlight
        textView.textStorage?.addAttribute(.backgroundColor, value: highlightColor, range: range)
        textView.textStorage?.addAttribute(.foregroundColor, value: textColor.inverted, range: range)
    }

    func show() {
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        self.orderOut(nil)
    }
}

public class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    let invertedColorManager: InvertedColorManager

    lazy var hudWindow = SpeechHUDWindow(invertedColorManager: invertedColorManager)

    public enum SpeechState: String {
        case stopped
        case started
        case speaking
        case paused
    }
    
    @Published public var state: SpeechState = .stopped

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
//        print("did start speaking")
        state = .speaking
    }
    
    public func speechSynthesizer(_: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
//        print("willSpeakRangeOfSpeechString: \(characterRange) of utterance: \(utterance)")
        if debugSpeechHUD {
            hudWindow.update(range: characterRange, utterance: utterance)
        } else if hudWindow.isVisible {
            hudWindow.hide()
        }
        state = .speaking
        currentCharacterIndex = characterRange.location
    }

    public func speechSynthesizer(_: AVSpeechSynthesizer, didFinish: AVSpeechUtterance) {
        if !didChangeRate {
            speechString = ""
            currentCharacterIndex = 0
        }
        didChangeRate = false
        hudWindow.hide()
        state = .stopped
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
    @AppStorage(.debugSpeechHUD) private var debugSpeechHUD: Bool = false

    init(invertedColorManager: InvertedColorManager) {
        self.invertedColorManager = invertedColorManager
        
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
        print("\n\n\n[WAKEAUDIO] *** systemDidWake *** \(Date.now)\n\n\n")
    }
    
    public static func wakeAudio() {
//        print("[WAKEAUDIO] \(Date.now) Checking if audio is asleep...")
        let isAsleep = isAudioAsleep()
        if isAsleep {
//            print("[WAKEAUDIO] \(Date.now) Waking audio...")
            wakeAudioInterfaces(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Self.wakeAudio()
            }
            return
        }
//        print("[WAKEAUDIO] \(Date.now) Audio is awake!")
    }
    
    @objc private func screenDidWake(notification _: NSNotification) {
//        print("\n\n\n[WAKEAUDIO] *** screenDidWake *** \(Date.now)\n\n\n")

        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer = AVSpeechSynthesizer()
        
        Self.wakeAudio()

        startBackgroundSilence()
    }

    @objc private func audioConfigurationDidChange(notification _: NSNotification) {
//        print("[WAKEAUDIO] audioConfigurationDidChange \(Date.now)")
        if isAudioAsleep() {
            return;
        }
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

    private var speechSynthesizer = AVSpeechSynthesizer()

    private let pasteboardObserver = PasteboardObserver()

    private let replacementsManager = ReplacementsManager.shared

    private var speechString: String = ""
    private var currentCharacterIndex: Int = 0
    private var speechRateChangeTimer: Timer?

    private func replaceText(_ text: String) -> String {
        if !enableReplacements {
            /// We must "escape" left double square brackets `[[`
            return text.replacingOccurrences(of: "[[", with: "[ [")
        }

        /// Initially escape double left square brackets.
        var replacedText = text.replacingOccurrences(of: "[[", with: "[ [")

        replacementsManager.reloadReplacements()
        let replacements = replacementsManager.replacements.filter { replacement in
            replacement.isEnabled
        }

        // Apply replacements
        for replacement in replacements {
            if replacement.isRegex {
                /// Replace using regex
                let options: NSRegularExpression.Options = replacement.ignoreCase ? [.caseInsensitive] : []
                guard
                    let regex = try? NSRegularExpression(pattern: replacement.pattern, options: options)
                else { continue }
                let range = NSRange(replacedText.startIndex..., in: replacedText)
                replacedText = regex.stringByReplacingMatches(in: replacedText, range: range, withTemplate: " \(replacement.replacement) ")
            } else {
                // Replace using plain text
                let options: String.CompareOptions = replacement.ignoreCase ? [.caseInsensitive, .diacriticInsensitive] : [.diacriticInsensitive]
                replacedText = replacedText.replacingOccurrences(of: replacement.pattern, with: " \(replacement.replacement) ", options: options)
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
        
        state = .started

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
        if debugSpeechHUD {
            hudWindow.show()
        }
        speechSynthesizer.speak(utterance)
    }
}
