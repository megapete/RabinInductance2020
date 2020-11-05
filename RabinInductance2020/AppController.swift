//
//  AppController.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Cocoa

// Key (String) so that the user doesn't have to go searching for the last folder he opened
let LAST_OPENED_INPUT_FILE_KEY = "PCH_RABIN2020_LastInputFile"

class AppController: NSObject {
    
    @IBOutlet weak var mainWindow: NSWindow!
    var currentPhase:Phase? = nil
    
    @IBAction func handleOpenDesignFile(_ sender: Any) {
        
        let openPanel = NSOpenPanel()
        
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Design file"
        openPanel.message = "Open a valid Excel-design-sheet-generated file"
        openPanel.allowsMultipleSelection = false
        
        // If there was a previously successfully opened design file, set that file's directory as the default, otherwise go to the user's Documents folder
        if let lastFile = UserDefaults.standard.url(forKey: LAST_OPENED_INPUT_FILE_KEY)
        {
            openPanel.directoryURL = lastFile.deletingLastPathComponent()
        }
        else
        {
            openPanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        if openPanel.runModal() == .OK
        {
            if let fileURL = openPanel.url
            {
                let _ = self.doOpen(fileURL: fileURL)
            }
            else
            {
                DLog("This shouldn't ever happen...")
            }
        }
    }
    
    func doOpen(fileURL:URL) -> Bool {
        
        if !FileManager.default.fileExists(atPath: fileURL.path)
        {
            let alert = NSAlert()
            alert.messageText = "The file does not exist!"
            alert.alertStyle = .critical
            let _ = alert.runModal()
            return false
        }
        
        do {
            
            // create the current Transformer from the Excel design file
            let newDesign = try PCH_ExcelDesignFile(designFile: fileURL)
            
            // if we make it here, we have successfully opened the file, so save it as the "last successfully opened file"
            UserDefaults.standard.set(fileURL, forKey: LAST_OPENED_INPUT_FILE_KEY)
            
            NSDocumentController.shared.noteNewRecentDocumentURL(fileURL)
            
            self.mainWindow.title = fileURL.lastPathComponent
            
            self.currentPhase = Phase(xlDesign: newDesign)
            
            return true
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return false
        }
    }
    
    @IBAction func handleCalculateReactance(_ sender: Any) {
        
        guard let phase = self.currentPhase else
        {
            return
        }
        
        let reactance = phase.LeakageReactancePU(baseVA: phase.coils[0].xlWinding!.terminal.kVA / 3 * 1000.0, baseI: phase.coils[0].I)
        
        print("Reactance: \(reactance)")
    }
    
    @IBAction func handleCreateMatrix(_ sender: Any) {
        
        guard let phase = self.currentPhase else
        {
            return
        }
        
        let indMatrix = phase.RecalculateInductanceMatrix()
        
        print("Matrix is positive definite: \(indMatrix.TestPositiveDefinite())")
        
        // let _ = MatrixDisplay(windowTitle: "Matrix", matrix: indMatrix)
    }
    
    @IBAction func handleTestMatrixOpen(_ sender: Any) {
        
        let panel = NSOpenPanel()
        
        panel.allowedFileTypes = ["txt"]
        panel.allowsOtherFileTypes = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK
        {
            if let fileURL = panel.url
            {
                do {
                    
                    let fileData = try Data(contentsOf: fileURL)
                    
                    let decoder = JSONDecoder()
                    
                    let testMatrix = try decoder.decode(Matrix.self, from: fileData)
                    
                    let _ = MatrixDisplay(matrix: testMatrix)
                    
                }
                catch {
                    
                    let alert = NSAlert(error: error)
                    let _ = alert.runModal()
                    return
                }
                
                
            }
        }
    }
    
    
    @IBAction func handleTestMatrixSave(_ sender: Any) {
        
        let testMatrix = Matrix(type: .Double, rows: 3, columns: 5)
        
        var value = 1.0
        for i in 0..<3
        {
            for j in 0..<5
            {
                testMatrix[i, j] = value
                value += 1.0
            }
        }
        
        // let _ = MatrixDisplay(matrix: testMatrix)
        
        let panel = NSSavePanel()
        
        panel.allowedFileTypes = ["txt"]
        panel.allowsOtherFileTypes = false
        
        if panel.runModal() == .OK
        {
            if let fileURL = panel.url
            {
                let encoder = JSONEncoder()
                
                do {
                    
                    let fileData = try encoder.encode(testMatrix)
                    
                    if FileManager.default.fileExists(atPath: fileURL.path)
                    {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                    
                    FileManager.default.createFile(atPath: fileURL.path, contents: fileData, attributes: nil)
                }
                catch {
                    
                    let alert = NSAlert(error: error)
                    let _ = alert.runModal()
                    return
                }
            }
        }
        
    }
    
    @IBAction func handleTest1(_ sender: Any) {
        
        let core = Core(realWindowHt: 0.680, radius: 0.295 / 2)
        
        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: 0 + 3 * meterPerInch, zMax: 0.68 + 23.276 * meterPerInch, N: 190, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: 0 + 3 * meterPerInch, zMax: 0.68 + 23.276 * meterPerInch, N: 190, inNode: 0, outNode: 0)
        
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
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: 0 + 3.5 * meterPerInch, zMax: 1.26 + (3.5 + 41.025) * meterPerInch, N: 64, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: 0 + 3.5 * meterPerInch, zMax: 1.26 + (3.5 + 41.025) * meterPerInch, N: 613, inNode: 0, outNode: 0)
        
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
        let zOffset = 0 * meterPerInch // (Core.windowHtMultiplier - 1.0) / 2 * core.realWindowHt
        
        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: zOffset + 3.5 * meterPerInch, zMax: zOffset + (3.5 + 41.025) * meterPerInch, N: 64, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: zOffset + 3.5 * meterPerInch, zMax: zOffset + (3.5 + 41.025) * meterPerInch, N: 613, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", currentDirection: -1, innerRadius: 20.5 * meterPerInch / 2, outerRadius: 23.723 * meterPerInch / 2, I: 801.3, sections: [], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", currentDirection: 1, innerRadius: 26.723 * meterPerInch / 2, outerRadius: 30.274 * meterPerInch / 2, I: 83.67, sections: [], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        innerCoil.sections = fullInnerSection.SplitSection(numSections: 10)
        outerCoil.sections = fullOuterSection.SplitSection(numSections: 10)
        
        let phase = Phase(core: core, coils: [innerCoil, outerCoil])
        
        let testMatrix = phase.RecalculateInductanceMatrix()
        
        let testPosDef = testMatrix.TestPositiveDefinite()
        
        print("Matrix is Positive Definite: \(testPosDef)")
        
        let _ = MatrixDisplay(windowTitle: "Matrix", matrix: testMatrix)
        
        print("Reactance (pu): \(phase.LeakageReactancePU(baseVA: 10.0E6 / 3.0, baseI: 83.67))")
    }
    
