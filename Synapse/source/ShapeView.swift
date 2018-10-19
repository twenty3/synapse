//
//  ShapeView.swift
//  Synapse
//
//  Created by 23 on 10/19/18.
//  Copyright © 2018 Escape Plan. All rights reserved.
//

import UIKit

class ShapeView: UIView {

    init(frame: CGRect, shape: Shape) {
        self.shape = shape
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.shape = .square
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .clear
    }
    
    private var shape: Shape
    
    override func draw(_ rect: CGRect) {
        
        let strokeWidth: CGFloat = 4.0
        let pathBounds = rect.insetBy(dx: strokeWidth, dy: strokeWidth)
        let path: UIBezierPath
        switch shape {
        case .square: path = UIBezierPath(roundedRect: pathBounds, cornerRadius: 5.0)
        case .circle: path = UIBezierPath(ovalIn: pathBounds)
        case .triangle: path = UIBezierPath(triangle: pathBounds)
        default: path = UIBezierPath(rect: pathBounds)
        }
        
        UIColor.white.withAlphaComponent(0.25).set()
        path.fill()
        
        UIColor.white.set()
        let pattern: [CGFloat] = [5.0, 5.0]
        path.setLineDash(pattern, count: 2, phase: 0)
        path.lineWidth = strokeWidth
        path.stroke()
    }

}

extension UIBezierPath {
    public convenience init(triangle rect: CGRect) {
        self.init()
        move(to: CGPoint(x: rect.midX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        close()
    }
}
