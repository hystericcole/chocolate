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
	public struct Color: CustomStringConvertible {
		public let display:CHCLT.Vector4
		public let linear:CHCLT.Vector4
		public let chclt:CHCLT
		
		public var displayRGB:DisplayRGB { return DisplayRGB(display) }
		public var linearRGB:CHCLT.LinearRGB { return CHCLT.LinearRGB(linear.xyz) }
		public var red:CHCLT.Scalar { return display.x }
		public var green:CHCLT.Scalar { return display.y }
		public var blue:CHCLT.Scalar { return display.z }
		public var alpha:CHCLT.Scalar { return display.w }
		public var hue:CHCLT.Scalar { return chclt.hue(linear.xyz, luminance:linear.w) }
		public var chroma:CHCLT.Scalar { return chclt.chroma(linear.xyz, luminance:linear.w) }
		public var saturation:CHCLT.Scalar { return chclt.saturation(linear.xyz, luminance:linear.w) }
		public var luma:CHCLT.Scalar { return chclt.luma(luminance:linear.w) }
		public var luminance:CHCLT.Scalar { return linear.w }
		public var isDark:Bool { return chclt.contrast.luminanceIsDark(linear.w) }
		public var isNormal:Bool { return linear.min() >= 0.0 && linear.max() <= 1.0 }
		public var contrast:CHCLT.Scalar { return chclt.contrast(luminance:linear.w) }
		public var rgb:CHCLT.Vector3 { return display.xyz }
		public var hcl:CHCLT.Vector3 { return CHCLT.Scalar.vector3(hue, chroma, luma) }
		public var hsb:CHCLT.Vector3 { return ColorModel.hsb_from_rgb(r:red, g:green, b:blue) }
		public var lab:CHCLT.Vector3 { return chclt.lab(linearRGB:linear.xyz) }
		public var lch:CHCLT.Vector3 { return chclt.lch(linearRGB:linear.xyz) }
		public var xyz:CHCLT.Vector3 { return chclt.xyz(linearRGB:linear.xyz) }
		public var uint:simd_uint4 { var v = display * 255.0; v.round(.toNearestOrAwayFromZero); return simd_uint(v) }
		public var description:String { return rgba() }
		
		public init(_ chclt:CHCLT, display:CHCLT.Vector4) {
			let linearRGB:CHCLT.Vector3 = chclt.linear(display.xyz)
			
			self.chclt = chclt
			self.display = display
			self.linear = CHCLT.Scalar.vector4(linearRGB, chclt.luminance(linearRGB))
		}
		
		public init(_ chclt:CHCLT, linear:CHCLT.Vector3, alpha:CHCLT.Scalar = 1) {
			self.chclt = chclt
			self.display = CHCLT.Scalar.vector4(chclt.display(linear), alpha)
			self.linear = CHCLT.Scalar.vector4(linear, chclt.luminance(linear))
		}
		
		public init(_ chclt:CHCLT, _ color:Color) {
			self.init(chclt, linear:chclt.convert(linearRGB:color.linear.xyz, from:color.chclt))
		}
		
		public init(_ chclt:CHCLT, _ color:DisplayRGB) {
			self.init(chclt, display:color.vector)
		}
		
		public init(_ chclt:CHCLT, _ color:CHCLT.LinearRGB, alpha:CHCLT.Scalar = 1) {
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
		
		public func convert(_ chclt:CHCLT) -> Color { return Color(chclt, self) }
		public func hueShifted(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.hueShift(linear.xyz, luminance:linear.w, by:value), alpha:display.w) }
		public func hueTurned(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.hueShift(linear.xyz, luminance:linear.w, by:value, apply:chroma), alpha:display.w) }
		public func applyHue(_ value:CHCLT.Scalar) -> Self { return hueShifted(value - hue) }
		public func scaleChroma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.scaleChroma(linear.xyz, luminance:linear.w, by:value), alpha:display.w) }
		public func applyChroma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyChroma(linear.xyz, luminance:linear.w, apply:value), alpha:display.w) }
		public func scaleLuma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyLuminance(linear.xyz, luminance:linear.w, apply:chclt.luminance(luma:chclt.luma(luminance:linear.w) * value)), alpha:display.w) }
		public func applyLuma(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyLuminance(linear.xyz, luminance:linear.w, apply:chclt.luminance(luma:value)), alpha:display.w) }
		public func scaleLuminance(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:linear.xyz * value, alpha:display.w) }
		public func applyLuminance(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyLuminance(linear.xyz, luminance:linear.w, apply:value), alpha:display.w) }
		public func scaleContrast(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.scaleContrast(linear.xyz, luminance:linear.w, by:value), alpha:display.w) }
		public func applyContrast(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyContrast(linear.xyz, luminance:linear.w, apply:value), alpha:display.w) }
		public func contrasting(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.contrasting(linear.xyz, luminance:linear.w, value:value), alpha:display.w) }
		public func opposing(_ value:CHCLT.Scalar) -> Self { return Color(chclt, linear:chclt.applyContrast(linear.xyz, luminance:linear.w, apply:-value), alpha:display.w) }
		public func transform(_ transform:CHCLT.Transform) -> Self { return Color(chclt, linear:chclt.transform(linear.xyz, luminance:linear.w, transform:transform), alpha:display.w) }
		
		public func normalize() -> Self { return Color(chclt, linear:CHCLT.normalize(linear.xyz, luminance:linear.w, leavePositive:false), alpha:display.w) }
		public func illuminate() -> Self { return Color(chclt, linear:CHCLT.illuminate(linear.xyz), alpha:display.w) }
		public func inverse() -> Self { return Color(chclt, linear:1 - linear.xyz, alpha:display.w) }
		public func liminal() -> Self { return applyLuma(1 - luma) }
		public func complementary() -> Self { return applyChroma(-chroma) }
		public func hueGroup(_ turned:CHCLT.Scalar...) -> [Self] { return turned.map { hueTurned($0) } }
		public func triadic() -> [Self] { return hueGroup(1/3, 2/3) }
		public func tetradic(clockwise:Bool = false) -> [Self] { return clockwise ? hueGroup(1/6, 3/6, 4/6) : hueGroup(-1/6, -3/6, -4/6) }
		public func square() -> [Self] { return hueGroup(1/4, 2/4, 3/4) }
		public func analogous(turns:Scalar = 1/12) -> [Self] { return hueGroup(turns, -turns) }
		public func complementarySplit(turns:Scalar = 1/12) -> [Self] { return hueGroup(0.5 - turns, turns - 0.5) }
		
		public func difference(_ color:Color) -> Scalar { return Lab.difference(lab, color.lab) }
		
		public func rgba() -> String { return String(format:"RGBA(%.3g, %.3g, %.3g, %.3g)", red, green, blue, alpha) }
		public func web(allowFormat:Int = 0) -> String { return displayRGB.web(allowFormat:allowFormat) }
		public func css(withAlpha:Int = 0) -> String { return displayRGB.css(withAlpha:withAlpha) }
		public func chcl(withAlpha:Int = 0, formatter:NumberFormatter = NumberFormatter(fractionDigits:1 ... 1)) -> [String] {
			let symbol = isDark ? "◐" : "◑"
			
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
	
	public let vector:CHCLT.Vector4
	
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
	
	public init(hexagonal hue:Scalar, saturation:Scalar, brightness:Scalar, alpha:Scalar = 1) {
		vector = Scalar.vector4(ColorModel.rgb_from_hsb(h:hue, s:saturation, b:brightness), alpha)
	}
	
	public func color(_ chclt:CHCLT) -> CHCLT.Color {
		return CHCLT.Color(chclt, display:vector)
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
	
	//	MARK: Hexagonal
	
	public func hsb() -> Scalar.Vector4 {
		let hsb = ColorModel.hsb_from_rgb(r:vector.x, g:vector.y, b:vector.z)
		
		return Scalar.vector4(hsb, vector.w)
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
	
	public init?(_ color:CGColor?) {
		guard let components = color?.componentsVector4 else { return nil }
		
		self.init(components)
	}
	
	public func color(colorSpace:CGColorSpace? = nil) -> CGColor! {
		let space:CGColorSpace
		
		if let colorSpace = colorSpace, colorSpace.model == .rgb, colorSpace.numberOfComponents == 3 {
			space = colorSpace
		} else {
			space = DisplayRGB.colorSpace
		}
		
		return CGColor.with(colorSpace:space, componentsVector4:vector)
	}
}

//	MARK: -

extension CHCLT.LinearRGB {
	public static var colorSpace:CGColorSpace = linearColorSpace()
	
	public static func linearColorSpace() -> CGColorSpace! {
		if #available(macOS 10.14.3, iOS 12.3, *), let linear = CGColorSpace(name:CGColorSpace.extendedLinearDisplayP3) { return linear }
		if #available(macOS 10.12, iOS 10.0, *), let linear = CGColorSpace(name:CGColorSpace.linearSRGB) { return linear }
		
		return CGColorSpace(name:CGColorSpace.genericRGBLinear)!
	}
	
	public init?(_ color:CGColor?) {
		guard let components = color?.componentsVector3 else { return nil }
		
		self.init(components)
	}
	
	public init?(_ color:CGColor?, convertingToLinearColorSpace colorSpace:CGColorSpace?) {
		if
			#available(macOS 10.11, iOS 9.0, *),
			let converted = color?.converted(to:colorSpace ?? CHCLT.LinearRGB.colorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = converted.componentsVector3
		{
			self.init(components)
		} else {
			self.init(color)
		}
	}
	
	public func color(alpha:CGFloat = 1) -> CGColor! {
		return CGColor.with(colorSpace:CHCLT.LinearRGB.colorSpace, componentsVector3:vector, alpha:alpha)
	}
}

//	MARK: -

extension CHCLT.Color {
	public init?(_ chclt:CHCLT, _ color:CGColor?, useSpaceFromColorWhenAvailable:Bool = false) {
		guard let color = color else { return nil }
		
		if color.colorSpace == nil, let components = color.componentsVector4 {
			self.init(chclt, display:components)
		} else if let other = color.colorSpace?.chclt, let components = color.componentsVector4 {
			if useSpaceFromColorWhenAvailable || chclt === other {
				self.init(other, display:components)
			} else {
				self.init(chclt, linear:chclt.convert(linearRGB:other.linear(components.xyz), from:other), alpha:components.w)
			}
		} else if
			#available(macOS 10.11, iOS 9.0, *),
			let rgbColorSpace = chclt.rgbColorSpace(),
			let converted = color.converted(to:rgbColorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = converted.componentsVector4
		{
			self.init(chclt, display:components)
		} else if
			#available(macOS 10.11, iOS 9.0, *),
			let labColorSpace = chclt.labColorSpace(),
			let converted = color.converted(to:labColorSpace, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = converted.componentsVector4
		{
			self.init(chclt, linear:chclt.linearRGB(lab:components.xyz), alpha:components.w)
		} else if let components = color.componentsVector4, let model = color.colorSpace?.model {
			switch model {
			case .rgb: self.init(chclt, display:components)
			case .lab: self.init(chclt, linear:chclt.linearRGB(xyz:CHCLT.Lab.toXYZ(lab:components.xyz, white:CHCLT.Lab.genericWhite)), alpha:components.w)
			case .XYZ: self.init(chclt, linear:chclt.linearRGB(xyz:components.xyz), alpha:components.w)
			default: return nil
			}
		} else {
			return nil
		}
	}
	
	public init?(_ color:CGColor?) {
		guard let chclt = color?.colorSpace?.chclt, let components = color?.componentsVector4 else { return nil }
		
		self.init(chclt, display:components)
	}
	
	init?(_ chclt:CHCLT, _ color:PlatformColor?, useSpaceFromColorWhenAvailable:Bool = false) {
		self.init(chclt, color?.cgColor, useSpaceFromColorWhenAvailable:useSpaceFromColorWhenAvailable)
	}
	
	init?(_ color:PlatformColor?) {
		self.init(color?.cgColor)
	}
	
	var platformColor:PlatformColor { return color.platformColor }
	
	public var color:CGColor! {
		if let colorSpace = chclt.rgbColorSpace() {
			return CGColor.with(colorSpace:colorSpace, componentsVector4:display)
		} else if let colorSpace = chclt.labColorSpace() {
			return CGColor.with(colorSpace:colorSpace, componentsVector3:chclt.lab(linearRGB:linear.xyz), alpha:CGFloat(alpha))
		} else {
			return CGColor.with(colorSpace:CHCLT.LinearRGB.colorSpace, componentsVector3:linear.xyz, alpha:CGFloat(alpha))
		}
	}
	
	public var linearColor:CGColor! {
		return linearRGB.color(alpha:CGFloat(alpha))
	}
	
	public func convert(colorSpace:CGColorSpace?) -> CGColor! {
		if
			let space = colorSpace,
			let chclt = space.chclt,
			let color = CGColor.with(colorSpace:space, componentsVector4:convert(chclt).display)
		{
			return color
		}
		
		guard let color = color else { return nil }
		
		if
			#available(macOS 10.11, iOS 9.0, *),
			let space = colorSpace,
			space != color.colorSpace,
			let converted = color.converted(to:space, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil)
		{
			return converted
		} else {
			return color
		}
	}
}

//	MARK: -

extension CHCLT {
	public static let colorSpaceNameByCHCLT = availableColorSpaceNameByCHCLT()
	public static let colorSpaceByCHCLT = colorSpaceNameByCHCLT.compactMapValues(CGColorSpace.init)
	public static let colorSpaceNameToCHCLT = availableColorSpaceNameToCHCLT()
	public static let colorSpaceCommonKeyCHCLT = availableColorSpaceKeyToCHCLT(colorSpaceNameToCHCLT)
	
	private static func availableColorSpaceNameByCHCLT() -> [CHCLT:CFString] {
		var result:[CHCLT:CFString] = [:]
		
		result[CHCLT_Linear.sRGB] = CGColorSpace.genericRGBLinear
		if #available(macOS 10.12, iOS 10.0, *) { result[CHCLT_Linear.sRGB] = CGColorSpace.linearSRGB }
		//if #available(macOS 10.12, iOS 10.0, *) { result[CHCLT_Linear.sRGB] = CGColorSpace.extendedLinearSRGB }
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_Linear.aces] = CGColorSpace.acescgLinear }
		
		result[CHCLT_Pure.sRGB] = CGColorSpace.sRGB
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_Pure.dciP3] = CGColorSpace.dcip3 }
		result[CHCLT_Pure.adobeRGB] = CGColorSpace.adobeRGB1998
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_Pure.y709] = CGColorSpace.itur_709 }
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_Pure.y2020] = CGColorSpace.itur_2020 }
		//if #available(macOS 11.0, iOS 14.0, *) { result[CHCLT_Pure.y2020] = CGColorSpace.extendedITUR_2020 }
		
		result[CHCLT_sRGB.standard] = CGColorSpace.sRGB
		result[CHCLT_sRGB.g18] = CGColorSpace.sRGB
		if #available(macOS 10.11.2, iOS 9.3, *) { result[CHCLT_sRGB.displayP3] = CGColorSpace.displayP3 }
		//if #available(macOS 11.0, iOS 14.0, *) { result[CHCLT_sRGB.displayP3] = CGColorSpace.extendedDisplayP3 }
		
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_ROMM.standard] = CGColorSpace.rommrgb }
		
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_BT.y709] = CGColorSpace.itur_709 }
		if #available(macOS 10.11, iOS 9.0, *) { result[CHCLT_BT.y2020] = CGColorSpace.itur_2020 }
		
		return result
	}
	
	private static func availableColorSpaceNameToCHCLT() -> [CFString:CHCLT] {
		var result:[CFString:CHCLT] = [:]
		
		result[CGColorSpace.genericRGBLinear] = CHCLT_Linear.sRGB
		if #available(macOS 10.12, iOS 10.0, *) { result[CGColorSpace.linearSRGB] = CHCLT_Linear.sRGB }
		if #available(macOS 10.12, iOS 10.0, *) { result[CGColorSpace.extendedLinearSRGB] = CHCLT_Linear.sRGB }
		if #available(macOS 10.11, iOS 9.0, *) { result[CGColorSpace.acescgLinear] = CHCLT_Linear.aces }
		
		result[CGColorSpace.adobeRGB1998] = CHCLT_Pure.adobeRGB
		if #available(macOS 10.11, iOS 9.0, *) { result[CGColorSpace.dcip3] = CHCLT_Pure.dciP3 }
		
		result["kCGColorSpaceGenericRGB" as CFString] = CHCLT_sRGB.standard
		result[CGColorSpace.sRGB] = CHCLT_sRGB.standard
		if #available(macOS 10.12, iOS 10.0, *) { result[CGColorSpace.extendedSRGB] = CHCLT_sRGB.standard }
		if #available(macOS 10.11.2, iOS 9.3, *) { result[CGColorSpace.displayP3] = CHCLT_sRGB.displayP3 }
		if #available(macOS 10.14.3, iOS 12.3, *) { result[CGColorSpace.extendedLinearDisplayP3] = nil }
		if #available(macOS 11.0, iOS 14.0, *) { result[CGColorSpace.extendedDisplayP3] = CHCLT_sRGB.displayP3 }
		
		if #available(macOS 10.11, iOS 9.0, *) { result[CGColorSpace.rommrgb] = CHCLT_ROMM.standard }
		
		if #available(macOS 10.11, iOS 9.0, *) { result[CGColorSpace.itur_709] = CHCLT_BT.y709 }
		if #available(macOS 10.11, iOS 9.0, *) { result[CGColorSpace.itur_2020] = CHCLT_BT.y2020 }
		if #available(macOS 11.0, iOS 14.0, *) { result[CGColorSpace.extendedITUR_2020] = CHCLT_BT.y2020 }
		if #available(macOS 10.14.3, iOS 12.3, *) { result[CGColorSpace.extendedLinearITUR_2020] = nil }
		
		return result
	}
	
	private static func availableColorSpaceKeyToCHCLT(_ nameToCHCLT:[CFString:CHCLT]) -> [CFData:CHCLT] {
		var result:[CFData:CHCLT] = [:]
		
		for (name, chclt) in nameToCHCLT {
			guard let key = CGColorSpace(name:name)?.commonKey else { continue }
			
			//	Extended and truncated variants may have identical keys
			result[key] = chclt
		}
		
		return result
	}
	
	public func rgbColorSpace() -> CGColorSpace? {
		return CHCLT.colorSpaceByCHCLT[self]
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
	var commonKey:CFData? {
		if #available(OSX 10.12, *) {
			return copyICCData()
		} else {
			return iccData
		}
	}
	
	public var chclt:CHCLT? {
		guard model == .rgb else { return nil }
		
		if let name = name, let chclt = CHCLT.colorSpaceNameToCHCLT[name] { return chclt }
		if let key = commonKey, let chclt = CHCLT.colorSpaceCommonKeyCHCLT[key] { return chclt }
		
		return nil
	}
}

//	MARK: -

extension CGColor {
	var componentsVector4:CGFloat.Vector4? {
		guard numberOfComponents == 4, let components = components else { return nil }
		
		return CGFloat.vector4(components[0], components[1], components[2], components[3])
	}
	
	var componentsVector3:CGFloat.Vector3? {
		guard numberOfComponents == 4, let components = components else { return nil }
		
		return CGFloat.vector3(components[0], components[1], components[2])
	}
	
	static func with(colorSpace:CGColorSpace, componentsVector4:CGFloat.Vector4) -> CGColor? {
		return withUnsafeBytes(of:componentsVector4) { CGColor(colorSpace:colorSpace, components:$0.baseAddress!.assumingMemoryBound(to:CGFloat.self)) }
	}
	
	static func with(colorSpace:CGColorSpace, componentsVector3:CGFloat.Vector3, alpha:CGFloat = 1) -> CGColor? {
		return with(colorSpace:colorSpace, componentsVector4:CGFloat.vector4(componentsVector3, alpha))
	}
}
