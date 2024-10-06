import AVFoundation
import Cocoa
import OSLog
import ServiceManagement
import SwiftUI
import WakeAudio

final class MagicMacAppState: ObservableObject {
    @Published var observers: [NSObjectProtocol] = []

    let logger = Logger(subsystem: "MagicMac", category: "MagicMacApp")
    let invertedColorManager = InvertedColorManager()
    lazy var speechManager = SpeechManager(invertedColorManager: invertedColorManager)
    let dimmer = DisplayDimmer()

    @AppStorage(.speechRate) var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.speechVolume) var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) var speechVoice: String = UserDefaults.UniversalAccess.preferredVoice ?? ""

    lazy var keyboardShortcutsManager = KeyboardShortcutsManager(
        invertedColorManager: invertedColorManager,
        speechManager: speechManager,
        dimmer: dimmer
    )

    lazy var synth = AVSpeechSynthesizer()

    lazy var mouseBatteryWarnTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
        self?.warnMouseBatteryLevel()
    }

    init() {
        keyboardShortcutsManager.enableShortcuts()
    }

    func warnMouseBatteryLevel() {
        let (mouse: mousePercent, keyboard: keyboardPercent) = getBatteryLevels()
        var deadline: DispatchTime = .now()
        for value in [(mousePercent, "Mouse"), (keyboardPercent, "Keyboard")] {
            guard let percent = value.0 else { continue }
            if percent < 25 {
                logger.debug("WARN \(value.1) BATTERY \(percent) \(self.synth.debugDescription)")
                let speechString = "\(value.1) battery at \(percent) percent."
                let utterance = AVSpeechUtterance(string: speechString)
                utterance.rate = Float(speechRate)
                utterance.volume = Float(speechVolume)
                if !speechVoice.isEmpty {
                    utterance.voice = AVSpeechSynthesisVoice(identifier: speechVoice)
                }
                DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
                    self?.synth.speak(utterance)
                }
                deadline = deadline.advanced(by: .seconds(5))
            }
        }
    }
}
