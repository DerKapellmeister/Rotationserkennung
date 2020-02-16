//
//  TouchImageView.swift
//  smartCam
//
//  Created by Jonas on 02.09.19.
//  Copyright © 2019 Jonas. All rights reserved.
//

import UIKit

class TouchImageView: UIImageView {
    
    var lineColor: UIColor!
    var lineWidth: CGFloat!
    var path: UIBezierPath!
    var touchPoint: CGPoint!
    var startPoint: CGPoint!
    var shapeLayer: CAShapeLayer!
    var requestAngle: Bool = false
    
    var firstUse = true
    
    typealias angleCallback = (_ angle: Float) -> (Void)
    var callback: angleCallback!
    
    override func layoutSubviews() {
        self.clipsToBounds = true
        self.isMultipleTouchEnabled = false
        self.isUserInteractionEnabled = true
        
        lineColor = UIColor.red.withAlphaComponent(0.4)
        lineWidth = 10

    }
    
    func drawShapeLayer(){
        if !requestAngle {
            return
        }
        
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = lineColor.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.fillColor = UIColor.clear.cgColor
        self.setNeedsLayout()
        self.layer.addSublayer(shapeLayer)
        //self.layer.replaceSublayer(shapeLayer, with: shapeLayer)

    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if !requestAngle {
            return
        }
        
        shapeLayer = CAShapeLayer()
        path = UIBezierPath()
        let touch = touches.first
        startPoint = touch?.location(in: self)
        path.lineJoinStyle = .round
        path.move(to: startPoint)
        path.addLine(to: CGPoint(x: 0, y: 0))

    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if !requestAngle {
            return
        }
        
        let touch = touches.first
        touchPoint = touch?.location(in: self)
        
        path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: touchPoint)
        
        drawShapeLayer()

    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if !requestAngle {
            return
        }

        print("Start: \(startPoint!)")
        print("End: \(touchPoint!)")
        
        let y = touchPoint.y - startPoint.y
        let x = touchPoint.x - startPoint.x
        
        let angle = atan2(x, y) - (CGFloat.pi / 2)
        print("Angle: \(angle)")

        shapeLayer = nil
        
        if requestAngle {
            requestAngle = false
            callback(Float(angle))
        }
        
        super.touchesEnded(touches, with: event)

    }
    
    func requestAngle( _ cb: @escaping angleCallback) {
        
        requestAngle = true
        callback = cb
        
    }
    
}


