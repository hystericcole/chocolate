//
//  Common.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation

#if os(macOS)
import Cocoa

typealias PlatformFont = NSFont
typealias PlatformFontDescriptor = NSFontDescriptor
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
typealias PlatformWindow = NSWindow
typealias PlatformResponder = NSResponder
typealias PlatformViewController = NSViewController
typealias PlatformView = NSView
typealias PlatformPriority = NSLayoutConstraint.Priority
typealias PlatformAutoresizing = NSView.AutoresizingMask
typealias PlatformButton = NSButton
typealias PlatformControl = NSControl
typealias PlatformSlider = NSSlider
typealias PlatformSwitch = NSButton
typealias PlatformLabel = NSTextField
typealias PlatformImageView = NSImageView
typealias PlatformScroller = NSScroller
typealias PlatformScrollingView = NSScrollView
typealias PlatformClipView = NSClipView
typealias PlatformSpinner = NSProgressIndicator
typealias PlatformStepper = NSStepper
typealias PlatformPicker = NSPopUpButton
typealias PlatformStackView = NSStackView
typealias PlatformTableView = NSTableView
typealias PlatformTableColumn = NSTableColumn
typealias PlatformTableViewCell = NSTableCellView
typealias PlatformTableDelegate = NSTableViewDelegate
typealias PlatformTableDataSource = NSTableViewDataSource
typealias PlatformColorWell = NSColorWell
typealias PlatformVisualEffectView = NSVisualEffectView
typealias PlatformGestureRecognizer = NSGestureRecognizer
typealias PlatformPanGestureRecognizer = NSPanGestureRecognizer
typealias PlatformTapGestureRecognizer = NSClickGestureRecognizer
typealias PlatformPressGestureRecognizer = NSPressGestureRecognizer
typealias PlatformRotationGestureRecognizer = NSRotationGestureRecognizer
typealias PlatformMagnificationGestureRecognizer = NSMagnificationGestureRecognizer
typealias PlatformGestureRecognizerDelegate = NSGestureRecognizerDelegate
typealias PlatformGestureRecognizerState = NSGestureRecognizer.State

#else
import UIKit

typealias PlatformFont = UIFont
typealias PlatformFontDescriptor = UIFontDescriptor
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformWindow = UIWindow
typealias PlatformResponder = UIResponder
typealias PlatformViewController = UIViewController
typealias PlatformView = UIView
typealias PlatformPriority = UILayoutPriority
typealias PlatformAutoresizing = UIView.AutoresizingMask
typealias PlatformButton = UIButton
typealias PlatformControl = UIControl
typealias PlatformSlider = UISlider
typealias PlatformSwitch = UISwitch
typealias PlatformLabel = UILabel
typealias PlatformImageView = UIImageView
typealias PlatformScrollingView = UIScrollView
typealias PlatformScrollingDelegate = UIScrollViewDelegate
typealias PlatformSpinner = UIActivityIndicatorView
typealias PlatformStepper = UIStepper
typealias PlatformPicker = UIPickerView
typealias PlatformPickerDelegate = UIPickerViewDelegate
typealias PlatformPickerDataSource = UIPickerViewDataSource
typealias PlatformStackView = UIStackView
typealias PlatformTableView = UITableView
typealias PlatformTableViewCell = UITableViewCell
typealias PlatformTableDelegate = UITableViewDelegate
typealias PlatformTableDataSource = UITableViewDataSource
typealias PlatformVisualEffectView = UIVisualEffectView
typealias PlatformGestureRecognizer = UIGestureRecognizer
typealias PlatformPanGestureRecognizer = UIPanGestureRecognizer
typealias PlatformTapGestureRecognizer = UITapGestureRecognizer
typealias PlatformPressGestureRecognizer = UILongPressGestureRecognizer
typealias PlatformRotationGestureRecognizer = UIRotationGestureRecognizer
typealias PlatformMagnificationGestureRecognizer = UIPinchGestureRecognizer
typealias PlatformGestureRecognizerDelegate = UIGestureRecognizerDelegate
typealias PlatformGestureRecognizerState = UIGestureRecognizer.State

@available(iOS 14.0, *)
typealias PlatformColorWell = UIColorWell
#endif

//	MARK: -

extension CGColor {
	var platformColor:PlatformColor? { return PlatformColor(cgColor:self) }
}

//	MARK: -

extension CTFont {
	var platformFont:PlatformFont { return self as PlatformFont }
}

//	MARK: -

#if os(macOS)
class PlatformTaggableView: PlatformView {
	var _tag = 0
	override var isFlipped:Bool { return true }
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	
	func prepareViewableColor(isOpaque:Bool) {
		wantsLayer = true
		layer?.isOpaque = isOpaque
		compressionResistance = .zero
	}
}

//	MARK: -

