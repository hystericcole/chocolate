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
			let model = ColorModel(rawValue:rawValue / 3) ?? .chclt
			let axis = rawValue % 3
			
			return ChocolatePlaneLayer.Mode(
				model:model,
				axis:axis
			)
		}
		
		static var titles:[String] = ["CHCLT Hue", "CHCLT Chroma", "CHCLT Luma", "RGB Red", "RGB Green", "RGB Blue", "HSB Hue", "HSB Saturation", "HSB Brightness"]
	}
	
	enum Constant {
		static let colorStyle = Style(font:.monospaceDigits, size:14, color:nil, alignment:.center)
	}
	
	struct IndicatorColors {
		let chclt:CHCLT
		let mode:ChocolatePlaneLayer.Mode
		let linearColor:CHCLT.LinearRGB
		let platformColor:PlatformColor
		let borderColor:CGColor
	}
	
	let indicatorRadius:CGFloat = 33.5
	let planeView = ChocolatePlaneView()
	let slider = ChocolateGradientSlider(value:0.5, action:#selector(sliderChanged))
	let picker = Viewable.Picker(titles:Axis.titles, attributes:Style.medium.attributes, select:1, action:#selector(axisChanged))
	let indicator = Viewable.Color(color:.black)
	var positionIndicator = Layout.Align(Layout.empty)
	let colorLabel = Constant.colorStyle.label("", maximumLines:1)
	let group = Viewable.Group()
	let axis:Axis = .chclt_l
	
	let lineContrast = Viewable.Color(color:.black, intrinsicSize:CGSize(width:1, height:1))
	let complement = Viewable.Color(color:.black)
	var positionLineContrast = Layout.Align(Layout.empty, horizontal:.fill)
	var positionComplement = Layout.Align(Layout.empty)
	
	var chclt:CHCLT { return planeView.planeLayer.chclt }
	
	var isDisplayed:Bool {
		guard let layer = indicator.view?.layer else { return false }
		
		return layer.cornerRadius > 0
	}
	
	override func prepare() {
		super.prepare()
		
		slider.value = planeView.scalar
		title = DisplayStrings.Picker.title
		positionIndicator.target = indicator.padding(0.5 - indicatorRadius.native).fixed(width:1, height:1)
		positionLineContrast.target = lineContrast
		positionComplement.target = complement.padding(0.5 - indicatorRadius.native * 0.5).fixed(width:1, height:1)
		
		Common.Recognizer.attachRecognizers([
			Common.Recognizer(.pan(false), target:self, action:#selector(indicatorPanned)),
			Common.Recognizer(.tap(false, 1), target:self, action:#selector(indicatorPanned))
		], to:planeView)
		
		applyIndicatorColors(computeIndicatorColors(CGPoint(x:0.5, y:0.5)))
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
		let hcl = chclt.hcl(linear:linearColor.vector)
		let contrast = linearColor.contrast(chclt)
		let symbol = chclt.contrast.lumaIsDark(hcl.z) ? "◐" : "◑"
		
		colorLabel.text = [
			formatter.string(hcl.x * 360.0) + "°",
			formatter.string(hcl.y * 100) + "%",
			formatter.string(hcl.z * 100) + "☼",
			formatter.string(contrast * 100) + symbol,
			//formatter.string(linearColor.saturation(chclt) * 100) + "➞",
			linearColor.display(chclt).web()
		].joined(separator:" • ")
	}
	
	func refreshGradient() {
		let point = positionIndicator.point()
		
		slider.applyModel(model:planeView.mode.model, axis:planeView.mode.axis, chclt:chclt, hue:point.x.native)
	}
	
	func computeIndicatorColors(_ unit:CGPoint) -> IndicatorColors {
		let chclt = self.chclt
		let mode = planeView.mode
		let borderContrasting = 0.0
		let coordinates = CHCLT.Scalar.vector3(unit.x.native, 1 - unit.y.native, slider.value)
		
		let linearColor:CHCLT.LinearRGB
		let platformColor:PlatformColor
		let borderColor:CGColor
		
		if mode.model == .chclt {
			linearColor = mode.linearColor(chclt:chclt, coordinates:coordinates)
			platformColor = CHCLT.Color(chclt, linearColor).platformColor
			borderColor = linearColor.contrasting(chclt, value:borderContrasting).applyChroma(chclt, value:linearColor.chroma(chclt)).color()
		} else {
			platformColor = mode.platformColor(chclt:chclt, coordinates:coordinates)
			linearColor = platformColor.chocolateColor(chclt:chclt)?.linearRGB ?? .white
			borderColor = linearColor.contrasting(chclt, value:borderContrasting).applyChroma(chclt, value:linearColor.chroma(chclt)).color()
		}
		
		return IndicatorColors(chclt:chclt, mode:mode, linearColor:linearColor, platformColor:platformColor, borderColor:borderColor)
	}
	
	func applyIndicatorColors(_ colors:IndicatorColors) {
		let chclt = colors.chclt
		let mode = colors.mode
		let linearComplement = colors.linearColor.applyChroma(chclt, value:-colors.linearColor.chroma(chclt))
		let coordinatesComplement = mode.model.coordinates(axis:mode.axis, color:linearComplement, chclt:chclt)
		let linearContrast = colors.linearColor.contrasting(chclt, value:0)
		
		indicator.color = colors.platformColor
		lineContrast.color = colors.platformColor
		positionLineContrast.vertical = .fraction(1 - linearContrast.luma(chclt))
		
		complement.color = linearComplement.color()?.platformColor
		positionComplement.horizontal = .fraction(coordinatesComplement.x)
		positionComplement.vertical = .fraction(1 - coordinatesComplement.y)
		
		applyColorDescription(chclt:chclt, linearColor:colors.linearColor)
		
		if let layer = indicator.view?.layer {
			layer.border = CALayer.Border(width:3, radius:indicatorRadius, color:colors.borderColor, clips:true)
		}
		
		if let layer = complement.view?.layer {
			layer.border = CALayer.Border(width:2, radius:indicatorRadius * 0.5, color:colors.borderColor, clips:true)
		}
	}
	
	func refreshContent(_ unit:CGPoint, animate:Bool) {
		let colors = computeIndicatorColors(unit)
		
		applyColorToPanel(colors.platformColor)
		
		if animate, let view = group.view {
			Common.animate(duration:0.25, animations:{
				self.applyIndicatorColors(colors)
				self.refreshGradient()
				
				view.ordered = self.layout()
				view.arrangeContents()
			})
		} else {
			applyIndicatorColors(colors)
			refreshGradient()
			
			group.view?.ordered = layout()
		}
	}
	
	@objc
	func indicatorPanned(_ recognizer:PlatformGestureRecognizer) {
		switch recognizer.state {
		case .recognized, .began, .changed: break
		default: return
		}
		
		let box = CGRect(origin:.zero, size:planeView.bounds.size)
		let location = recognizer.location(in:planeView)
		let unbound = location / box.size
		let unit = CGPoint(x:min(max(0, unbound.x), 1), y:min(max(0, unbound.y), 1))
		
		positionIndicator.horizontal = .fraction(unit.x.native)
		positionIndicator.vertical = .fraction(unit.y.native)
		refreshContent(unit, animate:recognizer is PlatformTapGestureRecognizer)
	}
	
	@objc
	func sliderChanged() {
		planeView.scalar = slider.value
		refreshContent(positionIndicator.point(), animate:!slider.isTracking)
	}
	
	@objc
	func axisChanged() {
		let axis = Axis(rawValue:picker.select)
		
		planeView.mode = axis?.mode ?? .standard
		refreshContent(positionIndicator.point(), animate:isDisplayed)
		
		lineContrast.view?.isHidden = axis != .chclt_c && axis != .chclt_h
	}
	
#if os(macOS)
	private var isAccessingColorPanel:Bool = false
	
	@objc
	func changeColor(_ panel:PlatformColorPanel) {
		guard !isAccessingColorPanel, let color = panel.color.chocolateColor() else { return }
		
		isAccessingColorPanel = true
		planeView.planeLayer.chclt = color.chclt
		applyColor(color.normalize(), animated:false)
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
	
	func applyColor(_ color:CHCLT.Color, animated:Bool) {
		let mode = planeView.mode
		let coordinates = mode.model.coordinates(axis:mode.axis, color:color)
		let unit = CGPoint(x:coordinates.x, y:1 - coordinates.y)
		let z = min(max(0, round(coordinates.z * 0x1p20) * 0x1p-20), 1)
		
		slider.value = z
		planeView.scalar = z
		positionIndicator.horizontal = .fraction(coordinates.x)
		positionIndicator.vertical = .fraction(1 - coordinates.y)
		refreshContent(unit, animate:animated)
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
				positionLineContrast,
				positionComplement,
				positionIndicator
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
