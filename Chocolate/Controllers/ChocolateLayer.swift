//
//  ChocolateLayer.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import QuartzCore
import Foundation

class ChocolateLayer: CALayer {
	enum ColorModel: Int {
		case chclt, rgb, hsb
	}
	
	struct Mode {
		static let standard = Mode(model:.chclt, axis:0)
		
		var model:ColorModel
		var axis:Int
		
		func colors(chocolate:CHCLT, color:CHCLT.LinearRGB, count:Int) -> [CHCLT.LinearRGB] {
			switch (model, axis % 3) {
			case (.rgb, 0): return [.black, .red]
			case (.rgb, 1): return [.black, .green]
			case (.rgb, _): return [.black, .blue]
			case (.hsb, 0): return (0 ..< count).map { CHCLT.LinearRGB(chocolate.linear(DisplayRGB.hexagonal(hue:Double($0) / Double(count - 1), saturation:1, brightness:1))) }
			case (.hsb, 1): return [.white, CHCLT.LinearRGB(chocolate.linear(DisplayRGB.hexagonal(hue:color.display(chocolate).hsb().hue, saturation:1, brightness:1)))]
			case (.hsb, _): return [.black, CHCLT.LinearRGB(chocolate.linear(DisplayRGB.hexagonal(hue:color.display(chocolate).hsb().hue, saturation:1, brightness:1)))]
			case (.chclt, 0): return chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count).map { CHCLT.LinearRGB($0).applyLuminance(chocolate, value:0.5) }
			case (.chclt, 1): return [color.saturated().applyChroma(chocolate, value:0), color.saturated().applyChroma(chocolate, value:1)]
			case (.chclt, _): return [.black, .white]
			}
		}
	}
	
	var chocolate:CHCLT = CHCLT.default
	var colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear) ?? CGColorSpaceCreateDeviceRGB()
	var scalar:CHCLT.Scalar = 0.5 { didSet { setNeedsDisplay() } }
	var mode = Mode.standard { didSet { setNeedsDisplay() } }
	
	func colorsForMode(mode:Mode, color:CHCLT.LinearRGB, count:Int = 360) -> [CHCLT.LinearRGB] {
		return mode.colors(chocolate:chocolate, color:color, count:count)
	}
	
	func colorsForChroma(primary:CHCLT.LinearRGB, chroma:CHCLT.Scalar, drawSpace:CGColorSpace) -> CGGradient? {
		let color = primary.applyChroma(chocolate, value:chroma)
		let value = color.luminance(chocolate)
		let locations:[CGFloat] = [0, CGFloat(1 - value), 1]
		let colors:[CGColor] = [CHCLT.LinearRGB(.one), color, CHCLT.LinearRGB(.zero)].compactMap { $0.color(colorSpace:colorSpace, alpha:1) }
		
		return CGGradient(colorsSpace:drawSpace, colors:colors as CFArray, locations:locations)
	}
	
	func drawCHCLT(_ context:CGContext, box:CGRect, axis:Int, scalar:CHCLT.Linear) {
		let drawSpace = colorSpace
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		let isFlipped = (axis / 3) & 1 != 0
		let count = Int(isFlipped ? box.size.height : box.size.width)
		let size = isFlipped ? CGSize(width:box.size.width, height:1) : CGSize(width:1, height:box.size.height)
		
		switch axis % 3 {
		case 0:	//	scalar is hue
			let primary = CHCLT.LinearRGB(chocolate, hue:scalar)
			
			for index in 0 ..< count {
				let origin = isFlipped ? CGPoint(x:box.origin.x, y:box.origin.y + CGFloat(index)) : CGPoint(x:box.origin.x + CGFloat(index), y:box.origin.y)
				let stripe = CGRect(origin:origin, size:size)
				let chroma = CHCLT.Scalar(index) / CHCLT.Scalar(count - 1)
				
				guard let gradient = colorsForChroma(primary:primary, chroma:chroma, drawSpace:drawSpace) else { continue }
				
				context.clip(to:stripe)
				context.drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
				context.resetClip()
			}
		case 1:	//	scalar is chroma
			let hues = chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			
			for index in 0 ..< count {
				let origin = isFlipped ? CGPoint(x:box.origin.x, y:box.origin.y + CGFloat(index)) : CGPoint(x:box.origin.x + CGFloat(index), y:box.origin.y)
				let stripe = CGRect(origin:origin, size:size)
				
				guard let gradient = colorsForChroma(primary:CHCLT.LinearRGB(hues[index]), chroma:scalar, drawSpace:drawSpace) else { continue }
				
				context.clip(to:stripe)
				context.drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
				context.resetClip()
			}
		default:	//	scalar is luminance
			let hues = chocolate.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
			let gray = CHCLT.LinearRGB(gray:scalar)
			let huesWithLuminance = hues.compactMap { CHCLT.LinearRGB($0).applyLuminance(chocolate, value:scalar).color(colorSpace:colorSpace, alpha:1) }
			let desaturate = [gray.color(colorSpace:colorSpace, alpha:0)!, gray.color(colorSpace:colorSpace, alpha:1)!]
			
			context.clip(to:box)
			
			if let gradient = CGGradient(colorsSpace:drawSpace, colors:huesWithLuminance as CFArray, locations:nil) {
				context.setBlendMode(.copy)
				context.drawLinearGradient(gradient, start:start, end:isFlipped ? downEnd : overEnd, options:options)
			}
			
			if let gradient = CGGradient(colorsSpace:drawSpace, colors:desaturate as CFArray, locations:nil) {
				context.setBlendMode(.normal)
				context.drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
			}
			
			context.resetClip()
		}
	}
	
	func drawHSB(_ context:CGContext, box:CGRect, axis:Int, scalar:CHCLT.Linear) {
		let colorSpace = CGColorSpace(name:CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
		let drawSpace = CGColorSpace(name:CGColorSpace.sRGB) ?? colorSpace
		
		context.clip(to:box)
		context.drawPlaneFromCubeHSB(box:box, axis:axis, scalar:CGFloat(scalar), colorSpace:colorSpace, drawSpace:drawSpace)
		context.resetClip()
	}
	
	func drawRGB(_ context:CGContext, box:CGRect, axis:Int, scalar:CHCLT.Linear) {
		let colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear) ?? CGColorSpaceCreateDeviceRGB()
		let drawSpace = CGColorSpace(name:CGColorSpace.sRGB) ?? colorSpace
		
		context.clip(to:box)
		context.drawPlaneFromCubeRGB(box:box, axis:axis, scalar:CGFloat(scalar), colorSpace:colorSpace, drawSpace:drawSpace)
		context.resetClip()
	}
	
	override func draw(in ctx: CGContext) {
		let box = CGRect(origin:.zero, size:bounds.size)
		
		switch mode.model {
		case .chclt: drawCHCLT(ctx, box:box, axis:mode.axis, scalar:scalar)
		case .rgb: drawRGB(ctx, box:box, axis:mode.axis, scalar:scalar)
		case .hsb: drawHSB(ctx, box:box, axis:mode.axis, scalar:scalar)
		}
	}
	
	override func render(in ctx: CGContext) {
		draw(in:ctx)
	}
}

