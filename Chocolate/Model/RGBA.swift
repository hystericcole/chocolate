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

extension CHCLT {
	public struct Color {
		public var display:CHCLT.Vector4
		public var linear:CHCLT.Vector4
		public let chclt:CHCLT
		
		public init(_ chclt:CHCLT, display:CHCLT.Vector4) {
			let l = chclt.linear(display.xyz)
			
			self.chclt = chclt
			self.display = display
			self.linear = CHCLT.Scalar.vector4(l, chclt.luminance(l))
		}
		
		public init(_ chclt:CHCLT, linear:CHCLT.Vector3, alpha:CHCLT.Scalar = 1) {
			self.chclt = chclt
			self.display = CHCLT.Scalar.vector4(chclt.display(linear), alpha)
			self.linear = CHCLT.Scalar.vector4(linear, chclt.luminance(linear))
		}
		
		public init?(_ chclt:CHCLT, _ color:CGColor) {
			guard let linear = CHCLT.LinearRGB(color, chclt:chclt) else { return nil }
			
			self.init(chclt, linear:linear.vector, alpha:color.alpha.native)
		}
		
		public init?(_ color:CGColor, chclt:CHCLT = CHCLT.default) {
			self.init(color.colorSpace?.chclt ?? chclt, color)
		}
		
		init?(_ chclt:CHCLT, _ color:PlatformColor) {
			self.init(chclt, color.cgColor)
		}
		
		public init(_ chclt:CHCLT, _ color:DisplayRGB) {
			self.init(chclt, display:color.vector)
		}
		
		public init(_ chclt:CHCLT, _ color:CHCLT.LinearRGB, alpha:CHCLT.Scalar) {
			self.init(chclt, linear:color.vector, alpha:alpha)
		}
		
		public init(_ chclt:CHCLT, gray:CHCLT.Scalar, alpha:CHCLT.Scalar = 1) {
			self.init(chclt, display:CHCLT.Scalar.vector4(gray, gray, gray, alpha))
		}
		
		public init(_ chclt:CHCLT, red:CHCLT.Scalar, green:CHCLT.Scalar, blue:CHCLT.Scalar, alpha:CHCLT.Scalar = 1) {
			self.init(chclt, display:CHCLT.Scalar.vector4(red, green, blue, alpha))
		}
		
		public init(_ chclt:CHCLT, hue:CHCLT.Scalar, chroma:CHCLT.Scalar, luma:CHCLT.Scalar, alpha:CHCLT.Scalar = 1) {
			self.init(chclt, linear:CHCLT.LinearRGB(chclt, hue:hue, chroma:chroma, luma:luma).vector, alpha:alpha)
		}
		
		public var description:String { return rgba() }
		
		var platformColor:PlatformColor { return color.platformColor }
		public var color:CGColor { return linearRGB.color(chclt:chclt, alpha:CGFloat(display.w)) }
		public var displayRGB:DisplayRGB { return DisplayRGB(display) }
		public var linearRGB:CHCLT.LinearRGB { return CHCLT.LinearRGB(linear.xyz) }
		public var uint:simd_uint4 { var v = display * 255.0; v.round(.toNearestOrAwayFromZero); return simd_uint(v) }
		
		public var red:CHCLT.Scalar { return display.x }
		public var green:CHCLT.Scalar { return display.y }
		public var blue:CHCLT.Scalar { return display.z }
		public var alpha:CHCLT.Scalar { return display.w }
		public var hue:CHCLT.Scalar { return chclt.hue(linear.xyz, luminance:linear.w) }
		public var chroma:CHCLT.Scalar { return chclt.chroma(linear.xyz, luminance:linear.w) }
		public var saturation:CHCLT.Scalar { return chclt.saturation(linear.xyz, luminance:linear.w) }
		public var luma:CHCLT.Scalar { return chclt.transfer(linear.w) }
		public var luminance:CHCLT.Scalar { return linear.w }
		public var contrast:CHCLT.Scalar { return chclt.contrast(luminance:linear.w) }
		public var hcl:CHCLT.Vector3 { return chclt.hcl(linear:linear.xyz) }
		public var hsba:CHCLT.Vector4 { return displayRGB.hsb() }
		
