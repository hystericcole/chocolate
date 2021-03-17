//
//  RGBA.swift
//  Chocolate
//
//  Created by Eric Cole on 1/26/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation
import simd

public struct DisplayRGB {
	public typealias Scalar = CHCLT.Scalar
	
	public static let black = DisplayRGB(Scalar.vector4(Scalar.Vector3.zero, 1.0))
	public static let white = DisplayRGB(Scalar.Vector4.one)
	
	public let vector:CHCLT.Vector4
	public var clamped:DisplayRGB { return DisplayRGB(simd_min(simd_max(.zero, vector), .one)) }
	public var inverted:DisplayRGB { return DisplayRGB(Scalar.vector4(1 - vector.xyz, vector.w)) }
	
	public var red:Scalar { return vector.x }
	public var green:Scalar { return vector.y }
	public var blue:Scalar { return vector.z }
	public var alpha:Scalar { return vector.w }
	
	public var integer:(red:UInt, green:UInt, blue:UInt, alpha:UInt) {
		var scaled = vector * 255
		
		scaled.round(.toNearestOrAwayFromZero)
		
		let integer = simd_uint(scaled)
		
		return (UInt(integer.x), UInt(integer.y), UInt(integer.z), UInt(integer.w))
	}
	
	public var description:String {
		return String(format:"RGBA(%.3g, %.3g, %.3g, %.3g)", red, green, blue, alpha)
	}
	
	public init(_ rgba:CHCLT.Vector4) {
		vector = rgba
	}
	
	public init(_ red:Scalar, _ green:Scalar, _ blue:Scalar, _ alpha:Scalar = 1) {
		vector = Scalar.vector4(red, green, blue, alpha)
	}
	
	public init(gray:Scalar, _ alpha:Scalar = 1) {
		vector = Scalar.vector4(gray, gray, gray, alpha)
	}
	
	public init(_ chclt:CHCLT, hue:Scalar, chroma:Scalar, luma:Scalar, alpha:Scalar = 1) {
		let linear = CHCLT.LinearRGB(chclt, hue:hue, chroma:chroma, luminance:luma)
		
		vector = Scalar.vector4(chclt.display(simd_max(linear.vector, simd_double3.zero)), alpha)
	}
	
	public init(hexagonal hue:Scalar, saturation:Scalar, brightness:Scalar, alpha:Scalar = 1) {
		vector = Scalar.vector4(DisplayRGB.hexagonal(hue:hue, saturation:saturation, brightness:brightness), alpha)
	}
	
	public func web(allowFormat:Int = 0) -> String {
		let (r, g, b, a) = integer
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
		if withAlpha > 0 || (withAlpha == 0 && alpha < 1) {
			return String(format:"rgba(%.1f, %.1f, %.1f, %.3g)", red * 255, green * 255, blue * 255, alpha).replacingOccurrences(of:".0,", with:",")
		} else {
			return String(format:"rgb(%.1f, %.1f, %.1f)", red * 255, green * 255, blue * 255).replacingOccurrences(of:".0", with:"")
		}
	}
	
	public func pixel() -> UInt32 {
		var v = vector * 255.0
		
		v.round(.toNearestOrAwayFromZero)
		
		let u = simd_uint(v)
		let a = u.w << 24
		let r = u.x << 16
		let g = u.y << 8
		let b = u.z << 0
		
		return r | g | b | a
	}
	
	public func linear(_ chclt:CHCLT) -> CHCLT.LinearRGB {
		return CHCLT.LinearRGB(chclt.linear(vector.xyz))
	}
	
	public func scaled(_ scalar:Scalar) -> DisplayRGB {
		return DisplayRGB(Scalar.vector4(vector.xyz * scalar, vector.w))
	}
	
	public func normalized(_ chclt:CHCLT) -> DisplayRGB {
		return linear(chclt).normalized(chclt).display(chclt, alpha:vector.w)
	}
	
