//
//  Core.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-12.
//

import Foundation

fileprivate let defaultWindowHtMultiplier = 1.5

struct Core:Codable {
    
    let realWindowHt:Double
    let radius:Double
    
    // The 2nd edition of DelVecchio used to say that the core window should be multiplied by 3 for the 'L' variable in all the equations. The 3rd edition just says "some multiple". I have learned that it definitely needs to be >1 but it is probably better if it is less than 3 (current default value, with only minor testing: 1.5). At 3, with enough elements, the inductance matrix is not positive-definite. Also note that it is imperative to NOT center the coils on the enlarged window (doing so seems to be the cause of negative mutual impedances. This makes some sense to me - I think that the current density calculations are based more on the "fraction of L" of the z-coordinates than on the actual height in the window. This is definitely true of the J0 calculation (which doesn't consider the actual z-coordinate within the window at all...). Experimentation continues...
    var windowHtMultiplier:Double
    
    var useWindowHt:Double {
        get {
            return self.realWindowHt * self.windowHtMultiplier
        }
    }
    
    init(realWindowHt:Double, radius:Double, windowMultiplier:Double = defaultWindowHtMultiplier)
    {
        self.realWindowHt = realWindowHt
        self.radius = radius
        self.windowHtMultiplier = windowMultiplier
    }
    
}
