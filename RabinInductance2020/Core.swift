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
    
    // The 2nd edition of DelVecchio used to say that the core window should be multiplied by 3 for the 'L' variable in all the equations. The 3rd edition just says "some multiple". I have learned that it definitely needs to be >1 but it is probably better if it is less than 3 (current value: 2.5). At 3, with enough elements, the inductance matrix is not positive-definite. Also note that it is imperative to NOT center the coils on the enlarged window (doing so seems to be the cause of negative mutual impedances. Experimentation continues...
    static let windowHtMultiplier:Double = 2.5
    
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
