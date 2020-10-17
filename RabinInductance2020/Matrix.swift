//
//  Matrix.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-17.
//

// The idea here is to make a simpler, better thought-out matrix class than the bloatware that PCH_Matrix turned into. Specifcally, we're going for something faster and more lightweight for use with the BIL simulation program. Everything is based on BLAS and LAPACK routines.  For now, most things only work with __CLPK_doublereal (Double).

import Foundation
import Accelerate

/// A general-purpose, lightweight matrix class. Double and Complex types are allowed,
class Matrix:CustomStringConvertible {
    
    /// A simple way of looking at the matrix in the Debug window. Don't use this for huge (or supersmall) numbers
    var description: String {
        get {
            
            var result = "|"
            
            for i in 0..<self.columns
            {
                
            }
            
            return result
        }
    }
    
    
    enum NumberType {
        case Double
        case Complex
    }
    
    let type:NumberType
    
    private let doubleBuffPtr:UnsafeMutablePointer<__CLPK_doublereal>
    private let complexBuffPtr:UnsafeMutablePointer<__CLPK_doublecomplex>
    
    let rows:UInt
    let columns:UInt
    
    init(type:NumberType, rows:UInt, columns:UInt) {
        
        self.type = type
        self.rows = rows
        self.columns = columns
        
        if type == .Double
        {
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: Int(rows * columns))
            self.doubleBuffPtr.assign(repeating: 0.0, count: Int(rows * columns))
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>(nil)!
        }
        else
        {
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: Int(rows * columns))
            self.complexBuffPtr.assign(repeating: __CLPK_doublecomplex(r: 0.0, i: 0.0), count: Int(rows * columns))
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>(nil)!
        }
    }
    
    /// Accessor for Double matrices
    subscript(row:UInt, column:UInt) -> Double
    {
        get {
            
            assert(self.type == .Double, "Illegal type")
            assert(checkBounds(row: row, column: column), "Subscript out of bounds")

            return self.doubleBuffPtr[Int((column * self.rows) + row)]
        }
        
        set {
            
            assert(self.type == .Double, "Illegal type")
            assert(checkBounds(row: row, column: column), "Subscript out of bounds")

            self.doubleBuffPtr[Int((column * self.rows) + row)] = newValue
        }
    }
    
    /// Accessor for Complex matrices
    subscript(row:UInt, column:UInt) -> Complex
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
            self.complexBuffPtr[Int((column * self.rows) + row)] = clpk_newValue
        }
    }
    
    // return true if the bounds are okay
    private func checkBounds(row:UInt, column:UInt) -> Bool
    {
        return row < self.rows && column < self.columns
    }
    
    /// A routine to check whether a matrix is really positive-definite or not (inductance matrix is supposed to always be). The idea comes from this discussion: https://icl.cs.utk.edu/lapack-forum/viewtopic.php?f=2&t=3534. The idea is to try and perform a Cholesky factorization of the matrix (LAPACK routine DPOTRF). If the factorization is successfull, the matrix is positive definite.
    func TestPositiveDefinite() -> Bool
    {
        
        return true
    }
    
}