    @IBAction func handleTest4(_ sender: Any) {
        
        let A = Matrix(type: .Double, rows: 8, columns: 8)
        for i in 0..<8
        {
            for j in 0..<8
            {
                A[i, j] = Double.random(in: -25.2...53.7)
            }
        }
        
        let _ = MatrixDisplay(windowTitle: "A-matrix", matrix: A)
        
        let X = Matrix(type: .Double, rows: 8, columns: 1)
        
        var nextNum = 5.0
        for i in 0..<8
        {
            X[i, 0] = nextNum
            
            nextNum += 2.0
        }
        
        let _ = MatrixDisplay(windowTitle: "X-matrix", matrix: X)
        
        let _ = MatrixDisplay(windowTitle: "B-Matrix", matrix: A * X)
        
        let B = A * X
        
        let solvedX = Matrix(srcMatrix: B)
        
        if A.SolveForDoubleGeneralMatrix(B: solvedX.doubleBuffPtr, numBcols: 1)
        {
            print("Solved it!")
        }
        
        let _ = MatrixDisplay(windowTitle: "Solved X", matrix: solvedX)
    }
    
    @IBAction func handleTest5(_ sender: Any) {
        
        let core = Core(realWindowHt: 1.26, radius: 0.483 / 2)
        let zOffset = 0 * meterPerInch // (Core.windowHtMultiplier - 1.0) / 2 * core.realWindowHt

        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: zOffset + 3.5 * meterPerInch, zMax: zOffset + (3.5 + 41.025) * meterPerInch, N: 64, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: zOffset + 3.5 * meterPerInch, zMax: zOffset + (3.5 + 41.025) * meterPerInch, N: 613, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", currentDirection: -1, innerRadius: 20.5 * meterPerInch / 2, outerRadius: 23.723 * meterPerInch / 2, I: 801.3, sections: [], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", currentDirection: 1, innerRadius: 26.723 * meterPerInch / 2, outerRadius: 30.274 * meterPerInch / 2, I: 83.67, sections: [], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        innerCoil.sections = fullInnerSection.SplitSection(numSections: 10, withInterdisk: 0.15 * 0.98 * meterPerInch)
        outerCoil.sections = fullOuterSection.SplitSection(numSections: 10, withInterdisk: 0.2 * 0.98 * meterPerInch)
        
        let totalSections = innerCoil.sections.count + outerCoil.sections.count
        
        let phase = Phase(core: core, coils: [innerCoil, outerCoil])
        
        let A = phase.RecalculateInductanceMatrix()
        
        let testPosDef = A.TestPositiveDefinite()
        
        print("Matrix is Positive Definite: \(testPosDef)")
        
        let _ = MatrixDisplay(windowTitle: "M-Matrix", matrix: A)
        
        print("Reactance (pu): \(phase.LeakageReactancePU(baseVA: 10.0E6 / 3.0, baseI: 83.67))")
        
        let X = Matrix(type: .Double, rows: UInt(totalSections), columns: 1)
        for i in 0..<(totalSections)
        {
            X[i, 0] = Double.random(in: 0.5...2.5)
        }
        
        // let _ = MatrixDisplay(windowTitle: "X-matrix", matrix: X)
        
        let B = A * X
        
        // let _ = MatrixDisplay(windowTitle: "B-Matrix", matrix: B)
        
        let solvedX = Matrix(srcMatrix: B)
        
        if A.SolveForDoubleGeneralMatrix(B: solvedX.doubleBuffPtr, numBcols: 1)
        {
            print("Solved As General Matrix!")
        }
        
        if solvedX == X
        {
            print("solvedX equals X")
        }
        else
        {
            print("ERROR: solvedX not equal to X")
        }
        
        // let _ = MatrixDisplay(windowTitle: "Solved X", matrix: solvedX)
        
        let factoredA = Matrix(srcMatrix: A)
        let _ = factoredA.TestPositiveDefinite(overwriteExistingMatrix: true)
        // let _ = MatrixDisplay(windowTitle: "Factored M-Matrix", matrix: factoredA)
        let solvedPosDefX = Matrix(srcMatrix: B)
        if factoredA.SolveForDoublePositiveDefinite(B: solvedPosDefX.doubleBuffPtr, numBcols: 1)
        {
            print("Solved As Positive Definite Matrix!")
        }
        
        if solvedPosDefX == X
        {
            print("solvedPosX equals X")
        }
        else
        {
            print("ERROR: solvedPosDefX not equal to X")
        }
        
        // let _ = MatrixDisplay(windowTitle: "Solved Positive Definite X", matrix: solvedPosDefX)
    }
    
