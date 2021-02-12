//
//  Extensions.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import CoreGraphics
import Foundation
import simd

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

extension Double {
	typealias Vector2 = SIMD2<Self>
	typealias Vector3 = SIMD3<Self>
	typealias Vector4 = SIMD4<Self>
	typealias Vector8 = SIMD8<Self>
	
	static func vector2(_ x:Double, _ y:Double) -> Vector2 { return simd_make_double2(x, y) }
	static func vector3(_ x:Double, _ y:Double, _ z:Double) -> Vector3 { return simd_make_double3(x, y, z) }
	static func vector3(_ xyz:Vector4) -> Vector3 { return simd_make_double3(xyz) }
	static func vector4(_ x:Double, _ y:Double, _ z:Double, _ w:Double) -> Vector4 { return simd_make_double4(x, y, z, w) }
	static func vector4(_ xyz:Vector3, _ w:Double = 0) -> Vector4 { return simd_make_double4(xyz, w) }
	static func vector8(_ lower:Vector4, _ upper:Vector4) -> simd_double8 { return simd_make_double8(lower, upper) }
}

extension Float {
	typealias Vector2 = SIMD2<Self>
	typealias Vector3 = SIMD3<Self>
	typealias Vector4 = SIMD4<Self>
	typealias Vector8 = SIMD8<Self>
	
	static func vector2(_ x:Float, _ y:Float) -> Vector2 { return simd_make_float2(x, y) }
	static func vector3(_ x:Float, _ y:Float, _ z:Float) -> Vector3 { return simd_make_float3(x, y, z) }
	static func vector3(_ xyz:Vector4) -> Vector3 { return simd_make_float3(xyz) }
	static func vector4(_ x:Float, _ y:Float, _ z:Float, _ w:Float) -> Vector4 { return simd_make_float4(x, y, z, w) }
	static func vector4(_ xyz:Vector3, _ w:Float = 0) -> Vector4 { return simd_make_float4(xyz, w) }
	static func vector8(_ lower:Vector4, _ upper:Vector4) -> Vector8 { return simd_make_float8(lower, upper) }
}

extension CGFloat {
	typealias Vector2 = SIMD2<NativeType>
	typealias Vector3 = SIMD3<NativeType>
	typealias Vector4 = SIMD4<NativeType>
	typealias Vector8 = SIMD8<NativeType>
	
	static func vector2(_ x:CGFloat, _ y:CGFloat) -> Vector2 { return NativeType.vector2(x.native, y.native) }
	static func vector3(_ x:CGFloat, _ y:CGFloat, _ z:CGFloat) -> Vector3 { return NativeType.vector3(x.native, y.native, z.native) }
	static func vector3(_ xyz:Vector4) -> Vector3 { return NativeType.vector3(xyz) }
	static func vector4(_ x:CGFloat, _ y:CGFloat, _ z:CGFloat, _ w:CGFloat) -> Vector4 { return NativeType.vector4(x.native, y.native, z.native, w.native) }
	static func vector4(_ xyz:Vector3, _ w:CGFloat) -> Vector4 { return NativeType.vector4(xyz, w.native) }
	static func vector8(_ lower:Vector4, _ upper:Vector4) -> Vector8 { return NativeType.vector8(lower, upper) }
}

extension SIMD4 where Scalar == Double {
	var xyz:SIMD3<Scalar> {
		get { return simd_make_double3(self) }
		set { self = simd_make_double4(newValue, w) }
	}
}

extension SIMD4 where Scalar == Float {
	var xyz:SIMD3<Scalar> {
		get { return simd_make_float3(self) }
		set { self = simd_make_float4(newValue, w) }
	}
}
