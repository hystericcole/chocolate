//
//  ChocolateViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import CoreGraphics
import Foundation
import simd

class ChocolateViewController: BaseViewController {
	typealias Strings = DisplayStrings.Chocolate
	
	class Model {
		static let sampleCount = 3
		
		var chocolate:CHCLT = ColorSpace.default.chocolate
		var primary = DisplayRGB(0.2, 0.4, 0.6)
		var foregrounds:[DisplayRGB] = []
	}
	
	enum Input:Int {
		case unknown, red, green, blue, hue, chroma, luma
	}
	
	enum ColorSpace: Int {
		case sRGBpower, sRGB, g18, y601power, y601, y709power, y709, y2020
		
		var chocolate:CHCLT {
			switch self {
			case .sRGBpower: return CHCLTPower.sRGB
			case .sRGB: return CHCLT_sRGB.standard
			case .g18: return CHCLT_sRGB.g18
			case .y601power: return CHCLTPower.y601
			case .y601: return CHCLT_BT.y601
			case .y709power: return CHCLTPower.y709
			case .y709: return CHCLT_BT.y709
			case .y2020: return CHCLT_BT.y2020
			}
		}
		
		static let `default` = sRGBpower
		static var titles:[String] = ["sRGBⁿ", "sRGB", "G18", "y601ⁿ", "y601", "y709ⁿ", "y709", "y2020"]
	}
	
	var model = Model()
	var previousValue:Double = 0
	var previousInput:Input = .luma
	var stableChroma:Bool = true
	
