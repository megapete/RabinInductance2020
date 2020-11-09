//
//  Coil.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Foundation
import Accelerate

fileprivate let relError = 1.0E-8
fileprivate let absError = 1.0E-12

let convergenceIterations = 200

class Coil:Codable, Equatable {
    
    static func == (lhs: Coil, rhs: Coil) -> Bool {
        
        return lhs.coilID == rhs.coilID
    }
    
    enum Region:Int, Codable {
        case I
        case II
        case III
    }
    
    /// If the Coil was created using an Excel-gernerated design file, this will hold a copy of the Winding
    let xlWinding:PCH_ExcelDesignFile.Winding?
    
    let coilID:Int
    let name:String
    var currentDirection:Int
    
    let innerRadius:Double
    let outerRadius:Double
    var radialBuild:Double {
        get {
            return self.outerRadius - self.innerRadius
        }
    }
    
    let I:Double
    
    /// The ScaledReturnType stores a number as a power of e and a constant multiplier. The idea is to make addition and subtraction of very large (or very small) numbers more precise, escpeciially when there is a long equation with pluses and minuese.
    struct ScaledReturnType:Codable, CustomStringConvertible {
        
        var description: String {
            get {
                
                var result = "{"
                var isFirst = true
                for nextTerm in self.terms
                {
                    if !isFirst
                    {
                        result.append(" + ")
                    }
                    
                    result.append("[e^\(nextTerm.scale)(\(nextTerm.scaledValue))]")
                    
                    isFirst = false
                }
                
                result.append("}")
                
                return result
            }
        }
        
        /// The current number of terms in the ScaledReturnType
        var count:Int {
            get {
                return self.terms.count
            }
        }
        
        /// The struct used to hold a single term of the ScaledReturnType
        struct Term:Codable {
            
            /// The power of the term (as in e^scale)
            let scale:Double
            /// The value that e^scale will be multiplied to give the actual vaklue of the number
            let scaledValue:Double
            
            /// A convenience routine to get the true value of the number (as a Double)
            var trueValue:Double {
                get {
                    return exp(scale) * scaledValue
                }
            }
            
            /// This function assumes that the argument 'termArray' is sorted on entry. The new term will be inserted so that the array is still sorted on exit. It is basically a binary search method.
            static func InsertTerm(_ newTerm:Term, into termArray:inout [Term])
            {
                var loIndex = 0
                var hiIndex = termArray.count - 1
                
                while loIndex < hiIndex
                {
                    let midPointIndex = (loIndex + hiIndex) / 2
                    let midPointScale = termArray[midPointIndex].scale
                    
                    if midPointScale < newTerm.scale
                    {
                        loIndex = midPointIndex + 1
                    }
                    else if midPointScale > newTerm.scale
                    {
                        hiIndex = midPointIndex - 1
                    }
                    else
                    {
                        termArray.insert(newTerm, at: midPointIndex)
                    }
                }
                
                termArray.insert(newTerm, at: loIndex)
            }
        }
        
        /// An array holding the terms of the ScaledReturnType
        var terms:[Term]
        
        /// Better (I think) method of getting the Double value of a ScaledReturnType. The idea is to sort the terms so that the highest scales are at the beginning of the array, then remove the first pair of terms and add them together to from a new term. This new term is then appended to the array, which is resorted and the whole thing goes on until there is only one term left, which is then converted to a double. I'm hoping that this method will keep large values (in the terms array) from swamping smaller ones.
        var doubleValue:Double {
            get {
                
                // Sort the terms array based on the scale
                var resultTerms = self.terms.sorted(by: {$0.scale > $1.scale})
                
                // Keep going until there is only a single term left
                while resultTerms.count > 1
                {
                    // Remove and store the first term - if it's zero, go back to the top of the loop
                    let firstTerm = resultTerms.removeFirst()
                    if firstTerm.scaledValue == 0
                    {
                        continue
                    }
                    // Remove and store the second term. If it's zero. reinsert the first term (at the beginning) and start the loop again
                    let secondTerm = resultTerms.removeFirst()
                    if secondTerm.scaledValue == 0
                    {
                        resultTerms.insert(firstTerm, at: 0)
                        continue
                    }
                    
                    // Evaluate the sum of the first two terms as a Double, scaled to the e-power of the second term
                    let b = secondTerm.scale
                    let newValue = exp(firstTerm.scale - b) * firstTerm.scaledValue + secondTerm.scaledValue
                    
                    // If the sum is zero, go back to the top of the loop
                    if newValue == 0
                    {
                        continue
                    }
                    
                    // We can't take the ln of a negative number, so we set the new term's value as +1 or -1, depending on the sign
                    let sValue = newValue < 0 ? -1.0 : 1.0
                    
                    // Save the new term
                    let newTerm = Term(scale: b + log(fabs(newValue)), scaledValue: sValue)
                    
                    Term.InsertTerm(newTerm, into: &resultTerms)
                    
                    // print("result term count: \(resultTerms.count)")
                    // Add the term back to the array and sort the array based on the scale
                    // resultTerms.append(newTerm)
                    // resultTerms.sort(by: {$0.scale > $1.scale})
                }
                
                // If no terms are left, return 0
                if resultTerms.count == 0
                {
                    return 0.0
                }
                
                // There's one term left, evaluate it as a Double
                let result = exp(resultTerms[0].scale) * resultTerms[0].scaledValue
                
                // In a Debug build, check that we don't have a NaN
                assert(!result.isNaN, "Got a NaN!")
                
                return result
            }
        }
        
        
        
