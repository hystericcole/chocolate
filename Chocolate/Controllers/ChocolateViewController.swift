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
	
	let group = Viewable.Group(content:Layout.EmptySpace())
	let sliderRed = Viewable.Slider(value:0.2, action:#selector(ChocolateViewController.colorChanged), minimumTrackColor:.red)
	let sliderGreen = Viewable.Slider(value:0.4, action:#selector(ChocolateViewController.colorChanged), minimumTrackColor:.green)
	let sliderBlue = Viewable.Slider(value:0.6, action:#selector(ChocolateViewController.colorChanged), minimumTrackColor:.blue)
	let sliderHue = Viewable.Slider(value:0.0, action:#selector(ChocolateViewController.chocolateChanged))
	let sliderChroma = Viewable.Slider(value:0.0, action:#selector(ChocolateViewController.chocolateChanged))
	let sliderLuma = Viewable.Slider(value:0.0, action:#selector(ChocolateViewController.chocolateChanged))
	let sliderContrast = Viewable.Slider(value:1.0, action:#selector(ChocolateViewController.deriveChanged))
	let stringRed = Style.small.label("")
	let stringGreen = Style.small.label("")
	let stringBlue = Style.small.label("")
	let stringHue = Style.small.label("")
	let stringChroma = Style.small.label("")
	let stringLuma = Style.small.label("")
	let stringContrast = Style.medium.label("")
	let sliderSaturation = Viewable.Slider(value:0.5, action:#selector(ChocolateViewController.deriveChanged))
	let stringPrimary = Style.caption.label(Strings.primary)
	let stringDerived = Style.caption.label(Strings.derived)
	let colorBox = Viewable.Color(color:nil)
	var examples:[Example] = (1 ... Example.exampleCount).map { Example(index:$0, descriptions:Example.descriptionCount) }
	
	override func loadView() {
		view = group.lazyView()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		prepareLayout()
		colorChanged()
	}
	
	func generateBackgrounds(primary:RGBA, contrast:Double, saturation:Double, count:Int) -> [RGBA] {
		let chocolate = CGColor.chocolate
		let limit = Double(count - 1)
		
		return (0 ..< count).map { index in
			let s = (saturation - 0.5) * Double(count - index) / limit
			let c = 0.5 * (1 + contrast - Double(index) / limit)
			
			return RGBA(vector:chocolate.contrasting(chocolate.applySaturation(primary.vector, saturation:s), contrast:c))
		}
	}
	
	func generateForegrounds(primary:RGBA, contrast:Double, saturation:Double, count:Int) -> [RGBA] {
		let chocolate = CGColor.chocolate
		let limit = Double(count - 1)
		
		return (0 ..< count).map { index in
			let n = Double(index) / limit
			let s = 1 - n * (1 - saturation)
			let c = 1 - n * (1 - contrast)
			
			return RGBA(vector:chocolate.scaleContrast(chocolate.scaleSaturation(primary.vector, by:s), by:c))
		}
	}
	
	func applyColor(rgba:RGBA) {
		colorBox.color = rgba.cgColor()?.platformColor
		
		let chocolate = CGColor.chocolate
		let contrast = sliderContrast.value
		let saturation = sliderSaturation.value
		let backgrounds = generateBackgrounds(primary:rgba, contrast:contrast, saturation:saturation, count:examples.count)
		let foregrounds = generateForegrounds(primary:rgba, contrast:contrast, saturation:saturation, count:Example.descriptionCount)
		
		for i in examples.indices {
			examples[i].background.color = backgrounds[i].cgColor()?.platformColor
			
			for j in examples[i].foregrounds.indices {
				examples[i].foregrounds[j].textColor = foregrounds[j].cgColor()?.platformColor
			}
		}
		
		let formatter = NumberFormatter()
		
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 3
		stringRed.text = formatter.string(from:rgba.r as NSNumber)
		stringGreen.text = formatter.string(from:rgba.g as NSNumber)
		stringBlue.text = formatter.string(from:rgba.b as NSNumber)
		stringChroma.text = formatter.string(from:sliderChroma.value as NSNumber)
		stringLuma.text = (formatter.string(from:sliderLuma.value as NSNumber) ?? "") + "❂"
		stringContrast.text = (formatter.string(from:chocolate.contrast(rgba.vector) as NSNumber) ?? "") + "◐"
		
		formatter.maximumFractionDigits = 1
		stringHue.text = (formatter.string(from:sliderHue.value * 360.0 as NSNumber) ?? "") + "°"
	}
	
	@objc
	func deriveChanged() {
		let red = sliderRed.value
		let green = sliderGreen.value
		let blue = sliderBlue.value
		let rgba = RGBA(red, green, blue, 1)
		
		applyColor(rgba:rgba)
	}
	
	@objc
	func chocolateChanged() {
		let hue = sliderHue.value
		let chroma = sliderChroma.value
		let luma = sliderLuma.value
		let rgba = RGBA(vector:CGColor.chocolate.color(hue:hue, saturation:chroma, luma:luma, alpha: 1))
		
		sliderRed.value = rgba.r
		sliderGreen.value = rgba.g
		sliderBlue.value = rgba.b
		
		applyColor(rgba:rgba)
	}
	
	@objc
	func colorChanged() {
		let red = sliderRed.value
		let green = sliderGreen.value
		let blue = sliderBlue.value
		let rgba = RGBA(red, green, blue, 1)
		
		sliderHue.value = CGColor.chocolate.vectorHue(rgba.vector)
		sliderChroma.value = CGColor.chocolate.saturation(rgba.vector)
		sliderLuma.value = CGColor.chocolate.luma(rgba.vector)
		
		applyColor(rgba:rgba)
	}
	
	func prepareLayout() {
		let minimumSliderWidth = 200.0
		let colorBoxSize = 80.0
		
		let colorPicker = Layout.Horizontal(targets:[
			Layout.Vertical(targets:[
				stringPrimary,
				colorBox.fixed(width:colorBoxSize, height:colorBoxSize),
				stringContrast
			], spacing:2, alignment:.center, position:.stretch, primary:1),
			Layout.Columns(targets:[
				Style.small.label("R"), sliderRed, stringRed,
				Style.small.label("G"), sliderGreen, stringGreen,
				Style.small.label("B"), sliderBlue, stringBlue,
				Style.small.label("H"), sliderHue, stringHue,
				Style.small.label("C"), sliderChroma, stringChroma,
				Style.small.label("L"), sliderLuma, stringLuma,
			], columnCount:3, template:Layout.Horizontal(targets:[], spacing:4))
		], spacing:8, alignment:.center, position:.stretch)
		
		let colorDerivation = Layout.Vertical(targets:[
			stringDerived,
			sliderContrast.minimum(width:minimumSliderWidth),
			sliderSaturation.minimum(width:minimumSliderWidth)
		], spacing:4, alignment:.fill, position:.start).minimum(width:minimumSliderWidth)
		
		let exampleLayout = Viewable.Scroll(content:Layout.Flow(
			targets:examples.map { $0.lazy() }, 
			rowTemplate:Layout.Horizontal(targets:[], spacing:0, alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(targets:[], spacing:0, alignment:.fill, position:.stretch),
			axis:.horizontal
		), minimum:CGSize(square:200)).ignoringSafeBounds()
		
		//let exampleLayout = Viewable.SimpleTable(cells:examples.map { $0.lazy() }).ignoringSafeBounds()
		
		let controlsLayout = Layout.Vertical(targets:[
			colorPicker,
			colorDerivation,
		], spacing:10, alignment:.fill, position:.start)
		
		group.content = Layout.Vertical(targets:[
			Layout.EmptySpace(width:0, height:10),
			controlsLayout.padding(horizontal:20, vertical:0),
			exampleLayout
		], spacing:8, alignment:.fill, position:.stretch)
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
			return Layout.Overlay(targets:[
				background.ignoringSafeBounds(),
				Layout.Vertical(targets:foregrounds, spacing:4, alignment:.center, position:.center)
					.padding(8)
			], vertical:.fill, horizontal:.fill)
		}
		
		init(index:Int, descriptions:Int) {
			self.index = index
			self.background = Viewable.Color(tag:99, color:nil)
			self.foregrounds = (1 ... descriptions).map { description in
				let text = DisplayStrings.Chocolate.example(foreground:description, background:index)
				let string = Style.example.string(text)
				
				return Viewable.Label(tag:description, string:string)
			}
		}
	}
}