		public func hueShifted(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.hueShift(linear.xyz, luminance:linear.w, by:value), alpha:display.w) }
		public func applyHue(_ value:CHCLT.Scalar) -> Self { return hueShifted(value - hue) }
		public func scaleChroma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.scaleChroma(linear.xyz, luminance:linear.w, by:value), alpha:display.w) }
		public func applyChroma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyChroma(linear.xyz, luminance:linear.w, apply:value), alpha:display.w) }
		public func scaleLuma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyLuminance(linear.xyz, luminance:linear.w, apply:chclt.linear(chclt.transfer(linear.w) * value)), alpha:display.w) }
		public func applyLuma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyLuminance(linear.xyz, luminance:linear.w, apply:chclt.linear(value)), alpha:display.w) }
		public func scaleLuminance(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:linear.xyz * value, alpha:display.w) }
		public func applyLuminance(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyLuminance(linear.xyz, luminance:linear.w, apply:value), alpha:display.w) }
		public func scaleContrast(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.scaleContrast(linear.xyz, luminance:linear.w, by:value), alpha:display.w) }
		public func applyContrast(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyContrast(linear.xyz, luminance:linear.w, apply:value), alpha:display.w) }
		public func contrasting(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.contrasting(linear.xyz, luminance:linear.w, value:value), alpha:display.w) }
		public func normalize() -> Self { return Color(chclt, linear:CHCLT.normalize(linear.xyz, luminance:linear.w, leavePositive:false), alpha:display.w) }
		public func transform(_ transform:CHCLT.Transform) -> Self { return Color(chclt, linear:chclt.transform(linear.xyz, luminance:linear.w, transform:transform), alpha:display.w) }
		public func invert()  -> Self { return Color(chclt, linear:1 - linear.xyz, alpha:display.w) }
		
		public func rgba() -> String { return String(format:"RGBA(%.3g, %.3g, %.3g, %.3g)", red, green, blue, alpha) }
		public func web(allowFormat:Int = 0) -> String { return displayRGB.web(allowFormat:allowFormat) }
		public func css(withAlpha:Int = 0) -> String { return displayRGB.css(withAlpha:withAlpha) }
		public func chcl(withAlpha:Int = 0, formatter:NumberFormatter = NumberFormatter(fractionDigits:1 ... 1)) -> [String] {
			let symbol = linear.w < chclt.contrast.mediumLuminance ? "◐" : "◑"
			
			var result = [
				formatter.string(hue * 360.0) + "°",
				formatter.string(chroma * 100.0) + "%",
				formatter.string(luma * 100) + "☼",
				formatter.string(contrast * 100) + symbol
			]
			
			if withAlpha > 0 || (withAlpha == 0 && alpha < 1) {
				result.append(formatter.string(alpha) + "◍")
			}
			
			return result
		}
	}
}