        /// Easy to program, but (I think), less precise way of getting the Double value of the ScaledReturnType (As compared to "doubleValue").
        var totalTrueValue:Double {
            get {
                
                var result = 0.0
                
                let sortedTerms = terms.sorted(by: {$0.scale > $1.scale})
                
                for nextTerm in sortedTerms
                {
                    result += exp(nextTerm.scale) * nextTerm.scaledValue
                }
                
                return result
            }
        }
        
        // Operators for the struct.
        static func + (lhs:ScaledReturnType, rhs:ScaledReturnType) -> ScaledReturnType
        {
            var newTerms = lhs.terms
            newTerms.append(contentsOf: rhs.terms)
            
            return ScaledReturnType(terms: newTerms)
        }
        
        static func += (lhs:inout ScaledReturnType, rhs:ScaledReturnType)
        {
            lhs.terms.append(contentsOf: rhs.terms)
        }
        
        static func - (lhs:ScaledReturnType, rhs:ScaledReturnType) -> ScaledReturnType
        {
            var newTerms = lhs.terms
            
            for nextTerm in rhs.terms
            {
                newTerms.append(Term(scale: nextTerm.scale, scaledValue: -nextTerm.scaledValue))
            }
            
            return ScaledReturnType(terms: newTerms)
        }
        
        // Multiply a scalar by a ScaledReturnType and return a ScaledReturnType
        static func * (lhs:Double, rhs:ScaledReturnType) -> ScaledReturnType
        {
            if lhs == 0
            {
                return ScaledReturnType(number: 0)
            }
            
            var newTerms:[Coil.ScaledReturnType.Term] = []
            
            for nextTerm in rhs.terms
            {
                newTerms.append(Coil.ScaledReturnType.Term(scale: nextTerm.scale, scaledValue: lhs * nextTerm.scaledValue))
            }
            
            return ScaledReturnType(terms: newTerms)
        }
        
        static func * (lhs:ScaledReturnType, rhs:ScaledReturnType) -> ScaledReturnType
        {
            var newTerms:[Coil.ScaledReturnType.Term] = []
            // each member of the lhs must be multiplied by each member of the rhs
            for nextLhsTerm in lhs.terms
            {
                let lhsScale = nextLhsTerm.scale
                let lhsValue = nextLhsTerm.scaledValue
                
                for nextRhsTerm in rhs.terms
                {
                    let newScale = lhsScale + nextRhsTerm.scale
                    let newValue = lhsValue * nextRhsTerm.scaledValue
                    if newValue != 0
                    {
                        newTerms.append(Coil.ScaledReturnType.Term(scale: newScale, scaledValue: newValue))
                    }
                }
            }
            
            return ScaledReturnType(terms: newTerms)
        }
        
        /// Return a new ScaledReturnType that is made up of a single term. This uses the same logic as the "doubleValue" computed property. See that property for explanatory comments.
        func reduced() -> ScaledReturnType
        {
            var resultTerms = self.terms.sorted(by: {$0.scale > $1.scale})
            
            while resultTerms.count > 1
            {
                let firstTerm = resultTerms.removeFirst()
                if firstTerm.scaledValue == 0
                {
                    continue
                }
                let secondTerm = resultTerms.removeFirst()
                if secondTerm.scaledValue == 0
                {
                    resultTerms.insert(firstTerm, at: 0)
                    continue
                }
                
                let b = secondTerm.scale
                let newValue = exp(firstTerm.scale - b) * firstTerm.scaledValue + secondTerm.scaledValue
                
                if newValue == 0
                {
                    continue
                }
                
                let sValue = newValue < 0 ? -1.0 : 1.0
                let newTerm = Term(scale: b + log(fabs(newValue)), scaledValue: sValue)
                
                resultTerms.append(newTerm)
                resultTerms.sort(by: {$0.scale > $1.scale})
            }
            
            if resultTerms.count == 0
            {
                return ScaledReturnType(number: 0.0)
            }
            
            return ScaledReturnType(terms: resultTerms)
        }
        
