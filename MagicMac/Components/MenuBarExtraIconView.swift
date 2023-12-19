//
//  MenuBarExtraIconView.swift
//  MagicMac
//
//  Created by Tom Grushka on 10/29/23.
//

import SwiftUI

extension NSColor {
    var inverted: NSColor {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return self
        }
        return NSColor(red: 1 - rgbColor.redComponent,
                       green: 1 - rgbColor.greenComponent,
                       blue: 1 - rgbColor.blueComponent,
                       alpha: rgbColor.alphaComponent)
    }
}

extension NSImage {
    func padded(minWidth: CGFloat, alignment: Alignment = .leading) -> NSImage {
        if self.size.width >= minWidth {
            return self
        }

        let padding = minWidth - self.size.width
        let newImage = NSImage(size: NSSize(width: minWidth, height: self.size.height))

        newImage.lockFocus()
        let xOrigin: CGFloat
        switch alignment {
        case .leading:
            xOrigin = 0
        case .trailing:
            xOrigin = padding
        default:
            xOrigin = padding / 2
        }

        self.draw(at: NSPoint(x: xOrigin, y: 0),
                  from: NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height),
                  operation: .sourceOver,
                  fraction: 1)
        newImage.unlockFocus()

        return newImage
    }

    func tint(color: NSColor) -> NSImage {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return self }
        
        let rect = CGRect(origin: CGPoint.zero, size: size)
        let newImage = NSImage(size: size)
        
        newImage.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else { return self }
        context.clip(to: rect, mask: cgImage)
        color.set()
        context.fill(rect)
        newImage.unlockFocus()
        
        return newImage
    }
}

@available(macOS 14.0, *)
struct MenuBarExtraIconView: View {
    @EnvironmentObject var invertedColorManager: InvertedColorManager
    @EnvironmentObject var speechManager: SpeechManager
    
    var foregroundColor: Color? {
        if speechManager.state == .stopped {
            return nil
        }
        
        return invertedColorManager.isInverted ? .blue : .yellow
    }
    
    func smartInvert(_ color: NSColor) -> NSColor {
        invertedColorManager.isInverted ? color.inverted : color
    }
    
    var image: some View {
        let color = smartInvert(NSColor(red: 1.0, green: 0.753, blue: 0.00784, alpha: 1.0))
        let minWidth: Double = 24
        
        let symbolName: String

        switch speechManager.state {
        case .stopped:
//            return Image(invertedColorManager.isInverted ? .menuExtraInverted : .menuExtra)
            let name: NSImage.Name = invertedColorManager.isInverted ? .menuExtraInverted : .menuExtra
            return Image(nsImage: NSImage(named: name)!.tint(color: color).padded(minWidth: minWidth, alignment: .center))
        case .started:
            symbolName = "speaker.zzz.fill"
        case .speaking:
            let second = Int(Date.now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)) % 3 + 1
            symbolName = "speaker.wave.\(second).fill"
        case .paused:
            symbolName = "pause.fill"
        }

        return Image(nsImage: NSImage(systemSymbolName: symbolName, accessibilityDescription: speechManager.state.rawValue)!.tint(color: color).padded(minWidth: minWidth))
    }

    var body: some View {
        image
    }
}
