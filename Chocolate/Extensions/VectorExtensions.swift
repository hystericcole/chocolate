//
//  VectorExtensions.swift
//  Chocolate
//
//  Created by Eric Cole on 2/19/21.
//

import CoreGraphics
import Foundation
import simd

extension Double {
	public typealias Vector2 = SIMD2<Self>
	public typealias Vector3 = SIMD3<Self>
	public typealias Vector4 = SIMD4<Self>
	public typealias Vector8 = SIMD8<Self>
	public typealias Matrix3x3 = simd_double3x3
	public typealias Matrix4x4 = simd_double4x4
	
	public static func vector2(_ x:Double, _ y:Double) -> Vector2 { return simd_make_double2(x, y) }
	public static func vector3(_ x:Double, _ y:Double, _ z:Double) -> Vector3 { return simd_make_double3(x, y, z) }
	public static func vector3(_ xyz:Vector4) -> Vector3 { return simd_make_double3(xyz) }
	public static func vector4(_ x:Double, _ y:Double, _ z:Double, _ w:Double) -> Vector4 { return simd_make_double4(x, y, z, w) }
	public static func vector4(_ xyz:Vector3, _ w:Double = 0) -> Vector4 { return simd_make_double4(xyz, w) }
	public static func vector8(_ lower:Vector4, _ upper:Vector4) -> simd_double8 { return simd_make_double8(lower, upper) }
}

extension Float {
	public typealias Vector2 = SIMD2<Self>
	public typealias Vector3 = SIMD3<Self>
	public typealias Vector4 = SIMD4<Self>
	public typealias Vector8 = SIMD8<Self>
	public typealias Matrix3x3 = simd_float3x3
	public typealias Matrix4x4 = simd_float4x4
	
	public static func vector2(_ x:Float, _ y:Float) -> Vector2 { return simd_make_float2(x, y) }
	public static func vector3(_ x:Float, _ y:Float, _ z:Float) -> Vector3 { return simd_make_float3(x, y, z) }
	public static func vector3(_ xyz:Vector4) -> Vector3 { return simd_make_float3(xyz) }
	public static func vector4(_ x:Float, _ y:Float, _ z:Float, _ w:Float) -> Vector4 { return simd_make_float4(x, y, z, w) }
	public static func vector4(_ xyz:Vector3, _ w:Float = 0) -> Vector4 { return simd_make_float4(xyz, w) }
	public static func vector8(_ lower:Vector4, _ upper:Vector4) -> Vector8 { return simd_make_float8(lower, upper) }
}

extension CGFloat {
	public typealias Vector2 = SIMD2<NativeType>
	public typealias Vector3 = SIMD3<NativeType>
	public typealias Vector4 = SIMD4<NativeType>
	public typealias Vector8 = SIMD8<NativeType>
	
	public static func vector2(_ x:CGFloat, _ y:CGFloat) -> Vector2 { return NativeType.vector2(x.native, y.native) }
	public static func vector3(_ x:CGFloat, _ y:CGFloat, _ z:CGFloat) -> Vector3 { return NativeType.vector3(x.native, y.native, z.native) }
	public static func vector3(_ xyz:Vector4) -> Vector3 { return NativeType.vector3(xyz) }
	public static func vector4(_ x:CGFloat, _ y:CGFloat, _ z:CGFloat, _ w:CGFloat) -> Vector4 { return NativeType.vector4(x.native, y.native, z.native, w.native) }
	public static func vector4(_ xyz:Vector3, _ w:CGFloat) -> Vector4 { return NativeType.vector4(xyz, w.native) }
	public static func vector8(_ lower:Vector4, _ upper:Vector4) -> Vector8 { return NativeType.vector8(lower, upper) }
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
