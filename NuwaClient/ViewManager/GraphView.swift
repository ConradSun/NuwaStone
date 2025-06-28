//
//  GraphView.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/21.
//

import Cocoa

/// Trend chart of the number of events
class GraphView: NSView {
    var displayMode = DisplayMode.DisplayAll {
        didSet {
            updateLineVisibility()
        }
    }

    private var dataPoints = [[CGFloat]](repeating: [], count: DisplayMode.allCases.count - 1)
    private var lineLayers = [CAShapeLayer]()
    // red - process; blue - file; green - network
    private let lineColors = [NSColor.systemRed, NSColor.systemBlue, NSColor.systemGreen]
    private var maxDataPoints: Int = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = 8

        // Calculate max data points based on view width
        maxDataPoints = Int(bounds.width)

        // Only create line layers for event types (exclude total)
        for i in 0..<dataPoints.count {
            let lineLayer = CAShapeLayer()
            lineLayer.strokeColor = lineColors[i].cgColor
            lineLayer.fillColor = NSColor.clear.cgColor
            lineLayer.lineWidth = 1.0
            lineLayers.append(lineLayer)
            layer?.addSublayer(lineLayer)
        }
    }
    
    override func layout() {
        super.layout()
        // Recalculate on resize
        let newMax = Int(bounds.width)
        if newMax != maxDataPoints {
            maxDataPoints = newMax
            // Trim or adjust data points if necessary, then redraw
            for i in 0..<dataPoints.count {
                if dataPoints[i].count > maxDataPoints {
                    dataPoints[i] = Array(dataPoints[i].suffix(maxDataPoints))
                }
            }
        }
        updateAllLinePaths()
    }

    func addPointToLine(_ yValue: CGFloat, index: Int) {
        // Normalize yValue to a 0-1 range
        let normalizedY = min(max(yValue / 100.0, 0.0), 1.0)
        
        dataPoints[index].append(normalizedY)

        // Prune old data points if array exceeds max size
        if dataPoints[index].count > maxDataPoints {
            dataPoints[index].removeFirst()
        }
        
        updateLinePath(for: index)
    }

    private func updateLinePath(for index: Int) {
        guard index < lineLayers.count, maxDataPoints > 0 else { return }

        let path = NSBezierPath()
        let points = dataPoints[index]
        let stepX = bounds.width / CGFloat(maxDataPoints - 1)

        guard !points.isEmpty else {
            lineLayers[index].path = nil
            return
        }
        
        path.move(to: NSPoint(x: 0, y: points[0] * bounds.height))

        for (i, y) in points.enumerated().dropFirst() {
            let newX = CGFloat(i) * stepX
            let newY = y * bounds.height
            path.line(to: NSPoint(x: newX, y: newY))
        }

        lineLayers[index].path = path.cgPath
    }
    
    private func updateAllLinePaths() {
        for i in 0..<lineLayers.count {
            updateLinePath(for: i)
        }
    }

    private func updateLineVisibility() {
        // Show all lines; highlight the selected type, dim the others
        for (index, layer) in lineLayers.enumerated() {
            if displayMode == .DisplayAll {
                layer.isHidden = false
                layer.opacity = 1.0
            } else if displayMode.rawValue - 1 == index {
                layer.isHidden = false
                layer.opacity = 1.0
            } else {
                layer.isHidden = false
                layer.opacity = 0.2
            }
        }
    }
}

// Extension to convert NSBezierPath to CGPath
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }
}
