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
	var colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear) ?? CGColorSpaceCreateDeviceRGB()
	var vertical:Axis = .chroma
	var horizontal:Axis = .hue
	var scalar:CHCLT.Scalar = 0.5 { didSet { setNeedsDisplay() } }
	var bands:Int = 0
	
	func colorsWithHueLuminance(hue:CHCLT.Scalar, luminance scalar:CHCLT.Scalar) -> [CHCLTShading.ColorLocation] {
		let color = CHCL.LinearRGB(chocolate, hue:hue, luminance:scalar)
		
		return [
			CHCLTShading.ColorLocation(color:color, alpha:1, location:0),
			CHCLTShading.ColorLocation(color:color.scaleChroma(chocolate, by:0), alpha:1, location:1)
		]
	}
	
	func colorsWithHueChroma(hue:CHCLT.Scalar, chroma scalar:CHCLT.Scalar) -> [CHCLTShading.ColorLocation] {
		let reference = CHCL.LinearRGB(chocolate, hue:hue, luminance:0x1p-5).applyChroma(chocolate, value:scalar)
		let value = reference.maximumLuminancePreservingRatio(chocolate)
		let color = CHCL.LinearRGB(chocolate, hue:hue, luminance:value).applyChroma(chocolate, value:scalar)
		
		return [
			CHCLTShading.ColorLocation(color:color.applyLuminance(chocolate, value:1), alpha:1, location:0.0),
			CHCLTShading.ColorLocation(color:color, alpha:1, location:1 - value),
			CHCLTShading.ColorLocation(color:color.scaleLuminance(by:0), alpha:1, location:1.0)
		]
	}
	
	func drawColorsInBand(_ context:CGContext, colors:[CHCLTShading.ColorLocation], shadingStart:CGPoint, shadingEnd:CGPoint, useShading:Bool) {
		let space = colorSpace
		
		if useShading {
			let shading = CHCLTShading(model:chocolate, colors:colors)
			
			if let gradient = shading.shading(linearColorSpace:space, start:shadingStart, end:shadingEnd) {
				context.drawShading(gradient)
			}
		} else {
			let locations:[CGFloat] = colors.map { CGFloat($0.location) }
			let stops:[CGColor] = colors.compactMap { $0.color.color(colorSpace:space) }
			
			if let gradient = CGGradient(colorsSpace:space, colors:stops as CFArray, locations:locations) {
				context.drawLinearGradient(gradient, start:shadingStart, end:shadingEnd, options:[])
			}
		}
	}
	
	func drawChocolate(_ context:CGContext) {
		let size = bounds.size
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
			let colors:[CHCLTShading.ColorLocation]
			
			if isScalarLuma {
				colors = colorsWithHueLuminance(hue:x, luminance:scalar)
			} else {
				colors = colorsWithHueChroma(hue:x, chroma:scalar)
			}
			
			let origin = isHorizontal ? CGPoint(x:0, y:CGFloat(i) * thickness) : CGPoint(x:CGFloat(i) * thickness, y:0)
			let box = CGRect(origin:origin, size:band)
			
			context.clip(to:box)
			drawColorsInBand(context, colors:colors, shadingStart:shadingStart, shadingEnd:shadingEnd, useShading:false)
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
		chocolate.chocolateLayer?.vertical = toggle.isOn ? .luma : .chroma
		chocolate.chocolateLayer?.setNeedsDisplay()
	}
	
	func layout() -> Positionable {
		return Layout.Vertical(targets:[
			Layout.Horizontal(targets: [slider, toggle], spacing:20, position:.center).padding(20),
			chocolate
		], alignment:.fill, position:.stretch)
	}
}
