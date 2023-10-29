//
//  SettingsView.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import AVFoundation
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @FocusState public var isFocused: Bool

    var body: some View {
        TabView {
            SpeechTab()

            ShortcutsTab()

            ReplacementsView()
        }
        .frame(minWidth: 450, minHeight: 400)
    }
}
