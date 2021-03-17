//
//	ColorModel.swift
//	Chocolate
//
//	Created by Eric Cole on 3/11/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation

enum ColorModel: Int {
	case chclt, rgb, hsb
	
	static let count = 3
	
	struct AxisOptions: OptionSet {
		let rawValue:Int
		
		var flipOver:Bool { return rawValue & 1 != 0 ? ~rawValue & 4 != 0 : rawValue & 2 != 0 }
		var flipDown:Bool { return rawValue & 1 != 0 ? ~rawValue & 2 != 0 : rawValue & 4 != 0 }
		
		static let models = 3
		static let swapXY = AxisOptions(rawValue:1 << 0)
		static let flipX = AxisOptions(rawValue:1 << 1)
		static let flipY = AxisOptions(rawValue:1 << 2)
		static let flipZ = AxisOptions(rawValue:1 << 3)
		static let negativeY = AxisOptions(rawValue:1 << 4)
		
		init(rawValue:Int) { self.rawValue = rawValue }
		init(axis:Int) { self.rawValue = axis / ColorModel.count }
		
		static func overAxis(_ axis:Int) -> Int { return (axis / ColorModel.count & 3) * ColorModel.count + axis % ColorModel.count }
		static func downAxis(_ axis:Int) -> Int { return (axis / ColorModel.count & 5) * ColorModel.count + axis % ColorModel.count }
	}
	
	static func components(coordinates:CHCLT.Scalar.Vector3, axis:Int) -> CHCLT.Scalar.Vector3 {
		var c:CHCLT.Scalar.Vector3
		var v = coordinates
		let options = AxisOptions(axis:axis)
		
		if options.contains(.flipX) { v.x = 1 - v.x }
		if options.contains(.flipY) { v.y = 1 - v.y }
		if options.contains(.flipZ) { v.z = 1 - v.z }
		
		switch axis % 6 {
		case 0: c = CHCLT.Scalar.vector3(v.z, v.x, v.y)
		case 1: c = CHCLT.Scalar.vector3(v.x, v.z, v.y)
		case 2: c = CHCLT.Scalar.vector3(v.x, v.y, v.z)
		case 3: c = CHCLT.Scalar.vector3(v.z, v.y, v.x)
		case 4: c = CHCLT.Scalar.vector3(v.y, v.z, v.x)
		case _: c = CHCLT.Scalar.vector3(v.y, v.x, v.z)
		}
		
		if options.contains(.negativeY) { c.y = c.y * 2 - 1 }
		
		return c
	}
	
	static func coordinates(components:CHCLT.Scalar.Vector3, axis:Int) -> CHCLT.Scalar.Vector3 {
		var v:CHCLT.Scalar.Vector3
		var c = components
		let options = AxisOptions(axis:axis)
		
		if options.contains(.negativeY) { c.y = c.y * 0.5 + 0.5 }
		
		switch axis % 6 {
		case 0: v = CHCLT.Scalar.vector3(c.y, c.z, c.x)
		case 1: v = CHCLT.Scalar.vector3(c.x, c.z, c.y)
		case 2: v = CHCLT.Scalar.vector3(c.x, c.y, c.z)
		case 3: v = CHCLT.Scalar.vector3(c.z, c.y, c.x)
		case 4: v = CHCLT.Scalar.vector3(c.z, c.x, c.y)
		case _: v = CHCLT.Scalar.vector3(c.y, c.x, c.z)
		}
		
		if options.contains(.flipX) { v.x = 1 - v.x }
		if options.contains(.flipY) { v.y = 1 - v.y }
		if options.contains(.flipZ) { v.z = 1 - v.z }
		
		return v
	}
	
	static func linearRGB(axis:Int, coordinates:CHCLT.Scalar.Vector3) -> CHCLT.LinearRGB {
		return CHCLT.LinearRGB(components(coordinates:coordinates, axis:axis))
	}
	
	static func platformRGB(axis:Int, coordinates:CHCLT.Scalar.Vector3, alpha:CGFloat = 1.0) -> PlatformColor {
		let rgb = components(coordinates:coordinates, axis:axis)
		
		return PlatformColor(red:CGFloat(rgb.x), green:CGFloat(rgb.y), blue:CGFloat(rgb.z), alpha:alpha)
	}
	
