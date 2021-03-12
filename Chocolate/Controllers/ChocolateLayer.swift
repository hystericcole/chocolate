//
//  ChocolateLayer.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import QuartzCore
import Foundation

class ChocolateLayerViewController: BaseViewController {
	enum Axis: Int {
		case chclt_h, chclt_c, chclt_l, rgb_r, rgb_g, rgb_b, hsb_h, hsb_s, hsb_b
		
		var mode:ChocolatePlaneLayer.Mode {
			return ChocolatePlaneLayer.Mode(model:ColorModel(rawValue:rawValue / 3) ?? .chclt, axis:rawValue % 3)
		}
		
		static var titles:[String] = ["CHCLT Hue", "CHCLT Chroma", "CHCLT Luma", "RGB Red", "RGB Green", "RGB Blue", "HSB Hue", "HSB Saturation", "HSB Brightness"]
	}
	
	let indicatorRadius:CGFloat = 33.5
	let chocolate = ChocolatePlaneView()
	let slider = ChocolateGradientSlider(value:0.5, action:#selector(sliderChanged))
	let picker = Viewable.Picker(titles:Axis.titles, attributes:Style.medium.attributes, select:1, action:#selector(axisChanged))
	let indicator = Viewable.Color(color:.black)
	var indicatorPosition = Layout.Align(Layout.empty)
	let group = Viewable.Group()
	let axis:Axis = .chclt_l
	
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Picker.title
		indicatorPosition.target = indicator.padding(0.5 - indicatorRadius.native).fixed(width:1, height:1)
		
		Common.Recognizer(.pan(false), target:self, action:#selector(indicatorPanned)).attachToView(chocolate)
		
		refreshIndicator(CGPoint(x:0.5, y:0.5))
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
		let chclt = chocolate.planeLayer?.chclt ?? .default
		let point = indicatorPosition.point()
		let linear = chocolate.mode.linearColors(chclt:chclt, hue:point.x.native, count:360)
		let colors = linear.compactMap { $0.color() }
		
		slider.track.colors = colors
	}
	
	func refreshIndicator(_ unit:CGPoint) {
		let chclt = chocolate.planeLayer?.chclt ?? .default
		let mode = chocolate.mode
		let borderContrasting = 0.0
		let indicatorColor:PlatformColor
		let borderColor:CGColor
		
		if mode.model == .chclt {
			let color = mode.linearColor(chclt:chclt, x:unit.x.native, y:1 - unit.y.native, z:slider.value)
			
			indicatorColor = color.color().platformColor
			borderColor = color.contrasting(chclt, value:borderContrasting).color()
		} else {
			let color = mode.platformColor(chclt:chclt, x:unit.x.native, y:1 - unit.y.native, z:slider.value)
			let border = color.cgColor.linearRGB?.contrasting(chclt, value:borderContrasting).color(colorSpace:color.cgColor.colorSpace)
			
			indicatorColor = color
			borderColor = border ?? PlatformColor.white.cgColor
		}
		
		indicator.color = indicatorColor
		
		if let layer = indicator.view?.layer {
			layer.border = CALayer.Border(width:3, radius:indicatorRadius, color:borderColor, clips:true)
		}
	}
	
	@objc
	func indicatorPanned(_ recognizer:PlatformPanGestureRecognizer) {
		guard recognizer.state == .changed else { return }
		
		let box = CGRect(origin:.zero, size:chocolate.bounds.size)
		let location = recognizer.location(in:chocolate)
		let unit = location / box.size
		
		indicatorPosition.horizontal = .fraction(unit.x.native)
		indicatorPosition.vertical = .fraction(unit.y.native)
		refreshIndicator(unit)
		refreshGradient()
		
		group.view?.ordered = layout()
	}
	
	@objc
	func sliderChanged() {
		chocolate.scalar = slider.value
		refreshIndicator(indicatorPosition.point())
		refreshGradient()
	}
	
	@objc
	func axisChanged() {
		chocolate.mode = Axis(rawValue:picker.select)?.mode ?? .standard
		refreshIndicator(indicatorPosition.point())
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
				primary:0,
				chocolate,
				indicatorPosition
			).padding(0).ignoringSafeBounds(isUnderTabBar ? .horizontal : nil)
		)
	}
	
	func copyToPasteboard() {
		guard let layer = chocolate.planeLayer else { return }
		
		let size = layer.bounds.size
		
		guard let mutable = MutableImage(size:size, scale:layer.contentsScale, opaque:true) else { return }
		
		mutable.context.unflip()
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
			trackBelow:Layout.empty,
			trackAbove:Layout.empty,
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