extension PlatformAutoresizing {
	static let flexibleSize:PlatformAutoresizing = [.width, .height]
}

//	MARK: -

extension PlatformView {
	var alpha:CGFloat {
		get { return alphaValue }
		set { alphaValue = newValue }
	}
	
	var center:CGPoint {
		get { return frame.center }
	}
	
	var backgroundColor:PlatformColor? {
		get { return layer?.backgroundColor?.platformColor }
		set { layer?.backgroundColor = newValue?.cgColor }
	}
}

//	MARK: -

extension PlatformControl {
	func applyVieawbleAction(target:AnyObject?, action:Selector?) {
		self.target = target
		self.action = action
	}
}

//	MARK: -

class PlatformEmptyButton: PlatformButton {
	func prepareViewableButton() {
		isBordered = false
		isTransparent = true
	}
}

//	MARK: -

extension PlatformSwitch {
	var isOn:Bool {
		get { return state == .on }
		set { state = newValue ? .on : .off }
	}
	
	func prepareViewableSwitch(target:AnyObject? = nil, action:Selector?) {
		title = ""
		allowsMixedState = false
		bezelStyle = .rounded
		setButtonType(.switch)
		applyVieawbleAction(target:target, action:action)
	}
}

//	MARK: -

extension PlatformImageView {
	func prepareViewableImage(image:PlatformImage?, color:PlatformColor?) {
		self.image = image
		
		if #available(macOS 10.14, *), let color = color {
			contentTintColor = color
		}
	}
}

//	MARK: -

extension PlatformLabel {
	var text:String? { return stringValue }
	
	var maximumLines:Int {
		get {
			if #available(macOS 10.11, *) {
				return maximumNumberOfLines
			} else {
				return usesSingleLineMode ? 1 : 0
			}
		}
	}
	
	var attributedText:NSAttributedString? {
		get { return attributedStringValue }
		set { attributedStringValue = newValue ?? NSAttributedString() }
	}
	
	func prepareViewableLabel(intrinsicWidth:CGFloat, maximumLines:Int) {
		drawsBackground = false
		refusesFirstResponder = true
		isBezeled = false
		isBordered = false
		isEditable = false
		preferredMaxLayoutWidth = intrinsicWidth
		cell?.usesSingleLineMode = maximumLines == 1
		cell?.wraps = maximumLines == 1 ? false : true
		lineBreakMode = maximumLines == 1 ? .byTruncatingMiddle : .byWordWrapping
		
		if #available(macOS 10.11, *) {
			maximumNumberOfLines = maximumLines
		}
	}
}

//	MARK: -

extension PlatformPicker {
	var selectionIndex:Int {
		get { return indexOfSelectedItem }
		set { selectItem(at:newValue) }
	}
	
	func addItems(withTitles strings:[NSAttributedString]) {
		if let menu = cell?.menu {
			var tag = 1
			
			menu.items += strings.map { string in
				let item = NSMenuItem()
				item.attributedTitle = string
				item.tag = tag
				tag += 1
				return item
			}
		} else {
			addItems(withTitles:strings.map { $0.string })
		}
	}
}

//	MARK: -

extension PlatformScrollingView {
	var isAxisLockEnabled:Bool {
		get { return usesPredominantAxisScrolling }
		set { usesPredominantAxisScrolling = newValue }
	}
	
	var zoomScale:CGFloat {
		get { return magnification }
		set { magnification = newValue }
	}
	
	var zoomRange:Viewable.Scroll.ZoomRange {
		get {
			return minMagnification ... max(minMagnification, maxMagnification)
		}
		set {
			minMagnification = newValue.lowerBound
			maxMagnification = newValue.upperBound
			allowsMagnification = newValue.lowerBound < newValue.upperBound
		}
	}
}

//	MARK: -

extension PlatformSlider {
	static var intrinsicViewableSize:CGSize {
		return CGSize(width:-1, height:15)
	}
	
	var trackingFrame:CGRect {
		return frame.insetBy(dx:knobThickness / 2, dy:0)
	}
	
	var valueRange:ClosedRange<Double> {
		get { return minValue ... max(minValue, maxValue) }
		set { minValue = newValue.lowerBound; maxValue = newValue.upperBound }
	}
	
	func prepareViewableSlider(target:AnyObject?, action:Selector?, minimumTrackColor:PlatformColor?) {
		sliderType = .linear
		
		if #available(macOS 10.12.2, *), let color = minimumTrackColor {
			trackFillColor = color
		}
		
		if #available(macOS 11.0, *) {
			controlSize = .large
		} else {
			controlSize = .regular
		}
		
		self.target = target
		self.action = action
		isContinuous = true
	}
}

//	MARK: -

extension PlatformSpinner {
	var isHiddenWhenStopped:Bool {
		get { return !isDisplayedWhenStopped }
		set { isDisplayedWhenStopped = !newValue }
	}
	
