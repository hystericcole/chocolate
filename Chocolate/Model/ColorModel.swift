//
//	ColorModel.swift
//	Chocolate
//
//	Created by Eric Cole on 3/11/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation
import simd

enum ColorModel: Int {
	typealias Scalar = CHCLT.Scalar
	
	case chclt, rgb, hsb
	
	struct AxisOptions: OptionSet {
		static let axisCount = 3
		
		let rawValue:Int
		
		var flipOver:Bool { return rawValue & 1 != 0 ? ~rawValue & 4 != 0 : rawValue & 2 != 0 }
		var flipDown:Bool { return rawValue & 1 != 0 ? ~rawValue & 2 != 0 : rawValue & 4 != 0 }
		
		static let swapXY = AxisOptions(rawValue:1 << 0)
		static let flipX = AxisOptions(rawValue:1 << 1)
		static let flipY = AxisOptions(rawValue:1 << 2)
		static let flipZ = AxisOptions(rawValue:1 << 3)
		static let negativeY = AxisOptions(rawValue:1 << 4)
		
		init(rawValue:Int) { self.rawValue = rawValue }
		init(axis:Int) { self.rawValue = axis / AxisOptions.axisCount }
		
		static func overAxis(_ axis:Int) -> Int { return (axis / axisCount & 3) * axisCount + axis % axisCount }
		static func downAxis(_ axis:Int) -> Int { return (axis / axisCount & 5) * axisCount + axis % axisCount }
		static func wideAxis(_ axis:Int) -> Int { return 16 * axisCount + axis % axisCount }
	}
	
	static func components(coordinates:Scalar.Vector3, axis:Int) -> Scalar.Vector3 {
		var c:Scalar.Vector3
		var v = coordinates
		let options = AxisOptions(axis:axis)
		
		if options.contains(.flipX) { v.x = 1 - v.x }
		if options.contains(.flipY) { v.y = 1 - v.y }
		if options.contains(.flipZ) { v.z = 1 - v.z }
		
		switch axis % 6 {
		case 0: c = Scalar.vector3(v.z, v.x, v.y)
		case 1: c = Scalar.vector3(v.x, v.z, v.y)
		case 2: c = Scalar.vector3(v.x, v.y, v.z)
		case 3: c = Scalar.vector3(v.z, v.y, v.x)
		case 4: c = Scalar.vector3(v.y, v.z, v.x)
		case _: c = Scalar.vector3(v.y, v.x, v.z)
		}
		
		if options.contains(.negativeY) { c.y = c.y * 2 - 1 }
		
		return c
	}
	
	static func coordinates(components:Scalar.Vector3, axis:Int) -> Scalar.Vector3 {
		var v:Scalar.Vector3
		var c = components
		let options = AxisOptions(axis:axis)
		
		if options.contains(.negativeY) { c.y = c.y * 0.5 + 0.5 }
		
		switch axis % 6 {
		case 0: v = Scalar.vector3(c.y, c.z, c.x)
		case 1: v = Scalar.vector3(c.x, c.z, c.y)
		case 2: v = Scalar.vector3(c.x, c.y, c.z)
		case 3: v = Scalar.vector3(c.z, c.y, c.x)
		case 4: v = Scalar.vector3(c.z, c.x, c.y)
		case _: v = Scalar.vector3(c.y, c.x, c.z)
		}
		
		if options.contains(.flipX) { v.x = 1 - v.x }
		if options.contains(.flipY) { v.y = 1 - v.y }
		if options.contains(.flipZ) { v.z = 1 - v.z }
		
		return v
	}
	
	static func colorRGB(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1.0) -> CHCLT.Color {
		let rgb = components(coordinates:coordinates, axis:axis)
		
		return CHCLT.Color(chclt, display:Scalar.vector4(rgb, alpha))
	}
	
	static func colorHSB(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1.0) -> CHCLT.Color {
		let hsb = components(coordinates:coordinates, axis:axis)
		let rgb = ColorModel.rgb_from_hsb(h:hsb.x, s:hsb.y, b:hsb.z)
		
		return CHCLT.Color(chclt, display:Scalar.vector4(rgb, alpha))
	}
	