        /// Initializer that takes an array of ScaledReturnType.Terms as an argument.
        init(terms:[Term])
        {
            self.terms = terms
        }
        
        /// Create the ScaledReturnType of a Double
        init(number:Double)
        {
            if number == 0.0
            {
                let numTerm = Term(scale: 0.0, scaledValue: 0.0)
                self.terms = [numTerm]
            }
            else
            {
                let numTerm = Term(scale: log(number), scaledValue: 1.0)
                self.terms = [numTerm]
            }
        }
        
        /// Create a ScaledReturnType with the scale and multiplied value of a number
        init(scale:Double, value:Double)
        {
            self.terms = [ScaledReturnType.Term(scale: scale, scaledValue: value)]
        }
    }
    
    // Arrays to hold the constant radius-based "letter-functions" of the Coil
    var Cn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Dn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var En:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Fn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Gn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    
    // Integrals whose values we'll need
    var Integral_I1n:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Integral_L1n:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    
    // J-values for the coil
    var J:[Double] = []
    
    // Storage for the section array
    var sectionStore:[Section] = []
    
    var sections:[Section] {
        get {
            return self.sectionStore
        }
        
        set {
            self.sectionStore = newValue
            for nextSection in newValue
            {
                nextSection.parent = self
                nextSection.InitializeJn()
            }
        }
    }
    
    // The Core that this coil is on
    let core:Core
    
    /// Designated initializer for the Coil class.
    /// - Parameter coilID: A unique identifier (in terms of the phase) for the coil. Usually the "position" of the coil (0 = closest to the core, etc.)
    /// - Parameter name: A String that can be used to easily identify the coil
    /// - Parameter currentDirection: the azimuthal direction of the current (clamped to one of the following values: -1, 0, 1)
    /// - Parameter innerRadius: The inner radius of the coil in meters
    /// - Parameter outerRadius: The outer radius of the coil in meters
    /// - Parameter I: The current (in positive Amps) in the coil
    /// - Parameter sections: An array of Sections used to model the coil
    /// - Parameter core: The Core to be used for inductance calculations
    /// - Parameter xlWinding: A reference to the original Excel-generated winding data for the coil, if any - otherwise 'nil'
    init(coilID:Int, name:String, currentDirection:Int, innerRadius:Double, outerRadius:Double, I:Double, sections:[Section] = [], core:Core, xlWinding:PCH_ExcelDesignFile.Winding? = nil) {
        
        self.coilID = coilID
        self.name = name
        self.currentDirection = currentDirection == 0 ? 0 : currentDirection < 0 ? -1 : 1
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.I = fabs(I)
        self.sectionStore = sections.sorted(by: {$0.zMin < $1.zMin})
        self.core = core
        self.xlWinding = xlWinding
        
        for index in 0..<3
        {
            for n in 1...convergenceIterations
            {
                let m = Double(n) * π / core.useWindowHt
                let xc = m * self.core.radius
                
                var x1 = xc
                var x2 = m * self.innerRadius
            
                if index == 1
                {
                    x1 = m * self.innerRadius
                    x2 = m * self.outerRadius
                }
                else if index == 2
                {
                    x1 = m * self.outerRadius
                    x2 = m * (self.outerRadius + 0.2) // arbitrary distance to tank
                }
                
                let newCn = Coil.IntegralOf_tK1_t_dt(from: x1, to: x2)
                // print("before reduction: \(newCn.totalTrueValue)")
                // let reducedCn = newCn.reduced()
                // print("after reduction: \(reducedCn.totalTrueValue)")
                self.Cn[index].append(newCn)
                
                let i0k0_scaled = gsl_sf_bessel_I0_scaled(xc) / gsl_sf_bessel_K0_scaled(xc)
                let i0k0 = ScaledReturnType(scale: 2 * xc, value: i0k0_scaled)
                // let i0k0 = ScaledReturnType(terms: [ScaledReturnType.Term(scale: 2 * xc, scaledValue: i0k0_scaled)])
                
                let newDn = (i0k0 * newCn)
                self.Dn[index].append(newDn)
                
                let newFn = (newDn - Coil.IntegralOf_tI1_t_dt(from: 0, to: x1))
                // print("Old way: \(newFn.totalTrueValue), New way: \(newFn.tuned_totalTrueValue)")
                self.Fn[index].append(newFn)
                
                let newGn = (newDn + Coil.IntegralOf_tI1_t_dt(from: x1, to: x2))
                self.Gn[index].append(newGn)
                
                let newEn = Coil.IntegralOf_tK1_t_dt(from: 0, to: x2)
                self.En[index].append(newEn)
                
                let newI1n = Coil.IntegralOf_tI1_t_dt(from: x1, to: x2)
                self.Integral_I1n[index].append(newI1n)
                
                let newL1n = Coil.IntegralOf_tL1_t_dt(from: x1, to: x2)
                self.Integral_L1n[index].append(newL1n)
            }
        }
        
        for nextSection in self.sections
        {
            nextSection.parent = self
            nextSection.InitializeJn()
        }
    }
    
