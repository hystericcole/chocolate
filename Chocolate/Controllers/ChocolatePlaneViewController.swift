//
//  ChocolatePlaneViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import QuartzCore
import Foundation

class ChocolatePlaneViewController: BaseViewController {
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
		
		slider.applyModel(model:chocolate.mode.model, axis:chocolate.mode.axis, chclt:chclt, hue:point.x.native)
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
