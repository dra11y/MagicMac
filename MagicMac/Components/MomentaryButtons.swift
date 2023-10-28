//
//  MomentaryButtons.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/27/23.
//

import SwiftUI

struct ButtonSegment: Identifiable {
    let id = UUID()
    let view: AnyView
    let action: () -> Void
}

struct MomentaryButtons: View {
    @State private var redrawKey = UUID()
    let segments: [ButtonSegment]

    var body: some View {
        Picker("", selection: Binding<Int>(
            get: { -1 },
            set: { value in
                redrawKey = UUID()
                segments[value].action()
            }
        )) {
            ForEach(0 ..< segments.count, id: \.self) { index in
                segments[index].view.tag(index)
            }
        }
        .pickerStyle(.palette)
        .id(redrawKey)
    }
}
