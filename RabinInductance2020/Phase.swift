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
    
    
    
    /// DelVecchio 3e, Eq. 4.20
    func Energy() -> Double
    {
        var sumLI = 0.0
        var sumMII = 0.0
        
        var allSections = self.AllSections()
        
        while allSections.count > 0
        {
            let nextSection = allSections.removeFirst()
            let nextParent = nextSection.parent!
            
            sumLI += nextSection.SelfInductance() * nextParent.I * nextParent.I
            
            for otherSection in allSections
            {
                let otherParent = otherSection.parent!
                
                let sign = nextParent.currentDirection == otherParent.currentDirection ? 1.0 : -1.0
                
                sumMII += nextSection.MutualInductanceTo(otherSection: otherSection) * nextParent.I * otherParent.I * sign
            }
        }
        
        return 0.5 * sumLI + sumMII
    }
    
    func AllSections() -> [Section]
    {
        var result:[Section] = []
        
        for nextCoil in coils
        {
            result.append(contentsOf: nextCoil.sections)
        }
        
        return result
    }
}
