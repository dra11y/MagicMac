//
//  ContentView.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import KeyboardShortcuts
import SwiftUI

extension HorizontalAlignment {
    private enum ControlAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            return context[HorizontalAlignment.center]
        }
    }
    static let controlAlignment = HorizontalAlignment(ControlAlignment.self)
}


struct SettingsView: View {
    @FocusState public var isFocused: Bool
    @AppStorage("speechRate") private var speechRate: Double = 100
    
    var body: some View {
        TabView {
            Form {
                VStack {
                    HStack {
                        Slider(value: $speechRate, in: 100.0...300.0)
                        Text("\(Int(speechRate.rounded()))")
                    }
                    .padding()
                }
            }
            .tabItem {
                Image(systemName: "gear")
                Text("General")
            }

            Form {
                VStack {
                    ShortcutRecorderView(label: "Toggle Appearance:", name: .toggleAppearance)
                    ShortcutRecorderView(label: "Invert Colors:", name: .invertColors)
                    ShortcutRecorderView(label: "Toggle Hover Speech:", name: .hoverSpeech)
                    ShortcutRecorderView(label: "Maximize Window:", name: .maximizeFrontWindow)
                    ShortcutRecorderView(label: "Increase Brightness:", name: .increaseBrightness)
                    ShortcutRecorderView(label: "Decrease Brightness:", name: .decreaseBrightness)
                    ShortcutRecorderView(label: "Speak Selection:", name: .speakSelection)
                    
                    Button("Quit") {
                        NSApp.terminate(self)
                    }
                    .padding([.top, .bottom], 10)
                }.padding()
            }
            .tabItem {
                Image(systemName: "keyboard")
                Text("Shortcuts")
            }
            
            //            .onReceive(NotificationCenter.default.publisher(
            //                for: NSWindow.didBecomeKeyNotification), perform: { _ in
            //                    DispatchQueue.main.async {
            //                        self.isFocused = false
            //                    }
            //                })
            
            ReplacementsView()
                .tabItem {
                    Image(systemName: "textformat.abc.dottedunderline")
                    Text("Substitutions")
                }
            
        }
        .frame(minHeight: 400)
    }
}

struct ShortcutRecorderView: View {
    let label: String
    let name: KeyboardShortcuts.Name
    @FocusState var isFocused: Bool
    
    var body: some View {
        GeometryReader { geom in
            HStack {
                Text(label)
                    .frame(maxWidth: geom.size.width / 2, alignment: .trailing)
                KeyboardShortcuts.Recorder("", name: name)
                    .focused($isFocused, equals: true)
            }
            .padding(.top, 10)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

//        .onReceive(NotificationCenter.default.publisher(
//            for: NSWindow.didResignKeyNotification), perform: { _ in
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    self.isFocused = false
//                }
//            })
