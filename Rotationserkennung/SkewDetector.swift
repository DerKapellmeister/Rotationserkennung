//
//  SkewDetector.swift
//  smartCam
//
//  Created by Jonas on 12.01.20.
//  Copyright © 2019 Jonas. All rights reserved.
//

import Foundation
import UIKit
import Vision
import Contacts
import Accelerate


class SkewDetector {
    
    typealias SkewDetectDoneHandler = (UIImage?) -> Void
    
    let callback: SkewDetectDoneHandler!
    
    let btimer = BTimer()
    
    init(doneHandler: @escaping SkewDetectDoneHandler) {
        callback = doneHandler
    }
    
    
    func detectSkew(img: UIImage) {
                
                
        let cc_label = CcLabel()
        let cgImage = img.cgImage!
        
        
        let binarization: ImageBinarization! = ImageBinarization()

        guard let uiImage = binarization.threshold(image: cgImage) else {
            return
        }

        let labelledData = cc_label.labelImageFast(image: uiImage, calculateBoundingBoxes: true)
        
        var centerPointArray: [CGPoint] = []
        
        if var boundingBoxes = labelledData.boundingBoxes {
            
            var avg_size = 0
            
            
            for bb in boundingBoxes {
                
                let bb_height = bb.value.getHeight()
                let bb_width = bb.value.getWidth()

                if (bb_height * 10) < bb_width
                || (bb_width * 10) < bb_height
                || (bb_height / 10) > bb_width
                || (bb_width / 10) > bb_height
                || bb_height < 12
                && bb_width < 10
                {
                    boundingBoxes.removeValue(forKey: bb.key)
                    continue
                }
                
                avg_size += bb.value.getSize()
            }
            avg_size = avg_size / boundingBoxes.count
            print("AVG SIZE: \(avg_size)")
            
            UIGraphicsBeginImageContext(uiImage.size)
            
            uiImage.draw(at: CGPoint.zero)
            
            let context = UIGraphicsGetCurrentContext()!

            for bb in boundingBoxes {
                
                let bb = bb.value
                
                let size = bb.getSize()
                
                                
                let centerX = bb.x_start + ( (bb.x_end - bb.x_start) / 2 )
                let centerY = bb.y_start + ( (bb.y_end - bb.y_start) / 2 )
                let centerPoint = CGPoint(x: centerX, y: centerY)
                centerPointArray.append(centerPoint)
                
                let rect = CGRect(x: bb.x_start, y: bb.y_start, width: bb.getWidth(), height: bb.getHeight())
                let rectCenter = CGRect(x: centerX-2, y: centerY-2, width: 4, height: 4)

                
                context.setStrokeColor(UIColor.red.cgColor)
                context.setAlpha(1)
                context.setLineWidth(2.0)
                context.setFillColor(UIColor.red.cgColor)
                context.addRect(rectCenter)
                context.drawPath(using: .stroke)

                context.setStrokeColor(UIColor.green.cgColor)
                context.setAlpha(1)
                context.setLineWidth(2.0)
                context.addRect(rect)
                context.drawPath(using: .stroke)

                
            }
            
            if let myImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIImageWriteToSavedPhotosAlbum(myImage, nil, nil, nil)
            }

            UIGraphicsEndImageContext()

        }
        
        //UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        
        var angleHistogram = [Int](repeating: 0, count: 180)
        
        var curPoint = centerPointArray.removeFirst()
                
        while !centerPointArray.isEmpty {
                        
            var distMin: CGFloat = 999999
            var minDistPoint = curPoint
            var minDistPointIdx = 0
                        
            for nextPoint in centerPointArray.enumerated() {

                let point = nextPoint.element
                let dist = distance(from: curPoint, to: point)
                if dist < distMin {
                    distMin = dist
                    minDistPoint = point
                    minDistPointIdx = nextPoint.offset
                }
            }
            
            centerPointArray.remove(at: minDistPointIdx)
            
            var angleRad: CGFloat = 0
            if curPoint.x < minDistPoint.x {
                angleRad = atan2(
                    (minDistPoint.x - curPoint.x),
                    (minDistPoint.y - curPoint.y)
                )
            }else{
                angleRad = atan2(
                    (curPoint.x - minDistPoint.x),
                    (curPoint.y - minDistPoint.y)
                )
            }
            
            var angleDeg = radToDeg(angleRad)
            if angleDeg == 180 { angleDeg = 0 }
            
            angleHistogram[angleDeg] += 1
            
            curPoint = minDistPoint
            
        }
                
        var maxAngle = 0

        for angle in angleHistogram.enumerated() {
            if angle.element > angleHistogram[maxAngle] {
                maxAngle = angle.offset
            }
        }
        
        maxAngle -= 90
        let angleRadians = degToRad(maxAngle)
        
        if let skewFixedImage = img.rotate(radians: angleRadians) {
            UIImageWriteToSavedPhotosAlbum(skewFixedImage, nil, nil, nil)
            callback(skewFixedImage)
            return
        }
        
        
        callback(nil)
        
    }
    
    func radToDeg(_ angle: CGFloat) -> Int {
        return abs( Int( (angle * 180 / .pi).rounded() ) )
    }
    
    func degToRad(_ angle: Int) -> Float {
        return Float(angle) * .pi / 180
    }
    
    func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let xDistance = lhs.x - rhs.x
        let yDistance = lhs.y - rhs.y
        return (xDistance * xDistance + yDistance * yDistance).squareRoot()
    }
        
            
}
