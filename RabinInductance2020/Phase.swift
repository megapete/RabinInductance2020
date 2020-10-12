//
//  Phase.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation

class Phase:Codable {
    
    let core:Core
    
    let coils:[Coil]
    
    init(realWindowHt:Double, coreRadius:Double, coils:[Coil]) {
        
        self.core = Core(realWindowHt: realWindowHt, radius: coreRadius)
        self.coils = coils
    }
}
