//
//  Common.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import Foundation

#if os(macOS)
import Cocoa

typealias PlatformFont = NSFont
typealias PlatformFontDescriptor = NSFontDescriptor
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
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
typealias PlatformTableView = NSTableView
typealias PlatformTableColumn = NSTableColumn
typealias PlatformTableViewCell = NSTableCellView
typealias PlatformTableDelegate = NSTableViewDelegate
typealias PlatformTableDataSource = NSTableViewDataSource
typealias PlatformColorWell = NSColorWell
typealias PlatformVisualEffectView = NSVisualEffectView

#else
import UIKit

typealias PlatformFont = UIFont
typealias PlatformFontDescriptor = UIFontDescriptor
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
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
typealias PlatformTableView = UITableView
typealias PlatformTableViewCell = UITableViewCell
typealias PlatformTableDelegate = UITableViewDelegate
typealias PlatformTableDataSource = UITableViewDataSource
typealias PlatformVisualEffectView = UIVisualEffectView

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
		
		if #available(OSX 10.14, *), let color = color {
			contentTintColor = color
		}
	}
}

//	MARK: -

extension PlatformLabel {
	var text:String? { return stringValue }
	
	var maximumLines:Int {
		get {
			if #available(OSX 10.11, *) {
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
		
		if #available(OSX 10.11, *) {
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
	
	var valueRange:ClosedRange<Double> {
		get { return minValue ... max(minValue, maxValue) }
		set { minValue = newValue.lowerBound; maxValue = newValue.upperBound }
	}
	
	func prepareViewableSlider(target:AnyObject?, action:Selector?, minimumTrackColor:PlatformColor?) {
		sliderType = .linear
		
		if #available(OSX 10.12.2, *), let color = minimumTrackColor {
			trackFillColor = color
		}
		
		if #available(OSX 11.0, *) {
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