	public func luma(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).luminance(chclt)
	}
	
	public func scaleLuma(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return scaled(scalar > 0 ? chclt.transfer(scalar) : 0)
	}
	
	public func applyLuma(_ chclt:CHCLT, value u:Scalar) -> DisplayRGB {
		return linear(chclt).applyLuminance(chclt, value:u).display(chclt, alpha:vector.w)
	}
	
	public func contrast(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).contrast(chclt)
	}
	
	public func scaleContrast(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return linear(chclt).scaleContrast(chclt, by:scalar).display(chclt, alpha:vector.w)
	}
	
	public func applyContrast(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).applyContrast(chclt, value:value).display(chclt, alpha:vector.w)
	}
	
	public func contrasting(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).contrasting(chclt, value:value).display(chclt, alpha:vector.w)
	}
	
	public func chroma(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).chroma(chclt)
	}
	
	public func scaleChroma(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return linear(chclt).scaleChroma(chclt, by:scalar).display(chclt, alpha:vector.w)
	}
	
	public func applyChroma(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).applyChroma(chclt, value:value).display(chclt, alpha:vector.w)
	}
	
	public func vectorHue(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).hue(chclt)
	}
	
	public func hueShifted(_ chclt:CHCLT, by shift:Scalar) -> DisplayRGB {
		return linear(chclt).hueShifted(chclt, by:shift).display(chclt, alpha:vector.w)
	}
	
	//	MARK: Hexagonal
	
	public static func hexagonal(hue:Scalar, saturation:Scalar, brightness:Scalar) -> Scalar.Vector3 {
		let hue = saturation < 0 ? hue + 0.5 : hue
		let saturation = saturation.magnitude
		
		guard brightness > 0 && saturation > 0 else { return Scalar.vector3(brightness, brightness, brightness) }
		
		let hue1 = Scalar.vector3(hue, hue - 1.0/3.0, hue - 2.0/3.0)
		let hue2 = hue1 - hue1.rounded(.down) - 0.5
		let hue3 = simd_abs(hue2) * 6.0 - 1.0
		let hue4 = simd_clamp(hue3, simd_double3.zero, simd_double3.one)
		let c = saturation * brightness
		let m = brightness - c
		
		return hue4 * c + m
	}
	
	public func hsb() -> Scalar.Vector4 {
		let (h, s, b) = ColorModel.hsb_from_rgb(r:vector.x, g:vector.y, b:vector.z)
		
		return Scalar.vector4(h, s, b, vector.w)
	}
	
	public func hcl(_ chclt:CHCLT) -> Scalar.Vector4 {
		let hcl = chclt.hcl(linear(chclt).vector)
		
		return Scalar.vector4(hcl, vector.w)
	}
}

//	MARK: -

extension DisplayRGB {
	public static var colorSpace = displayColorSpace()
	
	public static func displayColorSpace() -> CGColorSpace {
		if #available(macOS 11.0, iOS 14.0, *), let extended = CGColorSpace(name:CGColorSpace.extendedDisplayP3) { return extended }
		if #available(macOS 10.12, iOS 10.0, *), let extended = CGColorSpace(name:CGColorSpace.extendedSRGB) { return extended }
		if #available(macOS 10.11.2, iOS 9.3, *), let display = CGColorSpace(name:CGColorSpace.displayP3) { return display }
		
		return CGColorSpace(name:CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
	}
	
	public var cg:CGColor? { return color() }
	
	public init?(_ color:CGColor?) {
		guard
			let color = color,
			color.numberOfComponents == 4,
			color.colorSpace?.model ?? .rgb == CGColorSpaceModel.rgb,
			let components = color.components
		else { return nil }
		
		self.init(components[0].native, components[1].native, components[2].native, components[3].native)
	}
	
	public func color(colorSpace:CGColorSpace? = nil) -> CGColor! {
		let space:CGColorSpace
		
		if let colorSpace = colorSpace, colorSpace.model == .rgb, colorSpace.numberOfComponents == 3 {
			space = colorSpace
		} else {
			space = DisplayRGB.colorSpace
		}
		
		var components:[CGFloat] = [CGFloat(vector.x), CGFloat(vector.y), CGFloat(vector.z), CGFloat(vector.w)]
		
		return CGColor(colorSpace:space, components:&components)
	}
}

//	MARK: -

extension CHCLT.LinearRGB {
	public static var colorSpace:CGColorSpace = linearColorSpace()
	
