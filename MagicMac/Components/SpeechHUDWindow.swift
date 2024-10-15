//
//  SpeechHUDWindow.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/15/24.
//

import AVFAudio
import OSLog

class SpeechHUDWindow: NSWindow {
    private let logger = Logger(subsystem: "MagicMac", category: "SpeechHUDWindow")

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

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        logger.debug("HUD Window deinit")
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