	let group = Viewable.Group(content:Layout.EmptySpace())
	let spacePicker = Viewable.Picker(titles:ColorSpace.titles, attributes:Style.medium.attributes, select:0, action:#selector(colorSpaceChanged))
	let sliderRed = Viewable.Slider(tag:Input.red.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.red)
	let sliderGreen = Viewable.Slider(tag:Input.green.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.green)
	let sliderBlue = Viewable.Slider(tag:Input.blue.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.blue)
	let sliderHue = Viewable.Slider(tag:Input.hue.rawValue, action:#selector(colorSliderChanged))
	let sliderChroma = Viewable.Slider(tag:Input.chroma.rawValue, action:#selector(colorSliderChanged))
	let sliderLuma = Viewable.Slider(tag:Input.luma.rawValue, action:#selector(colorSliderChanged))
	let sliderContrast = Viewable.Slider(value:0.5, action:#selector(deriveChanged))
	let sliderSaturation = Viewable.Slider(value:0.5, action:#selector(deriveChanged))
	let stringRed = Style.small.label("")
	let stringGreen = Style.small.label("")
	let stringBlue = Style.small.label("")
	let stringHue = Style.small.label("")
	let stringChroma = Style.small.label("")
	let stringLuma = Style.small.label("")
	let stringContrast = Style.small.label("")
	let stringSaturation = Style.small.label("")
	let stringPrimaryContrast = Style.medium.label("")
	let stringPrimary = Style.caption.label(Strings.primary)
	let stringForeground = Style.caption.label(Strings.foreground)
	let stringWeb = Style.webColor.label("")
	let colorBox = Viewable.Color(color:nil)
	var samples:[Sample] = []
	
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
				samples[index].sliderSaturation.value = 0.25 * Double(index) / Double(count - 1)
			}
		}
		
		if wasCount != count {
			applyColor(model.primary)
			
			if group.view != nil {
				prepareLayout()
			}
		}
	}
	
	func generateBackgrounds(primary:DisplayRGB, contrast:Double, saturation:Double, count:Int) -> [DisplayRGB] {
		let limit = Double(count - 1)
		let chocolate = model.chocolate
		
		return (0 ..< count).map { index in
			let s = 2 * (saturation - 0.5) * Double(count - index) / limit
			let c = 0.5 * (1 + contrast - Double(index) / limit)
			
			return primary.applyChroma(chocolate, value:s).contrasting(chocolate, value:c)
		}
	}
	
	func generateForegrounds(primary:DisplayRGB, contrast:Double, saturation:Double, count:Int) -> [DisplayRGB] {
		let limit = Double(count - 1)
		let chocolate = model.chocolate
		
		return (0 ..< count).map { index in
			let n = Double(index) / limit
			let s = 1 - n * (1 - saturation)
			let c = 1 - n * (1 - contrast)
			
			return primary.scaleContrast(chocolate, by:c).scaleChroma(chocolate, by:s)
		}
	}
	
	func applyColor(_ color:DisplayRGB) {
		colorBox.color = color.cg?.platformColor
		
		let chocolate = model.chocolate
		let formatter = NumberFormatter()
		let contrast = sliderContrast.value
		let saturation = sliderSaturation.value
		
		model.foregrounds = generateForegrounds(primary:color, contrast:contrast, saturation:saturation, count:Model.sampleCount)
		
		for index in samples.indices {
			samples[index].index = index
			samples[index].applyColor()
		}
		
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 3
		stringRed.text = formatter.string(from:color.red as NSNumber)
		stringGreen.text = formatter.string(from:color.green as NSNumber)
		stringBlue.text = formatter.string(from:color.blue as NSNumber)
		stringChroma.text = formatter.string(from:sliderChroma.value as NSNumber)
		stringLuma.text = (formatter.string(from:sliderLuma.value as NSNumber) ?? "") + "❂"
		stringPrimaryContrast.text = (formatter.string(from:color.contrast(chocolate) as NSNumber) ?? "") + "◑"
		stringWeb.text = color.web()
		
		stringContrast.text = formatter.string(from:sliderContrast.value as NSNumber)
		stringSaturation.text = formatter.string(from:sliderSaturation.value as NSNumber)
		
		formatter.maximumFractionDigits = 1
		stringHue.text = (formatter.string(from:sliderHue.value * 360.0 as NSNumber) ?? "") + "°"
		
		group.view?.invalidateLayout()
	}
	
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
		let color:DisplayRGB
		let chocolate = model.chocolate
		let previousColor = model.primary
		
		switch input {
		case .unknown:
			color = previousColor
		case .red:
			color = DisplayRGB(value, previousColor.vector.y, previousColor.vector.z)
		case .green:
			color = DisplayRGB(previousColor.vector.x, value, previousColor.vector.z)
		case .blue:
			color = DisplayRGB(previousColor.vector.x, previousColor.vector.y, value)
		case .hue:
			if stableChroma {
				color = DisplayRGB(chocolate, hue:value, chroma:sliderChroma.value, luma:sliderLuma.value)
			} else {
				color = previousColor.hueShifted(chocolate, by:value - previousColor.vectorHue(chocolate))
			}
		case .chroma:
			if previousInput != .chroma { stableChroma = !stableChroma }
			
			if previousColor.chroma(chocolate) > 0 {
				color = previousColor.applyChroma(chocolate, value:value)
			} else {
				color = DisplayRGB(chocolate, hue:sliderHue.value, chroma:value, luma:sliderLuma.value)
			}
		case .luma:
			if stableChroma {
				color = DisplayRGB(chocolate, hue:sliderHue.value, chroma:sliderChroma.value, luma:value)
			} else {
				color = previousColor.applyLuma(chocolate, value:value)
			}
		}
		
		if input != .red && input != .green && input != .blue {
			sliderRed.value = color.red
			sliderGreen.value = color.green
			sliderBlue.value = color.blue
		}
		
		if input != .hue && input != .chroma && input != .luma {
			sliderHue.value = color.vectorHue(chocolate)
			sliderChroma.value = color.chroma(chocolate)
			sliderLuma.value = color.luma(chocolate)
		} else if input != .chroma && !stableChroma {
			sliderHue.value = color.vectorHue(chocolate)
			sliderChroma.value = color.chroma(chocolate)
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
		let minimumSliderWidth = 200.0
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
			Layout.Columns(columnCount:3, template:Layout.Horizontal(spacing:4),
				Style.small.label("R"), sliderRed, stringRed.minimum(width:minimumStringWidth),
				Style.small.label("G"), sliderGreen, stringGreen,
				Style.small.label("B"), sliderBlue, stringBlue,
				Style.small.label("H"), sliderHue, stringHue,
				Style.small.label("C"), sliderChroma, stringChroma,
				Style.small.label("L"), sliderLuma, stringLuma,
				Layout.EmptySpace(), stringWeb, Layout.EmptySpace()
			)
		], spacing:8, alignment:.center, position:.stretch)
		
		let colorDerivation = Layout.Columns(columnCount:2, spacing:4, template:Layout.Horizontal(spacing:4),
			stringForeground, Layout.EmptySpace().minimum(width:minimumStringWidth),
			sliderContrast.minimum(width:minimumSliderWidth), stringContrast,
			sliderSaturation.minimum(width:minimumSliderWidth), stringSaturation
		)
		
		let exampleLayout = Viewable.Scroll(content:Layout.Flow(
			targets:samples.map { $0.layout() },
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.horizontal
		), minimum:CGSize(square:200)).ignoringSafeBounds()
		
		let controlsLayout = Layout.Vertical(spacing:10, alignment:.fill, position:.start,
			colorPicker,
			colorDerivation
		)
		
		group.content = Layout.Vertical(spacing:8, alignment:.fill, position:.stretch,
			Layout.EmptySpace(width:0, height:10),
			controlsLayout.padding(horizontal:20, vertical:0),
			exampleLayout
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
		let sliderSaturation = Viewable.Slider(range:-1 ... 1, action:#selector(applyColor))
		let stringContrast = Style.small.label("")
		let stringSaturation = Style.small.label("")
		
		var color:DisplayRGB {
			return model.primary
				.contrasting(model.chocolate, value:sliderContrast.value)
				//.applyContrast(model.chocolate, value:model.primary.contrast(model.chocolate) - sliderContrast.value - 1)
				.applyChroma(model.chocolate, value:sliderSaturation.value)
		}
		
		init(_ model:ChocolateViewController.Model) {
			self.model = model
			super.init()
			sliderSaturation.model.target = self
			sliderContrast.model.target = self
		}
		
		@objc
		func applyColor() {
			background.color = color.color()?.platformColor
			
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
			let legible = model.primary.applyContrast(model.chocolate, value:1).color()?.platformColor
			stringContrast.text = formatter.string(from:sliderContrast.value as NSNumber)
			stringContrast.textColor = legible
			stringSaturation.text = formatter.string(from:sliderSaturation.value as NSNumber)
			stringSaturation.textColor = legible
		}
		
		func applyForegrounds() {
			let color = self.color
			let sRGB = CHCLT_sRGB.g18
			let chocolate = model.chocolate
			let formatter = NumberFormatter(fractionDigits:2 ... 2)
			let bc = formatter.string(from:color.contrast(chocolate) as NSNumber) ?? "?"
			let bl = color.luma(sRGB)
			
			applyForegrounds(model.foregrounds.enumerated().map { order, color in
				let fc = formatter.string(from:color.contrast(chocolate) as NSNumber) ?? "?"
				let fl = color.luma(sRGB)
				let g18n = max(fl, bl) + 0.05
				let g18d = min(fl, bl) + 0.05
				let g18 = g18n / g18d
				let contrast = formatter.string(from:g18 as NSNumber) ?? "?"
				let text = DisplayStrings.Chocolate.example(foreground:order + 1, fc:fc, background:index + 1, bc:bc, contrast:contrast)
				
				return (text, color.color()?.platformColor)
			})
		}
		
		func layout() -> Positionable {
			let colorDerivation = Layout.Columns(columnCount:2, spacing:4, template:Layout.Horizontal(spacing:4),
				sliderContrast.minimum(width:200), stringContrast.minimum(width:48),
				sliderSaturation.minimum(width:200), stringSaturation.minimum(width:48)
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
