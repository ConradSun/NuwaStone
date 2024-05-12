//
//  GraphView.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/21.
//

import Cocoa

/// Trend chart of the number of events
class GraphView: NSView {
    var displayMode = DisplayMode.DisplayAll
    private var freqPointsArray = [[NSPoint]](repeating: [NSPoint(x: 0, y: 0)], count: DisplayMode.allCases.count)
    private var colorArray = [NSColor.black, NSColor.red, NSColor.blue, NSColor.green]
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.white.setFill()
        let frame = self.bounds
        
        let canvas = NSBezierPath()
        canvas.appendRoundedRect(frame, xRadius: 8, yRadius: 8)
        canvas.fill()
        drawFrepLines()
    }
    
    func addPointToLine(_ yValue: CGFloat, index: Int) {
        var point = NSPoint()
        let rate = yValue > 100 ? 1.0 : yValue / 100.0
        point.y = rate * frame.size.height
        
        if freqPointsArray[index].last!.x >= frame.size.width {
            freqPointsArray[index].removeAll(keepingCapacity: true)
            point.x = 0
        } else {
            point.x = freqPointsArray[index].last!.x + 1
        }
        
        freqPointsArray[index].append(point)
    }
    
    func drawFrepLines() {
        for (index, array) in freqPointsArray.enumerated() {
            if displayMode != .DisplayAll && displayMode.rawValue != index {
                continue
            }
            if index == DisplayMode.DisplayAll.rawValue {
                continue
            }
            
            let path = NSBezierPath()
            let color = colorArray[index]
            
            path.move(to: CGPoint(x: 0, y: 0))
            for point in array {
                path.line(to: point)
            }
            color.set()
            path.stroke()
        }
    }
}