//	MARK: -

class ChocolateLayerView: BaseView {
#if os(macOS)
	override class var layerClass:CALayer.Type { return ChocolateLayer.self }
	override func viewDidEndLiveResize() { super.viewDidEndLiveResize(); refresh() }
	override var wantsUpdateLayer:Bool { return true }
	
	func refresh() { needsDisplay = true }
#else
	override class var layerClass:AnyClass { return ChocolateLayer.self }
	
	func refresh() { setNeedsDisplay() }
#endif
	
	var chocolateLayer:ChocolateLayer? { return layer as? ChocolateLayer }
	
	var mode:ChocolateLayer.Mode { get { return chocolateLayer?.mode ?? .standard } set { chocolateLayer?.mode = newValue; refresh() } }
	var scalar:CHCLT.Scalar { get { return chocolateLayer?.scalar ?? 0 } set { chocolateLayer?.scalar = newValue } }
	
	override func prepare() { super.prepare(); refresh() }
}

//	MARK: -

class ChocolateImageView: PlatformImageView {
	var chocolate:CHCLT = CHCLT.default
	var colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear) ?? CGColorSpaceCreateDeviceRGB()
	var scalar:CHCLT.Scalar = 0.5 { didSet { refreshSoon() } }
	var axis = 0 { didSet { refreshSoon() } }
	var mutableImage:MutableImage?
	var isCurrent = false
	var isRefreshing = false
	var parameters:MutableImage.Parameters { return MutableImage.Parameters(space:colorSpace, size:bounds.size, scale:1, opaque:true) }
	override var intrinsicContentSize:CGSize { return CGSize(square:-1) }
	
	func refresh() {
		guard !isRefreshing else { return }
		
		let parameters = self.parameters
		let isEquivalent = mutableImage?.isEquivalent(parameters:parameters) ?? false
		
		guard !isCurrent || !isEquivalent else { return }
		
		MutableImage.manage(image:&mutableImage, parameters:parameters)
		
		guard let mutable = mutableImage else { return }
		
		isCurrent = true
		isRefreshing = true
		
		DispatchQueue.userInitiated.async {
			CHCLT.LinearRGB.drawPlaneFromCubeHCL(self.chocolate, axis:self.axis, value:self.scalar, image:mutable)
			
			DispatchQueue.main.async {
				self.refreshed(mutable)
			}
		}
	}
	