//	MARK: -

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
		
		vector = Scalar.vector4(chclt.display(simd_max(linear.vector, Scalar.Vector3.zero)), alpha)
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
		return linear(chclt).luma(chclt)
	}
	
	public func scaleLuma(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return linear(chclt).scaleLuma(chclt, by:scalar).display(chclt, alpha:vector.w)
	}
	
	public func applyLuma(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).applyLuma(chclt, value:value).display(chclt, alpha:vector.w)
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
		
		let hue1:Scalar.Vector3 = Scalar.vector3(hue, hue - 1.0/3.0, hue - 2.0/3.0)
		let hue2:Scalar.Vector3 = hue1 - hue1.rounded(.down) - 0.5
		let hue3:Scalar.Vector3 = simd_abs(hue2) * 6.0 - 1.0
		let hue4:Scalar.Vector3 = simd_clamp(hue3, Scalar.Vector3.zero, Scalar.Vector3.one)
		let c:Scalar = saturation * brightness
		let m:Scalar = brightness - c
		
		return hue4 * c + m
	}
	
	public func hsb() -> Scalar.Vector4 {
		let (h, s, b) = ColorModel.hsb_from_rgb(r:vector.x, g:vector.y, b:vector.z)
		
		return Scalar.vector4(h, s, b, vector.w)
	}
	
	public func hcl(_ chclt:CHCLT) -> Scalar.Vector4 {
		let hcl = chclt.hcl(linear:linear(chclt).vector)
		
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
	
	public init?(_ color:CGColor?, chclt:CHCLT) {
		guard let color = color, let linearRGB = CHCLT.LinearRGB(color, chclt:chclt) else { return nil }
		
		let rgb = chclt.display(linearRGB.vector)
		
		self.init(CHCLT.Scalar.vector4(rgb, color.alpha.native))
	}
	
	public init?(_ color:CGColor?) {
		guard
			let color = color,
			color.numberOfComponents == 4,
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
		if let chclt = color?.colorSpace?.chclt, let components = color?.components {
			let rgb = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			
			self.init(chclt.linear(rgb))
		} else {
			self.init(color, linearColorSpace:nil)
		}
	}
	
	public init?(linearColor color:CGColor?) {
		guard let color = color, color.numberOfComponents == 4, let components = color.components else { return nil }
		
		self.init(components[0].native, components[1].native, components[2].native)
	}
	
	public init?(_ color:CGColor?, linearColorSpace:CGColorSpace?) {
		if
			color?.colorSpace != nil,
			#available(macOS 10.11, iOS 9.0, *),
			let converted = color?.converted(to:linearColorSpace ?? CHCLT.LinearRGB.colorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = converted.components
		{
			let rgb = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			
			self.init(rgb)
		} else {
			self.init(linearColor:color)
		}
	}
	
	public init?(_ color:CGColor?, chclt:CHCLT) {
		guard let color = color else { return nil }
		
		if color.colorSpace == nil && color.numberOfComponents == 4, let components = color.components {
			let rgb = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			
			self.init(rgb)
		} else if let other = color.colorSpace?.chclt, let components = color.components {
			let rgb = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			
			self.init(chclt.convert(linearRGB:other.linear(rgb), from:other))
		} else if
			#available(macOS 10.11, iOS 9.0, *),
			let rgbColorSpace = chclt.rgbColorSpace(),
			let converted = color.converted(to:rgbColorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = converted.components
		{
			let rgb = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			let linearRGB = chclt.linear(rgb)
			
			self.init(linearRGB)
		} else if
			#available(macOS 10.11, iOS 9.0, *),
			let labColorSpace = chclt.labColorSpace(),
			let converted = color.converted(to:labColorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = converted.components
		{
			let lab = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			let linearRGB = chclt.linearRGB(lab:lab)
			
			self.init(linearRGB)
		} else if color.numberOfComponents == 4, let components = color.components, let model = color.colorSpace?.model {
			let c = CHCLT.Linear.vector3(components[0].native, components[1].native, components[2].native)
			
			switch model {
			case .rgb: self.init(chclt.linear(c))
			case .lab: self.init(chclt.linearRGB(lab:c))
			case .XYZ: self.init(chclt.linearRGB(xyz:c))
			default: return nil
			}
		} else {
			return nil
		}
	}
	
	public func color(chclt:CHCLT, alpha:CGFloat = 1) -> CGColor! {
		let space:CGColorSpace
		let c:CHCLT.Vector3
		
		if let colorSpace = chclt.rgbColorSpace() {
			c = chclt.display(vector)
			space = colorSpace
		} else if let colorSpace = chclt.labColorSpace() {
			c = chclt.lab(linearRGB:vector)
			space = colorSpace
		} else {
			c = vector
			space = CHCLT.LinearRGB.colorSpace
		}
		
		var components:[CGFloat] = [CGFloat(c.x), CGFloat(c.y), CGFloat(c.z), alpha]
		
		return CGColor(colorSpace:space, components:&components)
	}
	
	public func color(linearColorSpace:CGColorSpace, alpha:CGFloat = 1) -> CGColor? {
		guard linearColorSpace.numberOfComponents <= 3 else { return nil }
		
		var components:[CGFloat] = [CGFloat(vector.x), CGFloat(vector.y), CGFloat(vector.z), alpha]
		
		return CGColor(colorSpace:linearColorSpace, components:&components)
	}
	
	public func color(alpha:CGFloat = 1) -> CGColor! {
		var components:[CGFloat] = [CGFloat(vector.x), CGFloat(vector.y), CGFloat(vector.z), alpha]
		
		return CGColor(colorSpace:CHCLT.LinearRGB.colorSpace, components:&components)
	}
}

//	MARK: -

extension CHCLT {
	public static func named(_ name:CFString) -> CHCLT? {
		if name == CGColorSpace.sRGB || name == "kCGColorSpaceGenericRGB" as CFString { return CHCLT_sRGB.standard }
		if name == CGColorSpace.genericRGBLinear { return CHCLT_Linear.sRGB }
		if name == CGColorSpace.adobeRGB1998 { return CHCLT_Pure.adobeRGB }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.itur_709 { return CHCLT_BT.y709 }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.itur_2020 { return CHCLT_BT.y2020 }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.dcip3 { return CHCLT_Pure.dciP3 }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.acescgLinear { return CHCLT_Linear.aces }
		if #available(macOS 10.11, iOS 9.0, *), name == CGColorSpace.rommrgb { return CHCLT_ROMM.standard }
		if #available(macOS 10.11.2, iOS 9.3, *), name == CGColorSpace.displayP3 { return CHCLT_sRGB.displayP3 }
		if #available(macOS 10.12, iOS 10.0, *), name == CGColorSpace.extendedSRGB { return CHCLT_sRGB.standard }
		if #available(macOS 10.12, iOS 10.0, *), name == CGColorSpace.linearSRGB { return CHCLT_Linear.sRGB }
		if #available(macOS 10.12, iOS 10.0, *), name == CGColorSpace.extendedLinearSRGB { return CHCLT_Linear.sRGB }
		if #available(macOS 11.0, iOS 14.0, *), name == CGColorSpace.extendedITUR_2020 { return CHCLT_BT.y2020 }
		if #available(macOS 11.0, iOS 14.0, *), name == CGColorSpace.extendedDisplayP3 { return CHCLT_sRGB.displayP3 }
		
		return nil
	}
	
	public func colorSpaceName(preferExtended:Bool = false) -> CFString? {
		switch toXYZ {
		case CHCLT.XYZ.rgb_to_xyz_bt709_d65:
			if #available(macOS 10.12, iOS 10.0, *), self is CHCLT_Linear { return CGColorSpace.extendedLinearSRGB }
			if self is CHCLT_Linear { return CGColorSpace.genericRGBLinear }
			if #available(macOS 10.11, iOS 9.0, *), self is CHCLT_BT { return CGColorSpace.itur_709 }
			if #available(macOS 10.11, iOS 9.0, *), (self as? CHCLT_Pure)?.exponent == CHCLT_Pure.y709.exponent { return CGColorSpace.itur_709 }
			if preferExtended, #available(macOS 10.12, iOS 10.0, *) { return CGColorSpace.extendedSRGB }
			
			return CGColorSpace.sRGB
		case CHCLT.XYZ.rgb_to_xyz_displayP3_d65:
			if #available(macOS 10.14.3, iOS 12.3, *), self is CHCLT_Linear { return CGColorSpace.extendedLinearDisplayP3 }
			if preferExtended, #available(macOS 11.0, iOS 14.0, *) { return CGColorSpace.extendedDisplayP3 }
			if #available(macOS 10.11.2, iOS 9.3, *) { return CGColorSpace.displayP3 }
		case CHCLT.XYZ.rgb_to_xyz_bt2020_d65:
			if #available(macOS 10.14.3, iOS 12.3, *), self is CHCLT_Linear { return CGColorSpace.extendedLinearITUR_2020 }
			if preferExtended, #available(macOS 11.0, iOS 14.0, *) { return CGColorSpace.extendedITUR_2020 }
			if #available(macOS 10.11, iOS 9.0, *) { return CGColorSpace.itur_2020 }
		case CHCLT.XYZ.rgb_to_xyz_theaterP3_dci:
			if #available(macOS 10.11, iOS 9.0, *) { return CGColorSpace.dcip3 }
		case CHCLT.XYZ.rgb_to_xyz_adobeRGB_d65:
			return CGColorSpace.adobeRGB1998
		case CHCLT.XYZ.rgb_to_xyz_romm_d50:
			if #available(macOS 10.11, iOS 9.0, *) { return CGColorSpace.rommrgb }
		case CHCLT.XYZ.rgb_to_xyz_acescg:
			if #available(macOS 10.11, iOS 9.0, *) { return CGColorSpace.acescgLinear }
		default:
			break
		}
		
		return nil
	}
	
	public func rgbColorSpace() -> CGColorSpace? {
		guard let name = colorSpaceName() else { return nil }
		
		return CGColorSpace(name:name)
	}
	
	public func labColorSpace() -> CGColorSpace? {
		let w = whitepoint()
		let a:[CGFloat] = [CGFloat(w.x), CGFloat(w.y), CGFloat(w.z)]
		
		return CGColorSpace(labWhitePoint:a, blackPoint:nil, range:nil)
	}
	
	public func xyzColorSpace(gamma g:CGFloat) -> CGColorSpace? {
		let w = whitepoint()
		let a:[CGFloat] = [CGFloat(w.x), CGFloat(w.y), CGFloat(w.z)]
		let gamma:[CGFloat] = [g, g, g]
		let matrix:[CGFloat] = [
			CGFloat(toXYZ.columns.0.x), CGFloat(toXYZ.columns.0.y), CGFloat(toXYZ.columns.0.z),
			CGFloat(toXYZ.columns.1.x), CGFloat(toXYZ.columns.1.y), CGFloat(toXYZ.columns.1.z),
			CGFloat(toXYZ.columns.2.x), CGFloat(toXYZ.columns.2.y), CGFloat(toXYZ.columns.2.z)
		]
		
		return CGColorSpace(calibratedRGBWhitePoint:a, blackPoint:nil, gamma:gamma, matrix:matrix)
	}
}

//	MARK: -

extension CHCLT_Pure {
	public func xyzColorSpace() -> CGColorSpace? {
		return xyzColorSpace(gamma:CGFloat(exponent))
	}
}

//	MARK: -

extension CGColorSpace {
	static var nameByCommonKey:[CFData:CFString] = availableNamesByCommonKey()
	
	var commonKey:CFData? {
		if #available(OSX 10.12, *) {
			return copyICCData()
		} else {
			return iccData
		}
	}
	
	var commonKeyName:CFString? {
		guard let key = commonKey else { return nil }
		
		return CGColorSpace.nameByCommonKey[key]
	}
	
	static func availableNames() -> [CFString] {
		var names:[CFString] = [
			"kCGColorSpaceGenericRGB" as CFString,
			CGColorSpace.sRGB,
			CGColorSpace.genericRGBLinear,
			CGColorSpace.adobeRGB1998
		]
		
		if #available(macOS 10.11, iOS 9.0, *) { names.append(CGColorSpace.itur_709) }
		if #available(macOS 10.11, iOS 9.0, *) { names.append(CGColorSpace.itur_2020) }
		if #available(macOS 10.11, iOS 9.0, *) { names.append(CGColorSpace.dcip3) }
		if #available(macOS 10.11, iOS 9.0, *) { names.append(CGColorSpace.acescgLinear) }
		if #available(macOS 10.11, iOS 9.0, *) { names.append(CGColorSpace.rommrgb) }
		if #available(macOS 10.11.2, iOS 9.3, *) { names.append(CGColorSpace.displayP3) }
		if #available(macOS 10.12, iOS 10.0, *) { names.append(CGColorSpace.extendedSRGB) }
		if #available(macOS 10.12, iOS 10.0, *) { names.append(CGColorSpace.linearSRGB) }
		if #available(macOS 10.12, iOS 10.0, *) { names.append(CGColorSpace.extendedLinearSRGB) }
		if #available(macOS 10.14.3, iOS 12.3, *) { names.append(CGColorSpace.extendedLinearITUR_2020) }
		if #available(macOS 10.14.3, iOS 12.3, *) { names.append(CGColorSpace.extendedLinearDisplayP3) }
		if #available(macOS 11.0, iOS 14.0, *) { names.append(CGColorSpace.extendedITUR_2020) }
		if #available(macOS 11.0, iOS 14.0, *) { names.append(CGColorSpace.extendedDisplayP3) }
		
		return names
	}
	
	static func availableNamesByCommonKey(_ names:[CFString] = availableNames()) -> [CFData:CFString] {
		var namesByCommonKey:[CFData:CFString] = [:]
		
		for name in names {
			guard let space = CGColorSpace(name:name), let key = space.commonKey else { continue }
			
			namesByCommonKey[key] = name
		}
		
		return namesByCommonKey
	}
	
	public var chclt:CHCLT? {
		guard model == .rgb, let name = name ?? commonKeyName else { return nil }
		
		return CHCLT.named(name)
	}
}
