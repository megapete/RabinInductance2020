//
//  AppController.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Cocoa

class AppController: NSObject {

    @IBAction func handleTest1(_ sender: Any) {
        
        let testCoil = Coil(coilID: 1, name: "Nothing", innerRadius: 0.5, outerRadius: 0.75, J: 3.0E-6)
        
        DLog("M(200):\(testCoil.M0(x: 200.0))")
    }
    
}
