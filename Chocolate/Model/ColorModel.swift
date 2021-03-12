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
	
	static func transform(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar) -> CHCLT.Scalar.Vector3 {
		let a = axis / 6
		let x = a & 1 != 0 ? 1 - x : x
		let y = a & 2 != 0 ? 1 - y : y
		let z = a & 4 != 0 ? 1 - z : z
		
		switch axis % 6 {
		case 0: return CHCLT.Scalar.vector3(z, x, y)
		case 1: return CHCLT.Scalar.vector3(x, z, y)
		case 2: return CHCLT.Scalar.vector3(x, y, z)
		case 3: return CHCLT.Scalar.vector3(z, y, x)
		case 4: return CHCLT.Scalar.vector3(y, z, x)
		case _: return CHCLT.Scalar.vector3(y, x, z)
		}
	}
	
	static func linearRGB(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar) -> CHCLT.LinearRGB {
		return CHCLT.LinearRGB(transform(axis:axis, x:x, y:y, z:z))
	}
	
	static func platformRGB(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, alpha:CGFloat = 1.0) -> PlatformColor {
		let rgb = transform(axis:axis, x:x, y:y, z:z)
		
		return PlatformColor(red:CGFloat(rgb.x), green:CGFloat(rgb.y), blue:CGFloat(rgb.z), alpha:alpha)
	}
	
	static func linearHSB(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar) -> CHCLT.LinearRGB {
		let hsb = transform(axis:axis, x:x, y:y, z:z)
		
		return CHCLT.LinearRGB(DisplayRGB.hexagonal(hue:hsb.x, saturation:hsb.y, brightness:hsb.z))
	}
	
	static func platformHSB(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, alpha:CGFloat = 1.0) -> PlatformColor {
		let hsb = transform(axis:axis, x:x, y:y, z:z)
		
		return PlatformColor(hue:CGFloat(hsb.x), saturation:CGFloat(hsb.y), brightness:CGFloat(hsb.z), alpha:alpha)
	}
	
	static func linearCHCLT(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, chclt:CHCLT) -> CHCLT.LinearRGB {
		let hcl = transform(axis:axis, x:x, y:y, z:z)
		
		return CHCLT.LinearRGB(chclt, hue:hcl.x, chroma:hcl.y, luminance:hcl.z)
	}
	
	static func platformCHCLT(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, chclt:CHCLT, alpha:CGFloat = 1.0) -> PlatformColor {
		let hcl = transform(axis:axis, x:x, y:y, z:z)
		
		return CHCLT.LinearRGB(chclt, hue:hcl.x, chroma:hcl.y, luminance:hcl.z).display(chclt, alpha:alpha.native).color().platformColor
	}
	
	func linearColor(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, chclt:CHCLT) -> CHCLT.LinearRGB {
		switch self {
		case .rgb: return ColorModel.linearRGB(axis:axis, x:x, y:y, z:z)
		case .hsb: return ColorModel.linearHSB(axis:axis, x:x, y:y, z:z)
		case .chclt: return ColorModel.linearCHCLT(axis:axis, x:x, y:y, z:z, chclt:chclt)
		}
	}
	
	func displayColor(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, chclt:CHCLT, alpha:CHCLT.Scalar = 1) -> DisplayRGB {
		switch self {
		case .rgb: return DisplayRGB(CHCLT.Scalar.vector4(ColorModel.linearRGB(axis:axis, x:x, y:y, z:z).vector, alpha))
		case .hsb: return DisplayRGB(CHCLT.Scalar.vector4(ColorModel.linearHSB(axis:axis, x:x, y:y, z:z).vector, alpha))
		case .chclt: return ColorModel.linearCHCLT(axis:axis, x:x, y:y, z:z, chclt:chclt).display(chclt, alpha:alpha)
		}
	}
	
	func platformColor(axis:Int, x:CHCLT.Scalar, y:CHCLT.Scalar, z:CHCLT.Scalar, chclt:CHCLT, alpha:CGFloat = 1.0) -> PlatformColor {
		switch self {
		case .rgb: return ColorModel.platformRGB(axis:axis, x:x, y:y, z:z, alpha:alpha)
		case .hsb: return ColorModel.platformHSB(axis:axis, x:x, y:y, z:z, alpha:alpha)
		case .chclt: return ColorModel.platformCHCLT(axis:axis, x:x, y:y, z:z, chclt:chclt, alpha:alpha)
		}
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
		case (.hsb, 0):   result = (0 ..< count).map { ColorModel.platformHSB(axis:1, x:0, y:1, z:Double($0) / Double(count - 1)) }
		case (.hsb, 1):   result = [.white, ColorModel.platformHSB(axis:1, x:hue, y:1, z:1)]
		case (.hsb, _):   result = [.black, ColorModel.platformHSB(axis:2, x:hue, y:1, z:1)]
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
			ColorModel.platformRGB(axis:overAxis, x:0, y:0, z:scalar).cgColor,
			ColorModel.platformRGB(axis:overAxis, x:1, y:0, z:scalar).cgColor
		]
		downColors = [
			ColorModel.platformRGB(axis:downAxis, x:0, y:1, z:scalar).cgColor,
			ColorModel.platformRGB(axis:downAxis, x:0, y:0, z:scalar).cgColor
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
				ColorModel.platformHSB(axis:0, x:0, y:1, z:scalar).cgColor,
				ColorModel.platformHSB(axis:0, x:1, y:1, z:scalar).cgColor
			]
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case 1:
			copyColors = (0 ..< count).map { ColorModel.platformHSB(axis:1, x:Double($0) / Double(count - 1), y:1, z:scalar).cgColor }
			modeColors = [PlatformColor.white.cgColor, PlatformColor.black.cgColor]
			mode = .multiply
		case _:
			copyColors = (0 ..< count).map { ColorModel.platformHSB(axis:2, x:Double($0) / Double(count - 1), y:1, z:scalar).cgColor }
			modeColors = [
				ColorModel.platformHSB(axis:2, x:0, y:0, z:scalar, alpha:0).cgColor,
				ColorModel.platformHSB(axis:2, x:0, y:0, z:scalar, alpha:1).cgColor
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
