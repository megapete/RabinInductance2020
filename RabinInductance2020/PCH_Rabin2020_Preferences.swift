//
//  PCH_Rabin2020_Preferences.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-24.
//

// A new, hopefully more streamlined way of implementing preferences

import Foundation

// Keys into User Defaults
// The multiplier to use for the window height for inductance calculations
fileprivate let DEFAULT_COREHEIGHT_MULIPLIER_KEY = "PCH_RABIN2020_CoreheightMultiplier"
fileprivate let initialCoreHeightMulitplier = 2.5

// Boolean to indicate whether disks should be modeled with their interdisks (inductance calculations only)
fileprivate let MODEL_DISKS_WITH_INTERDISK_DIMENSION = "PCH_RABIN2020_ModelInterdiskDimensions"
fileprivate let initialModelInterdiskDimensions = false

struct PCH_Rabin2020_Prefs:Codable {
    
    private var coreMultiplierStore:Double? = nil
    
    var coreHeightMultiplier:Double
    {
        mutating get {
            
            if let storedValue = self.coreMultiplierStore
            {
                return storedValue
            }
        
            if UserDefaults.standard.object(forKey: DEFAULT_COREHEIGHT_MULIPLIER_KEY) != nil
            {
                self.coreMultiplierStore = UserDefaults.standard.double(forKey: DEFAULT_COREHEIGHT_MULIPLIER_KEY)
            }
            else
            {
                self.coreHeightMultiplier = initialCoreHeightMulitplier
            }
        
            return self.coreMultiplierStore!
        }
        
        set {
            
            UserDefaults.standard.setValue(newValue, forKey: DEFAULT_COREHEIGHT_MULIPLIER_KEY)
            self.coreMultiplierStore = newValue
        }
    }
    
    
}


