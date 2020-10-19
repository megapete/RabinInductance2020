//
//  Matrix.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-17.
//

// The idea here is to make a simpler, better thought-out matrix class than the bloatware that PCH_Matrix turned into. Specifcally, we're going for something faster and more lightweight for use with the BIL simulation program. Everything is based on BLAS and LAPACK routines.  For now, most things only work with __CLPK_doublereal (Double).

import Cocoa
import Accelerate

/// A general-purpose, lightweight matrix class. Double and Complex types are allowed,
class Matrix:CustomStringConvertible {
    
    /// A simple way of looking at the matrix in the Debug window. Don't use this for huge (or supersmall) numbers
    var description: String {
        get {
            
            var result = ""
            
            for j in 0..<self.rows
            {
                result += "|"
                for i in 0..<self.columns
                {
                    if self.type == .Double
                    {
                        let number:Double = self[j, i]
                        result.append(String(format: " % 6.3f", number))
                    }
                    else
                    {
                        let number:Complex = self[j, i]
                        result.append(String(format: " % 5.3fI%5.3f", number.real, number.imag))
                    }
                }
                
                result += " |\n"
            }
            
            return result
        }
    }
    
    /// The two number types that we allow
    enum NumberType {
        case Double
        case Complex
    }
    
    let type:NumberType
    
    /// The actual buffers that hold the matrix
    private let doubleBuffPtr:UnsafeMutablePointer<__CLPK_doublereal>
    private let complexBuffPtr:UnsafeMutablePointer<__CLPK_doublecomplex>
    
    /// The number of rows in the matrix
    let rows:Int
    /// The number of columns in the matrix
    let columns:Int
    
    /// The designated initializer for the class. Note that the rows and columns must be passed as UInts (to enforce >0 rules at the compiler level) but are immediately converted to Ints internally to keep from having to wrap things in Int()
    init(type:NumberType, rows:UInt, columns:UInt) {
        
        self.type = type
        self.rows = Int(rows)
        self.columns = Int(columns)
        
        if type == .Double
        {
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: Int(rows * columns))
            self.doubleBuffPtr.assign(repeating: 0.0, count: Int(rows * columns))
            // This is easier than trying to assign nil to the pointer
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: 1)
        }
        else
        {
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: Int(rows * columns))
            self.complexBuffPtr.assign(repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: Int(rows * columns))
            // This is easier than trying to assign nil to the pointer
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: 1)
        }
    }
    
    /// Accessor for Double matrices
    subscript(row:Int, column:Int) -> Double
    {
        get {
            
            assert(self.type == .Double, "Illegal type")
            assert(checkBounds(row: row, column: column), "Subscript out of bounds")

            return self.doubleBuffPtr[(column * self.rows) + row]
        }
        
        set {
            
            assert(self.type == .Double, "Illegal type")
            assert(checkBounds(row: row, column: column), "Subscript out of bounds")

            self.doubleBuffPtr[(column * self.rows) + row] = newValue
        }
    }
    
    /// Accessor for Complex matrices
    subscript(row:Int, column:Int) -> Complex
    {
        get {
            
            assert(self.type == .Complex, "Illegal type")
            assert(checkBounds(row: row, column: column), "Subscript out of bounds")

            let clpk_result = self.complexBuffPtr[Int((column * self.rows) + row)]
            let result = Complex(real: clpk_result.r, imag: clpk_result.i)
            return result
        }
        
        set {
            
            assert(self.type == .Double, "Illegal type")
            assert(checkBounds(row: row, column: column), "Subscript out of bounds")

            let clpk_newValue = __CLPK_doublecomplex(r: newValue.real, i: newValue.imag)
            self.complexBuffPtr[(column * self.rows) + row] = clpk_newValue
        }
    }
    
    static func * (scalar:Double, matrix:Matrix) -> Matrix
    {
        assert(matrix.type == .Double, "Mismatched types")
        let result = Matrix(type: .Double, rows: UInt(matrix.rows), columns: UInt(matrix.columns))
        
        for i in 0..<matrix.columns
        {
            for j in 0..<matrix.rows
            {
                let oldNum:Double = matrix[i, j]
                result[i, j] = oldNum * scalar
            }
        }
        
        return result
    }
    
    // return true if the bounds are okay
    private func checkBounds(row:Int, column:Int) -> Bool
    {
        return row < self.rows && column < self.columns
    }
    
    /// A routine to check whether a matrix is really positive-definite or not (inductance matrix is supposed to always be). The idea comes from this discussion: https://icl.cs.utk.edu/lapack-forum/viewtopic.php?f=2&t=3534. The idea is to try and perform a Cholesky factorization of the matrix (LAPACK routine DPOTRF). If the factorization is successfull, the matrix is positive definite.
    func TestPositiveDefinite() -> Bool
    {
        
        return true
    }
    
}

/// A class for displaying a Matrix in a window that has an NSTableView (like a spreadsheet). Some of the logic in here comes from the PCH_DialogBox class
class MatrixDisplay:NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet var window: NSWindow!
    @IBOutlet weak var contentView: NSView!
    
    var matrix:Matrix
    var windowTitle:String
    
    init?(windowTitle:String, matrix:Matrix)
    {
        self.matrix = matrix
        self.windowTitle = windowTitle
        
        super.init()
        
        guard let newNib = NSNib(nibNamed: "MatrixDisplay", bundle: Bundle.main) else
        {
            ALog("Could not load NIB file")
            return nil
        }
        
        if !newNib.instantiate(withOwner: self, topLevelObjects: nil)
        {
            ALog("Could not instantiate window")
            return nil
        }
    }
    
    override func awakeFromNib() {
        
        // This is where everything needs to be set up
        let dummyField = NSTextField(labelWithString: "9999999999")
        let fieldRect = dummyField.frame
        print(fieldRect)
        
        var rowViews:[[NSTextField]] = []
        for i in 0..<self.matrix.rows
        {
            var nextRow:[NSTextField] = []
            for j in 0..<self.matrix.columns
            {
                let newField = NSTextField(labelWithString: "9999999999")
                newField.stringValue = "\(i+1)-\(j+1)"
                newField.alignment = .center
                
                nextRow.append(newField)
            }
            
            rowViews.append(nextRow)
        }
        
        let gridView = NSGridView(views: rowViews)
        gridView.frame = self.contentView.frame
        self.contentView.addSubview(gridView)
        
        self.window.title = self.windowTitle
        self.window.makeKeyAndOrderFront(self)
    }
    
    
}
