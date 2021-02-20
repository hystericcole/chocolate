//
//  Extensions.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import CoreGraphics
import Foundation

extension BinaryFloatingPoint {
	var integerFraction:(Self, Self) { return modf(self) }
	
	func interpolate(towards:Self, by:Self) -> Self { let n = 1.0 - by; return self * n + towards * by }
}

extension RandomAccessCollection where Index == Int {
	/// return index (0 ... count) such that array[index - 1] < value <= array[index]
	func binarySearch<T>(_ value:T, by areInIncreasingOrder:(Element, T) throws -> Bool) rethrows -> Index {
		var m = startIndex, n = endIndex - 1, o = m
		var c = false
		
		while m <= n {
			o = (m + n) / 2
			c = try areInIncreasingOrder(self[o], value)
			
			if c { m = o + 1 }
			else { n = o - 1 }
		}
		
		return m
	}
}

extension NumberFormatter {
	var fractionDigits:ClosedRange<Int> {
		get { return minimumFractionDigits ... maximumFractionDigits }
		set { minimumFractionDigits = newValue.lowerBound; maximumFractionDigits = newValue.upperBound }
	}
	
	var integerDigits:ClosedRange<Int> {
		get { return minimumIntegerDigits ... maximumIntegerDigits }
		set { minimumIntegerDigits = newValue.lowerBound; maximumIntegerDigits = newValue.upperBound }
	}
	
	var significantDigits:ClosedRange<Int> {
		get { return minimumSignificantDigits ... maximumSignificantDigits }
		set { minimumSignificantDigits = newValue.lowerBound; maximumSignificantDigits = newValue.upperBound; usesSignificantDigits = true }
	}
	
	convenience init(fractionDigits:ClosedRange<Int>) {
		self.init()
		self.fractionDigits = fractionDigits
	}
}
