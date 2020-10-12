//
//  Phase.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation

class Phase:Codable {
    
    let realWindowHeight:Double
    let coreRadius:Double
    
    let coils:[Coil]
    
    init(realWindowHt:Double, coreRadius:Double, coils:[Coil]) {
        
        self.realWindowHeight = realWindowHt
        self.coreRadius = coreRadius
        self.coils = coils
    }
}