    /// Convenience initializer for the Coil class to return a Coil based on the data from an Excel-generated design file.
    /// - Parameter winding: The PCH_ExcelDesignFile.Winding from which the Coil will be modeled
    /// - Parameter core: The Core for the phase
    /// - Parameter detailedModel: If 'true', all sections (discs) and/or layers are modeled. Otherwise, only the "major" sections are modeled (see Discussion).
    /// - Parameter centerOnUseCore: If 'true', the axial sections are centered on the core AFTER the window-height factor has been applied.
    ///
    /// 'Major' sections are defined as axial sections that only break at the center-gap and DV gaps (if any). Axial interdisc and radial cooling ducts are ignored.
    convenience init(winding:PCH_ExcelDesignFile.Winding, core:Core, detailedModel:Bool = false, centerOnUseCore:Bool)
    {
        let coilID = winding.position
        let coilName = "Coil \(winding.position + 1)"
        let innerRadius = winding.innerDiameter / 2
        let outerRadius = innerRadius + winding.electricalRadialBuild
        let currentDirection = winding.terminal.currentDirection
        
        let numMainAxialSections = 1 + winding.centerGap > 0 ? 1 : 0 + winding.topDvGap > 0 ? 1 : 0 + winding.bottomDvGap > 0 ? 1 : 0
        var sections:[Section] = []
        
        if detailedModel
        {
            if winding.windingType == .disc || winding.windingType == .helix
            {
                let useAxialSections = winding.windingType == .disc ? winding.numAxialSections : Int(winding.numTurns.max)
                let turnsPerDisc = winding.numTurns.max / Double(useAxialSections)
                let numInterdisks = useAxialSections - numMainAxialSections
                let totalAxialInsulation = (Double(numInterdisks) * winding.stdAxialGap + winding.centerGap + winding.topDvGap + winding.bottomDvGap) * 0.98
                var gaps:[Double] = [0.0]
                let discAxialDimension = (winding.electricalHeight - totalAxialInsulation) / Double(useAxialSections)
                
                var mainSectionDiscs:[Int] = []
                if numMainAxialSections == 1
                {
                    mainSectionDiscs = [useAxialSections]
                }
                else if numMainAxialSections == 2
                {
                    let bottomDiscCount = Int(ceil(Double(useAxialSections / 2)))
                    mainSectionDiscs.append(bottomDiscCount)
                    mainSectionDiscs.append(useAxialSections - bottomDiscCount)
                    gaps = [winding.centerGap]
                }
                else if numMainAxialSections == 3
                {
                    let upperAndLowerSectionDiscCount = Int(ceil(Double(useAxialSections) / 4))
                    let centerSectionDiscCount = useAxialSections - 2 * upperAndLowerSectionDiscCount
                    mainSectionDiscs = [upperAndLowerSectionDiscCount, centerSectionDiscCount, upperAndLowerSectionDiscCount]
                    gaps = [winding.bottomDvGap, winding.topDvGap]
                }
                else // 4 sections
                {
                    let bottomHalfDiscCount = Int(ceil(Double(useAxialSections / 2)))
                    let topHalfDiscCount = useAxialSections - bottomHalfDiscCount
                    let bottompQuarterDiscCount = Int(ceil(Double(bottomHalfDiscCount / 2)))
                    let centerBottomQuarterDiscCount = bottomHalfDiscCount - bottompQuarterDiscCount
                    let topQuarterDiscCount = bottompQuarterDiscCount
                    let centerTopQuarterDiscCount = topHalfDiscCount - topQuarterDiscCount
                    
                    mainSectionDiscs = [bottompQuarterDiscCount, centerBottomQuarterDiscCount, centerTopQuarterDiscCount, topQuarterDiscCount]
                    
                    gaps = [winding.bottomDvGap, winding.centerGap, winding.topDvGap]
                }
                
                var currentMinZ = centerOnUseCore ? (core.useWindowHt - winding.electricalHeight) / 2 : winding.bottomEdgePack
                
                for nextMainSection in mainSectionDiscs
                {
                    for _ in 0..<nextMainSection
                    {
                        let newSection = Section(sectionID: Section.nextSerialNumber, zMin: currentMinZ, zMax: currentMinZ + discAxialDimension, N: turnsPerDisc, inNode: 0, outNode: 0)
                        
                        sections.append(newSection)
                        
                        currentMinZ += discAxialDimension + winding.stdAxialGap * 0.98
                    }
                    
                    currentMinZ += (gaps.removeFirst() - winding.stdAxialGap) * 0.98
                }
            }
        }
        else // non-detailed model
        {
            if winding.windingType == .disc || winding.windingType == .helix
            {
                let useAxialSections = winding.windingType == .disc ? winding.numAxialSections : Int(winding.numTurns.max)
                // let turnsPerDisc = winding.numTurns.max / Double(useAxialSections)
                // let numInterdisks = useAxialSections - numMainAxialSections
                let totalAxialInsulation = (winding.stdAxialGap + winding.centerGap + winding.topDvGap + winding.bottomDvGap) * 0.98
                var gaps:[Double] = [0.0]
                let totalAxialCopperDimension = winding.electricalHeight - totalAxialInsulation
                
                var mainSectionDiscs:[Int] = []
                if numMainAxialSections == 1
                {
                    mainSectionDiscs = [useAxialSections]
                }
                else if numMainAxialSections == 2
                {
                    let bottomDiscCount = Int(ceil(Double(useAxialSections / 2)))
                    mainSectionDiscs.append(bottomDiscCount)
                    mainSectionDiscs.append(useAxialSections - bottomDiscCount)
                    gaps = [winding.centerGap, 0.0]
                }
                else if numMainAxialSections == 3
                {
                    let upperAndLowerSectionDiscCount = Int(ceil(Double(useAxialSections) / 4))
                    let centerSectionDiscCount = useAxialSections - 2 * upperAndLowerSectionDiscCount
                    mainSectionDiscs = [upperAndLowerSectionDiscCount, centerSectionDiscCount, upperAndLowerSectionDiscCount]
                    gaps = [winding.bottomDvGap, winding.topDvGap, 0.0]
                }
                else // 4 sections
                {
                    let bottomHalfDiscCount = Int(ceil(Double(useAxialSections / 2)))
                    let topHalfDiscCount = useAxialSections - bottomHalfDiscCount
                    let bottompQuarterDiscCount = Int(ceil(Double(bottomHalfDiscCount / 2)))
                    let centerBottomQuarterDiscCount = bottomHalfDiscCount - bottompQuarterDiscCount
                    let topQuarterDiscCount = bottompQuarterDiscCount
                    let centerTopQuarterDiscCount = topHalfDiscCount - topQuarterDiscCount
                    
                    mainSectionDiscs = [bottompQuarterDiscCount, centerBottomQuarterDiscCount, centerTopQuarterDiscCount, topQuarterDiscCount]
                    
                    gaps = [winding.bottomDvGap, winding.centerGap, winding.topDvGap, 0.0]
                }
                
                var currentMinZ = centerOnUseCore ? (core.useWindowHt - winding.electricalHeight) / 2 : winding.bottomEdgePack
                
                for nextMainSection in mainSectionDiscs
                {
                    let sectionFraction = Double(nextMainSection) / Double(useAxialSections)
                    let turns = sectionFraction * winding.numTurns.max
                    let sectionHeight = sectionFraction * totalAxialCopperDimension
                    
                    let newSection = Section(sectionID: Section.nextSerialNumber, zMin: currentMinZ, zMax: currentMinZ + sectionHeight, N: turns, inNode: 0, outNode: 0)
                    
                    sections.append(newSection)
                    
                    currentMinZ += sectionHeight + gaps.removeFirst() * 0.98
                }
            }
        }
        
        self.init(coilID:coilID, name:coilName, currentDirection:currentDirection, innerRadius:innerRadius, outerRadius:outerRadius, I:winding.I, sections:sections, core:core, xlWinding:winding)
    }
    
