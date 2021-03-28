//
//	ChocolateLumaRampViewController.swift
//	Chocolate
//
//	Created by Eric Cole on 2/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import QuartzCore

class ChocolateLumaRampViewController: BaseViewController {
	enum Input: Int { case unknown, hueStart, hueShift, chroma, lumaLower, lumaUpper }
	
	var chclt = CHCLT.default
	let group = Viewable.Group()
	let sliderHueStart = Viewable.Slider(tag:Input.hueStart.rawValue, value:0.5, action:#selector(colorSliderChanged))
	let sliderHueRotations = Viewable.Slider(tag:Input.hueShift.rawValue, value:1, range:-4 ... 4, action:#selector(colorSliderChanged))
	let sliderLumaLower = Viewable.Slider(tag:Input.lumaLower.rawValue, value:1/16, action:#selector(colorSliderChanged))
	let sliderLumaUpper = Viewable.Slider(tag:Input.lumaUpper.rawValue, value:15/16, action:#selector(colorSliderChanged))
	let sliderChroma = Viewable.Slider(tag:Input.chroma.rawValue, value:1, action:#selector(colorSliderChanged))
	let sliderCount = Viewable.Slider(tag:Input.chroma.rawValue, value:16, range:2 ... 128, action:#selector(colorSliderChanged))
	var colorStops:[Viewable.Color] = []
	let gradient = ChocolateGradientViewable(colors:[])
	
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.LumaRamp.title
	}
	
	override func loadView() {
		view = group.lazyView
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		prepareLayout()
		applyColorInput(.unknown, value:0)
	}
	
	func prepareLayout() {
		let controls = Layout.Columns(
			columnCount:2,
			spacing:6,
			template:Layout.Horizontal(spacing:2, position:.stretch),
			Style.caption.label("↻"), sliderHueRotations,
			Style.caption.label("H"), sliderHueStart,
			Style.caption.label("C"), sliderChroma,
			Style.caption.label("L"), sliderLumaLower,
			Style.caption.label("L"), sliderLumaUpper,
			Style.caption.label("#"), sliderCount
		)
		
		let colors = Layout.Horizontal(
			spacing:2,
			alignment:.fill,
			Layout.Sizing(gradient, width:Layout.Dimension(constant:0, fraction:0.5), height:nil),
			Layout.Vertical(targets:colorStops, spacing:2, alignment:.fill, position:.uniformWithEnds(0.5))
		)
		
		group.content = Layout.Flow(
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.vertical,
			controls.limiting(width:300 ... 300).padding(20),
			colors.minimum(width:200, height:240).ignoringSafeBounds(isUnderTabBar ? .horizontal : nil)
		)
	}
	
	func applyColorStops(_ colors:[CHCLT.Color]) {
		let count = colors.count
		let current = colorStops.count
		
		if count < current {
			colorStops.removeLast(current - count)
		}
		
		if count > current {
			colorStops += (current ..< count).map { _ in Viewable.Color(nil) }
		}
		
		if count != current {
			prepareLayout()
		}
		
		for index in 0 ..< count {
			colorStops[index].color = colors[index].platformColor
		}
	}
	
	func applyColorInput(_ input:Input, value:Double) {
		let colorCount = ceil(sliderCount.value)
		let count = Int(colorCount)
		let rotations = sliderHueRotations.value
		let chroma = sliderChroma.value
		let lumaLower = sliderLumaLower.value
		let lumaUpper = sliderLumaUpper.value
		
		let colors = chclt.luminanceRamp(
			hueStart:sliderHueStart.value,
			hueShift:count > 1 ? rotations / (colorCount - 1) : rotations,
			chroma:chroma,
			luminance:lumaLower, lumaUpper,
			count:count
		).map { CHCLT.Color(chclt, linear:$0) }
		
		applyColorStops(colors)
		applyColorToPanel(colors[0].platformColor)
		
		//let all = colors.flatMap { [CHCLT.LinearRGB.black, $0] }.dropFirst()
		let all = colors
		
		gradient.colorSpace = CHCLT.LinearRGB.colorSpace
		gradient.colors = all.compactMap { $0.color() }
	}
	
	@objc
	func colorSliderChanged(_ slider:PlatformSlider) {
		let input = Input(rawValue:slider.tag) ?? .unknown
		
		applyColorInput(input, value:slider.doubleValue)
	}
	
#if os(macOS)
	private var isAccessingColorPanel:Bool = false
	
	@objc
	func changeColor(_ panel:PlatformColorPanel) {
		guard !isAccessingColorPanel, let color = panel.color.chocolateColor() else { return }
		
		chclt = color.chclt
		isAccessingColorPanel = true
		sliderHueStart.value = color.hue
		sliderChroma.value = color.chroma
		sliderLumaLower.value = color.luma
		sliderLumaUpper.value = 1 - color.luma
		applyColorInput(.unknown, value:0.0)
		isAccessingColorPanel = false
	}
	
	func applyColorToPanel(_ color:PlatformColor) {
		guard !isAccessingColorPanel else { return }
		let panel = PlatformColorPanel.shared
		
		isAccessingColorPanel = true
		panel.isContinuous = false
		panel.color = color
		panel.isContinuous = true
		isAccessingColorPanel = false
	}
#else
	func applyColorToPanel(_ color:PlatformColor) {}
#endif
	
	func copyToPasteboard() {
		let colors = colorStops.compactMap { $0.color?.chocolateColor() }
		let web = colors.compactMap { $0.web() }.joined(separator:", ")
		let css = colors.compactMap { $0.css() }.joined(separator:", ")
		
		PlatformPasteboard.general.setString([web, css].joined(separator:"\n"))
	}
	
#if os(macOS)
	@objc func copy(_ sender:Any?) { copyToPasteboard() }
#else
	override func copy(_ sender:Any?) { copyToPasteboard() }
#endif
}

//	MARK: -

class ChocolateGradientLayer: CALayer {
	var descriptor = CAGradientLayer.Gradient(colors:[]) {
		didSet { setNeedsDisplay() }
	}
	
	var colors:[CGColor] {
		get { return descriptor.colors }
		set { descriptor.colors = newValue }
	}
	
	var direction:CAGradientLayer.Direction {
		get { return descriptor.direction }
		set { descriptor.direction = newValue }
	}
	
	func drawGradient(_ context:CGContext) {
		guard let gradient = descriptor.gradient() else { return }
		
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let box = CGRect(origin:.zero, size:bounds.size)
		let start = box.unit(descriptor.start)
		let end = box.unit(descriptor.end)
		
		switch descriptor.type {
		case .radial: context.drawRadialGradient(gradient, startCenter:start, startRadius:descriptor.startRadius, endCenter:end, endRadius:descriptor.endRadius, options:options)
		default: context.drawLinearGradient(gradient, start:start, end:end, options:options)
		}
	}
	
	override func draw(in ctx: CGContext) {
		drawGradient(ctx)
	}
	
	override func render(in ctx: CGContext) {
		draw(in:ctx)
	}
}

//	MARK: -

class ChocolateGradientView: PlatformTaggableView {
#if os(macOS)
	override func makeBackingLayer() -> CALayer { return ChocolateGradientLayer() }
#else
	override class var layerClass: AnyClass { return ChocolateGradientLayer.self }
#endif
	
	var gradientLayer:ChocolateGradientLayer! { return layer as? ChocolateGradientLayer }
	
	var descriptor:CAGradientLayer.Gradient {
		get { return gradientLayer.descriptor }
		set { gradientLayer.descriptor = newValue }
	}
}

//	MARK: -

class ChocolateGradientViewable: ViewablePositionable {
	typealias ViewType = ChocolateGradientView
	typealias Descriptor = CAGradientLayer.Gradient
	typealias Direction = CAGradientLayer.Direction
	
	struct Model {
		let tag:Int
		var gradient:Descriptor
		var intrinsicSize:CGSize
		
		init(tag:Int = 0, gradient:Descriptor, intrinsicSize:CGSize) {
			self.tag = tag
			self.gradient = gradient
			self.intrinsicSize = intrinsicSize
		}
	}
	
	weak var view:ViewType?
	var model:Model
	var tag:Int { get { return view?.tag ?? model.tag } }
	var gradientLayer:ChocolateGradientLayer? { return view?.gradientLayer }
	
	var descriptor:Descriptor {
		get { return gradientLayer?.descriptor ?? model.gradient }
		set { model.gradient = newValue; gradientLayer?.descriptor = newValue }
	}
	
	var colors:[CGColor] {
		get { return gradientLayer?.colors ?? model.gradient.colors }
		set { model.gradient.colors = newValue; gradientLayer?.colors = newValue }
	}
	
	var colorSpace:CGColorSpace? {
		get { return gradientLayer?.descriptor.colorSpace ?? model.gradient.colorSpace }
		set { model.gradient.colorSpace = newValue; gradientLayer?.descriptor.colorSpace = newValue }
	}
	
	var direction:Direction {
		get { return gradientLayer?.direction ?? model.gradient.direction }
		set { model.gradient.direction = newValue; gradientLayer?.direction = newValue }
	}
	
	var intrinsicSize:CGSize {
		get { return model.intrinsicSize }
		set { model.intrinsicSize = newValue; view?.invalidateIntrinsicContentSize() }
	}
	
	init(tag:Int = 0, gradient:Descriptor, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
		self.model = Model(tag:tag, gradient:gradient, intrinsicSize:intrinsicSize)
	}
	
	convenience init(tag:Int = 0, colors:[PlatformColor], locations:[NSNumber]? = nil, direction:Direction = .maxY, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
		self.init(tag:tag, gradient:Descriptor(colors:colors.map { $0.cgColor }, locations:locations, direction:direction), intrinsicSize:intrinsicSize)
	}
	
	func applyToView(_ view:ChocolateGradientView) {
		view.tag = model.tag
		view.prepareViewableColor(isOpaque:false)
		
		if let layer = view.gradientLayer {
			layer.descriptor = model.gradient
			layer.needsDisplayOnBoundsChange = true
		}
	}
	
	func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
		return Layout.Size(prefer:model.intrinsicSize, maximum:model.intrinsicSize)
	}
}