	func applyAnimating(_ isAnimating:Bool) {
		if isAnimating {
			startAnimation(nil)
		} else {
			stopAnimation(nil)
		}
	}
	
	func prepareViewableSpinner() {
		style = .spinning
		isIndeterminate = true
		isBezeled = false
	}
}

#else

typealias PlatformTaggableView = PlatformView

extension PlatformAutoresizing {
	static let flexibleSize:PlatformAutoresizing = [.flexibleWidth, .flexibleHeight]
}

//	MARK: -

extension PlatformView {
	func prepareViewableColor(isOpaque:Bool) {
		self.isUserInteractionEnabled = false
		self.isOpaque = isOpaque
	}
}

//	MARK: -

extension PlatformImageView {
	func prepareViewableImage(image:PlatformImage?, color:PlatformColor?) {
		if let color = color {
			self.image = image?.withRenderingMode(.alwaysTemplate)
			
			tintColor = color
		} else {
			self.image = image
		}
		
		clipsToBounds = true
	}
	
	func alignImage(_ alignment:CGPoint = CGPoint(x:0.5, y:0)) {
		guard let imageSize = image?.size else { return }
		
		layer.alignContents(size:imageSize, alignment:alignment)
	}
}

//	MARK: -

class PlatformEmptyButton: PlatformControl {
	func applyVieawbleAction(target:AnyObject?, action:Selector?) {
		removeTarget(nil, action:nil, for:.touchUpInside)
		
		if let action = action {
			addTarget(target, action:action, for:.touchUpInside)
		}
	}
	
	func prepareViewableButton() {
	}
}

//	MARK: -

extension PlatformLabel {
	var maximumLines: Int {
		get { return numberOfLines }
	}
	
	static func sizeMeasuringString(_ string:NSAttributedString, with size:CGSize) -> CGSize {
		let string = string.withLineBreakMode()
		
		return string.boundingRect(with:size, options:.usesLineFragmentOrigin, context:nil).size
	}
	
	func prepareViewableLabel(intrinsicWidth:CGFloat, maximumLines:Int) {
		preferredMaxLayoutWidth = intrinsicWidth
		numberOfLines = maximumLines
		lineBreakMode = maximumLines == 1 ? .byTruncatingMiddle : .byWordWrapping
		adjustsFontSizeToFitWidth = maximumLines > 0
	}
}

//	MARK: -

extension PlatformPicker {
	var selectionIndex:Int {
		get { return selectedRow(inComponent:0) }
		set { selectRow(newValue, inComponent:0, animated:false) }
	}
}

//	MARK: -

extension PlatformScrollingView {
	var isAxisLockEnabled:Bool {
		get { return isDirectionalLockEnabled }
		set { isDirectionalLockEnabled = newValue }
	}
	
	var zoomRange:Viewable.Scroll.ZoomRange {
		get {
			return minimumZoomScale ... max(minimumZoomScale, maximumZoomScale)
		}
		set {
			minimumZoomScale = newValue.lowerBound
			maximumZoomScale = newValue.upperBound
		}
	}
	
	func flashScrollers() {
		flashScrollIndicators()
	}
}

//	MARK: -

extension PlatformSlider {
	static var intrinsicViewableSize:CGSize {
		return CGSize(width:-1, height:33)
	}
	
	var trackingFrame:CGRect {
		if let image = currentThumbImage {
			return frame.insetBy(dx:image.size.width / 2, dy:0)
		} else {
			return frame.insetBy(dx:bounds.size.height / 2, dy:0)
		}
	}
	
	var doubleValue:Double {
		get { return Double(value) }
		set { value = Float(newValue) }
	}
	
	var valueRange:ClosedRange<Double> {
		get { return Double(minimumValue) ... Double(max(minimumValue, maximumValue)) }
		set { minimumValue = Float(newValue.lowerBound); maximumValue = Float(newValue.upperBound) }
	}
	
	func applyVieawbleAction(target:AnyObject?, action:Selector?) {
		removeTarget(nil, action:nil, for:.valueChanged)
		
		if let action = action {
			addTarget(target, action:action, for:.valueChanged)
		}
	}
	
	func prepareViewableSlider(target:AnyObject?, action:Selector?, minimumTrackColor:PlatformColor?) {
		if let color = minimumTrackColor {
			minimumTrackTintColor = color
		}
		
		applyVieawbleAction(target:target, action:action)
	}
}

//	MARK: -

extension PlatformSpinner {
	var isHiddenWhenStopped:Bool {
		get { return hidesWhenStopped }
		set { hidesWhenStopped = newValue }
	}
	
	func applyAnimating(_ isAnimating:Bool) {
		if isAnimating {
			startAnimating()
		} else {
			stopAnimating()
		}
	}
	
