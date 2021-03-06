//
//  Section.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation

class Section:Codable {
    
    private static var nextSerialNumberStore:Int = 0
    
    static var nextSerialNumber:Int {
        get {
            
            let nextNum = Section.nextSerialNumberStore
            Section.nextSerialNumberStore += 1
            return nextNum
        }
    }
    
    let sectionID:Int
    let zMin:Double
    let zMax:Double
    let N:Double
    
    var Jn:[Double] = []
    
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
    
    /// Function to initilaize the J-values so that we don't need to calculate them every time through the "infinite" loops. Do not call this function if the 'parent' property has not been set.
    func InitializeJn()
    {
        guard let coil = self.parent else
        {
            DLog("The parent property must be set to use this function")
            return
        }
        
        let I = coil.I
        let radBuild = coil.radialBuild
        let L = coil.core.useWindowHt
        
        let J = self.J(I: I, radialBuild: radBuild)
        
        // J0
        self.Jn.append(J * (self.zMax - self.zMin) / L)
        
        // Jn
        for i in 0..<convergenceIterations
        {
            let n = Double(i + 1)
            self.Jn.append(2 * J / (n * π) * (sin(n * π * self.zMax / L) - sin(n * π * self.zMin / L)))
        }
        
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
        // let J = self.J(I: I, radialBuild: r2 - r1)
        
        var result = π * µ0 * N * N / (6 * L) * ((r2 + r1) * (r2 + r1) + 2 * r1 * r1)
        
        let sumQueue = DispatchQueue(label: "com.huberistech.rabin_inductance_2020.sum")
        
        // var sum = 0.0
        var scSum = Coil.ScaledReturnType(number: 0)

        DispatchQueue.concurrentPerform(iterations: convergenceIterations)
        {
            (i:Int) -> Void in // this is the way to specify one of those "dangling" closures
        
            let n = i + 1
            
            let m = Double(n) * π / L
            
            let Jn = self.Jn[n]
            
            // I was wondering why DelVecchio 3e, Eq. 9.98 was multiplying the second term by N^2/N^2 and I think that the reason is to stabilize the numbers in the sum.
            let J_M_NI_exp = log(fabs(Jn)) * 2 - log(m) * 4 - log(N * I) * 2
            let J_M_NI_scaled = Coil.ScaledReturnType(scale: J_M_NI_exp, value: 1.0)
            
            let firstProduct = (J_M_NI_scaled * (coil.En[1][i] * coil.Integral_I1n[1][i]))
            let secondProduct = (J_M_NI_scaled * (coil.Fn[1][i] * coil.Cn[1][i]))
            let thirdProduct = ((π / 2) * (J_M_NI_scaled * coil.Integral_L1n[1][i]))
            
            let scaledSum = firstProduct + secondProduct - thirdProduct
            
            // let checkSum1 = scaledSum.doubleValue
            
            sumQueue.sync {
                // sum += checkSum1
                scSum += scaledSum
            }
        }
                
        let multiplier = π * µ0 * L * N * N
        let sumValue = scSum.doubleValue
        
        result += multiplier * sumValue
        
        assert(!result.isNaN, "NaN discovered!")
        
        return result
    }
    