    /// Return the vector potential at the point passed to the routine
    func VectorPotential(at point:NSPoint) -> Double
    {
        let r = Double(point.x)
        let r1 = self.innerRadius
        let r2 = self.outerRadius
        let z = Double(point.y)
        let L = self.core.useWindowHt
                
        var result = µ0 * self.J[0]
        
        if r < self.innerRadius
        {
            // regiom I (index 0)
            result *= (r2 - r1) / 2 * r
            
            let sumQueue = DispatchQueue(label: "com.huberistech.rabin_inductance_2020.A_sum")
            
            var sum = 0.0
            // for i in 0..<convergenceIterations
            DispatchQueue.concurrentPerform(iterations: convergenceIterations)
            {
                (i:Int) -> Void in // this is the way to specify one of those "dangling" closures
            
                let n = i + 1
                
                let m = Double(n) * π / L
                
                let x = m * r
                
                let Jn = self.J[n]
                
                let J_M_exp = log(fabs(Jn)) + log(m) * -2
                let J_value = Jn < 0 ? -1.0 : 1.0
                let J_M_scaled = ScaledReturnType(scale: J_M_exp, value: J_value)
                // let J_M_scaled = Coil.ScaledReturnType(terms: [ScaledReturnType.Term(scale: J_M_exp, scaledValue: J_value)])
                
                let I1 =  ScaledReturnType(scale: x, value: gsl_sf_bessel_I1_scaled(x))
                // let I1 = Coil.ScaledReturnType(terms:[ScaledReturnType.Term(scale: x, scaledValue: gsl_sf_bessel_I1_scaled(x))])
                
                let firstProduct = J_M_scaled * self.Cn[0][n] * I1
                
                let K1 = ScaledReturnType(scale: -x, value: gsl_sf_bessel_K1_scaled(x))
                // let K1 = Coil.ScaledReturnType(terms: [ScaledReturnType.Term(scale: -x, scaledValue: gsl_sf_bessel_K1_scaled(x))])
                let secondProduct = J_M_scaled * self.Dn[0][n] * K1
                
                let innerSum = (firstProduct + secondProduct).doubleValue * cos(m * z)
                
                sumQueue.sync {
                    sum += innerSum
                }
            }
            
            sum *= µ0
            
            result += sum
            
        }
        else if r <= self.outerRadius
        {
            // region II (index 1)
            result *= r2 * r / 2 - r1 * r1 * r1 / (6 * r) - r2 * r2 / 3
            
            let sumQueue = DispatchQueue(label: "com.huberistech.rabin_inductance_2020.A_sum")
            
            var sum = 0.0
            // for i in 0..<convergenceIterations
            DispatchQueue.concurrentPerform(iterations: convergenceIterations)
            {
                (i:Int) -> Void in // this is the way to specify one of those "dangling" closures
            
                let n = i + 1
                
                let m = Double(n) * π / L
                
                let x = m * r
                
                let Jn = self.J[n]
                
                let J_M_exp = log(fabs(Jn)) + log(m) * -2
                let J_value = Jn < 0 ? -1.0 : 1.0
                let J_M_scaled = ScaledReturnType(scale: J_M_exp, value: J_value)
                // let J_M_scaled = Coil.ScaledReturnType(terms: [ScaledReturnType.Term(scale: J_M_exp, scaledValue: J_value)])
                
                let I1 =  ScaledReturnType(scale: x, value: gsl_sf_bessel_I1_scaled(x))
                // let I1 = Coil.ScaledReturnType(terms:[ScaledReturnType.Term(scale: x, scaledValue: gsl_sf_bessel_I1_scaled(x))])
                let firstProduct = J_M_scaled * self.En[1][n] * I1
                
                let K1 = ScaledReturnType(scale: -x, value: gsl_sf_bessel_K1_scaled(x))
                // let K1 = Coil.ScaledReturnType(terms: [ScaledReturnType.Term(scale: -x, scaledValue: gsl_sf_bessel_K1_scaled(x))])
                let secondProduct = J_M_scaled * self.Fn[1][n] * K1
                
                let innerSum = ((firstProduct + secondProduct).doubleValue - π / 2 * Coil.L1(x: x)) * cos(m * z)
                
                sumQueue.sync {
                    sum += innerSum
                }
            }
            
            sum *= µ0
            
            result += sum
        }
        else
        {
            // region III (index 2)
            result *= (r2 * r2 * r2 - r1 * r1 * r1) / (6 * r)
            
            let sumQueue = DispatchQueue(label: "com.huberistech.rabin_inductance_2020.A_sum")
            
            var sum = 0.0
            // for i in 0..<convergenceIterations
            DispatchQueue.concurrentPerform(iterations: convergenceIterations)
            {
                (i:Int) -> Void in // this is the way to specify one of those "dangling" closures
            
                let n = i + 1
                
                let m = Double(n) * π / L
                
                let x = m * r
                
                let Jn = self.J[n]
                
                let J_M_exp = log(fabs(Jn)) + log(m) * -2
                let J_value = Jn < 0 ? -1.0 : 1.0
                let J_M_scaled = ScaledReturnType(scale: J_M_exp, value: J_value)
                // let J_M_scaled = Coil.ScaledReturnType(terms: [ScaledReturnType.Term(scale: J_M_exp, scaledValue: J_value)])
                
                let K1 = ScaledReturnType(scale: -x, value: gsl_sf_bessel_K1_scaled(x))
                // let K1 = Coil.ScaledReturnType(terms: [ScaledReturnType.Term(scale: -x, scaledValue: gsl_sf_bessel_K1_scaled(x))])
                let firstProduct = J_M_scaled * self.Gn[2][n] * K1
                
                let innerSum = firstProduct.totalTrueValue * cos(m * z)
                
                sumQueue.sync {
                    sum += innerSum
                }
            }
            
            sum *= µ0
            
            result += sum
        }
        
        return result
    }
    
