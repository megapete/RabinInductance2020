//
//  Phase.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation

class Phase:Codable {
    
    var core:Core
    
    let coils:[Coil]
    
    var xlDesignFile:PCH_ExcelDesignFile? = nil
    
    private var indMatrixStore:Matrix? = nil
    
    var M:Matrix {
        get {
            
            if self.indMatrixStore == nil
            {
                
            }
            
            return indMatrixStore!
        }
    }
    
    init(core:Core, coils:[Coil]) {
        
        self.core = core
        self.coils = coils
    }
    
    convenience init(xlDesign:PCH_ExcelDesignFile) {
        
        let core = Core(realWindowHt: xlDesign.core.windowHeight, radius: xlDesign.core.diameter / 2, windowMultiplier: 1.5)
        
        var coils:[Coil] = []
        for nextWinding in xlDesign.windings
        {
            coils.append(Coil(winding: nextWinding, core: core, detailedModel: true, centerOnUseCore: true))
        }
        
        self.init(core:core, coils:coils)
    }
    
    func RecalculateInductanceMatrix() -> Matrix
    {
        // The key is the sectionID, the value is the index into the matrix
        var sectionMap:Dictionary<Int, Int> = [:]
        
        var allSections = self.AllSections()
        var index = 0
        for nextSection in AllSections()
        {
            sectionMap[nextSection.sectionID] = index
            index += 1
        }
        
        let result = Matrix(type: .Double, rows: UInt(allSections.count), columns: UInt(allSections.count))
        
        while allSections.count > 0
        {
            let nextSection = allSections.removeFirst()
            // let nextParent = nextSection.parent!
            let nextIndex = sectionMap[nextSection.sectionID]!
            
            let selfInd = nextSection.SelfInductance()
            result[nextIndex, nextIndex] = selfInd
            
            for otherSection in allSections
            {
                let otherIndex = sectionMap[otherSection.sectionID]!
                let mutInd = nextSection.MutualInductanceTo(otherSection: otherSection)
                result[nextIndex, otherIndex] = mutInd
                result[otherIndex, nextIndex] = mutInd
            }
        }
        
        return result
    }
    
    func LeakageReactancePU(baseVA:Double, baseI:Double, frequency:Double = 60) -> Double
    {
        return self.LeakageReactance(baseI: baseI, frequency: frequency) * baseI * baseI / baseVA
    }
    
    func LeakageReactance(baseI:Double, frequency:Double = 60.0) -> Double
    {
        return 2 * π * frequency * self.LeakageInductance(baseI: baseI)
    }
    
    /// Leakage inductance in Henries
    func LeakageInductance(baseI:Double) -> Double
    {
        return 2.0 * self.Energy() / (baseI * baseI)
    }

    /// DelVecchio 3e, Eq. 4.20. To calculate leakage inductance (in henries, and in terms of one of the coils), make sure that the current directions are properly set for each coil, then use Lh = 2W/I^2 where W is the energy calculated by this function and I is the rated current for the coil in question. To get the leakage reactance, Lr (in ohms, also in terms of one of the coils), multiply the leakage inductance by 2πf. To get the pu reactance: Lpu = Lr * Irated / Vrated
    func Energy() -> Double
    {
        // DLog("Calculating energy...")
        var sumLI = 0.0
        var sumMII = 0.0
        
        var allSections = self.AllSections()
        
        while allSections.count > 0
        {
            let nextSection = allSections.removeFirst()
            let nextParent = nextSection.parent!
            
            if nextParent.currentDirection == 0
            {
                continue
            }
            
            // DLog("Calculating inductances for section: \(nextSection.sectionID)")
            sumLI += nextSection.SelfInductance() * nextParent.I * nextParent.I
            
            for otherSection in allSections
            {
                let otherParent = otherSection.parent!
                
                if otherParent.currentDirection == 0
                {
                    continue
                }
                
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
