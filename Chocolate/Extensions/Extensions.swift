//
//  Extensions.swift
//  Chocolate
//
//  Created by Eric Cole on 1/26/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation

extension BinaryFloatingPoint {
	var integerFraction:(Self, Self) { return modf(self) }
	
	func interpolate(towards:Self, by:Self) -> Self { let n = 1.0 - by; return self * n + towards * by }
}

//	MARK: -

extension Double {
	func sincosturns() -> __double2 { return __sincospi_stret(self * 2.0) }
	func sincospi() -> __double2 { return __sincospi_stret(self) }
	func sincos() -> __double2 { return __sincos_stret(self) }
}

//	MARK: -

extension Float {
	func sincosturns() -> __float2 { return __sincospif_stret(self * 2.0) }
	func sincospi() -> __float2 { return __sincospif_stret(self) }
	func sincos() -> __float2 { return __sincosf_stret(self) }
}

//	MARK: -

extension ClosedRange where Bound: AdditiveArithmetic {
	var length:Bound { return upperBound - lowerBound }
}

//	MARK: -

extension DispatchQueue {
	static var background:DispatchQueue { return global(qos:.background) }
	static var utility:DispatchQueue { return global(qos:.utility) }
	static var normal:DispatchQueue { return global(qos:.default) }
	static var userInitiated:DispatchQueue { return global(qos:.userInitiated) }
	static var userInteractive:DispatchQueue { return global(qos:.userInteractive) }
}

//	MARK: -

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

//	MARK: -

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
	
	public convenience init(fractionDigits:ClosedRange<Int>) {
		self.init()
		self.fractionDigits = fractionDigits
	}
	
	func string(_ value:Int) -> String { return string(from:value as NSNumber) ?? "" }
	func string(_ value:Float) -> String { return string(from:value as NSNumber) ?? "" }
	func string(_ value:Double) -> String { return string(from:value as NSNumber) ?? "" }
}