    /// Routine to initialize the J-values with the current coil sections
    func InitializeJ()
    {
        self.J.removeAll()
        
        for n in 0...convergenceIterations
        {
            self.J.append(self.Jn(n: n))
        }
    }
    
    /// Method for calculating J0 for the COIL, using DelVecchio 9.13 (instead of 9.14 for EACH section)
    func J0() -> Double
    {
        var result = 0.0
        let I = self.I
        let rb = self.radialBuild
        
        for nextSection in self.sections
        {
            let Ji = nextSection.J(I: I, radialBuild: rb)
            
            result += Ji * (nextSection.zMax - nextSection.zMin)
        }
        
        result /= self.core.useWindowHt
        
        return result
    }
    
    /// Method for calculating Jn for the COIL, using DelVecchio 9.13 (instead of 9.14 for EACH section)
    func Jn(n index:Int) -> Double
    {
        if index == 0
        {
            return self.J0()
        }
        
        var result = 0.0
        let I = self.I
        let rb = self.radialBuild
        let n = Double(index)
        
        for nextSection in self.sections
        {
            let Ji = nextSection.J(I: I, radialBuild: rb)
            
            result += Ji * (sin(n * π * nextSection.zMax / self.core.useWindowHt) - sin(n * π * nextSection.zMin / self.core.useWindowHt))
        }
        
        result *= 2 / (n * π)
        
        return result
    }
    
