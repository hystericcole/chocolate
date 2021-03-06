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
typealias PlatformFontManager = NSFontManager
typealias PlatformFontDescriptor = NSFontDescriptor
typealias PlatformColor = NSColor
typealias PlatformColorPanel = NSColorPanel
typealias PlatformImage = NSImage
typealias PlatformPasteboard = NSPasteboard
typealias PlatformEvent = NSEvent
typealias PlatformApplication = NSApplication
typealias PlatformScreen = NSScreen
typealias PlatformWindow = NSWindow
typealias PlatformResponder = NSResponder
typealias PlatformViewController = NSViewController
typealias PlatformTabController = NSTabViewController
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
typealias PlatformEdgeInsets = NSEdgeInsets

#else
import UIKit
import CoreServices

typealias PlatformFont = UIFont
typealias PlatformFontDescriptor = UIFontDescriptor
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformPasteboard = UIPasteboard
typealias PlatformEvent = UIEvent
typealias PlatformApplication = UIApplication
typealias PlatformScreen = UIScreen
typealias PlatformWindow = UIWindow
typealias PlatformResponder = UIResponder
typealias PlatformViewController = UIViewController
typealias PlatformTabController = UITabBarController
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
typealias PlatformEdgeInsets = UIEdgeInsets

@available(iOS 14.0, *)
typealias PlatformColorWell = UIColorWell
#endif

//	MARK: -

extension CTFont {
	var platformFont:PlatformFont { return self as PlatformFont }
}

//	MARK: -

extension CGRect {
	func padded(by insets:PlatformEdgeInsets) -> CGRect {
		return CGRect(x:origin.x - insets.left, y:origin.y - insets.top, width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
	}
}

//	MARK: -

#if os(macOS)

extension CGColor {
	var platformColor:PlatformColor { return PlatformColor(cgColor:self) ?? .clear }
}

//	MARK: -

class PlatformTaggableView: CommonView {
	var _tag = 0
	var isUserInteractionEnabled:Bool = true
	override var isFlipped:Bool { return true }
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	
	func prepareViewableColor(isOpaque:Bool) {
		isUserInteractionEnabled = false
		wantsLayer = true
		layer?.isOpaque = isOpaque
		compressionResistance = .zero
	}
	
	override func hitTest(_ point: NSPoint) -> NSView? {
		return isUserInteractionEnabled ? super.hitTest(point) : nil
	}
}

//	MARK: -

extension PlatformAutoresizing {
	static let flexibleSize:PlatformAutoresizing = [.width, .height]
}

//	MARK: -

extension CGImage {
	func pngData() -> Data? {
		return NSBitmapImageRep(cgImage:self).representation(using:.png, properties:[:])
	}
}

//	MARK: -

extension PlatformPasteboard {
	func setImage(_ image:PlatformImage) {
		declareTypes([.png], owner:nil)
		writeObjects([image])
	}
	
	func setString(_ string:String) {
		declareTypes([.string], owner:nil)
		setString(string, forType:.string)
	}
	
	func setPNG(_ data:Data) {
		declareTypes([.png], owner:nil)
		setData(data, forType:.png)
	}
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
	
	var screenColorSpace:CGColorSpace? {
		return window?.screen?.colorSpace?.cgColorSpace
	}
	
	var backgroundColor:PlatformColor? {
		get { return layer?.backgroundColor?.platformColor }
		set { layer?.backgroundColor = newValue?.cgColor }
	}
	
	func scheduleLayout() {
		needsLayout = true
	}
	