    @IBAction func handleTest6(_ sender: Any) {
        
        let core = Core(realWindowHt: 1.26, radius: 0.483 / 2)

        // we're tripling the window height, so we'll just add one window height to the z-dims of the coils
        let fullInnerSection = Section(sectionID: Section.nextSerialNumber, zMin: 0 + 3.5 * meterPerInch, zMax: 0 + (3.5 + 41.025) * meterPerInch, N: 64, inNode: 0, outNode: 0)
        let fullOuterSection = Section(sectionID: Section.nextSerialNumber, zMin: 0 + 3.5 * meterPerInch, zMax: 0 + (3.5 + 41.025) * meterPerInch, N: 613, inNode: 0, outNode: 0)
        
        let innerCoil = Coil(coilID: 1, name: "Inner", currentDirection: -1, innerRadius: 20.5 * meterPerInch / 2, outerRadius: 23.723 * meterPerInch / 2, I: 801.3, sections: [], core: core)
        let outerCoil = Coil(coilID: 2, name: "Outer", currentDirection: 1, innerRadius: 26.723 * meterPerInch / 2, outerRadius: 30.274 * meterPerInch / 2, I: 83.67, sections: [], core: core)
        
        fullInnerSection.parent = innerCoil
        fullOuterSection.parent = outerCoil
        
        innerCoil.sections = fullInnerSection.SplitSection(numSections: 64, withInterdisk: 0.15 * 0.98 * meterPerInch)
        outerCoil.sections = fullOuterSection.SplitSection(numSections: 60, withInterdisk: 0.2 * 0.98 * meterPerInch)
        
        innerCoil.InitializeJ()
        
        print("Jinner = \(fullInnerSection.J(I: innerCoil.I, radialBuild: innerCoil.radialBuild))")
        
        
    }
    
    @IBAction func handleTest7(_ sender: Any) {
        
        self.handleOpenDesignFile(sender)
        
        var nextMultiplier = 2.5
        
        guard let phase = self.currentPhase else
        {
            return
        }
        
        while nextMultiplier < 3.01
        {
            let newCore = Core(realWindowHt: phase.core.realWindowHt, radius: phase.core.radius, windowMultiplier: nextMultiplier)
            
            var newCoils:[Coil] = []
            for nextCoil in phase.coils
            {
                var newSections = nextCoil.sections
                for nextSection in newSections
                {
                    nextSection.Jn = []
                }
                
                let newCoil = Coil(coilID: nextCoil.coilID, name: nextCoil.name, currentDirection: nextCoil.currentDirection, innerRadius: nextCoil.innerRadius, outerRadius: nextCoil.outerRadius, I: nextCoil.I, sections: newSections, core: newCore, xlWinding: nil)
                
                newCoils.append(newCoil)
            }
            
            let newPhase = Phase(core: newCore, coils: newCoils)
            
            print("Calculating inductance matrix entries...")
            let A = newPhase.RecalculateInductanceMatrix()
            print("Done!\n")
            
            print("Checking if positive definite..")
            let testPosDef = A.TestPositiveDefinite() ? "" : "NOT "
            print("Done!\n")
            
            print("Calculating reactance...")
            let reactance = newPhase.LeakageReactancePU(baseVA: phase.coils[0].xlWinding!.terminal.kVA / 3 * 1000.0, baseI: phase.coils[0].I)
            print("Done!\n")
            
            print("For WindHtMult = \(nextMultiplier): Matrix is \(testPosDef)Positive Definite; Reactance: \(reactance)\n\n")
            
            nextMultiplier += 0.1
        }
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