    /// Function to return the Jn value at the given z dimension (will return 0 if z is between sections). This function should be used for calculations of vector potential (A) and induction vector (B).
    func Jn(n:Int, z:Double) -> Double
    {
        for nextSection in self.sections
        {
            if nextSection.zMin > z
            {
                break
            }
            
            if z >= nextSection.zMin && z <= nextSection.zMax
            {
                let J = nextSection.J(I: self.I, radialBuild: self.radialBuild)
                return nextSection.Jn(n: n, J: J, L: self.core.useWindowHt)
            }
        }
        
        return 0.0
    }
    
    /// DelVecchio 3e, Eq. 9.61(a)
    static func IntegralOf_tI1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        // Return the scaled terms from the calculation of the integral.
        
        let x1TermValue = x1 == 0 ? 0 : -π / 2.0 * x1 * (Coil.M1(x: x1) * gsl_sf_bessel_I0_scaled(x1) - Coil.M0(x: x1) * gsl_sf_bessel_I1_scaled(x1))
        let x2TermValue = π / 2.0 * x2 * (Coil.M1(x: x2) * gsl_sf_bessel_I0_scaled(x2) - Coil.M0(x: x2) * gsl_sf_bessel_I1_scaled(x2))
        
        var result = ScaledReturnType(scale: x1, value: x1TermValue)
        result += ScaledReturnType(scale: x2, value: x2TermValue)
        
