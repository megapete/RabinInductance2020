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
    var doubleBuffPtr:UnsafeMutablePointer<__CLPK_doublereal>
    var complexBuffPtr:UnsafeMutablePointer<__CLPK_doublecomplex>
    
    /// The number of rows in the matrix
    let rows:Int
    /// The number of columns in the matrix
    let columns:Int
    
    /// The designated initializer for the class. Note that the rows and columns must be passed as UInts (to enforce >0 rules at the compiler level) but are immediately converted to Ints internally to keep from having to wrap things in Int()
    init(type:NumberType, rows:UInt, columns:UInt) {
        
        self.type = type
        
        // force vectors to have a single column instead of a single row
        if rows == 1
        {
            self.columns = 1
            self.rows = Int(columns)
        }
        else
        {
            self.rows = Int(rows)
            self.columns = Int(columns)
        }
        
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
    
    /// Copy constructor. Note that this function makes a deep copy of the source matrix.
    /// - Parameter srcMatrix: The matrix to copy
    init(srcMatrix:Matrix)
    {
        self.type = srcMatrix.type
        self.rows = srcMatrix.rows
        self.columns = srcMatrix.columns
        
        if self.type == .Double
        {
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: self.rows * self.columns)
            self.doubleBuffPtr.assign(from: srcMatrix.doubleBuffPtr, count: rows * columns)
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: 1)
        }
        else
        {
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: self.rows * self.columns)
            self.complexBuffPtr.assign(from: srcMatrix.complexBuffPtr, count: rows * columns)
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: 1)
        }
    }
    
    /// Dummy initializer
    init()
    {
        self.type = .Double
        self.rows = 0
        self.columns = 0
        self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: 1)
        self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: 1)
    }
    
    /// We need to take care of memory cleanup ourselves
    deinit {
        self.doubleBuffPtr.deallocate()
        self.complexBuffPtr.deallocate()
    }
    
    /// Accessor for Double matrices
    subscript(row:Int, column:Int) -> Double
    {
        get {
            
            if self.type != .Double
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Illegal type")
                return Double.nan
            }
            if !checkBounds(row: row, column: column)
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Subscript out of bounds")
                return Double.nan
            }

            return self.doubleBuffPtr[(column * self.rows) + row]
        }
        
        set {
            
            if self.type != .Double
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Illegal type")
                return
            }
            if !checkBounds(row: row, column: column)
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Subscript out of bounds")
                return
            }

            self.doubleBuffPtr[(column * self.rows) + row] = newValue
        }
    }
    
    /// Accessor for Complex matrices
    subscript(row:Int, column:Int) -> Complex
    {
        get {
            
            if self.type != .Complex
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Illegal type")
                return Complex.ComplexNan
            }
            if !checkBounds(row: row, column: column)
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Subscript out of bounds")
                return Complex.ComplexNan
            }

            let clpk_result = self.complexBuffPtr[Int((column * self.rows) + row)]
            let result = Complex(real: clpk_result.r, imag: clpk_result.i)
            return result
        }
        
        set {
            
            if self.type != .Complex
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Illegal type")
                return
            }
            if !checkBounds(row: row, column: column)
            {
                PCH_ErrorAlert(message: "Subscript error", info: "Subscript out of bounds")
                return
            }

            let clpk_newValue = __CLPK_doublecomplex(r: newValue.real, i: newValue.imag)
            self.complexBuffPtr[(column * self.rows) + row] = clpk_newValue
        }
    }
    
    static func * (scalar:Double, matrix:Matrix) -> Matrix
    {
        if matrix.type != .Double
        {
            PCH_ErrorAlert(message: "Scalar multiplication error", info: "Illegal type")
            return Matrix()
        }
        
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
    
    static func * (lhs:Matrix, rhs:Matrix) -> Matrix
    {
        if lhs.columns != rhs.rows
        {
            PCH_ErrorAlert(message: "Matrix multiplication", info: "Mismatched dimensions for multiply")
            return Matrix()
        }
        if (lhs.type != rhs.type)
        {
            PCH_ErrorAlert(message: "Matrix multiplication", info: "Mismatched types")
            return Matrix()
        }
        
        let result = Matrix(type: lhs.type, rows: UInt(lhs.rows), columns: UInt(rhs.columns))
        
        let m = __CLPK_integer(lhs.rows)
        let n = __CLPK_integer(rhs.columns)
        let k = __CLPK_integer(lhs.columns)
        let lda = k
        let ldb = n
        let ldc = m
        
        if lhs.type == .Double
        {
            let A = lhs.doubleBuffPtr
            let B = rhs.doubleBuffPtr
            let C = result.doubleBuffPtr
            
            if rhs.columns == 1
            {
                // do matrix-vector multiply
                cblas_dgemv(CblasColMajor, CblasNoTrans, m, k, 1.0, A, lda, B, 1, 0.0, C, 1)
            }
            else
            {
                cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, m, n, k, 1.0, A, lda, B, ldb, 0.0, C, ldc)
            }
        }
        else
        {
            let A = lhs.complexBuffPtr
            let B = rhs.complexBuffPtr
            let C = result.complexBuffPtr
            
            var alpha = __CLPK_doublecomplex(r: 1.0, i: 0.0)
            var beta = __CLPK_doublecomplex(r: 0.0, i: 0.0)
            
            if rhs.columns == 1
            {
                // do matrix-vector multiply
                cblas_zgemv(CblasColMajor, CblasNoTrans, m, k, &alpha, A, lda, B, 1, &beta, C, 1)
            }
            else
            {
                cblas_zgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, m, n, k, &alpha, A, lda, B, ldb, &beta, C, ldc)
            }
        }
        
        return result
    }
    
    /// return true if the bounds are okay
    private func checkBounds(row:Int, column:Int) -> Bool
    {
        return row < self.rows && column < self.columns
    }
    
    /// General matrix solver (slowest method) for AX=B, where A is 'self'. In the interest of speed, we pass the 'B' matrix as a pointer instead of a matrix. **NOTE** IT IS ASSUMED THAT A.rows == B.rows (this fact is NOT checked by this routine).
    /// - Parameter B: On entry, the matrix B (as in AX=B). On successful exit, the solution matrix X
    /// - Parameter numBcols: The number of columns in B (equal to 1 for a vector)
    /// - Parameter overwriteAMatrix: If 'true', self will be overwritten and on exit will hold the LU factorization of A
    /// - Returns: 'true' if the call was successful, otherwise 'false'
    func SolveForDoubleGeneralMatrix(B: UnsafeMutablePointer<__CLPK_doublereal>, numBcols:Int, overwriteAMatrix:Bool = false) -> Bool
    {
        var n = __CLPK_integer(self.rows)
        var lda = n
        var ldb = n
        var nrhs = __CLPK_integer(numBcols)
        var ipiv:[__CLPK_integer] = Array(repeating: 0, count: self.rows)
        var info = __CLPK_integer(0)
        let A = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: self.rows * self.columns)
        A.assign(from: self.doubleBuffPtr, count: self.rows * self.columns)
        
        dgesv_(&n, &nrhs, A, &lda, &ipiv, B, &ldb, &info)
        
        if info < 0
        {
            PCH_ErrorAlert(message: "DGESV Error", info: "Illegal Argument #\(-info)")
            return false
        }
        else if info > 0
        {
            PCH_ErrorAlert(message: "DGESV Error", info: "The element U(\(info),\(info)) is exactly zero.")
            return false
        }
        
        if overwriteAMatrix
        {
            self.doubleBuffPtr.deallocate()
            self.doubleBuffPtr = A
        }
        else
        {
            A.deallocate()
        }
        
        return true
    }
    
    /// Solve AX=B where A is a positive definite matrix, and instead of A, use the Cholesky factorization of A (which should have been created using DPOTRF). **NOTE**: There is no checking done in this routine.
    /// - Parameter B: On entry, the general matrix B (as in AX=B). On successful exit, the solution matrix X
    /// - Parameter numBcols: The number of columns in B (equal to 1 for a vector)
    /// - Returns: 'true' if the call was successful, otherwise 'false'
    func SolveForDoublePositiveDefinite(B: UnsafeMutablePointer<__CLPK_doublereal>, numBcols:Int) -> Bool
    {
        var uplo:Int8 = 85 // 'U'
        var n = __CLPK_integer(self.rows)
        var lda = n
        var ldb = n
        var nrhs = __CLPK_integer(numBcols)
        var info = __CLPK_integer(0)
        
        dpotrs_(&uplo, &n, &nrhs, self.doubleBuffPtr, &lda, B, &ldb, &info)
        
        if info < 0
        {
            PCH_ErrorAlert(message: "DPOTRS Error", info: "Illegal Argument #\(-info)")
            return false
        }
        
        return true
    }
    
    /// A  routine to check whether self is a symmetric matrix. Note that this function can be quite slow, so it should not be called in a loop.
    func TestForSymmetry() -> Bool
    {
        guard self.rows == self.columns else
        {
            DLog("Matrix must be square!")
            return false
        }
        
        if self.type == .Double
        {
            for i in 0..<self.rows
            {
                for j in i..<self.columns
                {
                    let lhs:Double = self[i, j]
                    let rhs:Double = self[j, i]
                    if lhs != rhs
                    {
                        return false
                    }
                }
            }
        }
        else
        {
            for i in 0..<self.rows
            {
                for j in i..<self.columns
                {
                    let lhs:Complex = self[i, j]
                    let rhs:Complex = self[j, i]
                    if lhs != rhs
                    {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    /// A routine to check whether a matrix is really positive-definite or not (inductance matrix is supposed to always be). The idea comes from this discussion: https://icl.cs.utk.edu/lapack-forum/viewtopic.php?f=2&t=3534. We need to try and perform a Cholesky factorization of the matrix (LAPACK routine DPOTRF). If the factorization is successfull, the matrix is positive definite.
    /// - Parameter overwriteExistingMatrix: If 'true', the function actually saves the Cholesky factorization by overwriting the existing buffer for this matrix
    /// - Returns: 'true' if the matrix is Positive Definite, otherwise 'false'
    func TestPositiveDefinite(overwriteExistingMatrix:Bool = false) -> Bool
    {
        guard self.TestForSymmetry() else
        {
            DLog("Matrix must be square and symmetric!")
            return false
        }
        
        if self.type == .Double
        {
            var uplo:Int8 = 85 // 'U'
            var n = __CLPK_integer(self.rows)
            var lda = n
            var info = __CLPK_integer(0)
            let A = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: self.rows * self.columns)
            A.assign(from: self.doubleBuffPtr, count: self.rows * self.columns)
            
            
            dpotrf_(&uplo, &n, A, &lda, &info)
            
            if info < 0
            {
                PCH_ErrorAlert(message: "DPOTRF Error", info: "Illegal Argument #\(-info)")
                return false
            }
            else if info > 0
            {
                DLog("The matrix is not positive definite (leading minor of order \(info)")
                return false
            }
            
            if overwriteExistingMatrix
            {
                self.doubleBuffPtr.deallocate()
                self.doubleBuffPtr = A
            }
            else
            {
                A.deallocate()
            }
        }
        else // .Complex
        {
            var uplo:Int8 = 85 // 'U'
            var n = __CLPK_integer(self.rows)
            var lda = n
            var info = __CLPK_integer(0)
            let A = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: self.rows * self.columns)
            A.assign(from: self.complexBuffPtr, count: self.rows * self.columns)
            
            
            zpotrf_(&uplo, &n, A, &lda, &info)
            
            if info < 0
            {
                PCH_ErrorAlert(message: "ZPOTRF Error", info: "Illegal Argument #\(-info)")
                return false
            }
            else if info > 0
            {
                DLog("The matrix is not positive definite (leading minor of order \(info)")
                return false
            }
            
            if overwriteExistingMatrix
            {
                self.complexBuffPtr.deallocate()
                self.complexBuffPtr = A
            }
            else
            {
                A.deallocate()
            }
        }
        
        return true
    }
    
}

/// A class for displaying a Matrix. After looking into NSTableView, NSGridView, and NSCollectionView, I decided to roll my own.
class MatrixDisplay:NSObject, NSWindowDelegate {
    
    @IBOutlet var window: NSWindow!
    @IBOutlet weak var contentView: NSView!
    
    var matrix:Matrix
    var windowTitle:String
    
    init?(windowTitle:String = "Matrix", matrix:Matrix)
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
                
        let tfWidth:CGFloat = 100.0
        let colNumWidth:CGFloat = 40.0
        let tfHeight:CGFloat = 21.0
        
        let contentView = self.contentView!
        
        let newFrameSize:NSSize = NSSize(width:max(colNumWidth + CGFloat(self.matrix.columns) * tfWidth, contentView.frame.size.width), height: max(CGFloat(1 + self.matrix.rows) * tfHeight, contentView.frame.size.height))
        // let newBounds:NSSize = NSSize(width:colNumWidth + CGFloat(self.matrix.columns) * tfWidth, height: CGFloat(1 + self.matrix.rows) * tfHeight)
        
        self.contentView.frame.size = newFrameSize
        var nextRowTop = contentView.frame.origin.y + contentView.frame.size.height
        
        var nextColLeft:CGFloat = colNumWidth
        for nextColNum in 0..<self.matrix.columns
        {
            let nextColumnHead = NSTextField(frame: NSRect(x: nextColLeft, y: nextRowTop - tfHeight, width: tfWidth, height: tfHeight))
            nextColumnHead.alignment = .center
            nextColumnHead.drawsBackground = false
            nextColumnHead.isEditable = false
            nextColumnHead.integerValue = nextColNum
            
            self.contentView.addSubview(nextColumnHead)
            
            nextColLeft += tfWidth
        }
        
        nextRowTop -= tfHeight
        
        let decimalFormatter = NumberFormatter()
        decimalFormatter.usesSignificantDigits = true
        decimalFormatter.minimumSignificantDigits = 3
        decimalFormatter.maximumSignificantDigits = 10
        
        let scientificFormatter = NumberFormatter()
        scientificFormatter.numberStyle = .scientific
        decimalFormatter.usesSignificantDigits = true
        decimalFormatter.minimumSignificantDigits = 3
        scientificFormatter.maximumSignificantDigits = 7
        
        for nextRow in 0..<self.matrix.rows
        {
            nextColLeft = 0
            
            let nextRowHead = NSTextField(frame: NSRect(x: nextColLeft, y: nextRowTop - tfHeight, width: colNumWidth, height: tfHeight))
            nextRowHead.alignment = .center
            nextRowHead.drawsBackground = false
            nextRowHead.isEditable = false
            nextRowHead.integerValue = nextRow
            
            self.contentView.addSubview(nextRowHead)
            
            nextColLeft = colNumWidth
            for nextCol in 0..<self.matrix.columns
            {
                let nextTextField = NSTextField(frame: NSRect(x: nextColLeft, y: nextRowTop - tfHeight, width: tfWidth, height: tfHeight))
                
                nextTextField.alignment = .center
                nextTextField.drawsBackground = false
                
                let doubleValue:Double = self.matrix[nextRow, nextCol]
                if fabs(doubleValue) < 1.0E-5 || fabs(doubleValue) > 1.0E5
                {
                    nextTextField.formatter = scientificFormatter
                }
                else
                {
                    nextTextField.formatter = decimalFormatter
                }
                
                nextTextField.doubleValue = doubleValue
                
                self.contentView.addSubview(nextTextField)
                
                nextColLeft += tfWidth
            }
            
            nextRowTop -= tfHeight
        }
        
        self.window.title = self.windowTitle
        self.window.makeKeyAndOrderFront(self)
    }
    
    func windowDidResize(_ notification: Notification) {
        
        guard let wWindow = notification.object as? NSWindow, wWindow == self.window else
        {
            return
        }
        
        DLog("In windowDidResize()")
        
        let tfWidth:CGFloat = 100.0
        let colNumWidth:CGFloat = 40.0
        let tfHeight:CGFloat = 21.0
        
        let contentView = self.contentView!
        
        guard let parent = contentView.superview?.superview else
        {
            DLog("Couldn't get superview")
            return
        }
        
        let newFrameSize:NSSize = NSSize(width:max(colNumWidth + CGFloat(self.matrix.columns) * tfWidth, parent.frame.size.width), height: max(CGFloat(1 + self.matrix.rows) * tfHeight, parent.frame.size.height))
        // let newBounds:NSSize = NSSize(width:colNumWidth + CGFloat(self.matrix.columns) * tfWidth, height: CGFloat(1 + self.matrix.rows) * tfHeight)
        
        self.contentView.frame.size = newFrameSize
    }
    
}