	static func linearHSB(axis:Int, coordinates:CHCLT.Scalar.Vector3) -> CHCLT.LinearRGB {
		let hsb = components(coordinates:coordinates, axis:axis)
		
		return CHCLT.LinearRGB(DisplayRGB.hexagonal(hue:hsb.x, saturation:hsb.y, brightness:hsb.z))
	}
	
	static func platformHSB(axis:Int, coordinates:CHCLT.Scalar.Vector3, alpha:CGFloat = 1.0) -> PlatformColor {
		let hsb = components(coordinates:coordinates, axis:axis)
		
		return PlatformColor(hue:CGFloat(modf(hsb.y < 0 ? hsb.x + 0.5 : hsb.x).1), saturation:CGFloat(hsb.y.magnitude), brightness:CGFloat(hsb.z), alpha:alpha)
	}
	
	static func linearCHCLT(axis:Int, coordinates:CHCLT.Scalar.Vector3, chclt:CHCLT) -> CHCLT.LinearRGB {
		let hcl = components(coordinates:coordinates, axis:axis)
		
		return CHCLT.LinearRGB(chclt, hue:hcl.x, chroma:hcl.y, luminance:hcl.z)
	}
	
	static func platformCHCLT(axis:Int, coordinates:CHCLT.Scalar.Vector3, chclt:CHCLT, alpha:CGFloat = 1.0) -> PlatformColor {
		let hcl = components(coordinates:coordinates, axis:axis)
		
		return CHCLT.LinearRGB(chclt, hue:hcl.x, chroma:hcl.y, luminance:hcl.z).display(chclt, alpha:alpha.native).color().platformColor
	}
	
	func linearColor(axis:Int, coordinates:CHCLT.Scalar.Vector3, chclt:CHCLT) -> CHCLT.LinearRGB {
		switch self {
		case .rgb: return ColorModel.linearRGB(axis:axis, coordinates:coordinates)
		case .hsb: return ColorModel.linearHSB(axis:axis, coordinates:coordinates)
		case .chclt: return ColorModel.linearCHCLT(axis:axis, coordinates:coordinates, chclt:chclt)
		}
	}
	
	func displayColor(axis:Int, coordinates:CHCLT.Scalar.Vector3, chclt:CHCLT, alpha:CHCLT.Scalar = 1) -> DisplayRGB {
		switch self {
		case .rgb: return DisplayRGB(CHCLT.Scalar.vector4(ColorModel.linearRGB(axis:axis, coordinates:coordinates).vector, alpha))
		case .hsb: return DisplayRGB(CHCLT.Scalar.vector4(ColorModel.linearHSB(axis:axis, coordinates:coordinates).vector, alpha))
		case .chclt: return ColorModel.linearCHCLT(axis:axis, coordinates:coordinates, chclt:chclt).display(chclt, alpha:alpha)
		}
	}
	
	func platformColor(axis:Int, coordinates:CHCLT.Scalar.Vector3, chclt:CHCLT, alpha:CGFloat = 1.0) -> PlatformColor {
		switch self {
		case .rgb: return ColorModel.platformRGB(axis:axis, coordinates:coordinates, alpha:alpha)
		case .hsb: return ColorModel.platformHSB(axis:axis, coordinates:coordinates, alpha:alpha)
		case .chclt: return ColorModel.platformCHCLT(axis:axis, coordinates:coordinates, chclt:chclt, alpha:alpha)
		}
	}
	
	func coordinates(axis:Int, color:CHCLT.LinearRGB, chclt:CHCLT) -> CHCLT.Scalar.Vector3 {
		switch self {
		case .rgb: return ColorModel.coordinates(components:color.display(chclt).vector.xyz, axis:axis)
		case .hsb: return ColorModel.coordinates(components:color.display(chclt).hsb().xyz, axis:axis)
		case .chclt: return ColorModel.coordinates(components:chclt.hcl(color.vector), axis:axis)
		}
	}
	
	func coordinates(axis:Int, color:DisplayRGB, chclt:CHCLT) -> CHCLT.Scalar.Vector3 {
		switch self {
		case .rgb: return ColorModel.coordinates(components:color.vector.xyz, axis:axis)
		case .hsb: return ColorModel.coordinates(components:color.hsb().xyz, axis:axis)
		case .chclt: return ColorModel.coordinates(components:chclt.hcl(color.linear(chclt).vector), axis:axis)
		}
	}
	
