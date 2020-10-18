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
        
        let innerCoil = Coil(coilID: 1, name: "Inner", currentDirection: -1, innerRadius: 13.1 * meterPerInch / 2, outerRadius: 16.396 * meterPerInch / 2, I: 170, sections: [fullInnerSection], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", currentDirection: 1, innerRadius: 19.483 * meterPerInch / 2, outerRadius: 22.779 * meterPerInch / 2, I: 170, sections: [fullOuterSection], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        print("Self Inductance (inner): \(fullInnerSection.SelfInductance()) H")
        print("Self Inductance (outer): \(fullOuterSection.SelfInductance()) H")
        print("Mutual Inductance: \(fullInnerSection.MutualInductanceTo(otherSection: fullOuterSection)) H")
        print("Mutual Inductance (check): \(fullOuterSection.MutualInductanceTo(otherSection: fullInnerSection)) H")
        
        let leakageInductance = fullInnerSection.SelfInductance() + fullOuterSection.SelfInductance() - 2 * fullInnerSection.MutualInductanceTo(otherSection: fullOuterSection)
        print("leakage inductance (LV side): \(leakageInductance)")
        print("Leakage reactance: \(leakageInductance * 2 * π * 60) ohms")
        
        let phase = Phase(core: core, coils: [innerCoil, outerCoil])
        
        let energy = phase.Energy()
        
        print("Energy: \(energy)")
        print("Leakage inductance from energy (LV side): \(2.0 * energy / (170.0 * 170.0))")
    }
    
    @IBAction func handleTest2(_ sender: Any) {
        
        let core = Core(realWindowHt: 1.26, radius: 0.483 / 2)
        
        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: 1.26 + 3.5 * meterPerInch, zMax: 1.26 + (3.5 + 41.025) * meterPerInch, N: 64, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: 1.26 + 3.5 * meterPerInch, zMax: 1.26 + (3.5 + 41.025) * meterPerInch, N: 613, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", currentDirection: -1, innerRadius: 20.5 * meterPerInch / 2, outerRadius: 23.723 * meterPerInch / 2, I: 801.3, sections: [fullInnerSection], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", currentDirection: 1, innerRadius: 26.723 * meterPerInch / 2, outerRadius: 30.274 * meterPerInch / 2, I: 83.67, sections: [fullOuterSection], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        print("Self Inductance (inner): \(fullInnerSection.SelfInductance()) H")
        print("Self Inductance (outer): \(fullOuterSection.SelfInductance()) H")
        print("Mutual Inductance: \(fullInnerSection.MutualInductanceTo(otherSection: fullOuterSection)) H")
        print("Mutual Inductance (check): \(fullOuterSection.MutualInductanceTo(otherSection: fullInnerSection)) H")
        
        let leakageInductance = fullInnerSection.SelfInductance() + pow((fullInnerSection.N / fullOuterSection.N), 2.0) * fullOuterSection.SelfInductance() - 2 * (fullInnerSection.N / fullOuterSection.N) * fullInnerSection.MutualInductanceTo(otherSection: fullOuterSection)
        print("leakage inductance (LV side): \(leakageInductance)")
        print("Leakage reactance: \(leakageInductance * 2 * π * 60) ohms")
        
        let phase = Phase(core: core, coils: [innerCoil, outerCoil])
        
        let energy = phase.Energy()
        
        print("Energy: \(energy)")
        print("Leakage inductance from energy (LV side): \(2.0 * energy / (801.3 * 801.3))")
        
        print("Reactance (pu): \(phase.LeakageReactancePU(baseVA: 10.0E6 / 3.0, baseI: 801.3))")
    }
    
    @IBAction func handleTest3(_ sender: Any) {
        
        let core = Core(realWindowHt: 1.26, radius: 0.483 / 2)
        
        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: 1.26 + 3.5 * meterPerInch, zMax: 1.26 + (3.5 + 41.025) * meterPerInch, N: 64, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: 1.26 + 3.5 * meterPerInch, zMax: 1.26 + (3.5 + 41.025) * meterPerInch, N: 613, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", currentDirection: -1, innerRadius: 20.5 * meterPerInch / 2, outerRadius: 23.723 * meterPerInch / 2, I: 801.3, sections: [], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", currentDirection: 1, innerRadius: 26.723 * meterPerInch / 2, outerRadius: 30.274 * meterPerInch / 2, I: 83.67, sections: [], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        innerCoil.sections = fullInnerSection.SplitSection(numSections: 4)
        outerCoil.sections = fullOuterSection.SplitSection(numSections: 4)
        
        let phase = Phase(core: core, coils: [innerCoil, outerCoil])
        
        let testMatrix = 1000.0 * phase.InductanceMatrix()
        
        let matrixDisplay = MatrixDisplay(windowTitle: "Matrix", matrix: testMatrix)
        
        print("Reactance (pu): \(phase.LeakageReactancePU(baseVA: 10.0E6 / 3.0, baseI: 83.67))")
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
