//
//	Polynomial.swift
//	Chocolate
//
//	Created by Eric Cole on 3/30/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation

enum Polynomial {
	public typealias Scalar = Double
	
	/// ∑ c[n-i] xⁱ
	public static func evaluate(polynomial coefficients:[Scalar], at x:Scalar) -> Scalar {
		return coefficients.reduce(0.0) { $0 * x + $1 }
	}
	
	/// ax² + bx + c = 0
	public static func quadraticRoots(a:Scalar, b:Scalar, c:Scalar) -> [Scalar] {
		guard a != 0 else { return b.magnitude > 0 ? [-c / b] : [] }
		guard c != 0 else { return b.magnitude > 0 ? [0, -b / a] : [0] }
		
		let ss = b * b - 4 * a * c
		let t = a * 2
		
		guard ss != 0 else { return [-b / t] }
		guard ss > 0 else { return [] }
		
		let s = ss.squareRoot()
		
		return [(-b - s) / t, (-b + s) / t]
	}
	
	/// ax³ + bx² + cx + d = 0
	public static func cubicRoots(a:Scalar, b:Scalar, c:Scalar, d:Scalar) -> [Scalar] {
		guard a != 0 else { return quadraticRoots(a:b, b:c, c:d) }
		guard d != 0 else { var r = quadraticRoots(a:a, b:b, c:c); if !r.contains(0) { r.append(0) }; return r }
		
		let a0 = d / a
		let a1 = c / a
		let a2 = b / a
		
		let p = a2 * a2 - 3 * a1
		let qn = 2 * a2 * a2 * a2 - 9 * a2 * a1 + 27 * a0
		let q = qn / 2
		let qq = q * q
		let ppp = p * p * p
		
		if qq < ppp {
			let r = p.squareRoot()
			let d = p * r
			let phi = acos(-q / d) / 3
			let r0 = r * 2 * cos(phi - 0 * .pi / 3) - a2
			let r1 = r * 2 * cos(phi - 2 * .pi / 3) - a2
			let r2 = r * 2 * cos(phi + 2 * .pi / 3) - a2
			
			return [r2 / 3, r1 / 3, r0 / 3]
		} else {
			let ss = qq - ppp
			let s = ss.squareRoot()
			let rc = cbrt(q * s < 0 ? q - s : q + s)
			let rn = a2 + rc + p / rc
			
			return [rn / -3]
		}
	}
}
