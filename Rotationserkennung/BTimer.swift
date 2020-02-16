//
//  BTimer.swift
//  smartCam
//
//  Created by Jonas on 25.09.19.
//  Copyright © 2019 Jonas. All rights reserved.
//

import Foundation


class BTimer {
    
    private var startTime: DispatchTime?
    private var endTime: DispatchTime!
    
    func start() {
        startTime = DispatchTime.now()
    }
    
    func stop(label: String) {
        guard let startTime = startTime else {
            return
        }
        
        endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        print("TIMER \(label): \(timeInterval)")
    }
    
    func stop() {
        stop(label: "")
    }
    
}
