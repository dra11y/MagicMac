//
//  ContentView.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
//    enum FocusField {
//        case invertColors
//        case hoverSpeech
//        case maximizeFrontWindow
//        case increaseBrightness
//        case decreaseBrightness
//    }

//    @FocusState public var focus: FocusField?
    @FocusState public var isFocused: Bool

    var body: some View {
        Form {
            VStack {
                KeyboardShortcuts.Recorder("Toggle Appearance:", name: .toggleAppearance)
                    .padding()
                    .focused($isFocused, equals: true)

                KeyboardShortcuts.Recorder("Invert Colors:", name: .invertColors)
                    .padding()

                KeyboardShortcuts.Recorder("Toggle Hover Speech:", name: .hoverSpeech)
                    .padding()

                KeyboardShortcuts.Recorder("Maximize Window:", name: .maximizeFrontWindow)
                    .padding()

                KeyboardShortcuts.Recorder("Increase Brightness:", name: .increaseBrightness)
                    .padding()

                KeyboardShortcuts.Recorder("Decrease Brightness:", name: .decreaseBrightness)
                    .padding()

                Button("Quit") {
                    NSApp.terminate(self)
                }
            }.padding()
        }.padding()
        
        .onReceive(NotificationCenter.default.publisher(
            for: NSWindow.didBecomeKeyNotification), perform: { _ in
                DispatchQueue.main.async {
                    self.isFocused = false
                }
            })

//        .onReceive(NotificationCenter.default.publisher(
//            for: NSWindow.didResignKeyNotification), perform: { _ in
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    self.isFocused = false
//                }
//            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
