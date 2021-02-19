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
	
	enum Input:Int {
		case unknown, red, green, blue, hue, chroma, luma
	}
	
	enum ColorSpace: Int {
		case y601, y709, sRGB
		
		var chocolate:CHCLTPower {
			switch self {
			case .y601: return CHCLTPower.y601
			case .y709: return CHCLTPower.y709
			case .sRGB: return CHCLTPower.sRGB
			}
		}
		
		static var titles:[String] = ["y601", "y709", "sRGB"]
	}
	
	var previousColor:DisplayRGB = DisplayRGB(0.2, 0.4, 0.6)
	var previousValue:Double = 0
	var previousInput:Input = .luma
	var stableChroma:Bool = true
	var chocolate = CHCLTPower.y709
	
	let group = Viewable.Group(content:Layout.EmptySpace())
	let spacePicker = Viewable.Picker(titles:ColorSpace.titles, select:1, action:#selector(colorSpaceChanged))
	let sliderRed = Viewable.Slider(tag:Input.red.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.red)
	let sliderGreen = Viewable.Slider(tag:Input.green.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.green)
	let sliderBlue = Viewable.Slider(tag:Input.blue.rawValue, action:#selector(colorSliderChanged), minimumTrackColor:.blue)
	let sliderHue = Viewable.Slider(tag:Input.hue.rawValue, action:#selector(colorSliderChanged))
	let sliderChroma = Viewable.Slider(tag:Input.chroma.rawValue, action:#selector(colorSliderChanged))
	let sliderLuma = Viewable.Slider(tag:Input.luma.rawValue, action:#selector(colorSliderChanged))
	let sliderContrast = Viewable.Slider(value:1.0, action:#selector(deriveChanged))
	let sliderSaturation = Viewable.Slider(value:0.5, action:#selector(deriveChanged))
	let stringRed = Style.small.label("")
	let stringGreen = Style.small.label("")
	let stringBlue = Style.small.label("")
	let stringHue = Style.small.label("")
	let stringChroma = Style.small.label("")
	let stringLuma = Style.small.label("")
	let stringContrast = Style.medium.label("")
	let stringPrimary = Style.caption.label(Strings.primary)
	let stringDerived = Style.caption.label(Strings.derived)
	let stringWeb = Style.webColor.label("")
	let colorBox = Viewable.Color(color:nil)
	var examples:[Example] = (1 ... Example.exampleCount).map { Example(index:$0, descriptions:Example.descriptionCount) }
	
	override func loadView() {
		view = group.lazyView
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		prepareLayout()
		applyColorInput(.unknown, value:0)
	}
	
	func generateBackgrounds(primary:DisplayRGB, contrast:Double, saturation:Double, count:Int) -> [DisplayRGB] {
		let limit = Double(count - 1)
		
		return (0 ..< count).map { index in
			let s = 2 * (saturation - 0.5) * Double(count - index) / limit
			let c = 0.5 * (1 + contrast - Double(index) / limit)
			
			return primary.applyChroma(chocolate, value:s).contrasting(chocolate, value:c)
		}
	}
	
	func generateForegrounds(primary:DisplayRGB, contrast:Double, saturation:Double, count:Int) -> [DisplayRGB] {
		let limit = Double(count - 1)
		
		return (0 ..< count).map { index in
			let n = Double(index) / limit
			let s = 1 - n * (1 - saturation)
			let c = 1 - n * (1 - contrast)
			
			return primary.scaleContrast(chocolate, by:c).scaleChroma(chocolate, by:s)
		}
	}
	
	func applyColor(_ color:DisplayRGB) {
		colorBox.color = color.cg?.platformColor
		
		let formatter = NumberFormatter()
		let contrast = sliderContrast.value
		let saturation = sliderSaturation.value
		let backgrounds = generateBackgrounds(primary:color, contrast:contrast, saturation:saturation, count:examples.count)
		let foregrounds = generateForegrounds(primary:color, contrast:contrast, saturation:saturation, count:Example.descriptionCount)
		
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
		
		for i in examples.indices {
			let bc = formatter.string(from:backgrounds[i].contrast(chocolate) as NSNumber) ?? "?"
			let bl = backgrounds[i].luma(chocolate)
			examples[i].background.color = backgrounds[i].cg?.platformColor
			
			for j in examples[i].foregrounds.indices {
				let fc = formatter.string(from:foregrounds[j].contrast(chocolate) as NSNumber) ?? "?"
				let fl = foregrounds[j].luma(chocolate)
				let g18n = max(fl, bl) + 0.05
				let g18d = min(fl, bl) + 0.05
				let g18 = g18n / g18d
				let contrast = formatter.string(from:g18 as NSNumber) ?? "?"
				examples[i].foregrounds[j].textColor = foregrounds[j].cg?.platformColor
				examples[i].foregrounds[j].text = DisplayStrings.Chocolate.example(foreground:j + 1, fc:fc, background:i + 1, bc:bc, contrast:contrast)
			}
		}
		
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 3
		stringRed.text = formatter.string(from:color.red as NSNumber)
		stringGreen.text = formatter.string(from:color.green as NSNumber)
		stringBlue.text = formatter.string(from:color.blue as NSNumber)
		stringChroma.text = formatter.string(from:sliderChroma.value as NSNumber)
		stringLuma.text = (formatter.string(from:sliderLuma.value as NSNumber) ?? "") + "❂"
		stringContrast.text = (formatter.string(from:color.contrast(chocolate) as NSNumber) ?? "") + "◐"
		stringWeb.text = color.web()
		
		formatter.maximumFractionDigits = 1
		stringHue.text = (formatter.string(from:sliderHue.value * 360.0 as NSNumber) ?? "") + "°"
		
		group.view?.invalidateLayout()
	}
	
	@objc
	func deriveChanged() {
		applyColor(previousColor)
	}
	
	@objc
	func colorSpaceChanged() {
		guard let space = ColorSpace(rawValue:spacePicker.select) else { return }
		
		chocolate = space.chocolate
		
		applyColorInput(previousInput, value:previousValue)
	}
	
	func applyColorInput(_ input:Input, value:Double) {
		let color:DisplayRGB
		
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
		previousColor = color
		
		applyColor(color)
	}
	
	@objc
	func colorSliderChanged(_ slider:PlatformSlider) {
		let input = Input(rawValue:slider.tag) ?? .unknown
		
		applyColorInput(input, value:slider.doubleValue)
	}
	
	func prepareLayout() {
		let minimumSliderWidth = 200.0
		let colorBoxSize = 80.0
		
		let colorPicker = Layout.Horizontal(targets:[
			Layout.Vertical(spacing:2, alignment:.center, position:.stretch, primary:1,
				spacePicker.fixed(width:colorBoxSize, height:40).padding(horizontal:-10, vertical:0),
				//stringPrimary,
				colorBox.fixed(width:colorBoxSize, height:colorBoxSize),
				stringContrast
			),
			Layout.Columns(columnCount:3, template:Layout.Horizontal(spacing:4),
				Style.small.label("R"), sliderRed, stringRed,
				Style.small.label("G"), sliderGreen, stringGreen,
				Style.small.label("B"), sliderBlue, stringBlue,
				Style.small.label("H"), sliderHue, stringHue,
				Style.small.label("C"), sliderChroma, stringChroma,
				Style.small.label("L"), sliderLuma, stringLuma,
				Layout.EmptySpace(), stringWeb, Layout.EmptySpace()
			)
		], spacing:8, alignment:.center, position:.stretch)
		
		let colorDerivation = Layout.Vertical(spacing:4, alignment:.fill, position:.start,
			stringDerived,
			sliderContrast.minimum(width:minimumSliderWidth),
			sliderSaturation.minimum(width:minimumSliderWidth)
		).minimum(width:minimumSliderWidth)
		
		let exampleLayout = Viewable.Scroll(content:Layout.Flow(
			targets:examples.map { $0.lazy() }, 
			rowTemplate:Layout.Horizontal(alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(alignment:.fill, position:.stretch),
			axis:.horizontal
		), minimum:CGSize(square:200)).ignoringSafeBounds()
		
		//let exampleLayout = Viewable.SimpleTable(cells:examples.map { $0.lazy() }).ignoringSafeBounds()
		
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
	struct Example {
		static let exampleCount = 3
		static let descriptionCount = 3
		
		let index:Int
		var background:Viewable.Color
		var foregrounds:[Viewable.Label]
		
		func lazy() -> Positionable {
			return Layout.Overlay(horizontal:.fill, vertical:.fill,
				background.ignoringSafeBounds(),
				Layout.Vertical(targets:foregrounds, spacing:4, alignment:.fill, position:.center)
					.padding(8)
			)
		}
		
		init(index:Int, descriptions:Int) {
			self.index = index
			self.background = Viewable.Color(tag:99, color:nil)
			self.foregrounds = (1 ... descriptions).map { description in
				let text = DisplayStrings.Chocolate.example(foreground:description, background:index)
				let string = Style.example.centered.string(text)
				
				return Viewable.Label(tag:description, string:string)
			}
		}
	}
}
