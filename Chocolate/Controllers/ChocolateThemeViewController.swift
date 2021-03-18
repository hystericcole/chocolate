//
//	ChocolateThemeViewController.swift
//	Chocolate
//
//	Created by Eric Cole on 3/16/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import QuartzCore

class ChocolateThemeViewController: BaseViewController {
	let deriveCount = 5
	
	let group = Viewable.Group()
	let sampleScroll = Viewable.Scroll()
	
	let themeView = ChocolateThemeViewable()
	let sliderHue = ChocolateGradientSlider(value:2/3, action:#selector(hueChanged))
	let sliderDeriveContrast = Viewable.Slider(value:0.5, range:-2 ... 2, action:#selector(deriveChanged))
	let sliderDeriveChroma = Viewable.Slider(value:0.0, range:-2 ... 2, action:#selector(deriveChanged))
	let sliderContrasting = Viewable.Slider(value:0.5, range:-1 ... 1, action:#selector(deriveChanged))
	let sliderChroma = Viewable.Slider(value:0.5, range:-2 ... 2, action:#selector(deriveChanged))
	
	var indicators:[Viewable.Color] = []
	var primaryPosition:CGPoint = CGPoint(x:0.875, y:0.875)
	
	var chclt:CHCLT { return themeView.view?.themeLayer.chclt ?? .default }
	var colorModel:ColorModel = .chclt
	var axis:Int { return themeView.view?.themeLayer.axis ?? 48 }
	
	override func prepare() {
		super.prepare()
		
		themeView.hue = sliderHue.value
		sliderHue.applyModel(model:colorModel, axis:axis, chclt:chclt, hue:themeView.hue)
	}
	
	override func loadView() {
		group.content = layout()
		view = group.lazyView
		group.view?.attachViewController(self)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if let view = themeView.view {
			Common.Recognizer.attachRecognizers([
				Common.Recognizer(.pan(false), target:self, action:#selector(indicatorPanned)),
				Common.Recognizer(.tap(false, 1), target:self, action:#selector(indicatorPanned))
			], to:view)
		}
		
		applyPositions(animated:true)
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
	}
	
	@objc
	func hueChanged() {
		themeView.hue = sliderHue.value
		
		applyPositions(animated:!sliderHue.isTracking)
	}
	
	@objc
	func deriveChanged() {
		
		applyPositions()
	}
	
	@objc
	func indicatorPanned(_ recognizer:PlatformGestureRecognizer) {
		guard let view = themeView.view else { return }
		
		switch recognizer.state {
		case .recognized, .began, .changed: break
		default: return
		}
		
		let box = CGRect(origin:.zero, size:view.bounds.size)
		let location = recognizer.location(in:view)
		let unbound = location / box.size
		let unit = CGPoint(x:min(max(0.5, unbound.x), 1), y:min(max(0, unbound.y), 1))
		
		primaryPosition = unit
		applyPositions(animated:recognizer is PlatformTapGestureRecognizer)
	}
	
	func indicatorLayout() -> [Positionable] {
		let radius = 12.0
		let axis = self.axis
		let chclt = self.chclt
		
		var colors:[(color:CHCLT.LinearRGB, border:CHCLT.LinearRGB, neagted:Bool, scale:Layout.Native)] = []
		var layout:[Layout.Align] = []
		
		let primaryCoordinates = CHCLT.Scalar.vector3(primaryPosition.x.native, 1 - primaryPosition.y.native, sliderHue.value)
		let primaryColor = colorModel.linearColor(axis:axis, coordinates:primaryCoordinates, chclt:chclt)
		let primaryChroma = primaryColor.chroma(chclt)
		
		let reverseChroma = sliderChroma.value * primaryChroma
		let reverseContrast = sliderContrasting.value
		let reverseColor = primaryColor.contrasting(chclt, value:reverseContrast).applyChroma(chclt, value:reverseChroma)
		
		colors.append((primaryColor, reverseColor, false, 4))
		
		let deriveLimit = deriveCount - 1
		let deriveChroma = sliderDeriveChroma.value
		let deriveContrast = sliderDeriveContrast.value
		
		for index in 1 ... deriveLimit {
			let n = Double(index) / Double(deriveLimit)
			let s = 1 - n * (1 - deriveChroma)
			let c = 1 - n * (1 - deriveContrast)
			let color = primaryColor.scaleContrast(chclt, by:c).applyChroma(chclt, value:s * primaryChroma)
			
			colors.append((color, reverseColor, s < 0, index == deriveLimit ? 2 : 1))
		}
		
		colors.append((reverseColor, primaryColor, reverseChroma < 0, 3))
		
		for index in 1 ... deriveLimit {
			let n = Double(index) / Double(deriveLimit)
			let s = 1 - n * (1 - deriveChroma)
			let c = 1 - n * (1 - deriveContrast)
			let color = reverseColor.scaleContrast(chclt, by:c).applyChroma(chclt, value:s * reverseChroma.magnitude)
			
			colors.append((color, primaryColor, reverseChroma * s < 0, index == deriveLimit ? 2 : 1))
		}
		
		if indicators.count < colors.count {
			for _ in indicators.count ..< colors.count {
				indicators.append(Viewable.Color(color:nil))
			}
		}
		
		for index in colors.indices {
			let (color, border, negated, scale) = colors[index]
			let indicator = indicators[index]
			let coordinates = index == 0 ? primaryCoordinates : colorModel.coordinates(axis:axis, color:color, chclt:chclt)
			
			indicator.color = color.color().platformColor
			indicator.layer?.borderColor = border.color()
			indicator.layer?.borderWidth = CGFloat(scale)
			
			layout.append(Layout.Align(
				indicator.padding(-radius * scale).fixed(width:1, height:1).rounded(),
				horizontal:.fraction(negated ? 1 - coordinates.x : coordinates.x),
				vertical:.fraction(1 - coordinates.y)
			))
		}
		
		return layout
	}
	
	func layout() -> Positionable {
		let controls = Layout.Vertical(
			spacing:4,
			alignment:.fill,
			position:.stretch,
			sliderHue,
			sliderDeriveContrast,
			sliderDeriveChroma,
			sliderContrasting,
			sliderChroma
		)
		
		return Layout.Vertical(
			spacing:4,
			alignment:.fill,
			position:.stretch,
			controls.minimum(width:200).padding(horizontal:20, vertical:0),
			Layout.Overlay(targets:[themeView] + indicatorLayout(), primary:0).padding(36)
		)
	}
	
	func applyPositions(animated:Bool = false) {
		if animated, let view = group.view {
			Common.animate(duration:0.25, animations:{
				view.ordered = self.layout()
				view.sizeChanged()
			})
		} else {
			group.view?.ordered = layout()
		}
	}
}

//	MARK: -

class ChocolateThemeLayer: CALayer {
	var chclt:CHCLT = CHCLT.default
	var hue:CHCLT.Scalar = 0.5 { didSet { setNeedsDisplay() } }
	var axis:Int = 48
	
	override func draw(in ctx: CGContext) {
		let box = CGRect(origin:.zero, size:bounds.size)
		
		ctx.drawPlaneFromCubeCHCLT(axis:axis, scalar:hue, box:box, chclt:chclt)
	}
	
	override func render(in ctx: CGContext) {
		draw(in:ctx)
	}
}

//	MARK: -

class ChocolateThemeView: PlatformTaggableView {
#if os(macOS)
	override var isFlipped:Bool { return true }
	override var wantsUpdateLayer:Bool { return true }
	override func prepare() { super.prepare(); wantsLayer = true }
	override func makeBackingLayer() -> CALayer { return ChocolateThemeLayer() }
	override func viewDidEndLiveResize() { super.viewDidEndLiveResize(); scheduleDisplay() }
	override func acceptsFirstMouse(for event:PlatformEvent?) -> Bool { return true }
#else
	override class var layerClass:AnyClass { return ChocolateThemeLayer.self }
#endif
	
	var themeLayer:ChocolateThemeLayer! { return layer as? ChocolateThemeLayer }
	
	var hue:CHCLT.Scalar {
		get { return themeLayer?.hue ?? 0 }
		set { themeLayer?.hue = newValue }
	}
	
	var axis:Int {
		get { return themeLayer?.axis ?? 0 }
		set { themeLayer?.axis = newValue }
	}
}

//	MARK: -

class ChocolateThemeViewable: ViewablePositionable {
	typealias ViewType = ChocolateThemeView
	
	struct Model {
		let tag:Int
		var hue:CHCLT.Scalar
		var intrinsicSize:CGSize
	}
	
	weak var view:ViewType?
	var model:Model
	var tag:Int { get { return view?.tag ?? model.tag } }
	var hue:CHCLT.Scalar { get { return view?.hue ?? model.hue } set { model.hue = newValue; view?.hue = newValue } }
	
	var intrinsicSize:CGSize {
		get { return model.intrinsicSize }
		set { model.intrinsicSize = newValue; view?.invalidateIntrinsicContentSize() }
	}
	
	init(tag:Int = 0, hue:CHCLT.Scalar = 0.5, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
		self.model = Model(tag:tag, hue:hue, intrinsicSize:intrinsicSize)
	}
	
	func applyToView(_ view:ViewType) {
		view.tag = model.tag
		view.hue = model.hue
	}
	
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
		return Layout.Size(prefer:model.intrinsicSize)
	}
}
