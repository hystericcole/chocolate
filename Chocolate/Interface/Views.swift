//
//  Views.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import CoreGraphics
import Foundation

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

protocol ViewChanger {
	associatedtype ViewType: PlatformView
	
	func applyToView(view:ViewType)
}

protocol ViewMaker: ViewChanger {
	var tag:Int { get }
	var view:ViewType { get }
}

extension ViewMaker {
	func applyToSubview(view:PlatformView) {
		guard tag != 0, let view = view.viewWithTag(tag) as? ViewType else { return }
		
		applyToView(view:view)
	}
}

@available(macOS 10.15, *)
struct SwitchView: ViewMaker {
	var tag:Int
	var value:Bool
	weak var target:AnyObject?
	var action:Selector
	
	var view:PlatformSwitch {
		let view = PlatformSwitch()
		
		applyToView(view:view)
		
		return view
	}
	
	func applyToView(view:PlatformSwitch) {
		view.tag = tag
		
#if os(macOS)
		view.state = value ? .on : .off
		
		view.target = target
		view.action = action
		view.isContinuous = true
#else
		view.isOn = value
		
		view.removeTarget(nil, action:nil, for:.valueChanged)
		view.addTarget(target, action:action, for:.valueChanged)
#endif
	}
}

struct ColorView: ViewMaker {
#if os(macOS)
	class ViewType: PlatformView {
		var _tag = 0
		override var tag:Int { get { return _tag } set { _tag = newValue } }
	}
#else
	typealias ViewType = PlatformView
#endif
	
	var tag:Int
	var color:CGColor?
	
	init(tag:Int = 0, color:CGColor?) {
		self.tag = tag
		self.color = color
	}
	
	var view:ViewType {
		let view = ViewType()
		
		applyToView(view:view)
		
		return view
	}
	
	func applyToView(view:ViewType) {
#if os(macOS)
		view.tag = tag
		view.wantsLayer = true
#else
		view.tag = tag
		view.isUserInteractionEnabled = false
		view.isOpaque = color?.alpha ?? 0 < 1
#endif
		
		view.backgroundColor = color?.platformColor
	}
}

struct SliderView: ViewMaker {
	var tag:Int
	var value:Double
	var range:ClosedRange<Double>
	weak var target:AnyObject?
	var action:Selector
	var minimumTrackColor:PlatformColor?
	
	init(tag:Int = 0, value:Double = 0, range:ClosedRange<Double> = 0 ... 1, target:AnyObject?, action:Selector, minimumTrackColor:PlatformColor? = nil) {
		self.tag = tag
		self.value = value
		self.range = range
		self.target = target
		self.action = action
		self.minimumTrackColor = minimumTrackColor
	}
	
	var view:PlatformSlider {
		let view = PlatformSlider()
		
		applyToView(view:view)
		
		return view
	}
	
	func applyToView(view:PlatformSlider) {
		view.tag = tag
		
#if os(macOS)
		view.sliderType = .linear
		view.minValue = range.lowerBound
		view.maxValue = range.upperBound
		view.doubleValue = value
		
		if #available(OSX 10.12.2, *) {
			view.trackFillColor = minimumTrackColor
		}
		
		if #available(OSX 11.0, *) {
			view.controlSize = .large
		} else {
			view.controlSize = .regular
		}
		
		view.target = target
		view.action = action
		view.isContinuous = true
#else
		view.minimumValue = Float(range.lowerBound)
		view.maximumValue = Float(range.upperBound)
		view.value = Float(value)
		view.minimumTrackTintColor = minimumTrackColor
		
		view.removeTarget(nil, action:nil, for:.valueChanged)
		view.addTarget(target, action:action, for:.valueChanged)
#endif
	}
	
	static func value(_ view:PlatformSlider) -> Double {
#if os(macOS)
		return view.doubleValue
#else
		return Double(view.value)
#endif
	}
}

struct ImageView: ViewMaker {
	var tag:Int
	var image:PlatformImage?
	var color:PlatformColor?
	
	init(tag:Int = 0, image:PlatformImage?, color:PlatformColor? = nil) {
		self.tag = tag
		self.image = image
	}
	
	var view:PlatformImageView {
		let view = PlatformImageView()
		
		applyToView(view:view)
		
		return view
	}
	
	func applyToView(view:PlatformImageView) {
		view.tag = tag
		
#if os(macOS)
		if #available(OSX 10.14, *), let color = color {
			view.contentTintColor = color
		}
#else
		if let color = color {
			view.tintColor = color
		}
		
		view.clipsToBounds = true
#endif
		
		view.image = image
	}
}

struct LabelView: ViewMaker {
	var tag:Int
	var string:NSAttributedString
	var intrinsicWidth:CGFloat
	var maximumLines:Int
	
	init(tag:Int = 0, string:NSAttributedString, intrinsicWidth:CGFloat = 0, maximumLines:Int = 0) {
		self.tag = tag
		self.string = string
		self.maximumLines = maximumLines
		self.intrinsicWidth = intrinsicWidth
	}
	
	init(tag:Int = 0, text:String?, attributes:[NSAttributedString.Key:Any]? = nil, intrinsicWidth:CGFloat = 0, maximumLines:Int = 0) {
		self.tag = tag
		self.string = NSAttributedString(string:text ?? "", attributes:attributes)
		self.maximumLines = maximumLines
		self.intrinsicWidth = intrinsicWidth
	}
	
	var view:PlatformLabel {
		let view = PlatformLabel()
		
		applyToView(view:view)
		
		return view
	}
	
	func applyToView(view:PlatformLabel) {
		view.tag = tag
		
#if os(macOS)
		view.drawsBackground = false
		view.attributedStringValue = string
		view.refusesFirstResponder = true
		view.isBezeled = false
		view.isBordered = false
		view.isEditable = false
		view.preferredMaxLayoutWidth = intrinsicWidth
		view.cell?.usesSingleLineMode = maximumLines == 1
		view.cell?.wraps = maximumLines == 1 ? false : true
		view.lineBreakMode = maximumLines == 1 ? .byTruncatingMiddle : .byWordWrapping
		
		if #available(OSX 10.11, *) {
			view.maximumNumberOfLines = maximumLines
		}
#else
		view.attributedText = string
		view.preferredMaxLayoutWidth = intrinsicWidth
		view.numberOfLines = maximumLines
		view.lineBreakMode = maximumLines == 1 ? .byTruncatingMiddle : .byWordWrapping
		view.adjustsFontSizeToFitWidth = maximumLines > 0
#endif
	}
}

struct ActionControl: ViewChanger {
	weak var target:AnyObject?
	let action:Selector
	
	func applyToView(view:PlatformControl) {
#if os(macOS)
		view.target = target
		view.action = action
#else
		let events = view.allControlEvents
		
		view.removeTarget(nil, action:nil, for:events)
		view.addTarget(target, action:action, for:events)
#endif
	}
}

/*
	Text
	TextField
	SecureField
	TextEditor
	
√	Image
	
	Button
	EditButton
	PasteButton
	
	Menu
	Link
	NavigationLink
	
	Toggle
	Picker
	DatePicker
√	Slider
	Stepper
	ColorPicker
	
√	Label
	ProgressView
	Gauge
*/
