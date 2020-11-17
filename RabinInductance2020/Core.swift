//
//  Core.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-12.
//

import Foundation

fileprivate let defaultWindowHtMultiplier = 1.9

struct Core:Codable {
    
    let realWindowHt:Double
    let radius:Double
    
    // The 2nd edition of DelVecchio used to say that the core window should be multiplied by 3 for the 'L' variable in all the equations. The 3rd edition just says "some multiple". I have learned that it definitely needs to be >1 but it is probably better if it is less than 3 (current default value, with only minor testing: 1.5). At 3, with enough elements, the inductance matrix is not positive-definite. Also note that it is imperative to NOT center the coils on the enlarged window (doing so seems to be the cause of negative mutual impedances. This makes some sense to me - I think that the current density calculations are based more on the "fraction of L" of the z-coordinates than on the actual height in the window. This is definitely true of the J0 calculation (which doesn't consider the actual z-coordinate within the window at all...). Experimentation continues...
    
    // Update 2020-11-06: I have recreated the J0 and Jn (1-200) calculations for STME-0400 LV winding as an Excel sheet. There are a few things that I have learned:
    //  1) As far as the DEFINITION of J0 and Jn are concerned, it does not seem to matter whether the coil(s) are centered in the window. Or, at least, there is no discernable effect on the overall calculation of J at a given point 'z' and as noted above, centering the coils seems to cause negative mutual inductances. That said, it still does not seem logical to me that the winding be uncentred.
    //  2) The same reasons for NOT centering the coils is the real reason for using some "important" multiple of the actual core window. My reasoning is this: using the real window very nearly centers the coil in the window, causing the same issue as purposely centering the coil in an enlarged window. That is, we WANT the coil to be skewed toward the bottom as far as these calculations go.
    //  3) I have not yet determined why the inductance matrix goes "non-positive-definite" when the window multiple is too large. i believe it has something to do with the small fractions (z/L) that occur, perhaps meaning that either there are zeroes occuring or equalities that should not occur somewhere. That is to say, there seems to be a "precision" problem. In particualr, it appears that for some numbers, the 'ScaledReturnType' seems to help things but not for ALL numbers. I am trying to figure out why this is happening.
    
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