        return result
        
    }
    
    /// DelVecchio 3e, Eq. 9.61(b)
    static func IntegralOf_tK1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        // Return the scaled terms from the calculation of the integral.  Note that the function has been set up so that this will even work if x1=0
        
        let x1TermValue = x1 == 0 ? π / 2.0 :  π / 2.0 * x1 * (Coil.M1(x: x1) * gsl_sf_bessel_K0_scaled(x1) + Coil.M0(x: x1) * gsl_sf_bessel_K1_scaled(x1))
        let x2TermValue = -π / 2.0 * x2 * (Coil.M1(x: x2) * gsl_sf_bessel_K0_scaled(x2) + Coil.M0(x: x2) * gsl_sf_bessel_K1_scaled(x2))
        
        var result = ScaledReturnType(scale: -x1, value: x1TermValue)
        result += ScaledReturnType(scale: -x2, value: x2TermValue)
        
        return result
    }
    
    /// DelVecchio 3e, Eq. 9.64
    static func IntegralOf_tL1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        let unscaledValue = x1 * Coil.M0(x: x1) - x2 * Coil.M0(x: x2) + (x1 * x1 - x2 * x2) / π + Coil.IntegralOf_M0_t_dt(from: x1, to: x2)
        
        var result = ScaledReturnType(scale: 0, value: unscaledValue)
        result += Coil.IntegralOf_tI1_t_dt(from: x1, to: x2)
        
        return result
    }
    
    /// DelVecchio 3e, Eq. 9.58(a)
    static func L0(x:Double) -> Double
    {
        return gsl_sf_bessel_I0(x) - self.M0(x: x)
    }
    
    /// DelVecchio 3e, Eq. 9.58(b)
    static func L1(x:Double) -> Double
    {
        return gsl_sf_bessel_I1(x) - self.M1(x: x)
    }
    
    /// DelVecchio 3e, Eq. 9.59(a)
    static func M0(x:Double) -> Double
    {
        let quadrature = Quadrature(integrator: .qags(maxIntervals: 10), absoluteTolerance: absError, relativeTolerance: relError)
        
        let integrationResult = quadrature.integrate(over: 0.0...(π / 2.0)) { theta in
            
            return exp(-x * cos(theta))
            
        }
        
        switch integrationResult {
        
        case .success((let result, _ /* let estAbsError */)):
            // DLog("Absolute error: \(estAbsError); p.u: \(estAbsError / result)")
            return result * 2.0 / π
        
        case .failure(let error):
            ALog("Error calling integration routine. The error is: \(error)")
            return 0.0
        }
    }
    
    /// DelVecchio 3e, Eq. 9.59(b)
    static func M1(x:Double) -> Double
    {
        let quadrature = Quadrature(integrator: .qags(maxIntervals: 10), absoluteTolerance: absError, relativeTolerance: relError)
        
        let integrationResult = quadrature.integrate(over: 0.0...(π / 2.0)) { theta in
            
            return exp(-x * cos(theta)) * cos(theta)
            
        }
        
        switch integrationResult {
        
        case .success((let result, _ /* let estAbsError */)):
            // DLog("Absolute error: \(estAbsError); p.u: \(estAbsError / result)")
            return (1.0 - result) * 2.0 / π
        
        case .failure(let error):
            ALog("Error calling integration routine. The error is: \(error)")
            return 0.0
        }
    }
    
    /// DelVecchio 3e, Eq. 6.60
    static func IntegralOf_M0_t_dt(from a:Double, to b:Double) -> Double
    {
        ZAssert(b >= a, message: "Illegal integral range")
        
        if a == 0.0
        {
            let quadrature = Quadrature(integrator: .qags(maxIntervals: 10), absoluteTolerance: absError, relativeTolerance: relError)
            
            let integrationResult = quadrature.integrate(over: 0.0...(π / 2.0)) { theta in
                
                return (1 - exp(-b * cos(theta))) / cos(theta)
                
            }
            
            switch integrationResult {
            
            case .success((let result, _ /* let estAbsError */)):
                // DLog("Absolute error: \(estAbsError); p.u: \(estAbsError / result)")
                return result * 2.0 / π
            
            case .failure(let error):
                ALog("Error calling integration routine. The error is: \(error)")
                return 0.0
            }
        }
        
        return IntegralOf_M0_t_dt(from: 0, to: b) - IntegralOf_M0_t_dt(from: 0, to: a)
    }
}