	func prepareViewableSpinner() {
	}
}

//	MARK: -

extension PlatformSwitch {
	func prepareViewableSwitch(target:AnyObject? = nil, action:Selector?) {
		applyVieawbleAction(target:target, action:action)
	}
	
	func applyVieawbleAction(target:AnyObject?, action:Selector?) {
		removeTarget(nil, action:nil, for:.valueChanged)
		
		if let action = action {
			addTarget(target, action:action, for:.valueChanged)
		}
	}
}
#endif

//	MARK: -

protocol PlatformSizeChangeView: PlatformView {
	var priorSize:CGSize { get set }
	func sizeChanged()
}

extension PlatformSizeChangeView {
	func sizeMayHaveChanged(newSize:CGSize) {
		guard newSize != priorSize else { return }
		
		priorSize = newSize
		sizeChanged()
	}
}

//	MARK: -

enum Common {
	struct Interface {
		static var scale:CGFloat {
#if os(macOS)
			return NSScreen.main?.backingScaleFactor ?? 1
#else
			return UIScreen.main.scale
#endif
		}
		
		enum Idiom {
			case unspecified, phone, pad, mac, car, tv
			
			static var current:Idiom {
#if os(macOS)
				return .mac
#else
				switch UIDevice.current.userInterfaceIdiom {
				case .carPlay: return .car
				case .mac: return .mac
				case .pad: return .pad
				case .phone: return .phone
				case .tv: return .tv
				default: return .unspecified
				}
#endif
			}
		}
		
		enum Style {
			case unspecified, dark, light
			
			var isDark:Bool {
				switch self {
				case .dark: return true
				default: return false
				}
			}
			
			static var current:Style {
#if os(macOS)
				let appearance:NSAppearance?
				
				if #available(macOS 11.0, *) {
					appearance = NSAppearance.currentDrawing()
				} else {
					appearance = NSAppearance.current
				}
				
				let isDark = appearance?.name.rawValue.range(of:"Dark", options:.caseInsensitive) != nil
				
				return isDark ? .dark : .light
#else
				let traits = UIScreen.main.traitCollection
				
				switch traits.userInterfaceStyle {
				case .light: return .light
				case .dark: return .dark
				default: return .unspecified
				}
#endif
			}
		}
		
		var scale:CGFloat
		var idiom:Idiom
		var style:Style
		
		static var current:Interface {
			return Interface(scale:Interface.scale, idiom:.current, style:.current)
		}
	}
	
	struct Recognizer {
		enum Gesture {
		case pan(Bool)
		case tap(Bool, Int)
		case press(Bool, TimeInterval?, CGFloat?)
		case rotation
		case magnification
		}
		
		let gesture:Gesture
		let action:Selector
		weak var target:AnyObject?
		
		var recognizer: PlatformGestureRecognizer {
			switch gesture {
			case .pan(let two):
				let recognizer = PlatformPanGestureRecognizer(target:target, action:action)
				
				if two {
#if os(macOS)
					recognizer.buttonMask = 2
#else
					recognizer.minimumNumberOfTouches = 2
#endif
				}
				
				return recognizer
			
			case .tap(let two, let times):
				let recognizer = PlatformTapGestureRecognizer(target:target, action:action)
				
				if two {
#if os(macOS)
					recognizer.buttonMask = 2
#else
					recognizer.numberOfTouchesRequired = 2
#endif
				}
				
				if times > 1 {
#if os(macOS)
					recognizer.numberOfClicksRequired = times
#else
					recognizer.numberOfTapsRequired = times
#endif
				}
				
				return recognizer
			
			case .press(let two, let duration, let movement):
				let recognizer = PlatformPressGestureRecognizer(target:target, action:action)
				
				if let duration = duration {
					recognizer.minimumPressDuration = duration
				}
				
				if let movement = movement {
					recognizer.allowableMovement = movement
				}
				
				if two {
#if os(macOS)
					recognizer.buttonMask = 2
#else
					recognizer.numberOfTouchesRequired = 2
#endif
				}
				
				return recognizer
			
			case .rotation:
				let recognizer = PlatformRotationGestureRecognizer(target:target, action:action)
				
				return recognizer
			
			case .magnification:
				let recognizer = PlatformMagnificationGestureRecognizer(target:target, action:action)
				
				return recognizer
			}
		}
		
		init(_ gesture:Gesture, target:AnyObject?, action:Selector) {
			self.gesture = gesture
			self.target = target
			self.action = action
		}
		
		static func attachRecognizers(_ recognizers:[Recognizer], to view:PlatformView) {
			for recognizer in recognizers where recognizer.target != nil {
				view.addGestureRecognizer(recognizer.recognizer)
			}
			
#if os(macOS)
#else
			view.isUserInteractionEnabled = true
#endif
		}
	}
}
