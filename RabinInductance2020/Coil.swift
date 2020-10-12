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

fileprivate let convergenceIterations = 200

class Coil:Codable {
    
    let coilID:Int
    let name:String
    let innerRadius:Double
    let outerRadius:Double
    let J:Double
    
    struct IntegralReturnType:Codable {
        
        let scale1:Double
        let scaledTerm1:Double
        
        var unscaledTerm1:Double {
            get {
                return exp(scale1) * scaledTerm1
            }
        }
        
        let scale2:Double
        let scaledTerm2:Double
        
        var unscaledTerm2:Double {
            get {
                return exp(scale2) * scaledTerm2
            }
        }
        
        var unscaledResult:Double {
            get {
                return unscaledTerm1 + unscaledTerm2
            }
        }
    }
    
    var Cn:[IntegralReturnType] = []
    var Dn:[IntegralReturnType] = []
    
    var sections:[Section]
    
    init(coilID:Int, name:String, innerRadius:Double, outerRadius:Double, J:Double, sections:[Section] = [], core:Core) {
        
        self.coilID = coilID
        self.name = name
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.J = J
        self.sections = sections
        
        for n in 1...convergenceIterations
        {
            let m = Double(n) * π / core.useWindowHt
            let x1 = m * innerRadius
            let x2 = m * outerRadius
            let xc = m * core.radius
            
            let newCn = Coil.IntegralOf_tK1_t_dt(from: x1, to: x2)
            
            let i0k0_scaled = gsl_sf_bessel_I0_scaled(xc) / gsl_sf_bessel_K0_scaled(xc)
            let newDn = Coil.IntegralReturnType(scale1: 2 * xc + newCn.scale1, scaledTerm1: i0k0_scaled * newCn.scaledTerm1, scale2: 2 * xc + newCn.scale2, scaledTerm2: i0k0_scaled * newCn.scaledTerm2)
        }
    }
    
    /// DelVecchio 3e, Eq. 9.61(a)
    static func IntegralOf_tI1_t_dt(from x1:Double, to x2:Double) -> IntegralReturnType
    {
        // Return the scaled terms from the calculation of the integral.
        
        let x1Term = x1 == 0 ? 0 : -π / 2.0 * x1 * (Coil.M1(x: x1) * gsl_sf_bessel_I0_scaled(x1) - Coil.M0(x: x1) * gsl_sf_bessel_I1_scaled(x1))
        let x2Term = π / 2.0 * x2 * Coil.M1(x: x2) * gsl_sf_bessel_I0_scaled(x2) - Coil.M0(x: x2) * gsl_sf_bessel_I1_scaled(x2)
        
        return IntegralReturnType(scale1: x1, scaledTerm1: x1Term, scale2: x2, scaledTerm2: x2Term)
    }
    
    /// DelVecchio 3e, Eq. 9.61(b)
    static func IntegralOf_tK1_t_dt(from x1:Double, to x2:Double) -> IntegralReturnType
    {
        // Return the scaled terms from the calculation of the integral. Note that it is the calling routine's responsibility to multiply each term by e^-xi, then ADD the two terms upon return. Note that the function has been set up so that this will even work if x1=0
        
        let x1Term = x1 == 0 ? π / 2.0 :  π / 2.0 * x1 * Coil.M1(x: x1) * gsl_sf_bessel_K0_scaled(x1) + Coil.M0(x: x1) * gsl_sf_bessel_K1_scaled(x1)
        let x2Term = -π / 2.0 * x2 * (Coil.M1(x: x2) * gsl_sf_bessel_K0_scaled(x2) + Coil.M0(x: x2) * gsl_sf_bessel_K1_scaled(x2))
        
        return IntegralReturnType(scale1: -x1, scaledTerm1: x1Term, scale2: -x2, scaledTerm2: x2Term)
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
