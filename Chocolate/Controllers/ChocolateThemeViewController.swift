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
	
	class Sample {
		let background = Viewable.Color(nil)
		var foregrounds:[Style.Label] = []
		
		func layout() -> Positionable {
			return Layout.Overlay(
				background,
				Layout.Vertical(targets:foregrounds, spacing:4, alignment:.fill).padding(10)
			).minimum(width:200, height:60)
		}
		
		func applyFont(_ font:PlatformFont) {
			for label in foregrounds {
				label.style = label.style.with(font:.descriptor(font.fontDescriptor), size:font.pointSize)
			}
		}
		
		func sampleText(_ palette:Palette, index:Int, count:Int, formatter:NumberFormatter, reverseContrast:CHCLT.Scalar, reverseLuminance:CHCLT.Linear) -> (String, PlatformColor) {
			let fraction = Double(index) / Double(count - 1)
			let linear = palette.foreground(fraction)
			let name = linear.display(palette.chclt).web()
			let color = CHCLT.Color(palette.chclt, linear).platformColor
			let contrast = formatter.string(linear.contrast(palette.chclt) + reverseContrast)
			let ratio = CHCLT.Contrast.luminanceRatioG18(reverseLuminance, linear.luminance(CHCLT_sRGB.g18))
			let g18 = formatter.string(ratio)
			let text = "•\(index)/\(count - 1) \(name) G18 \(g18)◐ \(contrast)◐"
			
			return (text, color)
		}
		
		func applyPalette(_ palette:Palette, value:CHCLT.Scalar, count:Int) {
			let reverse = palette.background(value)
			let reverseContrast = reverse.contrast(palette.chclt)
			let reverseLuminance = reverse.luminance(CHCLT_sRGB.g18)
			let formatter = NumberFormatter(fractionDigits:2 ... 2)
			
			for index in 0 ..< count {
				let (text, color) = sampleText(palette, index:index, count:count, formatter:formatter, reverseContrast:reverseContrast, reverseLuminance:reverseLuminance)
				//let text = "The quick brown fox jumps over a lazy dog."
				
				if index < foregrounds.count {
					foregrounds[index].style = foregrounds[index].style.color(color)
					foregrounds[index].text = text
				} else {
					foregrounds.append(Style.Label(text:text, style:Style.monospace.centered.color(color)))
				}
			}
			
			background.border(.init(width:2, radius:0, color:palette.primary.color()))
			background.color = CHCLT.Color(palette.chclt, reverse).platformColor
		}
	}
	
	let deriveCount = 5
	
	let group = Viewable.Group()
	let sampleScroll = Viewable.Scroll(minimum:CGSize(square:240), maximum:CGSize(square:240))
	var samples:[Sample] = []
	
	let themeView = ChocolateThemeViewable()
	let sliderHue = ChocolateGradientSlider(value:2/3, action:#selector(hueChanged), trackInset:3)
	let sliderDeriveContrast = Viewable.Slider(value:0.5, range:-2 ... 2, action:#selector(deriveChanged))
	let sliderDeriveChroma = Viewable.Slider(value:0.0, range:-2 ... 2, action:#selector(deriveChanged))
	let sliderContrasting = Viewable.Slider(value:0.5, range:-1 ... 1, action:#selector(deriveChanged))
	let sliderChroma = Viewable.Slider(value:0.5, range:-2 ... 2, action:#selector(deriveChanged))
	
	let iconDerive = (0 ..< 3).map { _ in Viewable.Color(nil, intrinsicSize:CGSize(square:20)) }
	let iconContrasting = Viewable.Color(.orange, intrinsicSize:CGSize(square:10))
	let stringDeriveContrast = Style.numberRight.label("", maximumLines:1)
	let stringDeriveChroma = Style.numberRight.label("", maximumLines:1)
	let stringContrasting = Style.numberRight.label("", maximumLines:1)
	let stringChroma = Style.numberRight.label("", maximumLines:1)
	let stringHue = Style.numberRight.label("", maximumLines:1)
	
	var indicators:[Viewable.Color] = []
	var primaryPosition:CGPoint = CGPoint(x:0.875, y:0.875)
	var isComplement:Bool = false
	
	var chclt:CHCLT { return themeView.view?.themeLayer.chclt ?? .default }
	var colorModel:ColorModel = .chclt
	var axis:Int { return themeView.view?.themeLayer.axis ?? 48 }
	
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Palette.title
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
		
		applyPositions(animated:false)
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
		let unit = CGPoint(x:min(max(0.0, unbound.x), 1), y:min(max(0, unbound.y), 1))
		
		isComplement = unit.x < 0.5
		primaryPosition = unit
		applyPositions(animated:recognizer is PlatformTapGestureRecognizer)
	}
	
#if os(macOS)
	private var isAccessingColorPanel:Bool = false
	
	@objc
	func changeFont(_ manager:PlatformFontManager) {
		let font = Style.example.font.displayFont()
		let changed = manager.convert(font)
		
		for sample in samples {
			sample.applyFont(changed)
		}
		
		sampleScroll.view?.scheduleLayout()
	}
	
	@objc
	func changeColor(_ panel:PlatformColorPanel) {
		guard !isAccessingColorPanel, let color = panel.color.chocolateColor(chclt:chclt) else { return }
		
		isAccessingColorPanel = true
		applyColor(color.normalize(), animated:false)
		isAccessingColorPanel = false
	}
	
	func applyColorToPanel(_ palette:Palette) {
		guard !isAccessingColorPanel else { return }
		let panel = PlatformColorPanel.shared
		
		isAccessingColorPanel = true
		panel.isContinuous = false
		panel.color = CHCLT.Color(palette.chclt, palette.primary).platformColor
		panel.isContinuous = true
		isAccessingColorPanel = false
	}
#else
	func applyColorToPanel(_ palette:Palette) {}
#endif
	
	func applyColor(_ color:CHCLT.Color, animated:Bool) {
		let coordinates = colorModel.coordinates(axis:axis, color:color)
		let hue = isComplement ? 0.5 + coordinates.z : coordinates.z
		let chroma = isComplement ? 1.0 - coordinates.x : coordinates.x
		let luma = 1.0 - coordinates.y
		
		themeView.hue = hue
		sliderHue.value = hue
		primaryPosition = CGPoint(x:chroma, y:luma)
		applyPositions(animated:animated)
	}
	
	func current() -> Input {
		let axis = self.axis
		let chclt = self.chclt
		let model = colorModel
		let coordinates = CHCLT.Scalar.vector3(primaryPosition.x.native, 1 - primaryPosition.y.native, sliderHue.value)
		let primary = model.color(axis:axis, coordinates:coordinates, chclt:chclt)
		let adjust = CHCLT.Adjustment(contrast:sliderDeriveContrast.value, chroma:sliderDeriveChroma.value)
		let adjustment = CHCLT.Adjustment(contrast:0.5 + 0.6 * (0.5 - adjust.contrast), chroma:adjust.chroma)
		let increase = (1.0 - adjust.contrast) * 0.2
		let contrasting = CHCLT.Adjustment(contrast:sliderContrasting.value * (1 - increase) + increase, chroma:sliderChroma.value)
		let palette = Palette(chclt:chclt, primary:primary.linearRGB, contrasting:contrasting, primaryAdjustment:adjust, contrastingAdjustment:adjustment)
		
		return Input(axis:axis, model:model, chclt:chclt, palette:palette, coordinates:coordinates)
	}
	
	func applySliderValues(_ input:Input) {
		let formatter = NumberFormatter(fractionDigits:1 ... 1)
		let isDark = input.palette.primary.isDark(input.chclt)
		let deriveSymbol = isDark != (input.palette.primaryAdjustment.contrast < 0) ? "◐" : "◑"
		let contrastingSymbol = isDark ? "◓" : "◒"
		let increase = (1.0 - input.palette.primaryAdjustment.contrast) * 0.2
		let contrast = sliderContrasting.value * (1 - increase) + increase
		
		stringDeriveContrast.text = formatter.string(input.palette.primaryAdjustment.contrast * 100.0) + deriveSymbol
		stringDeriveChroma.text = formatter.string(input.palette.primaryAdjustment.chroma * 100.0) + "%"
		stringContrasting.text = formatter.string(contrast * 100.0) + contrastingSymbol
		stringChroma.text = formatter.string(sliderChroma.value * 100.0) + "%"
		stringHue.text = formatter.string(input.coordinates.z * 360.0) + "°"
		
		iconContrasting.color = input.palette.primaryBackground.platformColor
		iconContrasting.border(.init(width:1, color:input.palette.primaryForeground))
		for (index, color) in iconDerive.enumerated() {
			color.color = input.palette.foreground(Double(index + 1) / Double(iconDerive.count)).color()?.platformColor
			color.border(.init(width:1, radius:color.intrinsicSize.width / 2, color:input.palette.primaryBackground))
		}
	}
	
	func sampleLayout(_ input:Input, count:Int) -> Positionable {
		for index in 0 ..< count {
			let value = count > 1 ? Double(index) / Double(count - 1) : 1
			
			if index >= samples.count {
				samples.append(Sample())
			}
			
			samples[index].applyPalette(input.palette, value:value, count:deriveCount)
		}
		
		return Layout.Orient(
			targets:samples.map { $0.layout().padding(4) },
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.uniform),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.horizontal,
			mode:.ratio(3.0)
		)
	}
	
	func indicatorLayout(_ input:Input, count:Int) -> [Positionable] {
		let radius = 12.0
		let palette = input.palette
		let deriveLimit = count - 1
		let r = isComplement ? -1.0 : 1.0
		
		var colors:[(color:CHCLT.LinearRGB, border:CHCLT.LinearRGB, neagted:Bool, scale:Layout.Native)] = []
		var layout:[Layout.Align] = []
		
		colors.append((palette.primary, palette.contrasting, false, 4))
		
		for index in 1 ... deriveLimit {
			let value = Double(index) / Double(deriveLimit)
			let scale:Layout.Native = index == deriveLimit ? 2 : 1
			let s = 1 - value * (1 - palette.primaryAdjustment.chroma)
			
			colors.append((palette.foreground(value), palette.contrasting, r * s < 0, scale))
		}
		
		colors.append((palette.contrasting, palette.primary, palette.contrastingChroma * r < 0, 3))
		
		for index in 1 ... deriveLimit {
			let value = Double(index) / Double(deriveLimit)
			let scale:Layout.Native = index == deriveLimit ? 2 : 1
			let s = 1 - value * (1 - palette.contrastingAdjustment.chroma)
			
			colors.append((palette.background(value), palette.primary, palette.contrastingChroma * r * s < 0, scale))
		}
		
		if indicators.count < colors.count {
			for _ in indicators.count ..< colors.count {
				indicators.append(Viewable.Color(nil))
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
		
		applyColorToPanel(input.palette)
		
		return layout
	}
	
	func layout() -> Positionable {
		let input = current()
		let gap = Layout.EmptySpace(width:1, height:4)
		
		applySliderValues(input)
		
		let deriveScalar = Double(iconDerive.count - 1)
		let derive = Layout.Overlay(targets:iconDerive.enumerated().map { (offset, element) in
			return element.align(horizontal:.fraction(1 - Double(offset) / deriveScalar), vertical:.fraction(Double(offset) / deriveScalar))
		})
		
		let controls = Layout.Columns(
			spans:[
				derive.span(rows:2), sliderDeriveContrast, stringDeriveContrast,
				sliderDeriveChroma, stringDeriveChroma,
				gap, gap, gap,
				iconContrasting.aspect(ratio:1).rounded().span(rows:2), sliderContrasting, stringContrasting,
				sliderChroma, stringChroma,
				gap, gap, gap,
				sliderHue.span(columns:2), stringHue.minimum(width:50)
			],
			columnCount:3,
			spacing:4,
			template:Layout.Horizontal(spacing:4, alignment:.center, position:.stretch),
			position:.stretch
		)
		
		let picker = Layout.Vertical(
			spacing:4,
			alignment:.fill,
			position:.stretch,
			Layout.EmptySpace(width:1, height:1),
			controls.minimum(width:200),
			Layout.Overlay(targets:[themeView] + indicatorLayout(input, count:deriveCount), primary:0)
				.minimum(width:120, height:120)
				.padding(Layout.EdgeInsets(minX:16, maxX:16, minY:32, maxY:16))
		)
		
		sampleScroll.content = sampleLayout(input, count:4)
		
		return Layout.Orient(
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.vertical,
			mode:.ratio(0.75),
			picker.fraction(width:0.5, minimumWidth:200, height:0.5, minimumHeight:200).padding(20),
			sampleScroll.ignoringSafeBounds()
		)
	}
	
	func applyPositions(animated:Bool = false) {
		if animated, let view = group.view {
			Common.animate(duration:0.25, animations:{
				view.ordered = self.layout()
				view.arrangeContents()
			})
		} else {
			group.view?.ordered = layout()
		}
	}
}

//	MARK: -

class ChocolateThemeLayer: CALayer {
	var chclt:CHCLT = CHCLT.default { didSet { if chclt != oldValue { setNeedsDisplay() } } }
	var hue:CHCLT.Scalar = 0.5 { didSet { if hue != oldValue { setNeedsDisplay() } } }
	var axis:Int = 48 { didSet { if axis != oldValue { setNeedsDisplay() } } }
	
	override func draw(in ctx: CGContext) {
		let box = CGRect(origin:.zero, size:bounds.size)
		let space = view?.screenColorSpace
		
		ctx.drawPlaneFromCubeCHCLT(axis:axis, scalar:hue, box:box, chclt:chclt, drawSpace:space)
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
	var themeLayer:ChocolateThemeLayer? { return view?.themeLayer }
	
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
	
	func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
		return Layout.Size(prefer:model.intrinsicSize)
	}
}
