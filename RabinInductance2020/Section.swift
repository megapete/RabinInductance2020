//
//  Section.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation

class Section:Codable {
    
    let sectionID:Int
    let zMin:Double
    let zMax:Double
    let N:Double
    
    var inNode:Int
    var outNode:Int
    
    init(sectionID:Int, zMin:Double, zMax:Double, N:Double, inNode:Int, outNode:Int) {
        
        ZAssert(zMax >= zMin, message: "Illegal z-values")
        
        self.sectionID = sectionID
        self.zMin = zMin
        self.zMax = zMax
        self.N = N
        self.inNode = inNode
        self.outNode = outNode
    }
    
    /// DelVecchio 3e, Eq. 9.14
    func J(n:Int, J:Double, L:Double) -> Double
    {
        if n == 0
        {
            return J * (self.zMax - self.zMin) / L
        }
        
        let doubleN = Double(n)
        let result = 2 * J / (doubleN * π) * (sin(doubleN * π * self.zMax / L) - sin(doubleN * π * self.zMin / L))
        
        return result
    }
    
    
}
