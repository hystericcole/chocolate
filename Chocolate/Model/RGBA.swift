//
//  RGBA.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import CoreGraphics
import Foundation

public struct RGBA: CustomStringConvertible {
	public typealias Number = CHCLTScalar
	public typealias Curved = Number
	public typealias Linear = Number
	public typealias Vector4 = SIMD4<Number>
	
//	public let vector:Vector4
//	public var r:Native { return vector.x }
//	public var g:Native { return vector.y }
//	public var b:Native { return vector.z }
//	public var a:Native { return vector.w }
	public let r, g, b:Curved
	public let a:Linear
	public var vector:Vector4 { return Curved.vector4(r, g, b, a) }
	
	public var inverted:Self {
		return Self(1 - r, 1 - g, 1 - b, a)
	}
	
	public var clamped:Self {
		return Self(vector:vector.clamped(lowerBound:.zero, upperBound:.one))
	}
	
	public var integer:(red:UInt, green:UInt, blue:UInt, alpha:UInt) {
		var integer = vector * 255
		
		integer.round(.toNearestOrAwayFromZero)
		
		return (UInt(integer.x), UInt(integer.y), UInt(integer.z), UInt(integer.w))
	}
	
	public var hsb:(hue:Number, saturation:Number, brightness:Number) {
		return Self.hsb(vector)
	}
	
	public var description:String {
		return String(format:"RGBA(%.3f, %.3f, %.3f, %.3f)", r, g, b, a)
	}
	
	public init(vector:Vector4) {
		r = vector.x
		g = vector.y
		b = vector.z
		a = vector.w
//		self.vector = vector
	}
	
	public init(_ red:Number, _ green:Number, _ blue:Number, _ alpha:Number) {
		r = red
		g = green
		b = blue
		a = alpha
//		self.init(vector:Curved.vector4(red, green, blue, alpha))
	}
	
	public init?(color:CGColor?) {
		guard
			let color = color,
			color.numberOfComponents == 4,
			color.colorSpace?.model ?? .rgb == .rgb,
			let components = color.components
		else { return nil }
		
		self.init(components[0].native, components[1].native, components[2].native, components[3].native)
	}
	
	public func cgColor(colorSpace:CGColorSpace? = nil) -> CGColor? {
		let space:CGColorSpace
		
		if let colorSpace = colorSpace, colorSpace.model == .rgb {
			space = colorSpace
		} else {
			space = CGColorSpaceCreateDeviceRGB()
		}
		
		var components:[CGFloat] = [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)]
		
		return CGColor(colorSpace:space, components:&components)
	}
	
	public func web(allowFormat:Int = 0) -> String {
		let (r,g,b,a) = integer
		let format:String
		let scalar:UInt
		
		let allowCompact = allowFormat & 0x1A != 0
		let allowRegular = allowFormat & 0x144 != 0
		let isCompact = r % 17 == 0 && g % 17 == 0 && b % 17 == 0 && a % 17 == 0
		let isGray = r == g && r == b
		let isOpaque = a == 255
		
		if allowCompact && (isCompact || !allowRegular) {
			let allowOpacity = allowFormat & 0x10 != 0
			let allowGray = allowFormat & 0x02 != 0
			scalar = 17
			
			if allowGray && isGray && (isOpaque || !allowOpacity) {
				format = "#%X"
			} else if isOpaque ? allowFormat & 0x18 == 0x10 : allowOpacity {
				format = "#%X%X%X%X"
			} else {
				format = "#%X%X%X"
			}
		} else {
			let allowOpacity = allowFormat & 0x100 != 0
			let allowGray = allowFormat & 0x04 != 0
			scalar = 1
			
			if allowGray && isGray && (isOpaque || !allowOpacity) {
				format = "#%02X"
			} else if isOpaque ? allowFormat & 0x140 == 0x100 : allowOpacity {
				format = "#%02X%02X%02X%02X"
			} else {
				format = "#%02X%02X%02X"
			}
		}
		
		return String(format:format, r / scalar, g / scalar, b / scalar, a / scalar)
	}
	
	public func css(withAlpha:Int = 0) -> String {
		if withAlpha > 0 || a < 1 {
			return "rgba(\(r * 255.0),\(g * 255.0),\(b * 255.0),\(a))"
		} else {
			return "rgb(\(r * 255.0),\(g * 255.0),\(b * 255.0))"
		}
	}
	
	public static func hsb(_ rgb:Vector4) -> (hue:Number, saturation:Number, brightness:Number) {
		let domain, maximum, mid_minus_min, max_minus_min:Number
		let r = rgb.x, g = rgb.y, b = rgb.z
		
		if r < g {
			if g < b {
				maximum = b
				mid_minus_min = r - g
				max_minus_min = b - r
				domain = 4
			} else {
				maximum = g
				mid_minus_min = b - r
				max_minus_min = g - min(r, b)
				domain = 2
			}
		} else {
			if r < b {
				maximum = b
				mid_minus_min = r - g
				max_minus_min = b - g
				domain = 4
			} else {
				maximum = r
				mid_minus_min = g - b
				max_minus_min = r - min(g, b)
				domain = 0
			}
		}
		
		guard max_minus_min > 0 else { return (1, 0, 0) }
		
		let hue6 = domain + mid_minus_min / max_minus_min
		let hue = hue6 / 6
		
		return (hue < 0 ? 1 + hue : hue, max_minus_min, maximum)
	}
}
