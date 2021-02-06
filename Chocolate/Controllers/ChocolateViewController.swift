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
	
	enum Tag: Int {
		case zero, red, green, blue, contrast, saturation, colorLabel, colorBox
	}
	
	var isRGB = true
	var group = Viewable.Group(content:Layout.EmptySpace())
	var sliderRed = Viewable.Slider(tag:Tag.red.rawValue, value:0.2, action:#selector(ChocolateViewController.sliderChanged), minimumTrackColor:.red)
	var sliderGreen = Viewable.Slider(tag:Tag.green.rawValue, value:0.4, action:#selector(ChocolateViewController.sliderChanged), minimumTrackColor:.green)
	var sliderBlue = Viewable.Slider(tag:Tag.blue.rawValue, value:0.6, action:#selector(ChocolateViewController.sliderChanged), minimumTrackColor:.blue)
	var sliderContrast = Viewable.Slider(tag:Tag.contrast.rawValue, value:1.0, action:#selector(ChocolateViewController.sliderChanged))
	var sliderSaturation = Viewable.Slider(tag:Tag.saturation.rawValue, value:0.5, action:#selector(ChocolateViewController.sliderChanged))
	var primaryLabel = Viewable.Label(string:Style.caption.string(Strings.primary))
	var deriveLabel = Viewable.Label(string:Style.caption.string(Strings.derived))
	var colorBox = Viewable.Color(tag:Tag.colorBox.rawValue, color:nil)
	var colorLabel = Viewable.Label(string:Style.caption.string(" "))
	var examples:[Example] = (1 ... Example.exampleCount).map { Example(index:$0, descriptions:Example.descriptionCount) }
	
	override func loadView() {
		view = group.lazyView()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		prepareLayout()
		
		if !isRGB {
			let chocolate = CGColor.chocolate
			let vector = Double.vector4(sliderRed.value, sliderGreen.value, sliderBlue.value, 1)
			
			sliderRed.value = chocolate.vectorHue(vector)
			sliderGreen.value = chocolate.saturation(vector)
			sliderBlue.value = chocolate.luma(vector)
		}
		
		sliderChanged()
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
		
		let description = String(format:"%.3f◐  %.1f°  %.3fc  %.3f❂", chocolate.contrast(rgba.vector), 360.0 * chocolate.vectorHue(rgba.vector), chocolate.saturation(rgba.vector), chocolate.luma(rgba.vector))
		
		colorLabel.attributedText = Style.caption.centered.string(description)
	}
	
	@objc
	func sliderChanged() {
		let red = sliderRed.value
		let green = sliderGreen.value
		let blue = sliderBlue.value
		let rgba:RGBA
		
		if isRGB {
			rgba = RGBA(red, green, blue, 1)
		} else {
			rgba = RGBA(vector:CGColor.chocolate.color(hue:red, saturation:green, luma:blue, alpha: 1))
		}
		
		applyColor(rgba:rgba)
	}
	
	func prepareLayout() {
		let minimumSliderWidth = 200.0
		let colorBoxSize = 80.0
		
		let colorPicker = Layout.Horizontal(targets:[
			Layout.Vertical(targets:[
				primaryLabel,
				Layout.Sizing(target:colorBox, width:Layout.Dimension(value:colorBoxSize), height:Layout.Dimension(minimum:colorBoxSize, maximum:colorBoxSize * 2))
			], spacing:2, alignment:.center, position:.stretch, primary:1),
			Layout.Vertical(targets:[
				sliderRed,
				sliderGreen,
				sliderBlue,
				Layout.EmptySpace(width:0, height:2),
				colorLabel
			], spacing:4, alignment:.fill, position:.end).minimum(width:minimumSliderWidth),
		], spacing:8, alignment:.center, position:.stretch)
		
		let colorDerivation = Layout.Vertical(targets:[
			deriveLabel,
			sliderContrast.minimum(width:minimumSliderWidth),
			sliderSaturation.minimum(width:minimumSliderWidth)
		], spacing:4, alignment:.fill, position:.start).minimum(width:minimumSliderWidth)
		
		let exampleLayout = Viewable.Scroll(content:Layout.Flow(
			targets:examples.map { $0.lazy() }, 
			rowTemplate:Layout.Horizontal(targets:[], spacing:0, alignment:.fill, position:.stretch),
			columnTemplate:Layout.Vertical(targets:[], spacing:0, alignment:.fill, position:.stretch),
			axis:.horizontal
		), minimum:CGSize(square:200)).ignoringSafeBounds()
		
		let controlsLayout = Layout.Vertical(targets:[
			Layout.EmptySpace(width:0, height:10),
			colorPicker.padding(horizontal:20, vertical:0),
			colorDerivation.padding(horizontal:20, vertical:0),
		], spacing:10, alignment:.fill, position:.start)
		
		group.content = Layout.Vertical(targets:[
			controlsLayout,
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
			self.background = Viewable.Color(tag:index * 100, color:nil)
			self.foregrounds = (1 ... descriptions).map { description in
				let text = DisplayStrings.Chocolate.example(foreground:description, background:index)
				let string = Style.example.string(text)
				
				return Viewable.Label(tag:index * 100 + description, string:string)
			}
		}
	}
}
