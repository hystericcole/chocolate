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
	
	static func components(coordinates:CHCLT.Scalar.Vector3, axis:Int) -> CHCLT.Scalar.Vector3 {
		var v = coordinates
		let a = axis / 6
		
		if a & 1 != 0 { v.x = 1 - v.x }
		if a & 2 != 0 { v.y = 1 - v.y }
		if a & 4 != 0 { v.z = 1 - v.z }
		
		switch axis % 6 {
		case 0: return CHCLT.Scalar.vector3(v.z, v.x, v.y)
		case 1: return CHCLT.Scalar.vector3(v.x, v.z, v.y)
		case 2: return CHCLT.Scalar.vector3(v.x, v.y, v.z)
		case 3: return CHCLT.Scalar.vector3(v.z, v.y, v.x)
		case 4: return CHCLT.Scalar.vector3(v.y, v.z, v.x)
		case _: return CHCLT.Scalar.vector3(v.y, v.x, v.z)
		}
	}
	
	static func coordinates(components:CHCLT.Scalar.Vector3, axis:Int) -> CHCLT.Scalar.Vector3 {
		var v:CHCLT.Scalar.Vector3
		let c = components
		let a = axis / 6
		
		switch axis % 6 {
		case 0: v = CHCLT.Scalar.vector3(c.y, c.z, c.x)
		case 1: v = CHCLT.Scalar.vector3(c.x, c.z, c.y)
		case 2: v = CHCLT.Scalar.vector3(c.x, c.y, c.z)
		case 3: v = CHCLT.Scalar.vector3(c.z, c.y, c.x)
		case 4: v = CHCLT.Scalar.vector3(c.z, c.x, c.y)
		case _: v = CHCLT.Scalar.vector3(c.y, c.x, c.z)
		}
		
		if a & 1 != 0 { v.x = 1 - v.x }
		if a & 2 != 0 { v.y = 1 - v.y }
		if a & 4 != 0 { v.z = 1 - v.z }
		
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
		
		return PlatformColor(hue:CGFloat(hsb.x), saturation:CGFloat(hsb.y), brightness:CGFloat(hsb.z), alpha:alpha)
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
		let result:[CHCLT.LinearRGB]
		let a = axis / 6
		let r = a & 4 != 0
		
		switch (self, axis % 3) {
		case (.rgb, 0):   result = [.black, .red]
		case (.rgb, 1):   result = [.black, .green]
		case (.rgb, _):   result = [.black, .blue]
		case (.hsb, 0):   result = (0 ..< count).map { CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:Double($0) / Double(count - 1), saturation:1, brightness:1))) }
		case (.hsb, 1):   result = [.white, CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:hue, saturation:1, brightness:1)))]
		case (.hsb, _):   result = [.black, CHCLT.LinearRGB(chclt.linear(DisplayRGB.hexagonal(hue:hue, saturation:1, brightness:1)))]
		case (.chclt, 0): result = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count).map { CHCLT.LinearRGB($0).applyLuminance(chclt, value:0.5) }
		case (.chclt, 1): result = [CHCLT.LinearRGB(chclt, hue:hue).applyChroma(chclt, value:0), CHCLT.LinearRGB(chclt, hue:hue).applyChroma(chclt, value:1)]
		case (.chclt, _): result = [.black, .white]
		}
		
		return r ? result.reversed() : result
	}
	
	func platformColors(axis:Int, chclt:CHCLT, hue:CHCLT.Scalar, count:Int) -> [PlatformColor] {
		let result:[PlatformColor]
		let a = axis / 6
		let r = a & 4 != 0
		
		switch (self, axis % 3) {
		case (.rgb, 0):   result = [.black, .red]
		case (.rgb, 1):   result = [.black, .green]
		case (.rgb, _):   result = [.black, .blue]
		case (.hsb, 0):   result = (0 ..< count).map { ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(1, 1, Double($0) / Double(count - 1))) }
		case (.hsb, 1):   result = [.white, ColorModel.platformHSB(axis:1, coordinates:CHCLT.Scalar.vector3(hue, 1, 1))]
		case (.hsb, _):   result = [.black, ColorModel.platformHSB(axis:2, coordinates:CHCLT.Scalar.vector3(hue, 1, 1))]
		case (.chclt, 0): result = chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count).map { CHCLT.LinearRGB($0).applyLuminance(chclt, value:0.5).color().platformColor }
		case (.chclt, 1): result = [CHCLT.LinearRGB(chclt, hue:hue).applyChroma(chclt, value:0), CHCLT.LinearRGB(chclt, hue:hue).applyChroma(chclt, value:1)].map { $0.color().platformColor }
		case (.chclt, _): result = [.black, .white]
		}

		return r ? result.reversed() : result
	}
	
	static func chromaGradient(chclt:CHCLT, primary:CHCLT.LinearRGB, chroma:CHCLT.Scalar, colorSpace:CGColorSpace?, darkToLight:Bool = false) -> CGGradient? {
		let color = primary.applyChroma(chclt, value:chroma)
		let value = color.luminance(chclt)
		let locations:[CGFloat] = [0, CGFloat(darkToLight ? value : 1 - value), 1]
		var colors:[CGColor] = [.white, color, .black].map { $0.color() }
		
		if darkToLight { colors.reverse() }
		
		return CGGradient(colorsSpace:colorSpace, colors:colors as CFArray, locations:locations)
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
		let overAxis = (axis / 6 & 1) * 6 + axis % 6
		let downAxis = (axis / 6 & 2) * 6 + axis % 6
		
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
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:overColors as CFArray, locations:nil) {
			setBlendMode(.copy)
			drawLinearGradient(gradient, start:start, end:overEnd, options:options)
		}
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:downColors as CFArray, locations:nil) {
			setBlendMode(mode)
			drawLinearGradient(gradient, start:start, end:downEnd, options:options)
		}
	}
	
	func drawPlaneFromCubeHSB(axis:Int, scalar:CGFloat.NativeType, box:CGRect) {
		let drawSpace = colorSpace
		var copyColors:[CGColor]
		var modeColors:[CGColor]
		let mode:CGBlendMode
		let a = axis / 6
		let isFlipped = (axis / 3) & 1 != 0
		let flipOver = isFlipped ? ~a & 2 : a & 1
		let flipDown = isFlipped ? ~a & 1 : a & 2
		let count = Int(isFlipped ? box.size.height : box.size.width)
		
		switch axis % 3 {
		case 0:
			copyColors = [
				ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(0, 1, scalar)).cgColor,
				ColorModel.platformHSB(axis:0, coordinates:CHCLT.Scalar.vector3(1, 1, scalar)).cgColor
			]
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case 1:
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
		
		if flipOver != 0 { copyColors.reverse() }
		if flipDown != 0 { modeColors.reverse() }
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:copyColors as CFArray, locations:nil) {
			setBlendMode(.copy)
			drawLinearGradient(gradient, start:start, end:isFlipped ? downEnd : overEnd, options:options)
		}
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:modeColors as CFArray, locations:nil) {
			setBlendMode(mode)
			drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
		}
	}
	
	func drawPlaneFromCubeCHCLT(axis:Int, scalar:CGFloat.NativeType, box:CGRect, chocolate:CHCLT) {
		let drawSpace = CHCLT.LinearRGB.colorSpace
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let a = axis / 6
		let isFlipped = (axis / 3) & 1 != 0
		let flipOver = isFlipped ? ~a & 2 : a & 1
		let flipDown = isFlipped ? ~a & 1 : a & 2
		let count = Int(isFlipped ? box.size.height : box.size.width)
		let size = isFlipped ? CGSize(width:box.size.width, height:1) : CGSize(width:1, height:box.size.height)
		let step = isFlipped ? CGPoint(x:0, y:1) : CGPoint(x:1, y:0)
		
		setRenderingIntent(CGColorRenderingIntent.absoluteColorimetric)
		
		switch axis % 3 {
		case 0:	//	scalar is hue
			let primary = CHCLT.LinearRGB(chocolate, hue:scalar)
			let flipChroma = flipOver != 0
			let flipLuma = flipDown != 0
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let chroma = CHCLT.Scalar(index) / CHCLT.Scalar(count - 1)
				
				guard let gradient = ColorModel.chromaGradient(chclt:chocolate, primary:primary, chroma:flipChroma ? 1 - chroma : chroma, colorSpace:drawSpace, darkToLight:flipLuma) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
				resetClip()
			}
		case 1:	//	scalar is chroma
			let hues = chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = flipOver != 0
			let flipLuma = flipDown != 0
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index])
				
				guard let gradient = ColorModel.chromaGradient(chclt:chocolate, primary:primary, chroma:scalar, colorSpace:drawSpace, darkToLight:flipLuma) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
				resetClip()
			}
		case _:	//	scalar is luminance
			let hues = chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let flipHue = flipOver != 0
			let flipChroma = flipDown != 0
			
			for index in 0 ..< count {
				let origin = step * CGFloat(index) + box.origin
				let stripe = CGRect(origin:origin, size:size)
				let primary = CHCLT.LinearRGB(hues[flipHue ? count - 1 - index : index]).applyLuminance(chocolate, value:scalar)
				var colors = [primary, primary.applyChroma(chocolate, value:0.5), primary.applyChroma(chocolate, value:0)].map { $0.color() }
				
				if flipChroma { colors.reverse() }
				
				guard let gradient = CGGradient(colorsSpace:drawSpace, colors:colors as CFArray, locations:nil) else { continue }
				
				clip(to:stripe)
				drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
				resetClip()
			}
		}
	}
}
