//
//	ChocolatePlaneView.swift
//	Chocolate
//
//	Created by Eric Cole on 3/11/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import QuartzCore

class ChocolatePlaneLayer: CALayer {
	struct Mode {
		static let standard = Mode(model:.chclt, axis:0)
		
		var model:ColorModel
		var axis:Int
		
		func color(chclt:CHCLT, coordinates:CHCLT.Scalar.Vector3) -> CHCLT.Color {
			return model.color(axis:axis, coordinates:coordinates, chclt:chclt)
		}
		
		func linearColor(chclt:CHCLT, coordinates:CHCLT.Scalar.Vector3) -> CHCLT.LinearRGB {
			return model.linearColor(axis:axis, coordinates:coordinates, chclt:chclt)
		}
		
		func platformColor(chclt:CHCLT, coordinates:CHCLT.Scalar.Vector3) -> PlatformColor {
			return model.platformColor(axis:axis, coordinates:coordinates, chclt:chclt)
		}
		
		func linearColors(chclt:CHCLT, hue:CHCLT.Scalar, count:Int = 360) -> [CHCLT.LinearRGB] {
			return model.linearColors(axis:axis, chclt:chclt, hue:hue, count:count)
		}
	}
	
	var chclt:CHCLT = CHCLT.default { didSet { if chclt !== oldValue { setNeedsDisplay() } } }
	var scalar:CHCLT.Scalar = 0.5 { didSet { if scalar != oldValue { setNeedsDisplay() } } }
	var mode = Mode.standard { didSet { setNeedsDisplay() } }
	
	override func draw(in ctx: CGContext) {
		let box = CGRect(origin:.zero, size:bounds.size)
		let space = chclt is CHCLT_Linear ? nil : view?.screenColorSpace
		
		ctx.clip(to:box)
		
		switch mode.model {
		case .chclt: ctx.drawPlaneFromCubeCHCLT(axis:mode.axis, scalar:scalar, box:box, chclt:chclt, drawSpace:space)
		//case .lchok: ctx.drawPlaneFromCubeLCHOK(axis:mode.axis, scalar:scalar, box:box, chclt:chclt, drawSpace:space)
		//case .lchab: ctx.drawPlaneFromCubeLCH(axis:mode.axis, scalar:scalar, box:box, chclt:chclt, drawSpace:space)
		//case .xyz: ctx.drawPlaneFromCubeXYZ(axis:mode.axis, scalar:scalar, box:box, chclt:chclt, drawSpace:space)
		case .rgb: ctx.drawPlaneFromCubeRGB(axis:mode.axis, scalar:scalar, box:box, chclt:chclt, drawSpace:space)
		case .hsb: ctx.drawPlaneFromCubeHSB(axis:mode.axis, scalar:scalar, box:box, chclt:chclt, drawSpace:space)
		}
	}
	
	override func render(in ctx: CGContext) {
		draw(in:ctx)
	}
}

//	MARK: -

class ChocolatePlaneView: CommonView {
#if os(macOS)
	override var isFlipped:Bool { return true }
	override var wantsUpdateLayer:Bool { return true }
	override func prepare() { super.prepare(); wantsLayer = true }
	override func makeBackingLayer() -> CALayer { return ChocolatePlaneLayer() }
	override func viewDidEndLiveResize() { super.viewDidEndLiveResize(); scheduleDisplay() }
	override func acceptsFirstMouse(for event:PlatformEvent?) -> Bool { return true }
#else
	override class var layerClass:AnyClass { return ChocolatePlaneLayer.self }
#endif
	
	var planeLayer:ChocolatePlaneLayer! { return layer as? ChocolatePlaneLayer }
	
	var mode:ChocolatePlaneLayer.Mode {
		get { return planeLayer?.mode ?? .standard }
		set { planeLayer?.mode = newValue; scheduleDisplay() }
	}
	
	var scalar:CHCLT.Scalar {
		get { return planeLayer?.scalar ?? 0 }
		set { planeLayer?.scalar = newValue }
	}
}
