//
//  MenuBarExtraIconView.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

@available(macOS 14.0, *)
struct MenuBarExtraIconView: View {
    @EnvironmentObject var invertedColorManager: InvertedColorManager

    var body: some View {
        Image(invertedColorManager.isInverted ? .menuExtraInverted : .menuExtra)
    }
}
