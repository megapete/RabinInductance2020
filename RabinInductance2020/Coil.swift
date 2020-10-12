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

class Coil:Codable {
    
    let coilID:Int
    let name:String
    let innerRadius:Double
    let outerRadius:Double
    let J:Double
    
    var sections:[Section]
    
    init(coilID:Int, name:String, innerRadius:Double, outerRadius:Double, J:Double, sections:[Section] = []) {
        
        self.coilID = coilID
        self.name = name
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.J = J
        self.sections = sections
    }
    
    /// DelVecchio 3e, Eq. 9.61(a)
    func IntegralOf_tI1_t_dt(from x1:Double, to x2:Double) -> (x1Term:Double, x2Term:Double)
    {
        // Return the scaled terms from the calculation of the integral. Note that it is the calling routine's responsibility to multiply each term by pi/2 * xi * e^x1, then ADD the two terms upon return.
        
        let x1Term = -(self.M1(x: x1) * gsl_sf_bessel_I0_scaled(x1) - self.M0(x: x1) * gsl_sf_bessel_I1_scaled(x1))
        let x2Term = self.M1(x: x2) * gsl_sf_bessel_I0_scaled(x2) - self.M0(x: x2) * gsl_sf_bessel_I1_scaled(x2)
        
        return (x1Term, x2Term)
    }
    
    /// DelVecchio 3e, Eq. 9.61(b)
    func IntegralOf_tK1_t_dt(from x1:Double, to x2:Double) -> (x1Term:Double, x2Term:Double)
    {
        // Return the scaled terms from the calculation of the integral. Note that it is the calling routine's responsibility to multiply each term by pi/2 * xi * e^-x1, then ADD the two terms upon return.
        
        let x1Term = self.M1(x: x1) * gsl_sf_bessel_K0_scaled(x1) + self.M0(x: x1) * gsl_sf_bessel_K1_scaled(x1)
        let x2Term = -(self.M1(x: x2) * gsl_sf_bessel_K0_scaled(x2) + self.M0(x: x2) * gsl_sf_bessel_K1_scaled(x2))
        
        return (x1Term, x2Term)
    }
    
    /// DelVecchio 3e, Eq. 9.59(a)
    func M0(x:Double) -> Double
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
    func M1(x:Double) -> Double
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
    func IntegralOf_M0_t_dt(from a:Double, to b:Double) -> Double
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