	static func colorCHCLT(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1.0) -> CHCLT.Color {
		let hcl = components(coordinates:coordinates, axis:axis)
		let rgb = CHCLT.LinearRGB(chclt, hue:hcl.x, chroma:hcl.y, luma:hcl.z).vector
		
		return CHCLT.Color(chclt, linear:rgb, alpha:alpha)
	}
	
	static func colorCIEXYZ(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1.0) -> CHCLT.Color {
		let ciexyz = components(coordinates:coordinates, axis:axis)
		let rgb = chclt.linearRGB(ciexyz:ciexyz)
		
		return CHCLT.Color(chclt, linear:rgb, alpha:alpha)
	}
	
	static func colorLCHAB(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1.0) -> CHCLT.Color {
		let lchab = components(coordinates:coordinates, axis:axis)
		let rgb = chclt.linearRGB(lchab:lchab)
		
		return CHCLT.Color(chclt, linear:rgb, alpha:alpha)
	}
	
	static func colorLCHOK(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1.0) -> CHCLT.Color {
		let lchok = components(coordinates:coordinates, axis:axis)
		let rgb = chclt.linearRGB(lchok:lchok)
		
		return CHCLT.Color(chclt, linear:rgb, alpha:alpha)
	}
	
	static func linearRGB(axis:Int, coordinates:Scalar.Vector3) -> CHCLT.LinearRGB {
		return CHCLT.LinearRGB(components(coordinates:coordinates, axis:axis))
	}
	
	static func platformRGB(axis:Int, coordinates:Scalar.Vector3, alpha:CGFloat = 1.0) -> PlatformColor {
		let rgb = components(coordinates:coordinates, axis:axis)
		
		return PlatformColor(red:CGFloat(rgb.x), green:CGFloat(rgb.y), blue:CGFloat(rgb.z), alpha:alpha)
	}
	
	static func linearHSB(axis:Int, coordinates:Scalar.Vector3) -> CHCLT.LinearRGB {
		let hsb = components(coordinates:coordinates, axis:axis)
		
		return CHCLT.LinearRGB(ColorModel.rgb_from_hsb(h:hsb.x, s:hsb.y, b:hsb.z))
	}
	
	static func platformHSB(axis:Int, coordinates:Scalar.Vector3, alpha:CGFloat = 1.0) -> PlatformColor {
		let hsb = components(coordinates:coordinates, axis:axis)
		
		return PlatformColor(hue:CGFloat(modf(hsb.y < 0 ? hsb.x + 0.5 : hsb.x).1), saturation:CGFloat(hsb.y.magnitude), brightness:CGFloat(hsb.z), alpha:alpha)
	}
	
	static func linearCHCLT(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT) -> CHCLT.LinearRGB {
		let hcl = components(coordinates:coordinates, axis:axis)
		
		return CHCLT.LinearRGB(chclt, hue:hcl.x, chroma:hcl.y, luma:hcl.z)
	}
	
	static func platformCHCLT(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:CGFloat = 1.0) -> PlatformColor {
		return colorCHCLT(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha.native).platformColor
	}
	
