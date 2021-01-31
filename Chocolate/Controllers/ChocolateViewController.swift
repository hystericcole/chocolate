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
	enum Tag: Int {
		case zero, red, green, blue, contrast, saturation, colorLabel, colorBox
	}
	
	var isRGB = true
	var chocolateView:ChocolateView? { return isViewLoaded ? view as? ChocolateView : nil }
	
	override func loadView() {
		let chocolateView = ChocolateView()
		
		view = chocolateView
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if !isRGB, let chocolateView = chocolateView {
			let chocolate = CGColor.chocolate
			let vector = simd_double(Float.vector4(chocolateView.sliderRed.value, chocolateView.sliderGreen.value, chocolateView.sliderBlue.value, 1))
			
			chocolateView.sliderRed.value = Float(chocolate.vectorHue(vector))
			chocolateView.sliderGreen.value = Float(chocolate.saturation(vector))
			chocolateView.sliderBlue.value = Float(chocolate.luma(vector))
		}
		
		sliderChanged()
	}
	
	func generateBackgrounds(primary:RGBA, contrast:Double, saturation:Double, count:Int) -> [RGBA] {
		let chocolate = CGColor.chocolate
		let limit = Double(count - 1)
		
		return (1 ... count).map { index in
			let s = saturation * 0.25 * (1 - 2 * Double(index - 1) / limit)
			let c = 1.0 - (1.0 - contrast * 0.5) * 0.25 * Double(index) / limit
			
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
		guard let chocolateView = chocolateView else { return }
		
		chocolateView.colorBox.backgroundColor = rgba.cgColor()?.platformColor
		
		let chocolate = CGColor.chocolate
		let examples = chocolateView.examples
		let contrast = SliderView.value(chocolateView.sliderContrast)
		let saturation = SliderView.value(chocolateView.sliderSaturation)
		let backgrounds = generateBackgrounds(primary:rgba, contrast:contrast, saturation:saturation, count:examples.count)
		let foregrounds = generateForegrounds(primary:rgba, contrast:contrast, saturation:saturation, count:ChocolateView.Example.descriptionCount)
		
		for i in examples.indices {
			examples[i].background.backgroundColor = backgrounds[i].cgColor()?.platformColor
			
			for j in examples[i].foregrounds.indices {
				examples[i].foregrounds[j].textColor = foregrounds[j].cgColor()?.platformColor
			}
		}
		
		let description = String(format:"%.3f◐  %.1f°  %.3fc  %.3f❂", chocolate.contrast(rgba.vector), 360.0 * chocolate.vectorHue(rgba.vector), chocolate.saturation(rgba.vector), chocolate.luma(rgba.vector))
		
		chocolateView.colorLabel.attributedText = Style.caption.centered.string(description)
	}
	
	@objc
	func sliderChanged() {
		guard let chocolateView = chocolateView else { return }
		
		let red = SliderView.value(chocolateView.sliderRed)
		let green = SliderView.value(chocolateView.sliderGreen)
		let blue = SliderView.value(chocolateView.sliderBlue)
		let rgba:RGBA
		
		if isRGB {
			rgba = RGBA(red, green, blue, 1)
		} else {
			rgba = RGBA(vector:CGColor.chocolate.color(hue:red, saturation:green, luma:blue, alpha: 1))
		}
		
		applyColor(rgba:rgba)
	}
}

class ChocolateView: BaseView {
	typealias Tag = ChocolateViewController.Tag
	
	struct Example {
		static let exampleCount = 3
		static let descriptionCount = 3
		
		let index:Int
		let background:ColorView.ViewType
		let foregrounds:[LabelView.ViewType]
		
		var layout:Positionable {
			return Layout.Overlay(targets:[
				background.ignoringSafeBounds().padding(Layout.EdgeInsets(horizontal:-8, vertical:0)),
				Layout.Vertical(targets:foregrounds, spacing:4, alignment:.center, position:.center)
			], vertical:.fill, horizontal:.fill)
		}
		
		init(index:Int, descriptions:Int) {
			self.index = index
			self.background = ColorView(tag:index * 100, color:nil).view
			self.foregrounds = (1 ... descriptions).map { description in
				let text = DisplayStrings.Chocolate.example(foreground:description, background:index)
				let string = Style.example.string(text)
				
				return LabelView(tag:index * 100 + description, string:string).view
			}
		}
	}
	
	let sliderRed = SliderView(tag:Tag.red.rawValue, value:0.2, range:0 ... 1, target:nil, action:#selector(ChocolateViewController.sliderChanged), minimumTrackColor:.red).view
	let sliderGreen = SliderView(tag:Tag.green.rawValue, value:0.4, range:0 ... 1, target:nil, action:#selector(ChocolateViewController.sliderChanged), minimumTrackColor:.green).view
	let sliderBlue = SliderView(tag:Tag.blue.rawValue, value:0.6, range:0 ... 1, target:nil, action:#selector(ChocolateViewController.sliderChanged), minimumTrackColor:.blue).view
	let sliderContrast = SliderView(tag:Tag.contrast.rawValue, value:1.0, range:0 ... 1, target:nil, action:#selector(ChocolateViewController.sliderChanged)).view
	let sliderSaturation = SliderView(tag:Tag.saturation.rawValue, value:0.5, range:0 ... 1, target:nil, action:#selector(ChocolateViewController.sliderChanged)).view
	let primaryLabel = LabelView(string:Style.caption.string(DisplayStrings.Chocolate.primary)).view
	let deriveLabel = LabelView(string:Style.caption.string(DisplayStrings.Chocolate.derived)).view
	let colorBox = ColorView(tag:Tag.colorBox.rawValue, color:nil).view
	let colorLabel = LabelView(tag:Tag.colorLabel.rawValue, string:Style.caption.string(" ")).view
	let examples:[Example] = (1 ... Example.exampleCount).map { Example(index:$0, descriptions:Example.descriptionCount) }

	override func prepareHierarchy() {
		PlatformView.orderPositionables([makeLayout()], environment:positionableEnvironment, addingToHierarchy:true, hierarchyRoot:self)
	}
	
	override func makeLayout() -> Positionable {
		let minimumSliderWidth = 200.0
		let colorBoxSize = 40.0
		
		let colorPicker = Layout.Horizontal(targets:[
			Layout.Vertical(targets:[
				primaryLabel,
				colorBox.fixed(width:colorBoxSize, height:colorBoxSize)
			], spacing:2, alignment:.center, position:.center),
			Layout.Vertical(targets:[
				sliderRed,
				sliderGreen,
				sliderBlue
			], spacing:4, alignment:.fill, position:.start).minimum(width:minimumSliderWidth),
		], spacing:8, position:.stretch)
		
		let interfaceSliders = Layout.Vertical(targets:[
			colorLabel,
			deriveLabel,
			sliderContrast.minimum(width:minimumSliderWidth),
			sliderSaturation.minimum(width:minimumSliderWidth)
		], spacing:4, alignment:.fill, position:.start).minimum(width:minimumSliderWidth)
		
		let exampleLayout = Layout.Vertical(targets:examples.map { $0.layout }, spacing:0, alignment:.fill, position:.start)
		
		let layout = Layout.Vertical(targets:[
			Layout.EmptySpace(width:0, height:10),
			colorPicker.padding(horizontal:20, vertical:0),
			interfaceSliders.padding(horizontal:20, vertical:0),
			exampleLayout
		], spacing:10, alignment:.fill, position:.start)
		
		return layout
	}
}
