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
	
	enum Constant {
		static let colorStyle = Style(font:.monospaceDigits, size:14, color:nil, alignment:.center)
	}
	
	let indicatorRadius:CGFloat = 33.5
	let planeView = ChocolatePlaneView()
	let slider = ChocolateGradientSlider(value:0.5, action:#selector(sliderChanged))
	let picker = Viewable.Picker(titles:Axis.titles, attributes:Style.medium.attributes, select:1, action:#selector(axisChanged))
	let indicator = Viewable.Color(color:.black)
	var indicatorPosition = Layout.Align(Layout.empty)
	let colorLabel = Constant.colorStyle.label("")
	let group = Viewable.Group()
	let axis:Axis = .chclt_l
	
	override func prepare() {
		super.prepare()
		
		slider.value = planeView.scalar
		title = DisplayStrings.Picker.title
		indicatorPosition.target = indicator.padding(0.5 - indicatorRadius.native).fixed(width:1, height:1)
		
		Common.Recognizer(.pan(false), target:self, action:#selector(indicatorPanned)).attachToView(planeView)
		
		refreshIndicator(CGPoint(x:0.5, y:0.5))
	}
	
	override func loadView() {
		group.content = layout()
		view = group.lazyView
		group.view?.attachViewController(self)
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		axisChanged()
	}
	
	func applyColorDescription(chclt:CHCLT, linearColor:CHCLT.LinearRGB) {
		let formatter = NumberFormatter(fractionDigits:1 ... 1)
		let hcl = chclt.hcl(linearColor.vector)
		let contrast = linearColor.contrast(chclt)
		let symbol = hcl.z < chclt.contrast.mediumLuminance ? "◐" : "◑"
		
		colorLabel.text = [
			formatter.string(from:hcl.x * 360.0 as NSNumber)! + "°",
			formatter.string(from:hcl.y * 100 as NSNumber)! + "%",
			formatter.string(from:hcl.z * 100 as NSNumber)! + "☼",
			formatter.string(from:contrast * 100 as NSNumber)! + symbol
		].joined(separator:" • ")
	}
	
	func refreshGradient() {
		let chclt = planeView.planeLayer?.chclt ?? .default
		let point = indicatorPosition.point()
		
		slider.applyModel(model:planeView.mode.model, axis:planeView.mode.axis, chclt:chclt, hue:point.x.native)
	}
	
	func refreshIndicator(_ unit:CGPoint) {
		let chclt = planeView.planeLayer?.chclt ?? .default
		let mode = planeView.mode
		let borderContrasting = 0.0
		let coordinates = CHCLT.Scalar.vector3(unit.x.native, 1 - unit.y.native, slider.value)
		
		let linearColor:CHCLT.LinearRGB
		let platformColor:PlatformColor
		let borderColor:CGColor
		
		if mode.model == .chclt {
			linearColor = mode.linearColor(chclt:chclt, coordinates:coordinates)
			platformColor = linearColor.color().platformColor
			borderColor = linearColor.contrasting(chclt, value:borderContrasting).color()
		} else {
			platformColor = mode.platformColor(chclt:chclt, coordinates:coordinates)
			linearColor = platformColor.cgColor.linearRGB ?? .white
			borderColor = linearColor.contrasting(chclt, value:borderContrasting).color(colorSpace:platformColor.cgColor.colorSpace)
		}
		
		indicator.color = platformColor
		applyColorDescription(chclt:chclt, linearColor:linearColor)
		
		if let layer = indicator.view?.layer {
			layer.border = CALayer.Border(width:3, radius:indicatorRadius, color:borderColor, clips:true)
		}
	}
	
	@objc
	func indicatorPanned(_ recognizer:PlatformPanGestureRecognizer) {
		guard recognizer.state == .changed else { return }
		
		let box = CGRect(origin:.zero, size:planeView.bounds.size)
		let location = recognizer.location(in:planeView)
		let unbound = location / box.size
		let unit = CGPoint(x:min(max(0, unbound.x), 1), y:min(max(0, unbound.y), 1))
		
		indicatorPosition.horizontal = .fraction(unit.x.native)
		indicatorPosition.vertical = .fraction(unit.y.native)
		refreshIndicator(unit)
		refreshGradient()
		
		group.view?.ordered = layout()
	}
	
	@objc
	func sliderChanged() {
		planeView.scalar = slider.value
		refreshIndicator(indicatorPosition.point())
		refreshGradient()
	}
	
	@objc
	func axisChanged() {
		planeView.mode = Axis(rawValue:picker.select)?.mode ?? .standard
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
			colorLabel.padding(horizontal:20, vertical:0),
			Layout.Overlay(
				horizontal:.fill,
				vertical:.fill,
				primary:0,
				planeView,
				indicatorPosition
			).padding(0).ignoringSafeBounds(isUnderTabBar ? .horizontal : nil)
		)
	}
	
	func copyToPasteboard() {
		guard let layer = planeView.planeLayer else { return }
		
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
