//
//  Core.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-12.
//

import Foundation

struct Core:Codable {
    
    let realWindowHt:Double
    let radius:Double
    
    static let windowHtMultiplier:Double = 3.0
    
    var useWindowHt:Double {
        get {
            return self.realWindowHt * Core.windowHtMultiplier
        }
    }
    
    init(realWindowHt:Double, radius:Double)
    {
        self.realWindowHt = realWindowHt
        self.radius = radius
    }
    
}