    /// DelVecchio 3e, Eq. 9.91 and 9.94
    func MutualInductanceTo(otherSection:Section) -> Double
    {
        guard let selfCoil = self.parent, let otherCoil = otherSection.parent else
        {
            ALog("Parent coil has not been set for one of the sections!")
            return -Double.greatestFiniteMagnitude
        }
        
        let coils:[Coil] = [selfCoil, otherCoil].sorted(by: {$0.innerRadius <= $1.innerRadius})
        let isSameRadialPosition = fabs(selfCoil.innerRadius - otherCoil.innerRadius) < 0.001
        let sections:[Section] = [self, otherSection].sorted(by: {$0.parent!.innerRadius <= $1.parent!.innerRadius})
        
        let N1 = sections[0].N
        let N2 = sections[1].N
        let I1 = coils[0].I
        let I2 = coils[1].I
         
        let L = selfCoil.core.useWindowHt
        let r1 = coils[0].innerRadius
        let r2 = coils[0].outerRadius
         
        var result = isSameRadialPosition ? π * µ0 * N1 * N2 / (6 * L) * ((r1 + r2) * (r1 + r2) + 2 * r1 * r1) : π * µ0 * N1 * N2 / (3 * L) * (r1 * r1 + r1 * r2 + r2 * r2)
        
        let sumQueue = DispatchQueue(label: "com.huberistech.rabin_inductance_2020.sum")
        
        // var sum = 0.0
        var scSum = Coil.ScaledReturnType(number: 0)
        
        let NINI_exp = log(N1 * I1 * N2 * I2)

        DispatchQueue.concurrentPerform(iterations: convergenceIterations)
        {
            (i:Int) -> Void in // this is the way to specify one of those "dangling" closures
            
            let n = i + 1
            
            let m = Double(n) * π / L
            
            let J1n = sections[0].Jn[n]
            let J2n = sections[1].Jn[n]
            
            // I was wondering why DelVecchio 3e, Eq. 9.98 was multiplying the second term by N1^2/N2^2 and I think that the reason is to stabilize the numbers in the sum.
            let J_M_NI_exp = log(fabs(J1n)) + log(fabs(J2n)) - log(m) * 4 - NINI_exp
            // We need to set the minus sign if only one of the Jn values is negative (and Swift doesn't have an XOR, so...)
            let JJ_value = (J1n < 0) != (J2n < 0) ? -1.0 : 1.0
            let J_M_NI_scaled = Coil.ScaledReturnType(scale: J_M_NI_exp, value: JJ_value)
            
            if isSameRadialPosition
            {
                let firstProduct = (J_M_NI_scaled * (coils[0].En[1][i] * coils[0].Integral_I1n[1][i]))
                let secondProduct = (J_M_NI_scaled * (coils[0].Fn[1][i] * coils[0].Cn[1][i]))
                let thirdProduct = ((π / 2) * (J_M_NI_scaled * coils[0].Integral_L1n[1][i]))
                
                // let test = coils[0].Integral_L1n[1][i]
                
                let scaledSum = firstProduct + secondProduct - thirdProduct
                
                // let checkSum1 = scaledSum.doubleValue
                
                sumQueue.sync {
                    // sum += checkSum1
                    scSum += scaledSum
                }
            }
            else
            {
                let firstProduct = (J_M_NI_scaled * coils[1].Cn[1][i] * coils[0].Integral_I1n[1][i])
                let secondProduct = (J_M_NI_scaled * coils[1].Dn[1][i] * coils[0].Cn[1][i])
                
                let scaledSum = firstProduct + secondProduct
                // let checkSum1 = scaledSum.doubleValue
                
                sumQueue.sync {
                    // sum += checkSum1
                    scSum += scaledSum
                }
            }
        }
        
        // let multiplier = Coil.ScaledReturnType(number:π * µ0 * L * N1 * N2)
        
        // print("Diff: \(sum - scSum.doubleValue)")
        
        result += ((π * µ0 * L * N1 * N2) * scSum).doubleValue
        
        assert(!result.isNaN, "NaN discovered!")
        
        /*
        if result < 0
        {
            print("Neg: \(self.sectionID) to \(otherSection.sectionID) : \(result)")
        }
        */
        
        return result
    }
    
    /// Convenience routine for splitting up a section. If modeling with interdisk dimensions, the section to be split up must be UNIFORM (ie: all interdisks must be identical).
    /// - Parameter numSections: The number of sections to split this one into
    /// - Parameter withInterdisk: If non-nil, the *shrunk* dimension of the interdisk gaps. If nil, no interdisks are modeled (disks take up the whole height without gaps between them).
    func SplitSection(numSections:Int, withInterdisk:Double? = nil) -> [Section]
    {
        let interDiskDim = withInterdisk == nil ? 0.0 : withInterdisk!
        
        let zPerSection = (self.zMax - self.zMin - interDiskDim * Double(numSections - 1)) / Double(numSections)
        var currentLowZ = self.zMin
        
        var result:[Section] = []
        
        for _ in 0..<numSections
        {
            let newSection = Section(sectionID: Section.nextSerialNumber, zMin: currentLowZ, zMax: currentLowZ + zPerSection, N: self.N / Double(numSections), inNode: 0, outNode: 0, parent: self.parent)
            
            result.append(newSection)
            currentLowZ += zPerSection + interDiskDim
        }
        
        return result
    }
    
}
