//
//  PasteboardObserver.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import Foundation

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
            guard let self else { return }
            guard let timer, timer.isValid else { return }

            let elapsedTime = timer.fireDate.timeIntervalSince(startTime)
            guard elapsedTime < timeout else {
                self.timer?.invalidate()
                return
            }

            let changeCount = NSPasteboard.general.changeCount
            guard changeCount != lastChangeCount else { return }

            handler()
            lastChangeCount = changeCount
        }
        timer?.fire()
    }

    func stopObserving() {
        timer?.invalidate()
        timer = nil
    }
}
