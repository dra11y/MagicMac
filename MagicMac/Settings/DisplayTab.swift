//
//  DisplayTab.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

struct DisplayTab: View {
    @AppStorage(.invertColorsDelay) var invertColorsDelay: Double = 0
    @AppStorage(.switchThemeDelay) var switchThemeDelay: Double = 0
    
    var body: some View {
        Form {
            CustomGroupBox(label: "Invert Colors Delay", resetAction: { invertColorsDelay = 0 }) {
                Slider(value: $invertColorsDelay, in: 0.0...0.2)
                Text(invertColorsDelay.display(places: 3))
            }
            
            CustomGroupBox(label: "Switch Theme Delay", resetAction: { switchThemeDelay = 0 }) {
                Slider(value: $switchThemeDelay, in: 0.0...0.2)
                Text(switchThemeDelay.display(places: 3))
            }
            
            Spacer()
        }
        .scenePadding()
        .tabItem {
            Image(systemName: "display")
            Text("Display")
        }
    }
}

