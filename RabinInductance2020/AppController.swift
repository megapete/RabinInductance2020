//
//  AppController.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Cocoa

class AppController: NSObject {

    @IBAction func handleTest1(_ sender: Any) {
        
        let core = Core(realWindowHt: 0.680, radius: 0.295 / 2)
        
        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: 0.68 + 3 * meterPerInch, zMax: 0.68 + 23.276 * meterPerInch, N: 190, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: 0.68 + 3 * meterPerInch, zMax: 0.68 + 23.276 * meterPerInch, N: 190, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", innerRadius: 13.1 * meterPerInch / 2, outerRadius: 16.396 * meterPerInch / 2, I: 170, sections: [fullInnerSection], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", innerRadius: 19.483 * meterPerInch / 2, outerRadius: 22.779 * meterPerInch / 2, I: 170, sections: [fullOuterSection], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        print("Self Inductance (inner): \(fullInnerSection.SelfInductance()) H")
        print("Self Inductance (outer): \(fullOuterSection.SelfInductance()) H")
        print("Mutual Inductance: \(fullInnerSection.MutualInductanceTo(otherSection: fullOuterSection)) H")
        print("Mutual Inductance (check): \(fullOuterSection.MutualInductanceTo(otherSection: fullInnerSection)) H")
        
        let leakreact = fullInnerSection.SelfInductance() + fullOuterSection.SelfInductance() - 2 * fullInnerSection.MutualInductanceTo(otherSection: fullOuterSection)
        print("Leakage reactance: \(leakreact * 2 * π * 60) ohms")
        
        
        /*
        let n = 100
        let m = Double(n) * π / core.useWindowHt
        let x1 = m * innerCoil.innerRadius
        let x2 = m * innerCoil.outerRadius
        let xc = m * core.radius
        
        
        
        let simpleCnFrom = self.IntegralOf_tK1_t_dt_from_0(to: x1)
        let simpleCnTo = self.IntegralOf_tK1_t_dt_from_0(to: x2)
        let simpleCn = simpleCnTo - simpleCnFrom
        let simpleDn = gsl_sf_bessel_I0(xc) / gsl_sf_bessel_K0(xc) * simpleCn
        let i0k0_simple = gsl_sf_bessel_I0(xc) / gsl_sf_bessel_K0(xc)
        
        let scaledCn_scaled = Coil.IntegralOf_tK1_t_dt(from: x1, to: x2)
        let scaledCn = scaledCn_scaled.totalTrueValue
        let i0k0 = gsl_sf_bessel_I0_scaled(xc) / gsl_sf_bessel_K0_scaled(xc)
        let i0k0_scaled = Coil.ScaledReturnType(terms: [Coil.ScaledReturnType.Term(scale: 2 * xc, scaledValue: i0k0)])
        let i0k0_test = i0k0_scaled.totalTrueValue
        let scaledDn_scaled = i0k0_scaled * scaledCn_scaled
        let scaledDn = scaledDn_scaled.totalTrueValue
        
        let simpleFn = simpleDn - self.IntegralOf_tI1_t_dt_from_0(to: x1)
        let scaledFn = scaledDn - Coil.IntegralOf_tI1_t_dt(from: 0, to: x1).totalTrueValue
        let scaledFn_scaled = (scaledDn_scaled - Coil.IntegralOf_tI1_t_dt(from: 0, to: x1)).totalTrueValue
        let coilFn = innerCoil.Fn[n - 1].totalTrueValue
        print("SimpleCn: \(simpleCn); ScaledCn: \(scaledCn); Diff: \(simpleCn - scaledCn); %Diff: \((simpleCn - scaledCn) / simpleCn)")
        print("SimpleDn: \(simpleDn); ScaledDn: \(scaledDn); Diff: \(simpleDn - scaledDn); %Diff: \((simpleDn - scaledDn) / simpleDn)")
        print("SimpleFn: \(simpleFn); ScaledFn: \(scaledFn); Diff: \(simpleFn - scaledFn); %Diff: \((simpleFn - scaledFn) / simpleFn)")
        */
    }
    
    // MARK: Simple (unscaled) Versions of Del Vecchio functions (for testing)
    func IntegralOf_tI1_t_dt_from_0(to x:Double) -> Double
    {
        return π / 2 * x * (Coil.M1(x: x) * gsl_sf_bessel_I0(x) - Coil.M0(x: x) * gsl_sf_bessel_I1(x))
    }
    
    func IntegralOf_tK1_t_dt_from_0(to x:Double) -> Double
    {
        return π / 2 * (1 - x * (Coil.M1(x: x) * gsl_sf_bessel_K0(x) + Coil.M0(x: x) * gsl_sf_bessel_K1(x)))
    }
    
    func IntegralOf_tK1_t_dt(from x1:Double, to x2:Double) -> Double
    {
        return π / 2 * (x1 * (Coil.M1(x: x1) * gsl_sf_bessel_K0(x1) + Coil.M0(x: x1) * gsl_sf_bessel_K1(x1)) - x2 * (Coil.M1(x: x2) * gsl_sf_bessel_K0(x2) + Coil.M0(x: x2) * gsl_sf_bessel_K1(x2)))
    }
    
    func IntegralOf_tL1_t_dt_from_0(to x:Double) -> Double
    {
        return -x * Coil.M0(x: x) - x * x / π + Coil.IntegralOf_M0_t_dt(from: 0, to: x) + self.IntegralOf_tI1_t_dt_from_0(to: x)
    }
}