#if os(macOS)
	func refreshed(_ mutable:MutableImage) {
		imageScaling = .scaleAxesIndependently
		image = PlatformImage(cgImage:mutable.image.copy() ?? mutable.image, size:mutable.size)
		isRefreshing = false
	}
	
	func refreshSoon() {
		isCurrent = false
		refresh()
	}
	
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		if window != nil { refresh() }
		
		allowsCutCopyPaste = true
		isEditable = true
	}
	
	override func viewDidEndLiveResize() {
		super.viewDidEndLiveResize()
		refresh()
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		refresh()
	}
	
	func refreshed(_ mutable:MutableImage) {
		contentMode = .scaleToFill
		image = PlatformImage(cgImage:mutable.image.copy() ?? mutable.image)
		isRefreshing = false
	}
	
	func refreshSoon() {
		isCurrent = false
		setNeedsLayout()
	}
#endif
}

//	MARK: -

class ChocolateLayerViewController: BaseViewController {
	enum Axis: Int {
		case chclt_h, chclt_c, chclt_l, rgb_r, rgb_g, rgb_b, hsb_h, hsb_s, hsb_b
		
		var mode:ChocolateLayer.Mode {
			return ChocolateLayer.Mode(model:ChocolateLayer.ColorModel(rawValue:rawValue / 3) ?? .chclt, axis:rawValue % 3)
		}
		
		static var titles:[String] = ["CHCLT Hue", "CHCLT Chroma", "CHCLT Luma", "RGB Red", "RGB Green", "RGB Blue", "HSB Hue", "HSB Saturation", "HSB Brightness"]
	}
	