	func coordinates(axis:Int, color:PlatformColor, chclt:CHCLT) -> CHCLT.Scalar.Vector3? {
		guard let display = color.displayRGB else { return nil }
		
		return coordinates(axis:axis, color:display, chclt:chclt)
	}
	
	func linearColors(axis:Int, chclt:CHCLT, hue:CHCLT.Scalar, count:Int) -> [CHCLT.LinearRGB] {
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
			result = (0 ..< count).map { CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:Double($0) / Double(count - 1), saturation:1, brightness:1))) }
		case (.hsb, 1):
			result = [.white, CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:hue, saturation:1, brightness:1)))]
			if options.contains(.negativeY) { result.insert(CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:hue + 0.5, saturation:1, brightness:1))), at:0) }
		case (.hsb, _):
			result = [.black, CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:hue, saturation:1, brightness:1)))]
		case (.chclt, 0):
			result = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count - 1), count:count).map { CHCLT.LinearRGB($0) }
		case (.chclt, 1):
			let color = CHCLT.LinearRGB(chclt, hue:hue)
			result = chclt.chromaRamp(color.vector, luminance:color.luminance(chclt), intermediaries:0, withNegative:options.contains(.negativeY)).reversed().map { CHCLT.LinearRGB($0) }
		case (.chclt, _):
			result = [.black, .white]
		}
		
		if options.contains(.flipZ) { result.reverse() }
		
		return result
	}
	
	func platformColors(axis:Int, chclt:CHCLT, hue:CHCLT.Scalar, count:Int) -> [PlatformColor] {
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
			result = (0 ..< count).map { ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(1, 1, Double($0) / Double(count - 1))) }
		case (.hsb, 1):
			result = [.white, ColorModel.platformHSB(axis:1, coordinates:CHCLT.Scalar.vector3(hue, 1, 1))]
			// TODO: remove 49
			if options.contains(.negativeY) { result.insert(ColorModel.platformHSB(axis:49, coordinates:CHCLT.Scalar.vector3(hue, 1, 0)), at:0) }
		case (.hsb, _):
			result = [.black, ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(hue, 1, 1))]
		case (.chclt, 0):
			result = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count - 1), count:count).map { CHCLT.LinearRGB($0).color().platformColor }
		case (.chclt, 1):
			let color = CHCLT.LinearRGB(chclt, hue:hue)
			result = chclt.chromaRamp(color.vector, luminance:color.luminance(chclt), intermediaries:0, withNegative:options.contains(.negativeY)).reversed().map { CHCLT.LinearRGB($0).color().platformColor }
		case (.chclt, _):
			result = [.black, .white]
		}
		
		if options.contains(.flipZ) { result.reverse() }
		
		return result
	}
	
	static func luminanceGradient(chclt:CHCLT, primary:CHCLT.LinearRGB, chroma:CHCLT.Scalar, colorSpace:CGColorSpace?, darkToLight:Bool = false) -> CGGradient? {
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
		
		return CGGradient(colorsSpace:colorSpace, colors:colors.map { CHCLT.LinearRGB($0).color() } as CFArray, locations:nil)
	}
	
	static func hsb_from_rgb(r:CHCLT.Scalar, g:CHCLT.Scalar, b:CHCLT.Scalar) -> (hue:CHCLT.Scalar, saturation:CHCLT.Scalar, brightness:CHCLT.Scalar) {
		let domain, maximum, mid_minus_min, max_minus_min:CHCLT.Scalar
		
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
		
		return (hue < 0 ? 1 + hue : hue, max_minus_min / maximum, maximum)
	}
	
	static func hsb_from_hsl(h:CHCLT.Scalar, s:CHCLT.Scalar, l:CHCLT.Scalar) -> (hue:CHCLT.Scalar, saturation:CHCLT.Scalar, brightness:CHCLT.Scalar) {
		guard l > 0 else { return (h, 0, 0) }
		
		let d = l > 0.5 ? 1.0 - l : l
		let m = s * d
		let b = l + m
		
		return (h, m * 2.0 / b, b)
	}
	
	static func hsl_from_hsb(h:CHCLT.Scalar, s:CHCLT.Scalar, b:CHCLT.Scalar) -> (hue:CHCLT.Scalar, saturation:CHCLT.Scalar, lightness:CHCLT.Scalar) {
		guard b > 0 else { return (h, 0, 0) }
		
		let l = b - b * s * 0.5
		let d = l > 0.5 ? 1.0 - l : l
		
		return (h, s * b * 0.5 / d, l)
	}
}

