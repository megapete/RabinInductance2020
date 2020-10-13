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
    
    var parent:Coil?
    
    var inNode:Int
    var outNode:Int
    
    init(sectionID:Int, zMin:Double, zMax:Double, N:Double, inNode:Int, outNode:Int, parent:Coil? = nil) {
        
        ZAssert(zMax >= zMin, message: "Illegal z-values")
        
        self.sectionID = sectionID
        self.zMin = zMin
        self.zMax = zMax
        self.N = N
        self.inNode = inNode
        self.outNode = outNode
        self.parent = parent
    }
    
    func J(I:Double, radialBuild:Double) -> Double
    {
        let result = I * self.N / (radialBuild * (self.zMax - self.zMin))
        
        return result
    }
    
    /// DelVecchio 3e, Eq. 9.14
    func Jn(n:Int, J:Double, L:Double) -> Double
    {
        if n == 0
        {
            return J * (self.zMax - self.zMin) / L
        }
        
        let doubleN = Double(n)
        let result = 2 * J / (doubleN * π) * (sin(doubleN * π * self.zMax / L) - sin(doubleN * π * self.zMin / L))
        
        return result
    }
    
    /// DelVecchio 3e, Eq. 9.98
    func SelfInductance() -> Double
    {
        guard let coil = self.parent else
        {
            ALog("Parent coil has not been set!")
            return -Double.greatestFiniteMagnitude
        }
        
        let N = self.N
        let I = coil.I
        let L = coil.core.useWindowHt
        let r1 = coil.innerRadius
        let r2 = coil.outerRadius
        let J = self.J(I: I, radialBuild: r2 - r1)
        
        var result = π * µ0 * N * N / (6 * L) * ((r2 + r1) * (r2 + r1) + 2 * r1 * r1)
        
        var sum = 0.0
        for i in 0..<convergenceIterations
        {
            let n = i + 1
            
            let m = Double(n) * π / L
            let x1 = m * r1
            let x2 = m * r2
            let xc = m * coil.core.radius
            
            let Jn = self.Jn(n: n, J: J, L: L)
            
            let firstProduct = coil.En[i] * coil.I1n[i]
            let secondProduct = coil.Fn[i] * coil.Cn[i]
            let thirdProduct = (π / 2) * coil.L1n[i]
            
        }
        
        return result
    }
    
    
}
