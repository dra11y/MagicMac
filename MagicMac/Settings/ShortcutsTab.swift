//
//  ShortcutsTab.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI
import KeyboardShortcuts

struct ShortcutsTab: View {
    var body: some View {
        Form {
            VStack {
                ForEach(KeyboardShortcuts.Name.allCases, id: \.self) { shortcut in
                    ShortcutRecorderView(name: shortcut)
                }
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