	public static func linearColorSpace() -> CGColorSpace! {
		// extendedLinearDisplayP3 incorrect on iOS
		//if #available(macOS 10.14.3, iOS 12.3, *), let linear = CGColorSpace(name:CGColorSpace.extendedLinearDisplayP3) { return linear }
		if #available(macOS 10.12, iOS 10.0, *), let linear = CGColorSpace(name:CGColorSpace.linearSRGB) { return linear }
		
		return CGColorSpace(name:CGColorSpace.genericRGBLinear)!
	}
	
	public init?(_ color:CGColor?) {
		if
			#available(macOS 10.11, iOS 9.0, *),
			let color = color?.converted(to:CHCLT.LinearRGB.colorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = color.components
		{
			self.init(components[0].native, components[1].native, components[2].native)
		} else if
			let color = color,
			let chclt = color.colorSpace?.chclt,
			let components = color.components
		{
			self.init(chclt.linear(CHCLT.Scalar.vector3(components[0].native, components[1].native, components[2].native)))
		} else {
			return nil
		}
	}
	
	public func color(colorSpace:CGColorSpace? = nil, alpha:CGFloat = 1) -> CGColor! {
		let space:CGColorSpace
		let rgb:CHCLT.Vector3
		
		if let colorSpace = colorSpace, colorSpace.model == .rgb, colorSpace.numberOfComponents == 3 {
			rgb = colorSpace.chclt?.display(vector) ?? vector
			space = colorSpace
		} else {
			rgb = vector
			space = CHCLT.LinearRGB.colorSpace
		}
		
		var components:[CGFloat] = [CGFloat(rgb.x), CGFloat(rgb.y), CGFloat(rgb.z), alpha]
		
		return CGColor(colorSpace:space, components:&components)!
	}
}

//	MARK: -

extension CHCLT {
	public static func named(_ name:CFString) -> CHCLT? {
		if name == CGColorSpace.sRGB { return CHCLT_sRGB.standard }
		if name == CGColorSpace.genericRGBLinear { return CHCLT.sRGB_linear }
		if name == CGColorSpace.adobeRGB1998 { return CHCLT_Pure.adobeRGB }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.itur_709 { return CHCLT_BT.y709 }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.itur_2020 { return CHCLT_BT.y2020 }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.dcip3 { return CHCLT_Pure.dciP3 }
		if #available(macOS 10.11.2, iOS 9.3, *), name == CGColorSpace.displayP3 { return CHCLT_sRGB.displayP3 }
		if #available(macOS 10.12, iOS 10.0, *), name == CGColorSpace.extendedSRGB { return CHCLT_sRGB.standard }
		if #available(macOS 10.12, iOS 10.0, *), name == CGColorSpace.linearSRGB { return CHCLT.sRGB_linear }
		if #available(macOS 10.12, iOS 10.0, *), name == CGColorSpace.extendedLinearSRGB { return CHCLT.sRGB_linear }
		if #available(macOS 11.0, iOS 14.0, *), name == CGColorSpace.extendedITUR_2020 { return CHCLT_BT.y2020 }
		if #available(macOS 11.0, iOS 14.0, *), name == CGColorSpace.extendedDisplayP3 { return CHCLT_sRGB.displayP3 }
		
		return nil
	}
}

//	MARK: -

extension CGColorSpace {
	public var chclt:CHCLT? {
		guard let name = name, model == .rgb else { return nil }
		
		return CHCLT.named(name)
	}
}
