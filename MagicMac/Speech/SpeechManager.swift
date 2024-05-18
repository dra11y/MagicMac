//
//  SpeechManager.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/11/23.
//

import AVFoundation
import Cocoa
import Foundation
import Security
import SwiftUI
import WakeAudio

class SpeechHUDWindow: NSWindow {
    private var invertedColorManager: InvertedColorManager?
    private var textView: NSTextView?
    private var scrollView: NSScrollView?
    private var utterance: AVSpeechUtterance?

    private func computeBackgroundColor() -> NSColor {
        (isInverted ? NSColor.white : NSColor.black).withAlphaComponent(0.5)
    }

    override var canBecomeKey: Bool {
        get { true }
        set {}
    }

    private var isInverted: Bool {
        return invertedColorManager?.isInverted ?? false
    }

    private var textColor: NSColor {
        isInverted ? .black : .white
    }

    private var highlightColor: NSColor {
        isInverted ? .blue : .yellow
    }

    init(invertedColorManager: InvertedColorManager) {
        self.invertedColorManager = invertedColorManager
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect.zero
        let windowSize = CGSize(width: screenRect.width * 0.8, height: screenRect.height * 0.5)
        let windowRect = NSRect(
            x: (screenRect.width - windowSize.width) / 2 + screenRect.minX,
            y: (screenRect.height - windowSize.height) / 2 + screenRect.minY,
            width: windowSize.width,
            height: windowSize.height
        )
        
        super.init(contentRect: windowRect, styleMask: [.titled], backing: .buffered, defer: true)

        setupHUD()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("HUD Window deinit")
        for subview in contentView?.subviews ?? [] {
            subview.removeFromSuperview()
        }
        textView = nil
        scrollView = nil
        invertedColorManager = nil
    }

    private func setupHUD() {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        self.scrollView = scrollView
        self.textView = textView
        contentView!.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        ])

        isOpaque = false
        level = .floating
        styleMask = [.borderless, .nonactivatingPanel]
        isMovableByWindowBackground = true

        textView.isEditable = false
        scrollView.backgroundColor = .clear
        textView.backgroundColor = .clear
        textView.font = NSFont.monospacedSystemFont(ofSize: 36, weight: .regular)
    }

    func update(range: NSRange, utterance: AVSpeechUtterance) {
        guard let textView = textView else { return }

        if !isVisible {
            show()
        }

        backgroundColor = computeBackgroundColor()

        if utterance != self.utterance {
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
        backgroundColor = computeBackgroundColor()
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        orderOut(nil)
    }
}

public class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    let invertedColorManager: InvertedColorManager

    var hudWindow: SpeechHUDWindow?

    public enum SpeechState: String {
        case stopped
        case started
        case speaking
        case paused
    }

    @Published public var state: SpeechState = .stopped

    public func speechSynthesizer(_: AVSpeechSynthesizer, didStart _: AVSpeechUtterance) {
        state = .speaking
    }

    public func speechSynthesizer(_: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        showSpeechHUDWindowIfNeeded()
        hudWindow?.update(range: characterRange, utterance: utterance)
        state = .speaking
        currentCharacterIndex = characterRange.location
    }

    func stopSpeaking(force: Bool) {
        if force || !didChangeRate {
            speechString = ""
            currentCharacterIndex = 0
        }
        didChangeRate = false
        hudWindow?.hide()
        hudWindow = nil
        state = .stopped
    }

    public func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        stopSpeaking(force: false)
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
        observeAudioConfigurationChanged()
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

    private func observeAudioConfigurationChanged() {
        NotificationCenter.default.addObserver(self, selector: #selector(audioConfigurationDidChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: audioEngine)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioEngineConfigurationChange, object: audioEngine)
    }

    @objc private func systemWillSleep(notification _: NSNotification) {
        stopSpeaking(force: true)
        stopBackgroundSilence()
        hudWindow = nil
        speechSynthesizer.delegate = nil
    }

    @objc private func systemDidWake(notification _: NSNotification) {
        audioConfigurationDidChange()
        speechSynthesizer.delegate = self
    }

    public static func wakeAudio() {
        let isAsleep = isAudioAsleep()
        if isAsleep {
            wakeAudioInterfaces(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Self.wakeAudio()
            }
            return
        }
    }

    @objc private func screenDidWake(notification _: NSNotification) {
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer = AVSpeechSynthesizer()

        Self.wakeAudio()

        startBackgroundSilence()
    }

    @objc private func audioConfigurationDidChange(notification _: NSNotification? = nil) {
        if isAudioAsleep() {
            return
        }
        // Stop and restart the background silence to accommodate the new audio configuration
        stopSpeaking(force: true)
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
                let options: NSRegularExpression.Options = replacement.caseSensitive ? [] : [.caseInsensitive]
                guard
                    let regex = try? NSRegularExpression(pattern: replacement.pattern, options: options)
                else { continue }
                let range = NSRange(replacedText.startIndex..., in: replacedText)
                replacedText = regex.stringByReplacingMatches(in: replacedText, range: range, withTemplate: " \(replacement.replacement) ")
            } else {
                // Replace using plain text
                let options: String.CompareOptions = replacement.caseSensitive ? [.diacriticInsensitive] : [.diacriticInsensitive, .caseInsensitive]
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

    private func showSpeechHUDWindowIfNeeded() {
        if debugSpeechHUD {
            if hudWindow == nil {
                hudWindow = SpeechHUDWindow(invertedColorManager: invertedColorManager)
            }
            hudWindow!.show()
        } else {
            hudWindow?.hide()
            hudWindow = nil
        }
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
        showSpeechHUDWindowIfNeeded()
        hudWindow?.update(range: .init(), utterance: utterance)
        speechSynthesizer.speak(utterance)
    }
}