	let chocolate = ChocolateLayerView()
	let slider = ChocolateGradientSlider(value:0.5, action:#selector(sliderChanged))
	let picker = Viewable.Picker(titles:Axis.titles, attributes:Style.medium.attributes, select:1, action:#selector(axisChanged))
	let indicator = Viewable.Shape(style:Viewable.Shape.Style(fill:nil))
	let group = Viewable.Group(content:Layout.EmptySpace())
	let axis:Axis = .chclt_l
	
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Picker.title
		
		Common.Recognizer(.pan(false), target:self, action:#selector(indicatorPanned)).attachToView(chocolate)
	}
	
	override func loadView() {
		slider.value = chocolate.scalar
		group.content = layout()
		view = group.lazyView
		group.view?.attachViewController(self)
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		axisChanged()
	}
	
	func refreshGradient() {
		let chclt = chocolate.chocolateLayer?.chocolate ?? .default
		let linear = chocolate.mode.colors(chocolate:chclt, color:.green, count:360)
		let colors = linear.compactMap { $0.color() }
		
		slider.track.colors = colors
	}
	
	@objc
	func indicatorPanned(_ recognizer:PlatformPanGestureRecognizer) {
		
	}
	
	@objc
	func sliderChanged() {
		chocolate.scalar = slider.value
		refreshGradient()
	}
	
	@objc
	func axisChanged() {
		chocolate.mode = Axis(rawValue:picker.select)?.mode ?? .standard
		refreshGradient()
	}
	
	func layout() -> Positionable {
		return Layout.Vertical(alignment:.fill, position:.stretch,
			Layout.Horizontal(
				spacing:20,
				position:.stretch,
				slider.fraction(width:0.75, minimumWidth:66, height:nil),
				picker.fixed(width:160).limiting(height:30 ... 80)
			).padding(horizontal:20, vertical:10),
			Layout.Overlay(
				horizontal:.fill,
				vertical:.fill,
				primary:1,
				indicator,
				chocolate.ignoringSafeBounds(isUnderTabBar ? .horizontal : nil)
			)
		)
	}
	
	func copyToPasteboard() {
		guard let layer = chocolate.chocolateLayer else { return }
		
		let size = layer.bounds.size
		
		guard let mutable = MutableImage(size:size, scale:layer.contentsScale, opaque:true) else { return }
		
		layer.draw(in:mutable.context)
		
		guard let data = mutable.image.pngData() else { return }
		
		PlatformPasteboard.general.setPNG(data)
	}
	
#if os(macOS)
	@objc func copy(_ sender:Any?) { copyToPasteboard() }
#else
	override func copy(_ sender:Any?) { copyToPasteboard() }
#endif
}

//	MARK: -

extension CGContext {
	func drawPlaneFromCubeHSB(box:CGRect, axis:Int, scalar:CGFloat, colorSpace:CGColorSpace, drawSpace:CGColorSpace) {
		let colorSpace = self.colorSpace ?? colorSpace
		let drawSpace = self.colorSpace ?? drawSpace
		
		let overColors:[CGColor]
		let downColors:[CGColor]
		let mode:CGBlendMode
		let isFlipped = (axis / 3) & 1 != 0
		let count = Int(isFlipped ? box.size.height : box.size.width)
		
		switch axis % 3 {
		case 0:
			let gray = DisplayRGB(hexagonal:scalar.native, saturation:0, brightness:1)
			let color = DisplayRGB(hexagonal:scalar.native, saturation:1, brightness:1)
			
			overColors = [gray, color].compactMap { $0.color(colorSpace:colorSpace) }
			downColors = [DisplayRGB.white, DisplayRGB.black].compactMap { $0.color(colorSpace:colorSpace) }
			mode = .multiply
		case 1:
			overColors = (0 ..< count).compactMap { DisplayRGB(hexagonal:Double($0) / Double(count - 1), saturation:scalar.native, brightness:1).color(colorSpace:colorSpace) }
			downColors = [DisplayRGB.white, DisplayRGB.black].compactMap { $0.color(colorSpace:colorSpace) }
			mode = .multiply
		default:
			let gray = DisplayRGB(hexagonal:0, saturation:0, brightness:scalar.native, alpha:1)
			let clear = DisplayRGB(hexagonal:0, saturation:0, brightness:scalar.native, alpha:0)
			
			overColors = (0 ..< count).compactMap { DisplayRGB(hexagonal:Double($0) / Double(count - 1), saturation:1, brightness:scalar.native).color(colorSpace:colorSpace) }
			downColors = [clear, gray].compactMap { $0.color(colorSpace:colorSpace) }
			mode = .normal
		}
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:overColors as CFArray, locations:nil) {
			setBlendMode(.copy)
			drawLinearGradient(gradient, start:start, end:isFlipped ? downEnd : overEnd, options:options)
		}
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:downColors as CFArray, locations:nil) {
			setBlendMode(mode)
			drawLinearGradient(gradient, start:start, end:isFlipped ? overEnd : downEnd, options:options)
		}
	}
	
	func drawPlaneFromCubeRGB(box:CGRect, axis:Int, scalar:CGFloat, colorSpace:CGColorSpace, drawSpace:CGColorSpace) {
		let colorSpace = self.colorSpace ?? colorSpace
		let drawSpace = self.colorSpace ?? drawSpace
		
		let s = CGFloat(scalar)
		var c0:[CGFloat] = [0, 0, 0, 1]
		var c1:[CGFloat] = [0, 0, 0, 1]
		var c2:[CGFloat] = [0, 0, 0, 1]
		var c3:[CGFloat] = [0, 0, 0, 1]
		
		switch axis % 6 {
		case  0: c1[1] = 1; c3[2] = 1; c3[0] = s; c2[0] = s
		case  1: c1[2] = 1; c3[0] = 1; c3[1] = s; c2[1] = s
		case  2: c1[0] = 1; c3[1] = 1; c3[2] = s; c2[2] = s
		case  3: c1[2] = 1; c3[1] = 1; c3[0] = s; c2[0] = s
		case  4: c1[0] = 1; c3[2] = 1; c3[1] = s; c2[1] = s
		default: c1[1] = 1; c3[0] = 1; c3[2] = s; c2[2] = s
		}
		
		guard
			let color0 = CGColor(colorSpace:colorSpace, components:&c0),
			let color1 = CGColor(colorSpace:colorSpace, components:&c1),
			let color2 = CGColor(colorSpace:colorSpace, components:&c2),
			let color3 = CGColor(colorSpace:colorSpace, components:&c3)
		else { return }
		
		let overColors:[CGColor]
		let downColors:[CGColor]
		
		switch axis / 6 % 4 {
		case  0: overColors = [color0, color1]; downColors = [color3, color2]
		case  1: overColors = [color3, color2]; downColors = [color1, color0]
		case  2: overColors = [color1, color0]; downColors = [color2, color3]
		default: overColors = [color2, color3]; downColors = [color0, color1]
		}
		
		let start = box.origin
		let overEnd = CGPoint(x:box.maxX, y:box.minY)
		let downEnd = CGPoint(x:box.minX, y:box.maxY)
		let options:CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:overColors as CFArray, locations:nil) {
			setBlendMode(.copy)
			drawLinearGradient(gradient, start:start, end:overEnd, options:options)
		}
		
