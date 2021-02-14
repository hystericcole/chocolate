//
//  ChocolateLayer.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//

import QuartzCore
import Foundation

class ChocolateLayer: CALayer {
	enum Axis {
		case hue, chroma, luma
	}
	
	var chocolate:CHCLT = CHCLTPower.y709
	var vertical:Axis = .chroma
	var horizontal:Axis = .hue
	var scalar:CHCLT.Scalar = 0.5 { didSet { setNeedsDisplay() } }
	var bands:Int = 40
	
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
			let c, d:DisplayRGB
			
			if isScalarLuma {
				c = DisplayRGB(chocolate, hue:x, chroma:1, luma:scalar, alpha:1)
				d = c.scaleChroma(chocolate, by:0)
			} else {
				c = DisplayRGB(chocolate, hue:x, chroma:scalar, luma:1, alpha:1)
				d = c.scaleLuma(chocolate, by:0)
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

class ChocolateLayerView: BaseView {
#if os(macOS)
	override class var layerClass:CALayer.Type { return ChocolateLayer.self }
	override func prepare() { super.prepare(); layer?.setNeedsDisplay() }
#else
	override class var layerClass:AnyClass { return ChocolateLayer.self }
	override func prepare() { super.prepare(); layer.setNeedsDisplay() }
#endif
	var chocolateLayer:ChocolateLayer? { return layer as? ChocolateLayer }
}

class ChocolateLayerViewController: BaseViewController {
	let chocolate = ChocolateLayerView()
	let slider = Viewable.Slider(value:0.5, action:#selector(sliderChanged))
	let toggle = Viewable.Switch(action:#selector(switchFlipped))
	let group = Viewable.Group(content:Layout.EmptySpace())
	
	override func loadView() {
		group.content = layout()
		view = group.lazyView
		group.view?.attachViewController(self)
	}
	
	@objc
	func sliderChanged() {
		chocolate.chocolateLayer?.scalar = slider.value
	}
	
	@objc
	func switchFlipped() {
		chocolate.chocolateLayer?.vertical = toggle.isOn ? .chroma : .luma
	}
	
	func layout() -> Positionable {
		return Layout.Vertical(targets:[
			Layout.Horizontal(targets: [slider, toggle], spacing:20, position:.center).padding(20),
			chocolate
		], alignment:.fill, position:.stretch)
	}
}
