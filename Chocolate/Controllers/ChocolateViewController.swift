//
//  ChocolateViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation
import simd

class ChocolateViewController: BaseViewController {
	typealias Strings = DisplayStrings.Chocolate
	
	class Model {
		static let deriveCount = 4
		static let sampleCount = 3
		
		var chocolate:CHCLT = ColorSpace.default.chocolate
		var primary = CHCLT.Color(ColorSpace.default.chocolate, red:0.2, green:0.4, blue:0.6, alpha:1.0)
		var foregrounds:[CHCLT.Color] = []
	}
	
	enum Input: Int {
		case unknown, red, green, blue, hue, chroma, luma
	}
	
	enum ColorSpace: Int {
		case sRGB, sRGBpower, displayP3, g18, y601, y601power, y709, y709power, y2020, adobeRGB, theaterP3, romm
		
		var chocolate:CHCLT {
			switch self {
			case .sRGB: return CHCLT_sRGB.standard
			case .sRGBpower: return CHCLT_Pure.sRGB
			case .displayP3: return CHCLT_sRGB.displayP3
			case .g18: return CHCLT_sRGB.g18
			case .y601: return CHCLT_BT.y601
			case .y601power: return CHCLT_Pure.y601
			case .y709: return CHCLT_BT.y709
			case .y709power: return CHCLT_Pure.y709
			case .y2020: return CHCLT_BT.y2020
			case .adobeRGB: return CHCLT_Pure.adobeRGB
			case .theaterP3: return CHCLT_Pure.dciP3
			case .romm: return CHCLT_ROMM.standard
			}
		}
		
		static let `default` = sRGB
		static var titles:[String] = ["sRGB", "sRGBⁿ", "apple", "G18", "y601", "y601ⁿ", "y709", "y709ⁿ", "y2020", "adobe", "dciP3", "romm"]
	}
	
	var model = Model()
	var previousValue:Double = 0
	var previousInput:Input = .luma
	var stableChroma:Bool = true
	
