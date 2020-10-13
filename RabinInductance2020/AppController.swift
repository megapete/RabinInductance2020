//
//  AppController.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Cocoa

class AppController: NSObject {

    @IBAction func handleTest1(_ sender: Any) {
        
        let coil = Coil(coilID: 1, name: "LV", innerRadius: 10.0 * meterPerInch, outerRadius: 12.5 * meterPerInch, I: 100, core: Core(realWindowHt: 50.0 * meterPerInch, radius: 9.0 * meterPerInch))
    }
    
}