//	MARK: -

extension CGContext {
	func drawPlaneFromCubeRGB(axis:Int, scalar:CGFloat.NativeType, box:CGRect) {
		let drawSpace = colorSpace
		let overColors:[CGColor]
		let downColors:[CGColor]
		let mode:CGBlendMode
		let overAxis = ColorModel.AxisOptions.overAxis(axis)
		let downAxis = ColorModel.AxisOptions.downAxis(axis)
		
		overColors = [
			ColorModel.platformRGB(axis:overAxis, coordinates:CHCLT.Scalar.vector3(0, 0, scalar)).cgColor,
			ColorModel.platformRGB(axis:overAxis, coordinates:CHCLT.Scalar.vector3(1, 0, scalar)).cgColor
		]
		downColors = [
			ColorModel.platformRGB(axis:downAxis, coordinates:CHCLT.Scalar.vector3(0, 1, scalar)).cgColor,
			ColorModel.platformRGB(axis:downAxis, coordinates:CHCLT.Scalar.vector3(0, 0, scalar)).cgColor
		]
		mode = .lighten
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		
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
	
	func drawPlaneFromCubeHSB(axis:Int, scalar:CGFloat.NativeType, box:CGRect) {
		let drawSpace = colorSpace
		var copyColors:[CGColor]
		var modeColors:[CGColor]
		let mode:CGBlendMode
		let options = ColorModel.AxisOptions(axis:axis)
		let isFlipped = options.contains(.swapXY)
		let count = Int(isFlipped ? box.size.height : box.size.width)
		
		switch axis % 3 {
		case 0:
			copyColors = [
				ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(0, 1, scalar)).cgColor,
				ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(1, 1, scalar)).cgColor
			]
			
			if options.contains(.negativeY) {
				copyColors.insert(ColorModel.platformHSB(axis:48, coordinates:CHCLT.Scalar.vector3(0, 1, scalar)).cgColor, at:0)
			}
			
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case 1:
			let scalar = options.contains(.negativeY) ? scalar * 2 - 1 : scalar
			copyColors = (0 ..< count).map { ColorModel.platformHSB(axis:1, coordinates:CHCLT.Scalar.vector3(Double($0) / Double(count - 1), 1, scalar)).cgColor }
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case _:
			copyColors = (0 ..< count).map { ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(Double($0) / Double(count - 1), 1, scalar)).cgColor }
			modeColors = [
				ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(0, 0, scalar), alpha:0).cgColor,
				ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(0, 0, scalar), alpha:1).cgColor
			]
			mode = .normal
		}
		
		if options.flipOver { copyColors.reverse() }
		if options.flipDown { modeColors.reverse() }
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let drawingOptions:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		
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
	
	func drawPlaneFromCubeCHCLT(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chocolate:CHCLT) {
		let drawSpace = CHCLT.LinearRGB.colorSpace
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
			let primary = CHCLT.LinearRGB(chocolate, hue:scalar)
			let inverse = primary.applyChroma(chocolate, value:-1).saturated()
			let flipChroma = options.flipOver
			let flipLuma = options.flipDown
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				var chroma = CHCLT.Scalar(index) / CHCLT.Scalar(count - 1)
				
				if flipChroma { chroma = 1 - chroma }
				if wideChroma { chroma = chroma * 2 - 1 }
				
				guard let gradient = ColorModel.luminanceGradient(
					chclt:chocolate,
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
			let hues = chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = options.flipOver
			let flipLuma = options.flipDown
			let scalar = wideChroma ? scalar * 2 - 1 : scalar
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index])
				
				guard let gradient = ColorModel.luminanceGradient(
					chclt:chocolate,
					primary:scalar < 0 ? primary.applyChroma(chocolate, value:-1).saturated() : primary,
					chroma:scalar.magnitude,
					colorSpace:drawSpace,
					darkToLight:flipLuma
				) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:drawingOptions)
				resetClip()
			}
		case _:	//	scalar is luminance
			let hues = chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = options.flipOver
			let flipChroma = options.flipDown
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index]).applyLuminance(chocolate, value:scalar)
				
				guard let gradient = ColorModel.chromaGradient(
					chclt:chocolate,
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
