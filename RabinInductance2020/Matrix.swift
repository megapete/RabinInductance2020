//
//  Matrix.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-17.
//

// The idea here is to make a simpler, better thought-out matrix class than the bloatware that PCH_Matrix turned into. Specifcally, we're going for something faster and more lightweight for use with the BIL simulation program. Everything is based on BLAS and LAPACK routines.  For now, most things only work with __CLPK_doublereal (Double).

import Foundation
import Accelerate

class Matrix {
    
    enum NumberType {
        case Double
        case Complex
    }
    
    let type:NumberType
    
    let doubleBuffPtr:UnsafeMutablePointer<__CLPK_doublereal>
    let complexBuffPtr:UnsafeMutablePointer<__CLPK_doublecomplex>
    
    let rows:UInt
    let columns:UInt
    
    init(type:NumberType, rows:UInt, columns:UInt) {
        
        self.type = type
        self.rows = rows
        self.columns = columns
        
        if type == .Double
        {
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>.allocate(capacity: Int(rows * columns))
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>(nil)!
        }
        else
        {
            self.complexBuffPtr = UnsafeMutablePointer<__CLPK_doublecomplex>.allocate(capacity: Int(rows * columns))
            self.doubleBuffPtr = UnsafeMutablePointer<__CLPK_doublereal>(nil)!
        }
    }
    
    /// A routine to check whether a matrix is really positive-definite or not (inductance matrix is supposed to always be). The idea comes from this discussion: https://icl.cs.utk.edu/lapack-forum/viewtopic.php?f=2&t=3534. The idea is to try and perform a Cholesky factorization of the matrix (LAPACK routine DPOTRF). If the factorization is successfull, the matrix is positive definite.
    func TestPositiveDefinite() -> Bool
    {
        
        return true
    }
    
}
