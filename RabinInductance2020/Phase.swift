//
//  Phase.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation

class Phase:Codable {
    
    /// The core for this phase
    var core:Core
    
    /// The coils on this phase
    let coils:[Coil]
    
    /// The original Excel design file used to create this phase (if any)
    var xlDesignFile:PCH_ExcelDesignFile? = nil
    
    /// The Cholesky factorization of M (used to solve positive-definite matrices)
    var choleskyM:Matrix? = nil
    
    /// The storage for the inductance matrix for the coils on this phase (private variable)
    private var indMatrixStore:Matrix? = nil
    
    /// The public exposure of the inductance matrix for this phase. This is a read-only variable. If the inductance matrix hasn't been calculated yet, do so and save it to the private storage before returning it.
    var M:Matrix {
        get {
            
            if coils.count == 0
            {
                return Matrix()
            }
            
            if self.indMatrixStore == nil
            {
                indMatrixStore = self.CalculateInductanceMatrix()
                
                // create the Cholesky factorization of the matrix on a background thread
                let choleskyQueue = DispatchQueue(label: "com.huberistech.rabin_inductance_2020.cholesky")
                self.choleskyM = Matrix(srcMatrix: self.indMatrixStore!)
                choleskyQueue.async {
                    
                    let posDefCheck = self.choleskyM!.TestPositiveDefinite(overwriteExistingMatrix: true)
                    
                    // print("This is running")
                    if !posDefCheck
                    {
                        self.choleskyM = nil
                    }
                    else
                    {
                        DLog("Inductance matrix is positive definite")
                    }
                }
            }
            
            return indMatrixStore!
        }
    }
    
    /// An array of all the sections in the phase
    var sections:[Section]
    {
        get {
            
            var result:[Section] = []
            
            for nextCoil in coils
            {
                result.append(contentsOf: nextCoil.sections)
            }
            
            return result
        }
    }
    
    /// A map of the matrix row (key) to Section (value)
    private var reverseSectionMap:Dictionary<Int, Section> = [:]
    
    private var sectionMapStore:Dictionary<Int, Int>? = nil
    
    /// A map of the section IDs into the _current_ Inductance Matrix for the phase. The key is the sectionID, the value is the index into the matrix.
    var sectionMap:Dictionary<Int, Int> {
        get {
            
            if self.coils.count == 0
            {
                return [:]
            }
            
            if self.sectionMapStore == nil
            {
                // we also need to set up the reverseSectionMap
                self.reverseSectionMap = [:]
                // The key is the sectionID, the value is the index into the matrix
                var result:Dictionary<Int, Int> = [:]
                
                var index = 0
                for nextSection in self.sections
                {
                    result[nextSection.sectionID] = index
                    self.reverseSectionMap[index] = nextSection
                    index += 1
                }
                
                self.sectionMapStore = result
            }
            
            return self.sectionMapStore!
        }
    }
    
    
    /// Designated initializer for the class
    init(core:Core, coils:[Coil]) {
        
        self.core = core
        self.coils = coils
    }
    
    /// Initializer from an Excel design file.
    convenience init(xlDesign:PCH_ExcelDesignFile) {
        
        let core = Core(realWindowHt: xlDesign.core.windowHeight, radius: xlDesign.core.diameter / 2, windowMultiplier: 2.0)
        
        var coils:[Coil] = []
        for nextWinding in xlDesign.windings
        {
            coils.append(Coil(winding: nextWinding, core: core, detailedModel: true, centerOnUseCore: true))
        }
        
        self.init(core:core, coils:coils)
    }
    
    /// Recalculate the inductance matrix for the phase
    func RecalculateInductanceMatrix() -> Matrix
    {
        self.sectionMapStore = nil
        self.indMatrixStore = nil
        
        return self.M
    }
    
    /// Calculate the inductance matrix for the phase with the current sections that make up the coils.
    private func CalculateInductanceMatrix() -> Matrix
    {
        var allSections = self.sections
        
        let result = Matrix(type: .Double, rows: UInt(allSections.count), columns: UInt(allSections.count))
        
        var numNegativeMuties = 0
        while allSections.count > 0
        {
            let nextSection = allSections.removeFirst()
            print("Calculating inductance for: \(nextSection.sectionID)")
            let nextIndex = self.sectionMap[nextSection.sectionID]!
            
            let selfInd = nextSection.SelfInductance()
            result[nextIndex, nextIndex] = selfInd
            
            for otherSection in allSections
            {
                let otherIndex = sectionMap[otherSection.sectionID]!
                let mutInd = nextSection.MutualInductanceTo(otherSection: otherSection)
                
                if mutInd < 0
                {
                    numNegativeMuties += 1
                }
                
                result[nextIndex, otherIndex] = mutInd
                result[otherIndex, nextIndex] = mutInd
            }
        }
        
        DLog("Number of negative mutual inductances: \(numNegativeMuties)")
        
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
    
    /// Get the section from the matrix row, using the current sectionMap
    func SectionFromMatrixRow(_ row:Int) -> Section
    {
        guard row < self.M.rows else
        {
            DLog("Index out of range")
            return Section(sectionID: -1, zMin: 0, zMax: 0, N: 0, inNode: 0, outNode: 0)
        }
        
        if let section = self.reverseSectionMap[row]
        {
            return section
        }
        
        DLog("I don't know how this can happen")
        return Section(sectionID: -1, zMin: 0, zMax: 0, N: 0, inNode: 0, outNode: 0)
    }
    
    /// DelVecchio 3e, Eq. 4.20.
    func Energy() -> Double
    {
        var sumLI = 0.0
        var sumMII = 0.0
        
        for row in 0..<M.rows
        {
            let rowParent = self.SectionFromMatrixRow(row).parent!
            if rowParent.currentDirection == 0
            {
                continue
            }
            
            let rowI = rowParent.I
            
            sumLI += M[row, row] * rowI * rowI
            
            for col in (row + 1)..<M.columns
            {
                let colParent = self.SectionFromMatrixRow(col).parent!
                if colParent.currentDirection == 0
                {
                    continue
                }
                
                let colI = colParent.I
                
                let sign = rowParent.currentDirection != colParent.currentDirection ? -1.0 : 1.0
                
                sumMII += M[row, col] * rowI * colI * sign
            }
        }
        
        return 0.5 * sumLI + sumMII
    }

    /// DelVecchio 3e, Eq. 4.20. To calculate leakage inductance (in henries, and in terms of one of the coils), make sure that the current directions are properly set for each coil, then use Lh = 2W/I^2 where W is the energy calculated by this function and I is the rated current for the coil in question. To get the leakage reactance, Lr (in ohms, also in terms of one of the coils), multiply the leakage inductance by 2πf. To get the pu reactance: Lpu = Lr * Irated / Vrated
    func old_Energy() -> Double
    {
        // DLog("Calculating energy...")
        var sumLI = 0.0
        var sumMII = 0.0
        
        var allSections = self.sections
        
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
    
}