		if let gradient = CGGradient(colorsSpace:drawSpace, colors:downColors as CFArray, locations:nil) {
			setBlendMode(.lighten)
			drawLinearGradient(gradient, start:start, end:downEnd, options:options)
		}
	}
}

//	MARK: -

class ChocolateGradientSlider: Viewable.Group {
	var layout:Layout.ThumbTrackHorizontal
	var thumb = Viewable.Color(color:PlatformColor(white:1, alpha:0.0))
	var track = Viewable.Gradient(colors:[], direction:.right)
	var action:Selector
	var radius:CGFloat
	weak var target:AnyObject?
	
	enum Constant {
		static let trackBorderWidth:CGFloat = 1.0
		static let thumbBorderWidth:CGFloat = 3.0
		static let trackInset = thumbBorderWidth - trackBorderWidth
	}
	
	struct InsetGradient: PositionableWithTarget {
		let target:Positionable
		let inset:CGFloat
		
		func applyPositionableFrame(_ frame: CGRect, context: Layout.Context) {
			target.applyPositionableFrame(frame, context:context)
			
			let gradients = target.orderablePositionables(environment:context.environment, order:.existing)
				.compactMap { $0 as? PlatformView }
				.compactMap { $0.layer as? CAGradientLayer }
			
			for layer in gradients {
				layer.applyDirection(.right, inset:inset / layer.bounds.size.width)
			}
		}
	}
	
	var value:Double {
		get { return layout.thumbPosition }
		set { layout.thumbPosition = newValue; view?.ordered = layout }
	}
	
	init(value:Double = 0.0, target:AnyObject? = nil, action:Selector, radius:CGFloat = 22) {
		let diameter = radius.native * 2
		let gradient = InsetGradient(target:track, inset:radius - Constant.trackInset)
		
		self.radius = radius
		self.action = action
		self.target = target
		
		self.layout = Layout.ThumbTrackHorizontal(
			thumb:thumb.fixed(width:diameter, height:diameter),
			trackBelow:Layout.EmptySpace(),
			trackAbove:Layout.EmptySpace(),
			trackWhole:gradient.rounded(),
			thumbPosition:value,
			trackInset:Layout.EdgeInsets(uniform:Constant.trackInset.native)
		)
		
		super.init(content:layout)
	}
	
	override func attachToView(_ view: ViewableGroupView) {
		super.attachToView(view)
		
		let thumbBorderColor = PlatformColor.black
		let trackBorderColor = PlatformColor.lightGray
		
		track.border(CALayer.Border(width:Constant.trackBorderWidth, radius:radius, color:trackBorderColor.cgColor))
		thumb.border(CALayer.Border(width:Constant.thumbBorderWidth, radius:radius, color:thumbBorderColor.cgColor))
		
		Common.Recognizer(.pan(false), target:self, action:#selector(recognizerPanned)).attachToView(view)
	}
	
	@objc
	func recognizerPanned(_ recognizer:PlatformPanGestureRecognizer) {
		guard recognizer.state == .changed, let view = view else { return }
		
		let box = CGRect(origin:.zero, size:view.bounds.size)
		let groove = box.insetBy(dx:radius, dy:0)
		let location = recognizer.location(in:view)
		let offset = location.x.native - groove.origin.x.native
		let fraction = min(max(0, offset / groove.width.native), 1)
		
		guard value != fraction else { return }
		
		value = fraction
		
		PlatformApplication.shared.sendAction(action, to:target, from:view)
	}
}
