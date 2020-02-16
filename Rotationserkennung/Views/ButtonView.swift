//
//  ButtonView.swift
//  camSave
//
//  Created by Jonas on 04.07.19.
//  Copyright © 2019 Jonas. All rights reserved.
//

import UIKit

class ButtonView: UIButton {
    
    let gradientLayer = CAGradientLayer()
    let gradient = [
        
        [
            UIColor(red:0.93, green:0.42, blue:0.00, alpha:1.0).cgColor,
            UIColor(red:0.88, green:0.21, blue:0.00, alpha:1.0).cgColor
        ],
        [
            UIColor(red:0.93, green:0.0, blue:0.42, alpha:1.0).cgColor,
            UIColor(red:0.84, green:0, blue:0.23, alpha:1.0).cgColor
        ]
    ]
    
    var animRunning = false
    var resetAnim = false
    var requestRunning = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    func setupView(){
        self.layer.shadowRadius = 7
        self.layer.shadowOpacity = 0.1
        self.layer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        self.layer.masksToBounds =  false
        self.layer.cornerRadius = 10
        self.clipsToBounds =  false
        
        gradientLayer.frame = self.bounds
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.2)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = 10
        gradientLayer.colors = gradient[1]

        self.layer.insertSublayer(gradientLayer, at: 0)


    }
    
    // TODO: Try to offload touch event into exposed IBAction?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
//        if(!requestRunning) {
            animShrink()
//        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
//        if(requestRunning){
//            return
//        }
        animReset()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
//        if(requestRunning){
//            return
//        }
        animReset()
    }

    public func animShrink(){
//        animRunning = true
//        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut,animations: {
//            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
//            //self.frontLayer.backgroundColor = UIColor(red:0, green:0, blue:0, alpha:0.25).cgColor
//        }, completion: { result in
//            self.animRunning = false
//            if(self.resetAnim){
//                self.animReset()
//            }
//        })
        
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut,animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    public func animReset(){
//        if(animRunning){
//            resetAnim = true
//        }else{
//            resetAnim = false
//            UIView.animate(withDuration: 0.14, animations: {
//                self.transform = CGAffineTransform.identity
//                //self.frontLayer.backgroundColor = UIColor(red:0, green:0, blue:0, alpha:0).cgColor
//            })
//        }
        
        
        UIView.animate(withDuration: 0.14, animations: {
            self.transform = CGAffineTransform.identity
        })

        
    }

    
    
}
