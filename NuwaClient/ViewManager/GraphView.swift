//
//  GraphView.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/21.
//

import Cocoa

class GraphView: NSView {
    var freqPointsArray = [[NSPoint]](repeating: [NSPoint(x: 0, y: 0)], count: DisplayMode.count)
    var colorArray = [NSColor.black.cgColor, NSColor.red.cgColor, NSColor.blue.cgColor, NSColor.green.cgColor]
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        
        NSColor.white.setFill()
        let frame = self.bounds
        
        let path = NSBezierPath()
        path.appendRoundedRect(frame, xRadius: 8, yRadius: 8)
        path.fill()
        drawFrepLines(context)
    }
    
    func addPointToLine(_ yValue: CGFloat, type: DisplayMode) {
        var point = NSPoint()
        point.y = yValue / 100 * frame.size.height
        
        if (freqPointsArray[type.rawValue].last!.x >= frame.size.width) {
            freqPointsArray[type.rawValue].removeAll(keepingCapacity: true)
            point.x = 0
        }
        else {
            point.x = freqPointsArray[type.rawValue].last!.x + 1
        }
        
        freqPointsArray[type.rawValue].append(point)
    }
    
    func drawFrepLines(_ context: CGContext) {
        for (index, array) in freqPointsArray.enumerated() {
            let path = CGMutablePath()
            let color = colorArray[index]
            
            path.move(to: CGPoint(x: 0, y: 0))
            for point in array {
                path.addLine(to: point)
            }
            context.setLineWidth(1.0)
            context.setStrokeColor(color)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }
    }
}
