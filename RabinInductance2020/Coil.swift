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
    
    enum Region {
        case I
        case II
        case III
    }
    
    let coilID:Int
    let name:String
    
    let innerRadius:Double
    let outerRadius:Double
    var radialBuild:Double {
        get {
            return self.outerRadius - self.innerRadius
        }
    }
    
    let I:Double
    
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
        
        
        var count:Int {
            get {
                return self.terms.count
            }
        }
        
        struct Term:Codable {
            
            let scale:Double
            let scaledValue:Double
            
            var trueValue:Double {
                get {
                    return exp(scale) * scaledValue
                }
            }
        }
        
        let terms:[Term]
        
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
        
        static func + (lhs:ScaledReturnType, rhs:ScaledReturnType) -> ScaledReturnType
        {
            var newTerms = lhs.terms
            newTerms.append(contentsOf: rhs.terms)
            
            return ScaledReturnType(terms: newTerms)
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
        
        static func * (lhs:Double, rhs:ScaledReturnType) -> ScaledReturnType
        {
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
                    newTerms.append(Coil.ScaledReturnType.Term(scale: newScale, scaledValue: newValue))
                }
            }
            
            return ScaledReturnType(terms: newTerms)
        }
        
        init(terms:[Term])
        {
            self.terms = terms
        }
        
        init(number:Double)
        {
            let numTerm = Term(scale: log(number), scaledValue: 1.0)
            self.terms = [numTerm]
        }
    }
    
    var Cn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Dn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var En:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Fn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Gn:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    
    // Integrals whose values we'll need
    var Integral_I1n:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    var Integral_L1n:[[ScaledReturnType]] = Array(repeating: [], count: 3)
    
    var sections:[Section]
    
    let core:Core
    
    init(coilID:Int, name:String, innerRadius:Double, outerRadius:Double, I:Double, sections:[Section] = [], core:Core) {
        
        self.coilID = coilID
        self.name = name
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.I = I
        self.sections = sections
        self.core = core
        
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
                self.Cn[index].append(newCn)
                
                let i0k0_scaled = gsl_sf_bessel_I0_scaled(xc) / gsl_sf_bessel_K0_scaled(xc)
                let i0k0 = ScaledReturnType(terms: [ScaledReturnType.Term(scale: 2 * xc, scaledValue: i0k0_scaled)])
                
                let newDn = i0k0 * newCn
                self.Dn[index].append(newDn)
                
                let newFn = newDn - Coil.IntegralOf_tI1_t_dt(from: 0, to: x1)
                self.Fn[index].append(newFn)
                
                let newGn = newDn + Coil.IntegralOf_tI1_t_dt(from: x1, to: x2)
                self.Gn[index].append(newGn)
                
                let newEn = Coil.IntegralOf_tK1_t_dt(from: 0, to: x2)
                self.En[index].append(newEn)
                
                let newI1n = Coil.IntegralOf_tI1_t_dt(from: x1, to: x2)
                self.Integral_I1n[index].append(newI1n)
                
                let newL1n = Coil.IntegralOf_tL1_t_dt(from: x1, to: x2)
                self.Integral_L1n[index].append(newL1n)
            }
        }
    }
    
    /// DelVecchio 3e, Eq. 9.61(a)
    static func IntegralOf_tI1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        // Return the scaled terms from the calculation of the integral.
        
        let x1TermValue = x1 == 0 ? 0 : -π / 2.0 * x1 * (Coil.M1(x: x1) * gsl_sf_bessel_I0_scaled(x1) - Coil.M0(x: x1) * gsl_sf_bessel_I1_scaled(x1))
        let x2TermValue = π / 2.0 * x2 * (Coil.M1(x: x2) * gsl_sf_bessel_I0_scaled(x2) - Coil.M0(x: x2) * gsl_sf_bessel_I1_scaled(x2))
        
        var terms = [ScaledReturnType.Term(scale: x1, scaledValue: x1TermValue)]
        terms.append(ScaledReturnType.Term(scale: x2, scaledValue: x2TermValue))
        
        return ScaledReturnType(terms: terms)
        
    }
    
    /// DelVecchio 3e, Eq. 9.61(b)
    static func IntegralOf_tK1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        // Return the scaled terms from the calculation of the integral. Note that it is the calling routine's responsibility to multiply each term by e^-xi, then ADD the two terms upon return. Note that the function has been set up so that this will even work if x1=0
        
        let x1TermValue = x1 == 0 ? π / 2.0 :  π / 2.0 * x1 * (Coil.M1(x: x1) * gsl_sf_bessel_K0_scaled(x1) + Coil.M0(x: x1) * gsl_sf_bessel_K1_scaled(x1))
        let x2TermValue = -π / 2.0 * x2 * (Coil.M1(x: x2) * gsl_sf_bessel_K0_scaled(x2) + Coil.M0(x: x2) * gsl_sf_bessel_K1_scaled(x2))
        
        var terms = [ScaledReturnType.Term(scale: -x1, scaledValue: x1TermValue)]
        terms.append(ScaledReturnType.Term(scale: -x2, scaledValue: x2TermValue))
        
        return ScaledReturnType(terms: terms)
    }
    
    /// DelVecchio 3e, Eq. 9.64
    static func IntegralOf_tL1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        let unscaledValue = x1 * Coil.M0(x: x1) - x2 * Coil.M0(x: x2) + (x1 * x1 - x2 * x2) / π + Coil.IntegralOf_M0_t_dt(from: x1, to: x2)
        
        var terms = [ScaledReturnType.Term(scale: 0, scaledValue: unscaledValue)]
        terms.append(contentsOf: Coil.IntegralOf_tI1_t_dt(from: x1, to: x2).terms)
        
        return ScaledReturnType(terms: terms)
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
