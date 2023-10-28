//
//  ContentView.swift
//  MagicMac
//
//  Created by Tom Grushka on 8/12/22.
//

import KeyboardShortcuts
import SwiftUI
import AVFoundation


struct SettingsView: View {
    @FocusState public var isFocused: Bool

    var body: some View {
        TabView {
            GeneralTab()

            ShortcutsTab()

            ReplacementsView()
                .tabItem {
                    Image(systemName: "textformat.abc.dottedunderline")
                    Text("Substitutions")
                }
            
        }
        .frame(minWidth: 450, minHeight: 400)
    }
}

extension HorizontalAlignment {
    private enum ControlAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            return context[HorizontalAlignment.center]
        }
    }
    static let controlAlignment = HorizontalAlignment(ControlAlignment.self)
}

extension Double {
    func display(places: Int = 2) -> String {
        String(format: "%.\(places)f", self)
    }
    
    func displayPercent(places: Int = 0) -> String {
        String(format: "%.\(places)f %%", self * 100)
    }
}

struct GeneralTab: View {
    @AppStorage(.speechRate) private var speechRate: Double = UserDefaults.UniversalAccess.preferredRate
    @AppStorage(.slowSpeechRate) private var slowSpeechRate: Double = UserDefaults.UniversalAccess.preferredSlowRate
    @AppStorage(.speechVolume) private var speechVolume: Double = UserDefaults.UniversalAccess.preferredVolume
    @AppStorage(.speechVoice) private var speechVoice: String = ""

    @Namespace var namespace
    
    var body: some View {
        Form {
            VStack(spacing: 20) {
                GroupBox {
                    
                    HStack(spacing: 10) {
                    
                        Slider(value: $speechRate)
                            .accessibilityLabel("Speech Rate")
                        
                        Text(speechRate.displayPercent())
                    
                        Button("Reset") {
                            speechRate = UserDefaults.UniversalAccess.preferredRate
                        }
                        
                    }
                    .padding()
                    
                } label: {
                    Text("Speech Rate")
                }
                
                
                GroupBox {
                    
                    HStack(spacing: 10) {
                    
                        Slider(value: $slowSpeechRate)
                            .accessibilityLabel("Slow Speech Rate")
                        Text(slowSpeechRate.displayPercent())
                    
                        Button("Reset") {
                            slowSpeechRate = UserDefaults.UniversalAccess.preferredSlowRate
                        }
                    }
                    .padding()
                    
                } label: {
                    Text("Slow Speech Rate")
                }
                
                
                GroupBox {
                    
                    HStack(spacing: 10) {
                    
                        Slider(value: $speechVolume)
                            .accessibilityLabel("Speech Volume")
                        Text(speechVolume.displayPercent())
                    
                        Button("Reset") {
                            speechVolume = UserDefaults.UniversalAccess.preferredVolume
                        }
                    }
                    .padding()
                    
                } label: {
                    Text("Speech Volume")
                }
                
                
                GroupBox {
                    
                    HStack(spacing: 10) {

                        Picker("Speech Voice", selection: $speechVoice) {
                            ForEach(AVSpeechSynthesisVoice.voiceIdentifiers, id: \.self) { id in
                                Text(AVSpeechSynthesisVoice.voices[id]!).tag(id)
                            }
                        }

                        Button("Reset") {
                            speechVoice = ""
                        }
                    }
                    .padding()
                    
                } label: {
                    Text("Speech Voice")
                }
                
                
            }
        }
        .tabItem {
            Image(systemName: "gear")
            Text("General")
        }
        .scenePadding()
    }
}


struct ShortcutsTab: View {
    var body: some View {
        Form {
            VStack {
                ForEach(KeyboardShortcuts.Name.allCases, id: \.self) { shortcut in
                    ShortcutRecorderView(name: shortcut)
                }
                
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
    }
}


struct ShortcutRecorderView: View {
    let name: KeyboardShortcuts.Name
    @FocusState var isFocused: Bool
    
    var body: some View {
        GeometryReader { geom in
            HStack {
                Text("\(name.displayName):")
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