	func color(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:Scalar = 1) -> CHCLT.Color {
		switch self {
		case .rgb: return ColorModel.colorRGB(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		case .hsb: return ColorModel.colorHSB(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		//case .xyz: return ColorModel.colorCIEXYZ(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		//case .lchab: return ColorModel.colorLCHAB(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		//case .lchok: return ColorModel.colorLCHOK(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		case .chclt: return ColorModel.colorCHCLT(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		}
	}
	
	func linearColor(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT) -> CHCLT.LinearRGB {
		switch self {
		case .rgb: return ColorModel.linearRGB(axis:axis, coordinates:coordinates)
		case .hsb: return ColorModel.linearHSB(axis:axis, coordinates:coordinates)
		//case .xyz: return ColorModel.colorCIEXYZ(axis:axis, coordinates:coordinates, chclt:chclt).linearRGB
		//case .lchab: return ColorModel.colorLCHAB(axis:axis, coordinates:coordinates, chclt:chclt).linearRGB
		//case .lchok: return ColorModel.colorLCHOK(axis:axis, coordinates:coordinates, chclt:chclt).linearRGB
		case .chclt: return ColorModel.linearCHCLT(axis:axis, coordinates:coordinates, chclt:chclt)
		}
	}
	
	func platformColor(axis:Int, coordinates:Scalar.Vector3, chclt:CHCLT, alpha:CGFloat = 1.0) -> PlatformColor {
		switch self {
		case .rgb: return ColorModel.platformRGB(axis:axis, coordinates:coordinates, alpha:alpha)
		case .hsb: return ColorModel.platformHSB(axis:axis, coordinates:coordinates, alpha:alpha)
		//case .xyz: return ColorModel.colorCIEXYZ(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha.native).platformColor
		//case .lchab: return ColorModel.colorLCHAB(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha.native).platformColor
		//case .lchok: return ColorModel.colorLCHOK(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha.native).platformColor
		case .chclt: return ColorModel.platformCHCLT(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		}
	}
	
	func coordinates(axis:Int, color:CHCLT.Color) -> Scalar.Vector3 {
		switch self {
		case .rgb: return ColorModel.coordinates(components:color.display.xyz, axis:axis)
		case .hsb: return ColorModel.coordinates(components:color.hsb, axis:axis)
		//case .xyz: return ColorModel.coordinates(components:color.chclt.ciexyz(linearRGB:color.linear.xyz), axis:axis)
		//case .lchab: return ColorModel.coordinates(components:color.lchab, axis:axis)
		//case .lchok: return ColorModel.coordinates(components:color.lchok, axis:axis)
		case .chclt: return ColorModel.coordinates(components:color.hcl, axis:axis)
		}
	}
	
	func coordinates(axis:Int, color:CHCLT.LinearRGB, chclt:CHCLT) -> Scalar.Vector3 {
		switch self {
		case .rgb: return ColorModel.coordinates(components:color.display(chclt).xyz, axis:axis)
		case .hsb: return ColorModel.coordinates(components:CHCLT.Color(chclt, color).hsb, axis:axis)
		//case .xyz: return ColorModel.coordinates(components:chclt.ciexyz(linearRGB:color.vector), axis:axis)
		//case .lchab: return ColorModel.coordinates(components:chclt.lchab(linearRGB:color.vector), axis:axis)
		//case .lchok: return ColorModel.coordinates(components:chclt.lchok(linearRGB:color.vector), axis:axis)
		case .chclt: return ColorModel.coordinates(components:chclt.hcl(linear:color.vector), axis:axis)
		}
	}

	func coordinates(axis:Int, color:PlatformColor, chclt:CHCLT) -> Scalar.Vector3? {
		guard let color = color.chocolateColor(chclt:chclt) else { return nil }
		
		return coordinates(axis:axis, color:color)
	}
	
	func linearColors(axis:Int, chclt:CHCLT, hue:Scalar, count:Int) -> [CHCLT.LinearRGB] {
		let count = count > 1 ? count : 12
		var result:[CHCLT.LinearRGB]
		let options = AxisOptions(axis:axis)
		
		switch (self, axis % 3) {
		case (.rgb, 0):
			result = [.black, .red]
		case (.rgb, 1):
			result = [.black, .green]
		case (.rgb, _):
			result = [.black, .blue]
		case (.hsb, 0):
			result = (0 ..< count).map { CHCLT.LinearRGB(chclt.linear(ColorModel.rgb_from_hsb(h:Double($0) / Double(count - 1), s:1, b:1))) }
		case (.hsb, 1):
			result = [.white, CHCLT.LinearRGB(chclt.linear(ColorModel.rgb_from_hsb(h:hue, s:1, b:1)))]
			if options.contains(.negativeY) { result.insert(CHCLT.LinearRGB(chclt.linear(ColorModel.rgb_from_hsb(h:hue + 0.5, s:1, b:1))), at:0) }
		case (.hsb, _):
			result = [.black, CHCLT.LinearRGB(chclt.linear(ColorModel.rgb_from_hsb(h:hue, s:1, b:1)))]
		case (.chclt, 0):
			result = chclt.hueRange(start:0, shift:1 / Scalar(count - 1), count:count).map { CHCLT.LinearRGB($0) }
		case (.chclt, 1):
			let color = CHCLT.LinearRGB(chclt, hue:hue)
			result = chclt.chromaRamp(color.vector, luminance:color.luminance(chclt), intermediaries:0, withNegative:options.contains(.negativeY)).reversed().map { CHCLT.LinearRGB($0) }
		case (.chclt, _):
			result = [.black, .white]
		}
		
		if options.contains(.flipZ) { result.reverse() }
		
		return result
	}
	
	func platformColors(axis:Int, chclt:CHCLT, hue:Scalar, count:Int) -> [PlatformColor] {
		let count = count > 1 ? count : 12
		var result:[PlatformColor]
		let options = AxisOptions(axis:axis)
		
		switch (self, axis % 3) {
		case (.rgb, 0):
			result = [.black, .red]
		case (.rgb, 1):
			result = [.black, .green]
		case (.rgb, _):
			result = [.black, .blue]
		case (.hsb, 0):
			result = (0 ..< count).map { ColorModel.platformHSB(axis:0, coordinates:Scalar.vector3(1, 1, Double($0) / Double(count - 1))) }
		case (.hsb, 1):
			result = [.white, ColorModel.platformHSB(axis:1, coordinates:Scalar.vector3(hue, 1, 1))]
			if options.contains(.negativeY) { result.insert(ColorModel.platformHSB(axis:AxisOptions.wideAxis(1), coordinates:Scalar.vector3(hue, 1, 0)), at:0) }
		case (.hsb, _):
			result = [.black, ColorModel.platformHSB(axis:2, coordinates:Scalar.vector3(hue, 1, 1))]
		case (.chclt, 0):
			result = chclt.hueRange(start:0, shift:1 / Scalar(count - 1), count:count).map { CHCLT.LinearRGB($0).color().platformColor }
		case (.chclt, 1):
			let color = CHCLT.LinearRGB(chclt, hue:hue)
			result = chclt.chromaRamp(color.vector, luminance:color.luminance(chclt), intermediaries:0, withNegative:options.contains(.negativeY)).reversed().map { CHCLT.LinearRGB($0).color().platformColor }
		case (.chclt, _):
			result = [.black, .white]
		}
		
		if options.contains(.flipZ) { result.reverse() }
		
		return result
	}
	
	static func lumaGradient(chclt:CHCLT, primary:CHCLT.LinearRGB, chroma:Scalar, colorSpace:CGColorSpace?, darkToLight:Bool = false) -> CGGradient? {
		let fractionsAbove = [0.125, 0.75, 0.875, 0.9375]
		let fractionsBelow = [0.9375, 0.875, 0.125]
		let color = primary.applyChroma(chclt, value:chroma)
		let value = color.luma(chclt)
		let colorsAbove:[CHCLT.LinearRGB] = fractionsAbove.map { color.applyLuma(chclt, value:1.0 - $0 * (1.0 - value)) }
		let colorsBelow:[CHCLT.LinearRGB] = fractionsBelow.map { color.applyLuma(chclt, value:$0 * value) }
		let v = CGFloat(value)
		let locationsAbove:[CGFloat] = fractionsAbove.map { CGFloat($0) * (1.0 - v) }
		let locationsBelow:[CGFloat] = fractionsBelow.map { 1.0 - CGFloat($0) * v }
		var colorsOrder:[CHCLT.LinearRGB] = colorsAbove + colorsBelow
		var locations:[CGFloat] = locationsAbove + locationsBelow
		
		locations.insert(1.0 - v, at:fractionsAbove.count)
		colorsOrder.insert(color, at:fractionsAbove.count)
		
		locations.insert(0.0, at:0)
		colorsOrder.insert(.white, at:0)
		
		locations.append(1.0)
		colorsOrder.append(.black)
		
#if os(macOS)
		var colors:[CGColor] = colorsOrder.map { $0.color() }
#else
		var colors:[CGColor] = colorsOrder.map { CHCLT.Color(chclt, $0).color() }
#endif
		
		if darkToLight {
			colors.reverse()
			locations.reverse()
			locations = locations.map { 1.0 - $0 }
		}
		
		return CGGradient(colorsSpace:colorSpace, colors:colors as CFArray, locations:locations)
	}
	
	static func luminanceGradient(chclt:CHCLT, primary:CHCLT.LinearRGB, chroma:Scalar, colorSpace:CGColorSpace?, darkToLight:Bool = false) -> CGGradient? {
		let color = primary.applyChroma(chclt, value:chroma)
		let value = color.luminance(chclt)
		let locations:[CGFloat] = [0, CGFloat(darkToLight ? value : 1 - value), 1]
		var colors:[CGColor] = [.white, color, .black].map { $0.color() }
		
		if darkToLight { colors.reverse() }
		
		return CGGradient(colorsSpace:colorSpace, colors:colors as CFArray, locations:locations)
	}
	
	static func chromaGradient(chclt:CHCLT, primary:CHCLT.LinearRGB, colorSpace:CGColorSpace?, intermediaries:Int = 1, reverse:Bool, withNegative:Bool) -> CGGradient? {
		var colors = chclt.chromaRamp(primary.vector, luminance:chclt.luminance(primary.vector), intermediaries:intermediaries, withNegative:withNegative)
		
		if reverse { colors.reverse() }
		
		return CGGradient(colorsSpace:colorSpace, colors:colors.map { CHCLT.Color(chclt, linear:$0).color() } as CFArray, locations:nil)
	}
	
	static func rgb_from_hsb(h:Scalar, s:Scalar, b:Scalar) -> Scalar.Vector3 {
		let hue = s < 0 ? h + 0.5 : h
		let saturation = s.magnitude
		
		guard b > 0 && saturation > 0 else { return Scalar.vector3(b, b, b) }
		
		let hue1:Scalar.Vector3 = Scalar.vector3(hue, hue - 1.0/3.0, hue - 2.0/3.0)
		let hue2:Scalar.Vector3 = hue1 - hue1.rounded(.down) - 0.5
		let hue3:Scalar.Vector3 = simd_abs(hue2) * 6.0 - 1.0
		let hue4:Scalar.Vector3 = simd_clamp(hue3, Scalar.Vector3.zero, Scalar.Vector3.one)
		let c:Scalar = saturation * b
		let m:Scalar = b - c
		
		return hue4 * c + m
	}
	
	static func hsb_from_rgb(r:Scalar, g:Scalar, b:Scalar) -> Scalar.Vector3 {
		let domain, maximum, mid_minus_min, max_minus_min:Scalar
		
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
		
		guard max_minus_min > 0 else { return Scalar.vector3(1, 0, 0) }
		
		let hue6 = domain + mid_minus_min / max_minus_min
		let hue = hue6 / 6
		
		return Scalar.vector3(hue < 0 ? 1 + hue : hue, max_minus_min / maximum, maximum)
	}
	
	static func hsb_from_hsl(h:Scalar, s:Scalar, l:Scalar) -> Scalar.Vector3 {
		guard l > 0 else { return Scalar.vector3(h, 0, 0) }
		
		let d = l > 0.5 ? 1.0 - l : l
		let m = s * d
		let b = l + m
		
		return Scalar.vector3(h, m * 2.0 / b, b)
	}
	
	static func hsl_from_hsb(h:Scalar, s:Scalar, b:Scalar) -> Scalar.Vector3 {
		guard b > 0 else { return Scalar.vector3(h, 0, 0) }
		
		let l = b - b * s * 0.5
		let d = l > 0.5 ? 1.0 - l : l
		
		return Scalar.vector3(h, s * b * 0.5 / d, l)
	}
}

//	MARK: -

extension CGContext {
	func drawPlaneFromCubeRGB(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT?, drawSpace:CGColorSpace?) {
		let overColors:[CGColor]
		let downColors:[CGColor]
		let mode:CGBlendMode
		let overAxis = ColorModel.AxisOptions.overAxis(axis)
		let downAxis = ColorModel.AxisOptions.downAxis(axis)
		let overCoordinates = [CHCLT.Scalar.vector3(0, 0, scalar), CHCLT.Scalar.vector3(1, 0, scalar)]
		let downCoordinates = [CHCLT.Scalar.vector3(0, 1, scalar), CHCLT.Scalar.vector3(0, 0, scalar)]
		
		if let chclt = chclt {
			overColors = overCoordinates.map { ColorModel.colorRGB(axis:overAxis, coordinates:$0, chclt:chclt).color() }
			downColors = downCoordinates.map { ColorModel.colorRGB(axis:downAxis, coordinates:$0, chclt:chclt).color() }
		} else {
			overColors = overCoordinates.map { ColorModel.platformRGB(axis:overAxis, coordinates:$0).cgColor }
			downColors = downCoordinates.map { ColorModel.platformRGB(axis:downAxis, coordinates:$0).cgColor }
		}
		mode = .lighten
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let drawSpace = drawSpace ?? overColors.first?.colorSpace
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:overColors as CFArray, locations:nil) {
			setBlendMode(.copy)
			drawLinearGradient(gradient, start:start, end:overEnd, options:drawingOptions)
		}
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:downColors as CFArray, locations:nil) {
			setBlendMode(mode)
			drawLinearGradient(gradient, start:start, end:downEnd, options:drawingOptions)
		}
	}
	
	func drawPlaneFromCubeHSB(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT?, drawSpace:CGColorSpace?) {
		var copyColors:[CGColor]
		var modeColors:[CGColor]
		let mode:CGBlendMode
		let options = ColorModel.AxisOptions(axis:axis)
		let isFlipped = options.contains(.swapXY)
		let count = Int(isFlipped ? box.size.height : box.size.width)
		
		switch axis % 3 {
		case 0:
			if let chclt = chclt {
				copyColors = [
					ColorModel.colorHSB(axis:0, coordinates:CHCLT.Scalar.vector3(0, 1, scalar), chclt:chclt).color(),
					ColorModel.colorHSB(axis:0, coordinates:CHCLT.Scalar.vector3(1, 1, scalar), chclt:chclt).color()
				]
				
				if options.contains(.negativeY) {
					copyColors.insert(ColorModel.colorHSB(axis:48, coordinates:CHCLT.Scalar.vector3(0, 1, scalar), chclt:chclt).color(), at:0)
				}
			} else {
				copyColors = [
					ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(0, 1, scalar)).cgColor,
					ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(1, 1, scalar)).cgColor
				]
				
				if options.contains(.negativeY) {
					copyColors.insert(ColorModel.platformHSB(axis:48, coordinates:CHCLT.Scalar.vector3(0, 1, scalar)).cgColor, at:0)
				}
			}
			
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case 1:
			let scalar = options.contains(.negativeY) ? scalar * 2 - 1 : scalar
			if let chclt = chclt {
				copyColors = (0 ..< count).map { ColorModel.colorHSB(axis:1, coordinates:CHCLT.Scalar.vector3(Double($0) / Double(count - 1), 1, scalar), chclt:chclt).color() }
			} else {
				copyColors = (0 ..< count).map { ColorModel.platformHSB(axis:1, coordinates:CHCLT.Scalar.vector3(Double($0) / Double(count - 1), 1, scalar)).cgColor }
			}
			
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case _:
			if let chclt = chclt {
				copyColors = (0 ..< count).map { ColorModel.colorHSB(axis:2, coordinates:CHCLT.Scalar.vector3(Double($0) / Double(count - 1), 1, scalar), chclt:chclt).color() }
				modeColors = [
					ColorModel.colorHSB(axis:2, coordinates:CHCLT.Scalar.vector3(0, 0, scalar), chclt:chclt, alpha:0).color(),
					ColorModel.colorHSB(axis:2, coordinates:CHCLT.Scalar.vector3(0, 0, scalar), chclt:chclt, alpha:1).color()
				]
			} else {
				copyColors = (0 ..< count).map { ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(Double($0) / Double(count - 1), 1, scalar)).cgColor }
				modeColors = [
					ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(0, 0, scalar), alpha:0).cgColor,
					ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(0, 0, scalar), alpha:1).cgColor
				]
			}
			mode = .normal
		}
		
		if options.flipOver { copyColors.reverse() }
		if options.flipDown { modeColors.reverse() }
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let drawSpace = drawSpace ?? copyColors.first?.colorSpace
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:copyColors as CFArray, locations:nil) {
			setBlendMode(.copy)
			drawLinearGradient(gradient, start:start, end:isFlipped ? downEnd : overEnd, options:drawingOptions)
		}
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:modeColors as CFArray, locations:nil) {
			setBlendMode(mode)
			drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
		}
	}
	
	func drawPlaneFromCubeXYZ(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT, drawSpace:CGColorSpace?) {
		let drawSpace = drawSpace ?? chclt.rgbColorSpace()
		let columns = Int(box.size.width)
		let rows = min(16, Int(box.size.height))
		let start = box.origin
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let size = CGSize(width:1, height:box.size.height)
		let step = CGPoint(x:1, y:0)
		
		for column in 0 ..< columns {
			let x = Double(column) / Double(columns - 1)
			
			let colors:[CGColor] = (0 ..< rows).map { row in
				let y = Double(row) / Double(rows - 1)
				let color = ColorModel.colorCIEXYZ(axis:axis, coordinates:CHCLT.Scalar.vector3(x, 1 - y, scalar), chclt:chclt)
				
				if color.isNormal { return color.color() }
				
				return (color.linear.max() > 1 ? CHCLT.LinearRGB.white : CHCLT.LinearRGB.black).color()
				//return color.normalize().scaleContrast(0.75).color()
				//return color.normalize().color()
				//return color.color()
			}
			
			guard let gradient = CGGradient(colorsSpace:drawSpace, colors:colors as CFArray, locations:nil) else { continue }
			
			let origin = step * CGFloat(column) + box.origin
			let stripe = CGRect(origin:origin, size:size)
			
			clip(to:stripe)
			drawLinearGradient(gradient, start:start, end:downEnd, options:drawingOptions)
			resetClip()
		}
	}
	
	func drawPlaneFromCubeLCH(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT, drawSpace:CGColorSpace?) {
		let drawSpace = drawSpace ?? chclt.rgbColorSpace()
		let columns = Int(box.size.width)
		let rows = min(32, Int(box.size.height))
		let start = box.origin
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let size = CGSize(width:1, height:box.size.height)
		let step = CGPoint(x:1, y:0)
		
		for column in 0 ..< columns {
			let x = Double(column) / Double(columns - 1)
			
			let colors:[CGColor] = (0 ..< rows).map { row in
				let y = Double(row) / Double(rows - 1)
				let coordinates = CHCLT.Scalar.vector3(x, 1 - y, scalar)
				let color = ColorModel.colorLCHAB(axis:axis, coordinates:coordinates, chclt:chclt)
				
				if color.isNormal { return color.color() }
				
				return (color.linear.max() > 1 ? CHCLT.LinearRGB.white : CHCLT.LinearRGB.black).color()
				//return color.normalize().scaleContrast(0.75).color()
				//return color.normalize().color()
				//return color.color()
			}
			
			guard let gradient = CGGradient(colorsSpace:drawSpace, colors:colors as CFArray, locations:nil) else { continue }
			
			let origin = step * CGFloat(column) + box.origin
			let stripe = CGRect(origin:origin, size:size)
			
			clip(to:stripe)
			drawLinearGradient(gradient, start:start, end:downEnd, options:drawingOptions)
			resetClip()
		}
	}
	
	func drawPlaneFromCubeLCHOK(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT, drawSpace:CGColorSpace?) {
		let drawSpace = drawSpace ?? chclt.rgbColorSpace()
		let columns = Int(box.size.width)
		let rows = min(32, Int(box.size.height))
		let start = box.origin
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let size = CGSize(width:1, height:box.size.height)
		let step = CGPoint(x:1, y:0)
		
		for column in 0 ..< columns {
			let x = Double(column) / Double(columns - 1)
			
			let colors:[CGColor] = (0 ..< rows).map { row in
				let y = Double(row) / Double(rows - 1)
				let coordinates = CHCLT.Scalar.vector3(x, 1 - y, scalar)
				let color = ColorModel.colorLCHOK(axis:axis, coordinates:coordinates, chclt:chclt)
				
				if color.isNormal { return color.color() }
				
				return (color.linear.max() > 1 ? CHCLT.LinearRGB.white : CHCLT.LinearRGB.black).color()
				//return color.normalize().scaleContrast(0.75).color()
				//return color.normalize().color()
				//return color.color()
			}
			
			guard let gradient = CGGradient(colorsSpace:drawSpace, colors:colors as CFArray, locations:nil) else { continue }
			
			let origin = step * CGFloat(column) + box.origin
			let stripe = CGRect(origin:origin, size:size)
			
			clip(to:stripe)
			drawLinearGradient(gradient, start:start, end:downEnd, options:drawingOptions)
			resetClip()
		}
	}
	
	func drawPlaneFromCubeCHCLT(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT, drawSpace:CGColorSpace?) {
		let drawSpace = drawSpace ?? chclt.rgbColorSpace()
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let options = ColorModel.AxisOptions(axis:axis)
		let isFlipped = options.contains(.swapXY)
		let wideChroma = options.contains(.negativeY)
		let count = Int(isFlipped ? box.size.height : box.size.width)
		let size = isFlipped ? CGSize(width:box.size.width, height:1) : CGSize(width:1, height:box.size.height)
		let step = isFlipped ? CGPoint(x:0, y:1) : CGPoint(x:1, y:0)
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		switch axis % 3 {
		case 0:	//	scalar is hue
			let primary = CHCLT.LinearRGB(chclt, hue:scalar)
			let inverse = primary.applyChroma(chclt, value:-1).saturated()
			let flipChroma = options.flipOver
			let flipLuma = options.flipDown
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				var chroma = CHCLT.Scalar(index) / CHCLT.Scalar(count - 1)
				
				if flipChroma { chroma = 1 - chroma }
				if wideChroma { chroma = chroma * 2 - 1 }
				
				guard let gradient = ColorModel.lumaGradient(
					chclt:chclt,
					primary:chroma < 0 ? inverse : primary,
					chroma:chroma.magnitude,
					colorSpace:drawSpace,
					darkToLight:flipLuma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		case 1:	//	scalar is chroma
			let hues = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = options.flipOver
			let flipLuma = options.flipDown
			let scalar = wideChroma ? scalar * 2 - 1 : scalar
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index])
				
				guard let gradient = ColorModel.lumaGradient(
					chclt:chclt,
					primary:scalar < 0 ? primary.applyChroma(chclt, value:-1).saturated() : primary,
					chroma:scalar.magnitude,
					colorSpace:drawSpace,
					darkToLight:flipLuma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		case _:	//	scalar is luma
			let hues = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = options.flipOver
			let flipChroma = options.flipDown
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index]).applyLuma(chclt, value:scalar)
				
				guard let gradient = ColorModel.chromaGradient(
					chclt:chclt,
					primary:primary,
					colorSpace:drawSpace,
					intermediaries:3,
					reverse:flipChroma,
					withNegative:wideChroma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		}
	}
	
	func drawPlaneFromCubeLinearCHCLT(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chclt:CHCLT, drawSpace:CGColorSpace?) {
		let drawSpace = drawSpace ?? chclt.rgbColorSpace() ?? CHCLT.LinearRGB.colorSpace
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let options = ColorModel.AxisOptions(axis:axis)
		let isFlipped = options.contains(.swapXY)
		let wideChroma = options.contains(.negativeY)
		let count = Int(isFlipped ? box.size.height : box.size.width)
		let size = isFlipped ? CGSize(width:box.size.width, height:1) : CGSize(width:1, height:box.size.height)
		let step = isFlipped ? CGPoint(x:0, y:1) : CGPoint(x:1, y:0)
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		switch axis % 3 {
		case 0:	//	scalar is hue
			let primary = CHCLT.LinearRGB(chclt, hue:scalar)
			let inverse = primary.applyChroma(chclt, value:-1).saturated()
			let flipChroma = options.flipOver
			let flipLuma = options.flipDown
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				var chroma = CHCLT.Scalar(index) / CHCLT.Scalar(count - 1)
				
				if flipChroma { chroma = 1 - chroma }
				if wideChroma { chroma = chroma * 2 - 1 }
				
				guard let gradient = ColorModel.luminanceGradient(
					chclt:chclt,
					primary:chroma < 0 ? inverse : primary,
					chroma:chroma.magnitude,
					colorSpace:drawSpace,
					darkToLight:flipLuma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		case 1:	//	scalar is chroma
			let hues = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = options.flipOver
			let flipLuma = options.flipDown
			let scalar = wideChroma ? scalar * 2 - 1 : scalar
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index])
				
				guard let gradient = ColorModel.luminanceGradient(
					chclt:chclt,
					primary:scalar < 0 ? primary.applyChroma(chclt, value:-1).saturated() : primary,
					chroma:scalar.magnitude,
					colorSpace:drawSpace,
					darkToLight:flipLuma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		case _:	//	scalar is luminance
			let hues = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = options.flipOver
			let flipChroma = options.flipDown
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index]).applyLuminance(chclt, value:scalar)
				
				guard let gradient = ColorModel.chromaGradient(
					chclt:chclt,
					primary:primary,
					colorSpace:drawSpace,
					intermediaries:3,
					reverse:flipChroma,
					withNegative:wideChroma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		}
	}
}