	let group = Viewable.Group()
	let sampleScroll = Viewable.Scroll()
	let foregrounds = Viewable.Group()
	let spacePicker = Viewable.Picker(titles:ColorSpace.titles, attributes:Style.medium.attributes, select:0, action:#selector(colorSpaceChanged))
	let sliderRed = Viewable.Slider(tag:Input.red.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.red)
	let sliderGreen = Viewable.Slider(tag:Input.green.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.green)
	let sliderBlue = Viewable.Slider(tag:Input.blue.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.blue)
	let sliderHue = Viewable.Slider(tag:Input.hue.rawValue, action:#selector(colorSliderChanged))
	let sliderChroma = Viewable.Slider(tag:Input.chroma.rawValue, action:#selector(colorSliderChanged))
	let sliderLuma = Viewable.Slider(tag:Input.luma.rawValue, action:#selector(colorSliderChanged))
	let sliderDeriveContrast = Viewable.Slider(value:0.5, range:-2 ... 2, action:#selector(deriveChanged))
	let sliderDeriveChroma = Viewable.Slider(value:0.0, range:-2 ... 2, action:#selector(deriveChanged))
	let stringRed = Style.small.label("")
	let stringGreen = Style.small.label("")
	let stringBlue = Style.small.label("")
	let stringHue = Style.small.label("")
	let stringChroma = Style.small.label("")
	let stringLuma = Style.small.label("")
	let stringDeriveContrast = Style.small.label("")
	let stringDeriveChroma = Style.small.label("")
	let stringPrimaryContrast = Style.medium.label("")
	let stringPrimary = Style.caption.label(Strings.primary)
	let stringForeground = Style.caption.label(Strings.foreground)
	let stringWeb = Style.webColor.label("")
	let colorBox = Viewable.Color(color:nil)
	let colorCircleBackground = Viewable.Color(color:nil)
	let colorCircleCenter = Viewable.Color(color:nil)
	let colorCircles:[Viewable.Color] = (0 ..< 12).map { _ in Viewable.Color(color:nil) }
	var samples:[Sample] = []
	
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Chocolate.title
	}
	
	override func loadView() {
		applySampleCount(Model.sampleCount)
		view = group.lazyView
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		prepareLayout()
		applyColorInput(.unknown, value:0)
	}
	
	func applySampleCount(_ count:Int) {
		let wasCount = samples.count
		
		if wasCount > count {
			samples.removeLast(wasCount - count)
		}
		
		if wasCount < count {
			samples += (wasCount ..< count).map { _ in Sample(model) }
		}
		
		if wasCount == 0 {
			for index in 0 ..< count {
				samples[index].sliderContrast.value = 2.0 * Double(count - index) / Double(count + 1) - 1
				samples[index].sliderChroma.value = 0.25 * Double(index) / Double(count - 1)
			}
		}
		
		if wasCount != count {
			applyColor(model.primary)
			
			if group.view != nil {
				prepareLayout()
			}
		}
	}
	
	func generateForegrounds(primary:CHCLT.Color, contrast:Double, chroma:Double, count:Int) -> [CHCLT.Color] {
		let limit = Double(count - 1)
		
		return (0 ..< count).map { index in
			let n = Double(index) / limit
			let s = 1 - n * (1 - chroma)
			let c = 1 - n * (1 - contrast)
			
			return primary.scaleContrast(c).scaleChroma(s)
		}
	}
	
	func applyColorToCircle(_ color:CHCLT.Color) {
		let hues:[CHCLT.LinearRGB] = [.red, .orange, .yellow, .chartreuse, .green, .spring, .cyan, .azure, .blue, .violet, .magenta, .rose]
		let chocolate = model.chocolate
		let primary = color
		let contrast = primary.contrast
		
		colorCircleCenter.color = primary.platformColor
		colorCircleBackground.color = primary.opposing(1).platformColor
		
		for index in colorCircles.indices {
			colorCircles[index].color = hues[index]
				.matchLuminance(chocolate, to:primary.linearRGB, by:0.625 - 0.125 * contrast)
				.matchChroma(chocolate, to:primary.linearRGB, by:0.75 - 0.5 * contrast)
				.huePushed(chocolate, from:primary.linearRGB, minimumShift:0.05)
				.color()?.platformColor
		}
	}
	
	func applyColor(_ color:CHCLT.Color) {
		colorBox.color = color.platformColor
		
		let formatter = NumberFormatter()
		let contrast = sliderDeriveContrast.value
		let chroma = sliderDeriveChroma.value
		
		model.foregrounds = generateForegrounds(primary:color, contrast:contrast, chroma:chroma, count:Model.deriveCount)
		
		for index in samples.indices {
			samples[index].index = index
			samples[index].applyColor()
		}
		
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 3
		stringRed.text = formatter.string(color.red)
		stringGreen.text = formatter.string(color.green)
		stringBlue.text = formatter.string(color.blue)
		stringChroma.text = formatter.string(sliderChroma.value)
		stringLuma.text = formatter.string(sliderLuma.value) + "☼"
		stringPrimaryContrast.text = formatter.string(color.contrast) + "◑"
		stringWeb.text = color.web()
		
		stringDeriveContrast.text = formatter.string(sliderDeriveContrast.value)
		stringDeriveChroma.text = formatter.string(sliderDeriveChroma.value)
		
		formatter.maximumFractionDigits = 1
		stringHue.text = formatter.string(sliderHue.value * 360.0) + "°"
		
		foregrounds.content = Layout.Overlay(
			Viewable.Gradient(colors:[.black, .white]),
			Layout.Horizontal(
				targets:model.foregrounds.map { Viewable.Color(color:$0.platformColor).aspect(ratio:2) },
				spacing:4,
				alignment:.fill,
				position:.uniform,
				direction:.reverse
			).padding(4).rounded()
		)
		
		applyColorToCircle(color)
		applyColorToPanel()
		
		sampleScroll.view?.interfaceStyle = color.isDark ? .light : .dark
		group.view?.invalidateLayout()
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
	}
	
	@objc
	func changeColor(_ panel:PlatformColorPanel) {
		guard !isAccessingColorPanel, let color = panel.color.chocolateColor(chclt:model.chocolate) else { return }
		
		isAccessingColorPanel = true
		model.primary = color.normalize()
		applyColorInput(.unknown, value:0)
		isAccessingColorPanel = false
	}
	
	func applyColorToPanel() {
		guard !isAccessingColorPanel else { return }
		
		isAccessingColorPanel = true
		PlatformColorPanel.shared.color = model.primary.platformColor
		isAccessingColorPanel = false
	}
#else
	func applyColorToPanel() {}
#endif
	
	@objc
	func deriveChanged() {
		applyColor(model.primary)
	}
	
	@objc
	func colorSpaceChanged() {
		guard let space = ColorSpace(rawValue:spacePicker.select) else { return }
		
		model.chocolate = space.chocolate
		
		applyColorInput(previousInput, value:previousValue)
	}
	
	func applyColorInput(_ input:Input, value:Double) {
		let color:CHCLT.Color
		let chocolate = model.chocolate
		let previousColor = model.primary
		
		switch input {
		case .unknown:
			color = previousColor
		case .red:
			color = DisplayRGB(value, previousColor.display.y, previousColor.display.z).color(chocolate)
		case .green:
			color = DisplayRGB(previousColor.display.x, value, previousColor.display.z).color(chocolate)
		case .blue:
			color = DisplayRGB(previousColor.display.x, previousColor.display.y, value).color(chocolate)
		case .hue:
			if stableChroma {
				color = CHCLT.Color(chocolate, hue:value, chroma:sliderChroma.value, luma:sliderLuma.value)
			} else {
				color = previousColor.applyHue(value)
			}
		case .chroma:
			if previousInput != .chroma { stableChroma = !stableChroma }
			
			if previousColor.chroma > 0 {
				color = previousColor.applyChroma(value)
			} else {
				color = CHCLT.Color(chocolate, hue:sliderHue.value, chroma:value, luma:sliderLuma.value)
			}
		case .luma:
			if stableChroma {
				color = CHCLT.Color(chocolate, hue:sliderHue.value, chroma:sliderChroma.value, luma:value)
			} else {
				color = previousColor.applyLuma(value)
			}
		}
		
		if input != .red && input != .green && input != .blue {
			sliderRed.value = color.red
			sliderGreen.value = color.green
			sliderBlue.value = color.blue
		}
		
		if input != .hue && input != .chroma && input != .luma {
			sliderHue.value = color.hue
			sliderChroma.value = color.chroma
			sliderLuma.value = color.luma
		} else if input != .chroma && !stableChroma {
			sliderHue.value = color.hue
			sliderChroma.value = color.chroma
		}
		
		previousInput = input
		previousValue = value
		model.primary = color
		
		applyColor(color)
	}
	
	@objc
	func colorSliderChanged(_ slider:PlatformSlider) {
		let input = Input(rawValue:slider.tag) ?? .unknown
		
		applyColorInput(input, value:slider.doubleValue)
	}
	
	func prepareLayout() {
		let minimumSliderWidth = 60.0
		let minimumStringWidth = 48.0
		let colorBoxSize = 80.0
		
		let colorPicker = Layout.Horizontal(targets:[
			Layout.Vertical(spacing:2, alignment:.center, position:.stretch, primary:1,
				spacePicker.fixed(width:colorBoxSize).limiting(height:30 ... colorBoxSize),
				Layout.Overlay(
					Layout.Horizontal(alignment:.fill, position:.uniform,
						Viewable.Color(color:.white),
						Viewable.Color(color:.black)
					),
					colorBox.padding(4)
				).fixed(width:colorBoxSize, height:colorBoxSize),
				stringPrimaryContrast
			),
			Layout.Horizontal(
				spacing:4,
				alignment:.fill,
				Layout.Vertical(
					alignment:.trailing,
					position:.uniform,
					Style.small.label("R"),
					Style.small.label("G"),
					Style.small.label("B"),
					Style.small.label("H"),
					Style.small.label("C"),
					Style.small.label("L"),
					Layout.empty
				),
				Layout.Vertical(
					alignment:.fill,
					position:.uniform,
					sliderRed,
					sliderGreen,
					sliderBlue,
					sliderHue,
					sliderChroma,
					sliderLuma,
					stringWeb
				).minimum(width:minimumSliderWidth),
				Layout.Vertical(
					alignment:.fill,
					position:.uniform,
					stringRed,
					stringGreen,
					stringBlue,
					stringHue,
					stringChroma,
					stringLuma,
					Layout.empty
				).minimum(width:minimumStringWidth)
			)
		], spacing:8, alignment:.center, position:.stretch)
		
		let colorDerivation = Layout.Vertical(
			stringForeground,
			Layout.Horizontal(
				spacing:4,
				alignment:.fill,
				Layout.Vertical(
					position:.uniform,
					sliderDeriveContrast,
					sliderDeriveChroma
				).minimum(width:minimumSliderWidth),
				Layout.Vertical(
					alignment:.fill,
					position:.uniform,
					stringDeriveContrast,
					stringDeriveChroma
				).minimum(width:minimumStringWidth)
			)
		)
		
		let controlsLayout = Layout.Orient(
			rowTemplate:Layout.Horizontal(spacing:20, alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(spacing:10, alignment:.fill, position:.leading),
			axis:.vertical,
			mode:.ratio(0.5),
			colorPicker,
			Layout.Vertical(
				spacing:10,
				alignment:.fill,
				colorDerivation,
				foregrounds.fixed(height:40)
			)
		)
		
		let colorCircle = Layout.Overlay(
			colorCircleBackground,
			colorCircleCenter.rounded().fraction(width:0.5, height:0.5).aspect(ratio:1).align(),
			Layout.Circle(targets:colorCircles, scalar:0.875, radius:80).rounded().padding(10)
		)
		
		sampleScroll.minimum = CGSize(width:240, height:160)
		sampleScroll.content = Layout.Flow(
			targets:samples.map { $0.layout() } + [colorCircle],
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.horizontal
		)
		
		group.content = Layout.Vertical(spacing:8, alignment:.fill, position:.stretch,
			Layout.EmptySpace(width:0, height:10),
			controlsLayout.padding(horizontal:20, vertical:0),
			sampleScroll.ignoringSafeBounds()
		)
	}
}

extension ChocolateViewController {
	class Sample: NSObject {
		let model:ChocolateViewController.Model
		var index:Int = 0
		
		var foregrounds:[Style.Label] = []
		let background = Viewable.Color(color: nil)
		let sliderContrast = Viewable.Slider(range:-1 ... 1, action:#selector(applyColor))
		let sliderChroma = Viewable.Slider(range:-1 ... 1, action:#selector(applyColor))
		let stringContrast = Style.small.label("")
		let stringChroma = Style.small.label("")
		
		var color:CHCLT.Color {
			return model.primary
				.contrasting(sliderContrast.value)
				.applyChroma(sliderChroma.value)
		}
		
		init(_ model:ChocolateViewController.Model) {
			self.model = model
			super.init()
			sliderChroma.model.target = self
			sliderContrast.model.target = self
		}
		
		func applyFont(_ font:PlatformFont) {
			for label in foregrounds {
				label.style = label.style.with(font:.descriptor(font.fontDescriptor), size:font.pointSize)
			}
		}
		
		@objc
		func applyColor() {
			background.color = color.platformColor
			
			applyForegrounds()
		}
		
		func applyForegrounds(_ strings:[(text:String, color:PlatformColor?)]) {
			let wasCount = foregrounds.count
			let newCount = strings.count
			
			for index in 0 ..< min(wasCount, newCount) {
				foregrounds[index].textColor = strings[index].color
				foregrounds[index].text = strings[index].text
			}
			
			if wasCount > newCount {
				foregrounds.removeLast(wasCount - newCount)
			}
			
			if wasCount < newCount {
				foregrounds += strings.suffix(from:wasCount).map { Style.example.centered.label($0.text).color($0.color) }
			}
			
			let formatter = NumberFormatter(fractionDigits:1 ... 3)
			let legible = model.primary.applyContrast(1).platformColor
			stringContrast.text = formatter.string(from:sliderContrast.value as NSNumber)
			stringContrast.textColor = legible
			stringChroma.text = formatter.string(from:sliderChroma.value as NSNumber)
			stringChroma.textColor = legible
		}
		
		func applyForegrounds() {
			let color = self.color
			let sRGB = CHCLT_sRGB.g18
			let bl = color.convert(sRGB)
			let formatter = NumberFormatter(fractionDigits:2 ... 2)
			let bc = formatter.string(color.contrast)
			
			applyForegrounds(model.foregrounds.enumerated().map { order, color in
				let fc = formatter.string(color.contrast)
				let fl = color.convert(sRGB)
				let g18 = CHCLT_sRGB.ratioG18(bl.luminance, fl.luminance)
				let contrast = formatter.string(g18)
				let text = DisplayStrings.Chocolate.example(foreground:order + 1, fc:fc, background:index + 1, bc:bc, contrast:contrast)
				
				return (text, color.platformColor)
			})
		}
		
		func layout() -> Positionable {
			let colorDerivation = Layout.Columns(columnCount:2, spacing:4, template:Layout.Horizontal(spacing:4),
				sliderContrast.minimum(width:200), stringContrast.minimum(width:48),
				sliderChroma.minimum(width:200), stringChroma.minimum(width:48)
			)
			
			return Layout.Overlay(horizontal: .fill, vertical: .fill,
				background.ignoringSafeBounds(),
				Layout.Vertical(targets:foregrounds + [
					Layout.EmptySpace(height:10),
					colorDerivation,
				], spacing:4, alignment:.fill, position:.center).padding(20)
			)
		}
	}
}
