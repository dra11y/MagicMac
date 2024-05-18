////
////  Overlay.swift
////  MagicMac
////
////  Created by Tom Grushka on 4/20/24.
////
//
//import Cocoa
//
//class SelectionView: NSView {
//    var startPoint : NSPoint!
//    var shapeLayer : CAShapeLayer!
//
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
//
//    override func mouseDown(with event: NSEvent) {
//        self.startPoint = self.convert(event.locationInWindow, from: nil)
//
//        shapeLayer = CAShapeLayer()
//        shapeLayer.lineWidth = 1.0
//        shapeLayer.fillColor = NSColor.clear.cgColor
//        shapeLayer.strokeColor = NSColor.black.cgColor
//        shapeLayer.lineDashPattern = [10,5]
//        self.layer?.addSublayer(shapeLayer)
//
//        var dashAnimation = CABasicAnimation()
//        dashAnimation = CABasicAnimation(keyPath: "lineDashPhase")
//        dashAnimation.duration = 0.75
//        dashAnimation.fromValue = 0.0
//        dashAnimation.toValue = 15.0
//        dashAnimation.repeatCount = .infinity
//        shapeLayer.add(dashAnimation, forKey: "linePhase")
//    }
//
//    override func mouseDragged(with event: NSEvent) {
//        let point : NSPoint = self.convert(event.locationInWindow, from: nil)
//        let path = CGMutablePath()
//        path.move(to: self.startPoint)
//        path.addLine(to: NSPoint(x: self.startPoint.x, y: point.y))
//        path.addLine(to: point)
//        path.addLine(to: NSPoint(x:point.x,y:self.startPoint.y))
//        path.closeSubpath()
//        self.shapeLayer.path = path
//    }
//
//    override func mouseUp(with event: NSEvent) {
//        self.shapeLayer.removeFromSuperlayer()
//        self.shapeLayer = nil
//    }
//}
//
//class SelectionWindow: NSWindow {
//    override var canBecomeKey: Bool {
//        return true
//    }
//
//    override var canBecomeMain: Bool {
//        return true
//    }
//}
//
//class SelectionViewController: NSWindowController {
//    override func windowDidLoad() {
//        super.windowDidLoad()
//        guard let window = window else { return }
//        window.isOpaque = false
//        window.backgroundColor = NSColor.yellow
//        window.level = .screenSaver
//        let frame = window.contentRect(forFrameRect: NSScreen.main!.visibleFrame)
//        window.contentView = SelectionView(frame: frame)
//    }
//}
