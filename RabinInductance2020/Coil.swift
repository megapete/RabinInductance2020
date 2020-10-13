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

class Coil:Codable {
    
    let coilID:Int
    let name:String
    let innerRadius:Double
    let outerRadius:Double
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
                    return scale * scaledValue
                }
            }
        }
        
        let terms:[Term]
        
        var totalTrueValue:Double {
            get {
                
                var result = 0.0
                
                for nextTerm in self.terms
                {
                    result += nextTerm.trueValue
                }
                
                return result
            }
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
                var scale = nextLhsTerm.scale
                var value = nextLhsTerm.scaledValue
                
                for nextRhsTerm in rhs.terms
                {
                    scale += nextRhsTerm.scale
                    value *= nextRhsTerm.scaledValue
                }
                
                newTerms.append(Coil.ScaledReturnType.Term(scale: scale, scaledValue: value))
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
    
    var Cn:[ScaledReturnType] = []
    var Dn:[ScaledReturnType] = []
    var Fn:[ScaledReturnType] = []
    var En:[ScaledReturnType] = []
    
    // Integrals whose values we'll need
    var I1n:[ScaledReturnType] = []
    var L1n:[ScaledReturnType] = []
    
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
        
        for n in 1...convergenceIterations
        {
            let m = Double(n) * π / core.useWindowHt
            let x1 = m * innerRadius
            let x2 = m * outerRadius
            let xc = m * core.radius
            
            let newCn = Coil.IntegralOf_tK1_t_dt(from: x1, to: x2)
            
            let i0k0_scaled = gsl_sf_bessel_I0_scaled(xc) / gsl_sf_bessel_K0_scaled(xc)
            
            var dTerms = [ScaledReturnType.Term(scale: 2 * xc + newCn.terms[0].scale, scaledValue: i0k0_scaled * newCn.terms[0].scaledValue), ScaledReturnType.Term(scale: 2 * xc + newCn.terms[1].scale, scaledValue: i0k0_scaled * newCn.terms[1].scaledValue)]
            
            let newDn = ScaledReturnType(terms: dTerms)
            
            let integralI_scaled = Coil.IntegralOf_tI1_t_dt(from: 0, to: x1)
            dTerms.append(ScaledReturnType.Term(scale: integralI_scaled.terms[1].scale, scaledValue: -integralI_scaled.terms[1].scaledValue))
            
            let newFn = ScaledReturnType(terms: dTerms)
            
            let newEn = Coil.IntegralOf_tK1_t_dt(from: 0, to: x2)
            
            self.Cn.append(newCn)
            self.Dn.append(newDn)
            self.Fn.append(newFn)
            self.En.append(newEn)
            
            let newI1 = Coil.IntegralOf_tI1_t_dt(from: x1, to: x2)
            self.I1n.append(newI1)
            let newL1 = Coil.IntegralOf_tL1_t_dt(from: x1, to: x2)
            self.L1n.append(newL1)
            
            if n % 50 == 0
            {
                print("Cn: \(newCn)")
                print("Dn: \(newDn)")
                print("Fn: \(newFn)")
                print("En: \(newEn)")
                print("I1n: \(newI1)")
                print("L1n: \(newL1)")
                
            }
        }
        
        
    }
    
    /// DelVecchio 3e, Eq. 9.61(a)
    static func IntegralOf_tI1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        // Return the scaled terms from the calculation of the integral.
        
        let x1TermValue = x1 == 0 ? 0 : -π / 2.0 * x1 * (Coil.M1(x: x1) * gsl_sf_bessel_I0_scaled(x1) - Coil.M0(x: x1) * gsl_sf_bessel_I1_scaled(x1))
        let x2TermValue = π / 2.0 * x2 * Coil.M1(x: x2) * gsl_sf_bessel_I0_scaled(x2) - Coil.M0(x: x2) * gsl_sf_bessel_I1_scaled(x2)
        
        var terms = [ScaledReturnType.Term(scale: x1, scaledValue: x1TermValue)]
        terms.append(ScaledReturnType.Term(scale: x2, scaledValue: x2TermValue))
        
        return ScaledReturnType(terms: terms)
        
    }
    
    /// DelVecchio 3e, Eq. 9.61(b)
    static func IntegralOf_tK1_t_dt(from x1:Double, to x2:Double) -> ScaledReturnType
    {
        // Return the scaled terms from the calculation of the integral. Note that it is the calling routine's responsibility to multiply each term by e^-xi, then ADD the two terms upon return. Note that the function has been set up so that this will even work if x1=0
        
        let x1TermValue = x1 == 0 ? π / 2.0 :  π / 2.0 * x1 * Coil.M1(x: x1) * gsl_sf_bessel_K0_scaled(x1) + Coil.M0(x: x1) * gsl_sf_bessel_K1_scaled(x1)
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
