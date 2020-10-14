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
        let fullSection = Section(sectionID: Section.nextSerialNumber, zMin: 3 * meterPerInch, zMax: 23.3 * meterPerInch, N: 190, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", innerRadius: 13.1 * meterPerInch / 2, outerRadius: 16.4 * meterPerInch / 2, I: 170, sections: [fullSection], core: core)
        
        fullSection.parent = innerCoil
        
        let sectionSelfInductance = fullSection.SelfInductance()
    }
    
}
