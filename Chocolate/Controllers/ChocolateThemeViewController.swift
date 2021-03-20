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
	struct Input {
		let axis:Int
		let model:ColorModel
		let chclt:CHCLT
		let palette:Palette
		let coordinates:CHCLT.Scalar.Vector3
	}
	
	let deriveCount = 5
	var palette = Palette(primary:.black)
	
	let group = Viewable.Group()
	let sampleScroll = Viewable.Scroll()
	var samples:[Viewable.Color] = []
	
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
	
	func current() -> Input {
		let axis = self.axis
		let chclt = self.chclt
		let model = colorModel
		let coordinates = CHCLT.Scalar.vector3(primaryPosition.x.native, 1 - primaryPosition.y.native, sliderHue.value)
		let primary = model.linearColor(axis:axis, coordinates:coordinates, chclt:chclt)
		let adjustment = CHCLT.Adjustment(contrast:sliderDeriveContrast.value, chroma:sliderDeriveChroma.value)
		let contrasting = CHCLT.Adjustment(contrast:sliderContrasting.value, chroma:sliderChroma.value)
		let palette = Palette(chclt:chclt, primary:primary, contrasting:contrasting, primaryAdjustment:adjustment, contrastingAdjustment:adjustment)
		
		return Input(axis:axis, model:model, chclt:chclt, palette:palette, coordinates:coordinates)
	}
	
	func sampleLayout(_ input:Input, count:Int) -> Positionable {
		if samples.count < count {
			let intrinsicSize = CGSize(square:100)
			
			for _ in samples.count ..< count {
				samples.append(Viewable.Color(color:nil, intrinsicSize:intrinsicSize))
			}
		}
		
		for index in 0 ..< count {
			samples[index].color = input.palette.background(Double(index) / Double(count - 1)).color().platformColor
		}
		
		return Layout.Orient(
			targets:samples,
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.horizontal,
			ratio:1.0
		)
	}
	
	func indicatorLayout(_ input:Input, count:Int) -> [Positionable] {
		let radius = 12.0
		let palette = input.palette
		let deriveLimit = count - 1
		
		var colors:[(color:CHCLT.LinearRGB, border:CHCLT.LinearRGB, neagted:Bool, scale:Layout.Native)] = []
		var layout:[Layout.Align] = []
		
		colors.append((palette.primary, palette.contrasting, false, 4))
		
		for index in 1 ... deriveLimit {
			let value = Double(index) / Double(deriveLimit)
			let scale:Layout.Native = index == deriveLimit ? 2 : 1
			let s = 1 - value * (1 - palette.primaryAdjustment.chroma)
			
			colors.append((palette.foreground(value), palette.contrasting, s < 0, scale))
		}
		
		colors.append((palette.contrasting, palette.primary, palette.contrastingChroma < 0, 3))
		
		for index in 1 ... deriveLimit {
			let value = Double(index) / Double(deriveLimit)
			let scale:Layout.Native = index == deriveLimit ? 2 : 1
			let s = 1 - value * (1 - palette.contrastingAdjustment.chroma)
			
			colors.append((palette.background(value), palette.primary, palette.contrastingChroma * s < 0, scale))
		}
		
		if indicators.count < colors.count {
			for _ in indicators.count ..< colors.count {
				indicators.append(Viewable.Color(color:nil))
			}
		}
		
		for index in colors.indices {
			let (color, border, negated, scale) = colors[index]
			let indicator = indicators[index]
			let coordinates = index == 0 ? input.coordinates : input.model.coordinates(axis:input.axis, color:color, chclt:input.chclt)
			
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
		let input = current()
		
		let controls = Layout.Vertical(
			spacing:4,
			alignment:.fill,
			position:.stretch,
			Layout.EmptySpace(width:1, height:1),
			sliderHue,
			sliderDeriveContrast,
			sliderDeriveChroma,
			sliderContrasting,
			sliderChroma
		)
		
		let picker = Layout.Vertical(
			spacing:4,
			alignment:.fill,
			position:.stretch,
			controls.minimum(width:200).padding(horizontal:20, vertical:0),
			Layout.Overlay(targets:[themeView] + indicatorLayout(input, count:deriveCount), primary:0)
				.fraction(width:0.5, minimumWidth:200, height:0.5, minimumHeight:200)
				.padding(36)
		)
		
		return picker
		
		sampleScroll.content = sampleLayout(input, count:4)
		
		return Layout.Orient(
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.vertical,
			ratio:0.5,
			picker,
			sampleScroll.minimum(width:120, height:120)
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
