//
//  CustomGroupBox.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

struct CustomGroupBox<Content: View>: View {
    var label: String
    var resetAction: (() -> Void)?
    var content: Content

    init(label: String, resetAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.resetAction = resetAction
        self.content = content()
    }

    var body: some View {
        GroupBox {
            HStack(spacing: 10) {
                content
                if let resetAction = resetAction {
                    Spacer()
                    Button("Reset", action: resetAction)
                }
            }
            .padding()
        } label: {
            Text(label)
        }
    }
}