	func scheduleDisplay() {
		needsDisplay = true
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
	var interfaceStyle:Common.Interface.Style {
		get { return scrollerKnobStyle.interfaceStyle }
		set { scrollerKnobStyle.interfaceStyle = newValue }
	}
	
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

extension PlatformScroller.KnobStyle {
	var interfaceStyle:Common.Interface.Style {
		get {
			switch self {
			case .light: return .dark
			case .dark: return .light
			default: return .unspecified
			}
		}
		set {
			switch newValue {
			case .dark: self = .light
			case .light: self = .dark
			case .unspecified: self = .default
			}
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
		setContentCompressionResistancePriority(.defaultLow, for:.horizontal)
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

//	MARK: -

extension PlatformViewController {
	var isUnderTabBar:Bool { return false }
	var isUnderNavigationBar:Bool { return false }
}

//	MARK: -

extension PlatformTabController {
	var viewControllers:[PlatformViewController] {
		get { return tabViewItems.compactMap { $0.viewController } }
		set { tabViewItems = newValue.map(NSTabViewItem.init) }
	}
	
	var selectedIndex:Int {
		get { return selectedTabViewItemIndex }
		set { selectedTabViewItemIndex = newValue }
	}
	
	var selectedViewController:PlatformViewController? {
		get { return tabViewItems[selectedIndex].viewController }
		set { if let index = tabViewItems.firstIndex(where:{ $0.viewController === newValue }) { selectedIndex = index }  }
	}
}

#else

typealias PlatformTaggableView = CommonView

extension CGColor {
	var platformColor:PlatformColor { return PlatformColor(cgColor:self) }
}

//	MARK: -

extension PlatformAutoresizing {
	static let flexibleSize:PlatformAutoresizing = [.flexibleWidth, .flexibleHeight]
}

//	MARK: -

extension CGImage {
	func pngData() -> Data? {
		return UIImage(cgImage:self).pngData()
	}
}

//	MARK: -

extension PlatformApplication {
	func sendAction(_ action:Selector, to target:AnyObject?, from sender:AnyObject?) {
		self.sendAction(action, to:target, from:sender, for:nil)
	}
}

//	MARK: -

extension PlatformPasteboard {
	func setImage(_ image:PlatformImage) {
		self.image = image
	}
	
	func setString(_ string:String) {
		self.string = string
	}
	
	func setPNG(_ data:Data) {
		setData(data, forPasteboardType:kUTTypePNG as String)
	}
}

//	MARK: -

extension PlatformView {
	var screenColorSpace:CGColorSpace? {
		if #available(macOS 10.11.2, iOS 9.3, *), let display = CGColorSpace(name:CGColorSpace.displayP3) { return display }
		
		return nil
	}
	
	func prepareViewableColor(isOpaque:Bool) {
		self.isUserInteractionEnabled = false
		self.isOpaque = isOpaque
	}
	
	func scheduleDisplay() {
		setNeedsDisplay()
	}
	
	func scheduleLayout() {
		setNeedsLayout()
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
	var interfaceStyle:Common.Interface.Style {
		get { return indicatorStyle.interfaceStyle }
		set { indicatorStyle.interfaceStyle = newValue }
	}
	
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

extension PlatformScrollingView.IndicatorStyle {
	var interfaceStyle:Common.Interface.Style {
		get {
			switch self {
			case .black: return .light
			case .white: return .dark
			default: return .unspecified
			}
		}
		set {
			switch newValue {
			case .dark: self = .white
			case .light: self = .black
			case .unspecified: self = .default
			}
		}
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
		
		setContentCompressionResistancePriority(.defaultLow, for:.horizontal)
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

//	MARK: -

extension PlatformViewController {
	var isUnderTabBar:Bool { return tabBarController?.tabBar.isTranslucent ?? false }
	var isUnderNavigationBar:Bool { return navigationController?.navigationBar.isTranslucent ?? false }
}

#endif

//	MARK: -

protocol ViewControllerAttachable: AnyObject {
	func attachViewController(_ viewController:PlatformViewController)
}

//	MARK: -

extension PlatformView {
	var stableBounds:CGRect {
		return CGRect(origin:.zero, size:bounds.size)
	}
	
	var safeBounds:CGRect {
#if os(macOS)
		if #available(macOS 11.0, *) {
			let insets = safeAreaInsets
			let size = bounds.size
			
			return CGRect(x:insets.left, y:insets.top, width:size.width - insets.left - insets.right, height:size.height - insets.top - insets.bottom)
		}
		
		return stableBounds
#else
		return stableBounds.inset(by:safeAreaInsets)
#endif
	}
}

//	MARK: -

extension CALayer {
	var view:PlatformView? {
		return delegate as? PlatformView
	}
}

//	MARK: -

class CommonViewController: PlatformViewController {
	override init(nibName nibNameOrNil:String?, bundle nibBundleOrNil:Bundle?) {
		super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	func prepare() {}
}

//	MARK: -

class CommonTabController: PlatformTabController {
#if os(macOS)
#else
	override var viewControllers:[UIViewController]? {
		didSet {
			let index = selectedIndex
			
			selectedIndex = index ^ 1
			selectedIndex = index
		}
	}
#endif
	
	override init(nibName nibNameOrNil:String?, bundle nibBundleOrNil:Bundle?) {
		super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	func prepare() {}
}

//	MARK: -

class CommonView: PlatformView {
#if os(macOS)
	override var isFlipped:Bool { return true }
#endif
	
	override init(frame:CGRect) {
		super.init(frame:frame)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	func prepare() {}
}

//	MARK: -

class CommonControl: PlatformControl {
#if os(macOS)
	override var isFlipped:Bool { return true }
#endif
	
	override init(frame:CGRect) {
		super.init(frame:frame)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	func prepare() {}
}

//	MARK: -

enum Common {
	struct AnimationTiming {
		let c1, c2:CGPoint
		
		var function:CAMediaTimingFunction {
			return CAMediaTimingFunction(controlPoints:Float(c1.x), Float(c1.y), Float(c2.x), Float(c2.y))
		}
		
#if os(macOS)
#else
		var parameters:UICubicTimingParameters {
			return UICubicTimingParameters(controlPoint1:c1, controlPoint2:c2)
		}
#endif
		
		static let linear = AnimationTiming(c1:.zero, c2:CGPoint(x:1.0, y:1.0))
		static let easeIn = AnimationTiming(c1:CGPoint(x:0.42, y:0.0), c2:CGPoint(x:1.0, y:1.0))
		static let easeOut = AnimationTiming(c1:.zero, c2:CGPoint(x:0.58, y:1.0))
		static let easeInOut = AnimationTiming(c1:CGPoint(x:0.42, y:0.0), c2:CGPoint(x:0.58, y:1.0))
		static let systemDefault = AnimationTiming(c1:CGPoint(x:0.25, y:0.1), c2:CGPoint(x:0.25, y:1.0))
	}
	
	static func animate(duration:TimeInterval = 0.25, timing:AnimationTiming = .systemDefault, animations:@escaping () -> Void, completion:((Bool) -> Void)? = nil) {
#if os(macOS)
		NSAnimationContext.runAnimationGroup({ context in
			context.allowsImplicitAnimation = true
			context.duration = duration
			context.timingFunction = timing.function
			
			animations()
		}, completionHandler:completion != nil ? {
			completion!(true)
		} : nil)
#else
		let animator = UIViewPropertyAnimator(duration:duration, timingParameters:timing.parameters)
		
		if let completion = completion {
			animator.addCompletion { completion($0 == UIViewAnimatingPosition.end) }
		}
		
		animator.addAnimations(animations)
		animator.startAnimation()
#endif
	}
	
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
			
			func isKind(_ recognizer:PlatformGestureRecognizer) -> Bool {
				switch self {
				case .pan: return recognizer is PlatformPanGestureRecognizer
				case .tap: return recognizer is PlatformTapGestureRecognizer
				case .press: return recognizer is PlatformPressGestureRecognizer
				case .rotation: return recognizer is PlatformRotationGestureRecognizer
				case .magnification: return recognizer is PlatformMagnificationGestureRecognizer
				}
			}
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
		
		func isEquivalent(_ recognizer:PlatformGestureRecognizer) -> Bool {
#if os(macOS)
			guard recognizer.action == action && recognizer.target === target else { return false }
#endif
			
			return gesture.isKind(recognizer)
		}
		
		func attachToView(_ view:PlatformView) {
			view.addGestureRecognizer(recognizer)
			
#if os(macOS)
#else
			view.isUserInteractionEnabled = true
#endif
		}
		
		func detachFromView(_ view:PlatformView) {
#if os(macOS)
			let recognizers = view.gestureRecognizers
#else
			guard let recognizers = view.gestureRecognizers else { return }
#endif
			
			for recognizer in recognizers where isEquivalent(recognizer) {
				view.removeGestureRecognizer(recognizer)
			}
		}
		
		static func attachRecognizers(_ recognizers:[Recognizer], to view:PlatformView) {
			for recognizer in recognizers where recognizer.target != nil {
				recognizer.attachToView(view)
			}
		}
	}
}
