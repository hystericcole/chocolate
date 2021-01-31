//
//  CHCLTLayer.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import QuartzCore

class CHCLTLayer: CALayer {
	enum Axis {
		case hue, chroma, luma
	}
	
	var chocolate:CHCLT = CHCLTPower.y709
	var vertical:Axis = .chroma
	var horizontal:Axis = .hue
	var scalar:CHCLTScalar = 0.5 { didSet { setNeedsDisplay() } }
	var bands:Int = 20
	
	func drawChocolate(_ context:CGContext) {
		let size = bounds.size
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		
		let isHorizontal = vertical == .hue
		let isScalarLuma = isHorizontal ? horizontal != .luma : vertical != .luma
		let dimension = isHorizontal ? size.height : size.width
		let limit = bands > 0 ? bands : Int(ceil(dimension) - 1)
		let thickness = bands > 0 ? ceil(dimension / CGFloat(bands)) : 1
		let band = isHorizontal ? CGSize(width:size.width, height:thickness) : CGSize(width:thickness, height:size.height)
		let shadingStart = CGPoint(x:0, y:0)
		let shadingEnd = isHorizontal ? CGPoint(x:size.width, y:0) : CGPoint(x:0, y:size.height)
		
		for i in 0 ... limit {
			let x = Double(i) / Double(limit)
			let c, d:CHCLT.Vector4
			
			if isScalarLuma {
				c = chocolate.color(hue:x, saturation:1, luma:scalar, alpha:1)
				d = chocolate.scaleSaturation(c, by:0)
			} else {
				c = chocolate.color(hue:x, saturation:scalar, luma:1, alpha:1)
				d = chocolate.scaleLuma(c, by:0)
			}
			
			let origin = isHorizontal ? CGPoint(x:0, y:CGFloat(i) * thickness) : CGPoint(x:CGFloat(i) * thickness, y:0)
			let box = CGRect(origin:origin, size:band)
			let shading = CHCLTShading(model:chocolate, colors:[c, d])
			
			guard let gradient = shading.shading(colorSpace:colorSpace, start:shadingStart, end:shadingEnd) else { break }
			
			context.clip(to:box)
			context.drawShading(gradient)
			context.resetClip()
		}
	}
	
	override func draw(in ctx: CGContext) {
		drawChocolate(ctx)
	}
	
	override func render(in ctx: CGContext) {
		drawChocolate(ctx)
	}
}
