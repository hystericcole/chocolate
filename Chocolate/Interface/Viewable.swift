//
//  Viewable.swift
//  Chocolate
//
//  Created by Eric Cole on 2/1/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import QuartzCore
import Foundation

protocol LazyViewable: AnyObject, Positionable {
	var existingView:PlatformView? { get }
	var viewType:PlatformView.Type { get }
	var lazyView:PlatformView { get }
	var tag:Int { get }
	
	func attachToExistingView(_ view:PlatformView?)
	func detachView(prepareForReuse:Bool)
}

//	MARK: -

/// A Viewable can create and manage a view.  Most viewables can measure a view without creating it.
/// # Positionable
/// Views, Viewables, and Layouts are all Positionables, and can be mixed and used together.
/// # View
/// A viewable can be used to simplify the creation of a view, then discarded, keeping the view.
/// This would typically be used within another view.
/// 
/// ```
/// let gradient = Viewable.Gradient(colors: [.red, .blue]).lazy()
/// ```
/// # Layout
/// A viewable can be created directly within a layout, if no further interaction is needed.
/// The view will not be created until the layout is ordered in a container.
///
/// ```
/// Layout.Overlay(targets: [Viewable.Color(color: .green), anotherView])
/// ```
/// # View Controller
/// A viewable can be used to prepare a view for later creation.
/// This would typically be used in a view controller.
/// The view will not be created until ordered, usually in `viewDidLoad`.
/// Using a viewable can simplify attaching targets and delegates to views.
/// 
/// ```
/// let slider = Viewable.Slider(target: self, action: #selector(sliderValueChanged))
/// ```
/// Use a Viewable.Group or Viewable.Scroll as the root view of a view controller that only uses Positionable layout.
/// # Cell
/// A viewable can be used as the model for a cell.
/// The viewable can be used to measure the cell before it is created, for most content.
/// When the cell is created, the viewable is ordered into the cell.
/// When the cell is reused, one viewable is detached from the views in the cell, and later a similar viewable can be attached to the same views.
///
/// ```
/// let imageView = Viewable.Image(image: ...)
/// let content = imageView.padded(10)
/// let height = content.positionableSize(Layout.Limit(size: bounds.size)).height.resolve(bounds.size.height)
/// cell.contentView.orderPositionables([content], cell.positionableEnvironment)
/// ```
protocol ViewablePositionable: LazyViewable {
	associatedtype ViewType: PlatformView
	
	var view:ViewType? { get set }
	
	func lazy() -> ViewType
	func applyToView(_ view:ViewType)
	func attachToView(_ view:ViewType)
}

//	MARK: -

extension ViewablePositionable {
	var existingView:PlatformView? { return view }
	var lazyView:PlatformView { return lazy() }
	var viewType:PlatformView.Type { return ViewType.self }
	var frame:CGRect { return view?.frame ?? .zero }
	var compressionResistance:CGPoint { return view?.compressionResistance ?? .zero }
	
	func lazy() -> ViewType {
		if let view = view { return view }
		
		let view = ViewType()
		
		applyToView(view)
		attachToView(view)
		
		return view
	}
	
	func attachToExistingView(_ view:PlatformView?) {
		guard let view = view as? ViewType else { return }
		
		applyToView(view)
		attachToView(view)
	}
	
	func attachToView(_ view:ViewType) { self.view = view }
	func detachView(prepareForReuse:Bool) { self.view = nil }
	
	func applyPositionableFrame(_ frame:CGRect, context:Layout.Context) {
		view?.applyPositionableFrame(frame, context:context)
	}
	
	func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
		switch order {
		case .attach: return [self]
		case .create: return lazy().orderablePositionables(environment:environment, order:order)
		case .existing: return view?.orderablePositionables(environment:environment, order:order) ?? [self]
		}
	}
}

//	MARK: -

extension Positionable {
	@discardableResult
	func hide() -> Positionable { Viewable.hide(self, isHidden:true); return self }
	@discardableResult
	func show() -> Positionable { Viewable.hide(self, isHidden:false); return self }
	@discardableResult
	func fade(_ opacity:CGFloat) -> Positionable { Viewable.fade(self, opacity:opacity); return self }
	@discardableResult
	func shadow(_ shadow:CALayer.Shadow) -> Positionable { Viewable.applyShadow(self, shadow:shadow); return self }
	@discardableResult
	func border(_ border:CALayer.Border) -> Positionable { Viewable.applyBorder(self, border:border); return self }
	@discardableResult
	func remove() -> Positionable { Viewable.remove(self); return self }
	func rounded() -> Positionable { return Viewable.Rounded(target:self) }
	func recognize(_ gesture:Common.Recognizer.Gesture, target:AnyObject, action:Selector) -> Positionable { return recognize(Common.Recognizer(gesture, target:target, action:action)) }
	func recognize(_ recognizers:Common.Recognizer...) -> Positionable { return Viewable.AttachRecognizers(target:self, recognizers:recognizers) }
}

//	MARK: -

enum Viewable {
	class Group: ViewablePositionable {
		typealias ViewType = ViewableGroupView
		
		struct Model {
			let tag:Int
			var content:Positionable
			
			init(tag:Int = 0, content:Positionable) {
				self.tag = tag
				self.content = content
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var content:Positionable {
			get { return view?.content ?? model.content }
			set { model.content = newValue; view?.content = newValue }
		}
		
		init(tag:Int = 0, content:Positionable) {
			self.model = Model(tag:tag, content:content)
		}
		
		func applyToView(_ view:ViewableGroupView) {
			view.tag = model.tag
			view.prepareViewableGroup()
			view.content = model.content
		}
		
		func attachToView(_ view:ViewType) { self.view = view }
		
		func attachToExistingView(_ view: PlatformView?) {
			guard let view = view as? ViewType else { return }
			
			view.attachPositionables(content, environment:view.positionableEnvironment)
			applyToView(view)
			attachToView(view)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return model.content.positionableSize(fitting:limit)
		}
	}
	
	class Color: ViewablePositionable {
		typealias ViewType = ViewableColorView
		
		struct Model {
			let tag:Int
			var color:PlatformColor?
			var intrinsicSize:CGSize
			
			init(tag:Int = 0, color:PlatformColor? = nil, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
				self.tag = tag
				self.color = color
				self.intrinsicSize = intrinsicSize
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var color:PlatformColor? {
			get { return view?.backgroundColor ?? model.color }
			set { model.color = newValue; view?.backgroundColor = newValue }
		}
		
		var intrinsicSize:CGSize {
			get { return model.intrinsicSize }
			set { model.intrinsicSize = newValue; view?.invalidateIntrinsicContentSize() }
		}
		
		init(tag:Int = 0, color:PlatformColor?, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
			self.model = Model(tag:tag, color:color, intrinsicSize:intrinsicSize)
		}
		
		func applyToView(_ view:ViewType) {
			view.tag = model.tag
			view.prepareViewableColor(isOpaque:model.color?.cgColor.alpha ?? 0 < 1)
			view.backgroundColor = model.color
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(prefer:model.intrinsicSize, maximum:model.intrinsicSize)
		}
	}
	
	class Button: ViewablePositionable {
		typealias ViewType = ViewableButton
		
		struct Model {
			let tag:Int
			let content:Positionable
			weak var target:AnyObject?
			var action:Selector?
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		init(tag:Int = 0, content:Positionable, target:AnyObject? = nil, action:Selector?) {
			self.model = Model(tag:tag, content:content, target:target, action:action)
		}
		
		func applyToView(_ view:ViewableButton) {
			view.tag = model.tag
			view.content = model.content
			view.prepareViewableButton()
			view.applyVieawbleAction(target:model.target, action:model.action)
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			view?.applyVieawbleAction(target:target, action:action)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return model.content.positionableSize(fitting:limit)
		}
	}
	
	class Label: ViewablePositionable {
		typealias ViewType = PlatformLabel
		
		struct Model {
			let tag:Int
			var string:NSAttributedString?
			var maximumLines:Int
			var intrinsicWidth:CGFloat
			
			init(tag:Int = 0, string:NSAttributedString? = nil, maximumLines:Int = 0, intrinsicWidth:CGFloat = 0) {
				self.tag = tag
				self.string = string
				self.intrinsicWidth = intrinsicWidth
				self.maximumLines = maximumLines
			}
			
			func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
				guard let string = string else { return .zero }
				
				var sizeLimit = limit.size
				
				if intrinsicWidth > 0 && intrinsicWidth < sizeLimit.width {
					sizeLimit.width = intrinsicWidth
				}
				
				return Layout.Size(
					stringSize:string.boundsWrappingWithSize(sizeLimit).size,
					stringLength:string.length,
					maximumHeight:limit.height,
					maximumLines:maximumLines
				)
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var attributedText:NSAttributedString? {
			get { return view?.attributedText ?? model.string }
			set { model.string = newValue; view?.attributedText = newValue }
		}
		
		var intrinsicWidth:CGFloat {
			get { return view?.preferredMaxLayoutWidth ?? model.intrinsicWidth }
			set { model.intrinsicWidth = newValue; view?.preferredMaxLayoutWidth = newValue }
		}
		
		var textColor:PlatformColor? {
			get { return view?.textColor }
			set { view?.textColor = newValue }
		}
		
		var text:String? {
			get { return attributedText?.string }
			set { applyText(newValue) }
		}
		
		init(tag:Int = 0, string:NSAttributedString?, maximumLines:Int = 0, intrinsicWidth:CGFloat = 0) {
			self.model = Model(tag:tag, string:string, maximumLines:maximumLines, intrinsicWidth:intrinsicWidth)
		}
		
		func applyToView(_ view:PlatformLabel) {
			view.tag = model.tag
			view.attributedText = model.string
			view.prepareViewableLabel(intrinsicWidth:model.intrinsicWidth, maximumLines:model.maximumLines)
		}
		
		func applyText(_ text:String?) {
			if let string = model.string {
				attributedText = string.withText(text ?? "")
			} else if let text = text {
				attributedText = NSAttributedString(string:text)
			}
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? model.positionableSize(fitting:limit)
		}
	}
	
	class Image: ViewablePositionable {
		typealias ViewType = PlatformImageView
		typealias ImageOnMainThread = ((PlatformImage?) -> Void) -> Void
		
		struct Model {
			let tag:Int
			var image:PlatformImage?
			var color:PlatformColor?
			var provide:ImageOnMainThread?
			
			init(tag:Int = 0, image:PlatformImage? = nil, color:PlatformColor? = nil, provide:ImageOnMainThread? = nil) {
				self.tag = tag
				self.image = image
				self.color = color
				self.provide = provide
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var image:PlatformImage? { get { return view?.image ?? model.image } set { model.image = newValue; view?.image = newValue } }
		
		init(tag:Int = 0, image:PlatformImage?, color:PlatformColor? = nil, provide:ImageOnMainThread? = nil) {
			self.model = Model(tag:tag, image:image, color:color, provide:provide)
		}
		
		func load() {
			model.provide? { [weak self] image in
				guard let `self` = self else { return }
				
				self.model.provide = nil
				
				guard let image = image else { return }
				
				self.model.image = image
				self.view?.prepareViewableImage(image:image, color:self.model.color)
			}
		}
		
		func applyToView(_ view:PlatformImageView) {
			view.tag = model.tag
			view.prepareViewableImage(image:model.image, color:model.color)
			
			load()
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			let imageSize = view?.image?.size ?? model.image?.size ?? .zero
			
			return Layout.Size(prefer:imageSize, maximum:imageSize)
		}
	}
	
	class Picker: NSObject, ViewablePositionable {
		typealias ViewType = PlatformPicker
		
		struct Model {
			let tag:Int
			var select:Int
			var itemTitles:[NSAttributedString]
			weak var target:AnyObject?
			var action:Selector?
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var select:Int {
			get { return view?.selectionIndex ?? model.select }
			set { model.select = newValue; view?.selectionIndex = newValue }
		}
		
		var titles:[NSAttributedString] {
			get { return model.itemTitles }
			set { applyItems(newValue) }
		}
		
		init(tag:Int = 0, titles:[NSAttributedString], select:Int = 0, target:AnyObject? = nil, action:Selector?) {
			self.model = Model(tag:tag, select:select, itemTitles:titles, target:target, action:action)
		}
		
		convenience init(tag:Int = 0, titles:[String], attributes:[NSAttributedString.Key:Any]? = nil, select:Int = 0, target:AnyObject? = nil, action:Selector?) {
			self.init(tag:tag, titles:titles.map { NSAttributedString(string:$0, attributes:attributes) }, select:select, target:target, action:action)
		}
		
		func applyToView(_ view:PlatformPicker) {
			view.tag = model.tag
			
#if os(macOS)
			view.addItems(withTitles:model.itemTitles)
			view.target = model.target
			view.action = model.action
			view.pullsDown = false
#else
			view.layoutMargins = .zero
			view.delegate = self
			view.dataSource = self
			view.showsSelectionIndicator = false
#endif
			
			if model.itemTitles.indices.contains(model.select) {
				view.selectionIndex = model.select
			}
		}
		
		func applyItems(_ items:[NSAttributedString]) {
			model.itemTitles = items
			
			guard let view = view else { return }
			
#if os(macOS)
			view.removeAllItems()
			view.addItems(withTitles:model.itemTitles)
#else
			view.reloadAllComponents()
#endif
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			guard let view = view else { return }
			
#if os(macOS)
			view.target = model.target
			view.action = model.action
#else
			view.delegate = self
			view.dataSource = self
#endif
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? .zero
		}
	}
	
	class Scroll: ViewablePositionable {
		typealias ViewType = ViewableScrollingView
		typealias ZoomRange = ClosedRange<CGFloat>
		
		struct Model {
			let tag:Int
			var content:Positionable
			var minimum:CGSize
			var maximum:CGSize
			var zoomRange:ZoomRange
			
			init(tag:Int = 0, content:Positionable, minimum:CGSize, maximum:CGSize, zoomRange:ZoomRange) {
				self.tag = tag
				self.content = content
				self.minimum = minimum
				self.maximum = maximum
				self.zoomRange = zoomRange
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var minimum:CGSize {
			get { return model.minimum }
			set { model.minimum = newValue }
		}
		
		var maximum:CGSize {
			get { return model.maximum }
			set { model.maximum = newValue }
		}
		
		var content:Positionable {
			get { return view?.content ?? model.content }
			set { model.content = newValue; view?.content = newValue }
		}
		
		var zoom:CGFloat {
			get { return view?.zoomScale ?? 1 }
			set { view?.zoomScale = newValue }
		}
		
		var zoomRange:ZoomRange {
			get { return view?.zoomRange ?? model.zoomRange }
			set { model.zoomRange = newValue; view?.zoomRange = newValue }
		}
		
		init(tag:Int = 0, content:Positionable, minimum:CGSize? = nil, maximum:CGSize? = nil, zoomRange:ZoomRange = 1 ... 1) {
			self.model = Model(tag:tag, content:content, minimum:minimum ?? .zero, maximum:maximum ?? Layout.Size.unbound, zoomRange:zoomRange)
		}
		
		func applyToView(_ view:ViewableScrollingView) {
			view.tag = model.tag
			view.zoomRange = model.zoomRange
			view.prepareViewableScroll()
			view.content = model.content
		}
		
		func flashScrollers() {
			view?.flashScrollers()
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			var size = model.content.positionableSize(fitting:limit)
			
			size.minimize(minimum:model.minimum, maximum:model.maximum)
			
			return size
		}
	}
	
	class Slider: ViewablePositionable {
		typealias ViewType = PlatformSlider
		
		struct Model {
			let tag:Int
			var value:Double
			var range:ClosedRange<Double>
			weak var target:AnyObject?
			var action:Selector?
			var minimumTrackColor:PlatformColor?
			var intrinsicSize:CGSize
			
			init(tag:Int = 0, value:Double, range:ClosedRange<Double> = 0 ... 1, target:AnyObject? = nil, action:Selector? = nil, minimumTrackColor:PlatformColor? = nil) {
				self.tag = tag
				self.value = value
				self.range = range
				self.target = target
				self.action = action
				self.minimumTrackColor = minimumTrackColor
				self.intrinsicSize = PlatformSlider.intrinsicViewableSize
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var value:Double {
			get { return view?.doubleValue ?? model.value }
			set { model.value = newValue; view?.doubleValue = newValue }
		}
		
		var range:ClosedRange<Double> {
			get { return view?.valueRange ?? model.range }
			set { model.range = newValue; view?.valueRange = newValue }
		}
		
		init(tag:Int = 0, value:Double = 0, range:ClosedRange<Double> = 0 ... 1, target:AnyObject? = nil, action:Selector?, minimumTrackColor:PlatformColor? = nil) {
			self.model = Model(tag:tag, value:value, range:range, target:target, action:action, minimumTrackColor:minimumTrackColor)
		}
		
		func applyToView(_ view:PlatformSlider) {
			view.tag = model.tag
			view.valueRange = model.range
			view.doubleValue = model.value
			view.prepareViewableSlider(target:model.target, action:model.action, minimumTrackColor:model.minimumTrackColor)
		}
		
		func attachToView(_ view:PlatformSlider) {
			self.view = view
			
			model.intrinsicSize = view.intrinsicContentSize
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			view?.applyVieawbleAction(target:target, action:action)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsic:model.intrinsicSize)
		}
	}
	
	class Shape: ViewablePositionable {
		typealias ViewType = ViewableShapeView
		typealias Style = CAShapeLayer.Style
		typealias Shadow = CALayer.Shadow
		
		struct Model {
			let tag:Int
			var path:CGPath? { didSet { boundingBox = nil } }
			var style:Style
			var shadow:Shadow?
			var boundingBox:CGRect?
			
			init(tag:Int = 0, path:CGPath? = nil, style:Style, shadow:Shadow? = nil) {
				self.tag = tag
				self.path = path
				self.style = style
				self.shadow = shadow
				self.boundingBox = nil
			}
			
			mutating func lazyBoundingBox() -> CGRect {
				if let existing = boundingBox {
					return existing
				} else if let box = path?.boundingBoxOfPath {
					boundingBox = box
					
					return box
				} else {
					return .zero
				}
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var shapeLayer:CAShapeLayer? { return view?.shapeLayer }
		
		var path:CGPath? {
			get { return shapeLayer?.path ?? model.path }
			set { model.path = newValue; applyPath(path) }
		}
		
		var style:Style {
			get { return shapeLayer?.shapeStyle ?? model.style }
			set { model.style = newValue; shapeLayer?.shapeStyle = newValue }
		}
		
		var shadow:Shadow? {
			get { return shapeLayer?.shadow ?? model.shadow }
			set { model.shadow = newValue; shapeLayer?.shadow = newValue ?? .default }
		}
		
		init(tag:Int = 0, path:CGPath? = nil, style:Style, shadow:Shadow? = nil) {
			self.model = Model(tag:tag, path:path, style:style, shadow:shadow)
		}
		
		func pathForSize(_ size:CGSize) -> CGPath? {
			guard size.minimum > 0, let path = model.path, !path.isEmpty else { return nil }
			
			let stroke = model.style.stroke?.alpha ?? 0 > 0 ? model.style.width : 0
			let box = model.lazyBoundingBox()
			let size = CGSize(width:size.width - stroke, height:size.height - stroke)
			var transform = CGAffineTransform(a:size.width / box.size.width, b:0, c:0, d:size.height / box.size.height, tx:stroke / 2 - box.origin.x, ty:stroke / 2 - box.origin.y)
			
			return path.copy(using:&transform) ?? path
		}
		
		func applyPath(_ path:CGPath?) {
			model.path = path
			
			guard let layer = view?.shapeLayer else { return }
			
			let path = pathForSize(layer.bounds.size)
			
			layer.path = path
			layer.shadowPath = path
		}
		
		func applyToView(_ view:ViewableShapeView) {
			view.tag = model.tag
			view.prepareViewableColor(isOpaque:false)
			
			if let layer = view.shapeLayer {
				let path = pathForSize(layer.bounds.size)
				let hasShadow = model.shadow?.opacity ?? 0 > 0
				
				layer.path = path
				layer.shapeStyle = model.style
				layer.shadow = model.shadow ?? .default
				layer.shadowPath = path
				layer.masksToBounds = !hasShadow
			}
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(prefer:model.lazyBoundingBox().size)
		}
		
		func applyPositionableFrame(_ frame:CGRect, context:Layout.Context) {
			guard let view = view else { return }
			
#if os(macOS)
			//	NSView also sets shadow properties of layer
			if let layer = view.shapeLayer, let shadow = model.shadow {
				layer.shadow = shadow
			}
#endif
			
			if let layer = view.shapeLayer, let path = pathForSize(frame.size) {
				layer.path = path
				layer.shadowPath = path
			}
			
			view.applyPositionableFrame(frame, context:context)
		}
	}
	
	class Gradient: ViewablePositionable {
		typealias ViewType = ViewableGradientView
		typealias Descriptor = CAGradientLayer.Gradient
		typealias Direction = CAGradientLayer.Direction
		
		struct Model {
			let tag:Int
			var gradient:Descriptor
			var intrinsicSize:CGSize
			
			init(tag:Int = 0, gradient:Descriptor, intrinsicSize:CGSize) {
				self.tag = tag
				self.gradient = gradient
				self.intrinsicSize = intrinsicSize
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var gradientLayer:CAGradientLayer? { return view?.gradientLayer }
		
		var descriptor:Descriptor {
			get { return gradientLayer?.gradient ?? model.gradient }
			set { model.gradient = newValue; gradientLayer?.gradient = newValue }
		}
		
		var colors:[CGColor] {
			get { return gradientLayer?.colors as? [CGColor] ?? model.gradient.colors }
			set { model.gradient.colors = newValue; gradientLayer?.colors = newValue }
		}
		
		var direction:Direction {
			get { return gradientLayer?.direction ?? model.gradient.direction }
			set { model.gradient.direction = newValue; gradientLayer?.direction = newValue }
		}
		
		var intrinsicSize:CGSize {
			get { return model.intrinsicSize }
			set { model.intrinsicSize = newValue; view?.invalidateIntrinsicContentSize() }
		}
		
		init(tag:Int = 0, gradient:Descriptor, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
			self.model = Model(tag:tag, gradient:gradient, intrinsicSize:intrinsicSize)
		}
		
		convenience init(tag:Int = 0, colors:[PlatformColor], locations:[NSNumber]? = nil, direction:Direction = .maxY, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
			self.init(tag:tag, gradient:Descriptor(colors:colors.map { $0.cgColor }, locations:locations, direction:direction), intrinsicSize:intrinsicSize)
		}
		
		func applyToView(_ view:ViewableGradientView) {
			view.tag = model.tag
			view.prepareViewableColor(isOpaque:false)
			
			if let layer = view.gradientLayer {
				layer.gradient = model.gradient
			}
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(prefer:model.intrinsicSize, maximum:model.intrinsicSize)
		}
	}
	
	class Spinner: ViewablePositionable {
		typealias ViewType = PlatformSpinner
		
		struct Model {
			var isAnimating:Bool
			var isHiddenWhenStopped:Bool
			var intrinsicSize:CGSize = Viewable.noIntrinsicSize
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { return view?.tag ?? 0 }
		
#if os(macOS)
		var isAnimating:Bool {
			get { return model.isAnimating }
			set { model.isAnimating = newValue; view?.applyAnimating(newValue) }
		}
#else
		var isAnimating:Bool {
			get { return view?.isAnimating ?? model.isAnimating }
			set { model.isAnimating = newValue; view?.applyAnimating(newValue) }
		}
#endif
		
		var isHiddenWhenStopped:Bool {
			get { return view?.isHiddenWhenStopped ?? model.isHiddenWhenStopped }
			set { model.isHiddenWhenStopped = newValue; view?.isHiddenWhenStopped = newValue }
		}
		
		init(isAnimating:Bool = true, isHiddenWhenStopped:Bool = true) {
			self.model = Model(isAnimating:isAnimating, isHiddenWhenStopped:isHiddenWhenStopped)
		}
		
		func applyToView(_ view:PlatformSpinner) {
			view.isHiddenWhenStopped = model.isHiddenWhenStopped
			view.prepareViewableSpinner()
			view.applyAnimating(isAnimating)
		}
		
		func attachToView(_ view:PlatformSpinner) {
			self.view = view
			
			model.intrinsicSize = view.intrinsicContentSize
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsic:model.intrinsicSize)
		}
	}
	
	class Switch: ViewablePositionable {
		typealias ViewType = PlatformSwitch
		
		struct Model {
			let tag:Int
			var isOn:Bool
			weak var target:AnyObject?
			var action:Selector?
			var intrinsicSize:CGSize = Viewable.noIntrinsicSize
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var isOn:Bool {
			get { return view?.isOn ?? model.isOn }
			set { model.isOn = newValue; view?.isOn = newValue }
		}
		
		init(tag:Int = 0, isOn:Bool = false, target:AnyObject? = nil, action:Selector?) {
			self.model = Model(tag:tag, isOn:isOn, target:target, action:action)
		}
		
		func applyToView(_ view:PlatformSwitch) {
			view.tag = model.tag
			view.isOn = model.isOn
			view.prepareViewableSwitch(target:model.target, action:model.action)
		}
		
		func attachToView(_ view:PlatformSwitch) {
			self.view = view
			
			model.intrinsicSize = view.intrinsicContentSize
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			view?.applyVieawbleAction(target:target, action:action)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsic:model.intrinsicSize)
		}
	}
	
	class SimpleTable: NSObject, ViewablePositionable {
		typealias ViewType = ViewableTableView
		
		struct Model {
			let tag:Int
			var cells:[Positionable]
			var minimum:CGSize
			var maximum:CGSize
			weak var target:AnyObject?
			var action:Selector?
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
		var cells:[Positionable] {
			get { return model.cells }
			set { model.cells = newValue; view?.reloadData() }
		}
		
#if os(macOS)
		var selectionIndex:Int {
			get { return view?.tableView.selectedRow ?? -1 }
			set { view?.tableView.selectRowIndexes(IndexSet(integer:newValue), byExtendingSelection:false) }
		}
#else
		var selectionIndex:Int {
			get { return view?.indexPathForSelectedRow?.row ?? -1 }
			set { view?.selectRow(at: newValue < 0 ? nil : IndexPath(row:newValue, section:0), animated:false, scrollPosition:.middle) }
		}
#endif
		
		init(tag:Int = 0, cells:[Positionable], target:AnyObject? = nil, action:Selector? = nil, minimum:CGSize? = nil, maximum:CGSize? = nil) {
			self.model = Model(tag:tag, cells:cells, minimum:minimum ?? .zero, maximum:maximum ?? Layout.Size.unbound, target:target, action:action)
		}
		
		func applyToView(_ view:ViewableTableView) {
			view.tag = model.tag
			view.prepareViewableTable()
			view.registerCell(ViewableTableCell.self)
			view.delegate = self
			view.dataSource = self
		}
		
		func rowHeight(tableView:PlatformTableView, row:Int) -> CGFloat {
			let limit = tableView.bounds.size
			let size = model.cells[row].positionableSize(fitting:Layout.Limit(size:limit))
			
			return CGFloat(size.height.resolve(limit.height.native))
		}
		
		func rowSelected(tableView:PlatformTableView, row:Int) {
			if let target = model.target, let action = model.action {
				_ = target.perform(action, with:self)
			}
		}
		
		func rowPrepareCell(_ cell:ViewableTableCell, row:Int) -> PlatformTableViewCell {
			cell.prepareViewableCell()
			cell.content = model.cells[row]
			
			return cell
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			var size = Layout.Vertical(targets:model.cells, spacing:0).positionableSize(fitting:limit)
			
			size.minimize(minimum:model.minimum, maximum:model.maximum)
			
			return size
		}
	}
	
	static let noIntrinsicSize = CGSize(width:-1, height:-1)
}

//	MARK: -

#if os(macOS)
#else
extension Viewable.Picker: PlatformPickerDelegate, PlatformPickerDataSource {
	func numberOfComponents(in pickerView:PlatformPicker) -> Int {
		return 1
	}
	
	func pickerView(_ pickerView:PlatformPicker, numberOfRowsInComponent component:Int) -> Int {
		return component == 0 ? model.itemTitles.count : 0
	}
	
	func pickerView(_ pickerView:PlatformPicker, rowHeightForComponent component:Int) -> CGFloat {
		return component == 0 ? (model.itemTitles.first?.size().height ?? 0) * 1.25 : 0
	}
	
	func pickerView(_ pickerView:PlatformPicker, attributedTitleForRow row:Int, forComponent component:Int) -> NSAttributedString? {
		return component == 0 ? model.itemTitles[row] : nil
	}
	
	func pickerView(_ pickerView:PlatformPicker, viewForRow row:Int, forComponent component:Int, reusing view:PlatformView?) -> PlatformView {
		let label = Viewable.Label(string:model.itemTitles[row], maximumLines:1)

		label.attachToExistingView(view)

		return label.lazy()
	}
	
	func pickerView(_ pickerView:PlatformPicker, widthForComponent component:Int) -> CGFloat {
		guard component == 0 else { return 0 }
		
		return model.itemTitles.map { $0.size().width }.max() ?? 0
	}
	
	func pickerView(_ pickerView:PlatformPicker, didSelectRow row:Int, inComponent component:Int) {
		guard component == 0, model.select != row else { return }
		
		model.select = row
		
		if let action = model.action, let target = model.target ?? pickerView.target(forAction:action, withSender:pickerView), let object = target as? NSObject {
			object.perform(action, with:pickerView)
		}
	}
}
#endif

//	MARK: -

extension Viewable.SimpleTable: PlatformTableDelegate, PlatformTableDataSource {
#if os(macOS)
	func numberOfRows(in tableView:PlatformTableView) -> Int {
		return model.cells.count
	}
	
	func tableView(_ tableView:PlatformTableView, heightOfRow row:Int) -> CGFloat {
		return rowHeight(tableView:tableView, row:row)
	}
	
	func tableView(_ tableView:PlatformTableView, viewFor tableColumn:PlatformTableColumn?, row:Int) -> PlatformView? {
		return rowPrepareCell(ViewableTableCell.dequeue(tableView:tableView, row:row), row:row)
	}
	
	func tableViewSelectionDidChange(_ notification:Notification) {
		guard let tableView = notification.object as? PlatformTableView else { return }
		
		rowSelected(tableView:tableView, row:tableView.selectedRow)
	}
#else
	func tableView(_ tableView:PlatformTableView, numberOfRowsInSection section:Int) -> Int {
		return section == 0 ? model.cells.count : 0
	}
	
	func tableView(_ tableView:PlatformTableView, cellForRowAt indexPath:IndexPath) -> PlatformTableViewCell {
		return rowPrepareCell(ViewableTableCell.dequeue(tableView:tableView, indexPath:indexPath), row:indexPath.row)
	}
	
	func tableView(_ tableView:PlatformTableView, heightForRowAt indexPath:IndexPath) -> CGFloat {
		return rowHeight(tableView:tableView, row:indexPath.row)
	}
	
	func tableView(_ tableView:PlatformTableView, didSelectRowAt indexPath:IndexPath) {
		rowSelected(tableView:tableView, row:indexPath.row)
	}
#endif
}

//	MARK: -

extension PlatformView {
	func attachPositionables(_ root:Positionable, environment:Layout.Environment) {
		let ordered = root.orderablePositionables(environment:environment, order:.attach)
		let current = subviews
		
		var attached:Set<PlatformView> = []
		var anyViews:[PlatformView] = []
		var anyViewables:[LazyViewable] = []
		var viewablesByType:[ObjectIdentifier:[LazyViewable]] = [:]
		var viewableTypes:[ObjectIdentifier:PlatformView.Type] = [:]
		var viewsByType:[ObjectIdentifier:[PlatformView]] = [:]
		
		for item in ordered {
			guard let viewable = item as? LazyViewable else { continue }
			
			if let view = viewable.existingView, view.superview === self {
				attached.insert(view)
				continue
			}
			
			let viewType = viewable.viewType
			let typeKey = ObjectIdentifier(viewType)
			
			if viewType === PlatformView.self {
				anyViewables.append(viewable)
			} else if viewablesByType[typeKey]?.append(viewable) == nil {
				viewablesByType[typeKey] = [viewable]
				viewableTypes[typeKey] = viewType
			}
		}
		
		for view in current where !attached.contains(view) {
			var isKnown = false
			
			for (typeKey, viewType) in viewableTypes {
				if view.isKind(of:viewType) {
					if viewsByType[typeKey]?.append(view) == nil {
						viewsByType[typeKey] = [view]
					}
					
					isKnown = true
					break
				}
			}
			
			if !isKnown {
				anyViews.append(view)
			}
		}
		
		if !anyViewables.isEmpty {
			let viewType = PlatformView.self
			let typeKey = ObjectIdentifier(viewType)
			
			viewableTypes[typeKey] = viewType
			viewablesByType[typeKey] = anyViewables
			viewsByType[typeKey] = anyViews
		}
		
		for (typeKey, _) in viewableTypes {
			guard var views = viewsByType[typeKey], var viewables = viewablesByType[typeKey] else { continue }
			
			for index in viewables.indices.reversed() {
				let viewable = viewables[index]
				let tag = viewable.tag
				
				if tag != 0, let match = views.lastIndex(where: { $0.tag == tag }) {
					let view = views[match]
					
					viewable.attachToExistingView(view)
					
					if viewable.existingView != nil {
						viewables.remove(at:index)
						views.remove(at:match)
						attached.insert(view)
						break
					}
				}
			}
			
			for index in 0 ..< min(viewables.count, views.count) {
				viewables[index].attachToExistingView(views[index])
				
				if let view = viewables[index].existingView {
					attached.insert(view)
				}
			}
		}
		
		orderPositionables([root], environment:environment, options:.set)
	}
}

//	MARK: -

class ViewableColorView: PlatformTaggableView {
}

//	MARK: -

class ViewableShapeView: PlatformTaggableView {
#if os(macOS)
	override var wantsDefaultClipping:Bool { return false }
	override func makeBackingLayer() -> CALayer { return CAShapeLayer() }
#else
	override class var layerClass: AnyClass { return CAShapeLayer.self }
#endif
	
	var shapeLayer:CAShapeLayer? { return layer as? CAShapeLayer }
	
	override var intrinsicContentSize:CGSize {
		guard let layer = shapeLayer, let path = layer.path else { return .zero }
		
		let inset = layer.strokeColor?.alpha ?? 0 > 0 ? layer.lineWidth * -0.5 : 0
		let box = path.boundingBoxOfPath.insetBy(dx:inset, dy:inset)
		
		return box.size
	}
}

//	MARK: -

class ViewableGradientView: PlatformTaggableView {
#if os(macOS)
	override func makeBackingLayer() -> CALayer { return CAGradientLayer() }
#else
	override class var layerClass: AnyClass { return CAGradientLayer.self }
#endif
	
	var gradientLayer:CAGradientLayer? { return layer as? CAGradientLayer }
}

//	MARK: -

class ViewableGroupView: PlatformTaggableView, PlatformSizeChangeView, ViewControllerAttachable {
	var priorSize:CGSize = .zero
	var ordered:Positionable = Layout.EmptySpace() { didSet { invalidateLayout(); scheduleLayout() } }
	var content:Positionable { get { ordered } set { orderContent(newValue) } }
	
#if os(macOS)
	override var acceptsFirstResponder: Bool { return true }
#endif
	
	func prepareViewableGroup() {
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	func orderContent(_ content:Positionable) {
		orderPositionables([content], environment:positionableEnvironment, options:.set)
		ordered = content
	}
	
	func attachViewController(_ controller:PlatformViewController) {
		autoresizingMask = .flexibleSize
	}
	
#if os(macOS)
	override func layout() {
		super.layout()
		sizeMayHaveChanged(newSize:bounds.size)
	}
	
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		invalidateLayout()
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		sizeMayHaveChanged(newSize:bounds.size)
	}
#endif
	
	func invalidateLayout() { priorSize = .zero }
	func sizeChanged() { positionableContext.performLayout(content) }
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		return content.positionableSize(fitting:Layout.Limit(size:size)).data
	}
}

//	MARK: -

class ViewableButton: PlatformEmptyButton, PlatformSizeChangeView {
	var priorSize:CGSize = .zero
	var ordered:Positionable = Layout.EmptySpace() { didSet { invalidateLayout(); scheduleLayout() } }
	var content:Positionable { get { ordered } set { orderContent(newValue) } }
	
	override var intrinsicContentSize:CGSize {
		return content.positionableSize(fitting:Layout.Limit()).resolve(.zero)
	}
	
	func orderContent(_ content:Positionable) {
		orderPositionables([content], environment:positionableEnvironment, options:.set)
		ordered = content
	}
	
#if os(macOS)
	override func layout() {
		super.layout()
		sizeMayHaveChanged(newSize:bounds.size)
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		sizeMayHaveChanged(newSize:bounds.size)
	}
#endif
	
	func invalidateLayout() { priorSize = .zero }
	func sizeChanged() { positionableContext.performLayout(content) }
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		return content.positionableSize(fitting:Layout.Limit(size:size)).data
	}
}

//	MARK: -

#if os(macOS)
class ViewableScrollingContainerView: PlatformView {
	override var isFlipped:Bool { return true }
	override var acceptsFirstResponder: Bool { return true }
}

class ViewableScrollingClipView: PlatformClipView {
	var alignment = CGPoint(x:0.5, y:0.5)
	
	override func constrainBoundsRect(_ proposedBounds:NSRect) -> NSRect {
		var result = super.constrainBoundsRect(proposedBounds)
		
		guard let container = documentView else { return result }
		
		let scale = result.size.width / bounds.size.width
		let insets = contentInsets
		let frame = container.frame
		let content = CGRect(
			x:frame.origin.x - insets.left * scale,
			y:frame.origin.y - (isFlipped ? insets.top : insets.bottom) * scale,
			width:frame.size.width + (insets.left + insets.right) * scale,
			height:frame.size.height + (insets.top + insets.bottom) * scale
		)
		
		if result.width > content.size.width {
			result.origin.x = content.origin.x + (content.size.width - result.size.width) * alignment.x
		}
		
		if result.size.height > content.size.height {
			result.origin.y = content.origin.y + (content.size.height - result.size.height) * alignment.y
		}
		
		return backingAlignedRect(result, options:.alignAllEdgesNearest)
	}
}
#else
class ViewableScrollingContainerView: PlatformView, PlatformScrollingDelegate {
	func viewForZooming(in scroll:PlatformScrollingView) -> PlatformView? {
		return self
	}
}
#endif

//	MARK: -

class ViewableScrollingView: PlatformScrollingView, PlatformSizeChangeView, ViewControllerAttachable {
#if os(macOS)
	var _tag = 0
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	override var isFlipped:Bool { return true }
	override var acceptsFirstResponder: Bool { return true }
	
	var containerView: PlatformView {
		if let existing = documentView {
			return existing
		}
		
		let view = ViewableScrollingContainerView()
		
		documentView = view
		
		view.nextResponder = self
		
		return view
	}
	
	var alignment:CGPoint {
		get { return (contentView as? ViewableScrollingClipView)?.alignment ?? .zero }
		set { (contentView as? ViewableScrollingClipView)?.alignment = newValue }
	}
#else
	var alignment = CGPoint(x:0.5, y:0.5)
	let containerView = ViewableScrollingContainerView()
#endif
	
	var priorSize:CGSize = .zero
	var ordered:Positionable = Layout.EmptySpace() { didSet { invalidateLayout(); scheduleLayout() } }
	var content:Positionable { get { ordered } set { orderContent(newValue) } }
	
	func attachViewController(_ controller:PlatformViewController) {
		autoresizingMask = .flexibleSize
	}
	
	func prepareViewableScroll() {
		translatesAutoresizingMaskIntoConstraints = false
		
#if os(macOS)
		let save = documentView
		
		contentView = ViewableScrollingClipView()
		documentView = save
		scrollerStyle = .overlay
		borderType = .noBorder
		autohidesScrollers = true
		hasVerticalScroller = true
		hasHorizontalScroller = true
#else
		contentInsetAdjustmentBehavior = .always
		
		if delegate == nil {
			delegate = containerView
		}
#endif
	}
	
	func orderContent(_ content:Positionable) {
		ordered = content
		
#if os(macOS)
#else
		if containerView.superview !== self {
			insertSubview(containerView, at:0)
		}
#endif
		
		containerView.orderPositionables([content], environment:positionableEnvironment, options:.set)
	}
	
	func invalidateLayout() { priorSize = .zero }
	
#if os(macOS)
	override func layout() {
		super.layout()
		sizeMayHaveChanged(newSize:bounds.size)
	}
	
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		invalidateLayout()
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		sizeMayHaveChanged(newSize:bounds.size)
		alignContent()
	}
	
	func alignContent() {
		let scale = zoomScale
		let inset = adjustedContentInset
		let outer = bounds.size
		let small = CGSize(width:outer.width - inset.left - inset.right, height:outer.height - inset.top - inset.bottom)
		let inner = containerView.bounds.size * scale
		let center = containerView.center
		var aligned = CGPoint(x:inner.width * 0.5, y:inner.height * 0.5)
		
		if inner.width < small.width { aligned.x += (small.width - inner.width) * alignment.x }
		if inner.height < small.height { aligned.y += (small.height - inner.height) * alignment.y }
		if aligned != center { containerView.center = aligned }
	}
#endif
	
	func applyLayout() {
#if os(macOS)
		containerView.positionableContext.performLayout(content)
#else
		let innerBounds, outerBounds:CGRect
		let size = contentSize
		
		if contentInsetAdjustmentBehavior == .always {
			let insets = adjustedContentInset
			let padded = CGSize(width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
			
			innerBounds = CGRect(origin:.zero, size:contentSize)
			outerBounds = CGRect(origin:CGPoint(x:-insets.left, y:-insets.top), size:padded)
		} else {
			let insets = safeAreaInsets
			let padded = CGSize(width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
			
			innerBounds = CGRect(origin:CGPoint(x:insets.left, y:insets.top), size:contentSize)
			outerBounds = CGRect(origin:.zero, size:padded)
		}
		
		let context = Layout.Context(
			bounds:outerBounds,
			safeBounds:innerBounds,
			isDownPositive:false,
			scale:positionableScale,
			environment:positionableEnvironment
		)
		
		context.performLayout(content)
#endif
	}
	
	func sizeChanged() {
#if os(macOS)
		let limit = bounds.size
		let inset = PlatformScrollingView.frameSize(forContentSize:.zero, horizontalScrollerClass:PlatformScroller.self, verticalScrollerClass:PlatformScroller.self, borderType:.noBorder, controlSize:verticalScroller?.controlSize ?? .regular, scrollerStyle:scrollerStyle)
		let intrinsicSize = content.positionableSize(fitting:Layout.Limit(size:limit))
		let minimum = intrinsicSize.minimum
		let available = CGSize(
			width:minimum.height > limit.height ? limit.width - inset.width : limit.width,
			height:minimum.width > limit.width ? limit.height - inset.height : limit.height
		)
		let resolved = intrinsicSize.resolve(available)
		let size = CGSize(width:max(resolved.width, available.width), height:max(resolved.height, available.height))
		let displaySize = size.display(scale:positionableScale)
		
		if let view = documentView {
			view.setFrameSize(displaySize)
		} else {
			let view = ViewableScrollingContainerView(frame:CGRect(origin:.zero, size:displaySize))
			let environement = positionableEnvironment
			
			documentView = view
			view.nextResponder = self
			view.orderPositionables([content], environment:environement, options:.set)
		}
		
		verticalScrollElasticity = displaySize.height > available.height || !zoomRange.isEmpty ? .allowed : .none
#else
		let available = bounds.size
		let insets = contentInsetAdjustmentBehavior == .always ? adjustedContentInset : safeAreaInsets
		let limit = CGRect(origin:.zero, size:available).inset(by:insets).size
		let intrinsicSize = content.positionableSize(fitting:Layout.Limit(size:limit))
		let resolved = intrinsicSize.resolve(limit)
		let size = CGSize(width:max(resolved.width, limit.width), height:max(resolved.height, limit.height))
		let displaySize = size.display(scale:positionableScale)
		
		containerView.frame = CGRect(origin:.zero, size:displaySize).padded(by:insets)
		contentSize = displaySize
#endif
		
		applyLayout()
	}
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		return content.positionableSize(fitting:Layout.Limit(size:size)).data
	}
}

//	MARK: -

#if os(macOS)
class ViewableTableView: ViewableScrollingView {
	var tableView: PlatformTableView {
		if let existing = documentView as? PlatformTableView {
			return existing
		}
		
		let view = PlatformTableView()
		
		documentView = view
		
		view.nextResponder = self
		
		return view
	}
	
	var dataSource: PlatformTableDataSource? {
		get { return tableView.dataSource }
		set { tableView.dataSource = newValue }
	}
	
	var delegate: PlatformTableDelegate? {
		get { return tableView.delegate }
		set { tableView.delegate = newValue }
	}
	
	override var containerView: PlatformView {
		return tableView
	}
	
	override func sizeChanged() {
		
	}
	
	func reloadData() {
		tableView.reloadData()
	}
	
	func prepareViewableTable() {
		prepareViewableScroll()
		
		let table = tableView
		
		table.verticalMotionCanBeginDrag = true
		table.allowsEmptySelection = true
		table.allowsMultipleSelection = false
		table.allowsColumnReordering = false
		table.allowsColumnResizing = false
		table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
		table.rowSizeStyle = .custom
		table.selectionHighlightStyle = .none
		table.gridStyleMask = []
		table.headerView = nil
		
		hasHorizontalScroller = false
	}
	
	func registerCell(_ type:ViewableTableCell.Type) {
		let table = tableView
		
		if table.tableColumns.isEmpty {
			let column = PlatformTableColumn(identifier:.init(type.reuseIdentifier))
			
			table.addTableColumn(column)
		}
	}
}
#else
class ViewableTableView: PlatformTableView {
	func prepareViewableTable() {
		allowsSelection = true
		allowsMultipleSelection = false
		separatorStyle = .singleLine
		separatorInset = .zero
	}
	
	func registerCell(_ type:ViewableTableCell.Type) {
		register(type, forCellReuseIdentifier:type.reuseIdentifier)
	}
}
#endif

//	MARK: -

class ViewableTableCell: PlatformTableViewCell, PlatformSizeChangeView {
	class var reuseIdentifier:String { return String(describing:self) }
	
	var priorSize:CGSize = .zero
	var ordered:Positionable = Layout.EmptySpace() { didSet { invalidateLayout(); scheduleLayout() } }
	var content:Positionable { get { ordered } set { orderContent(newValue) } }
	
#if os(macOS)
	override var isFlipped:Bool { return true }
	
	class func dequeue(tableView:PlatformTableView, row:Int) -> ViewableTableCell {
		if let existing = tableView.makeView(withIdentifier:.init(rawValue:reuseIdentifier), owner:nil) as? Self {
			return existing
		} else {
			let cell = Self.init()
			
			cell.identifier = .init(rawValue:reuseIdentifier)
			
			return cell
		}
	}
#else
	class func dequeue(tableView:PlatformTableView, indexPath:IndexPath) -> ViewableTableCell {
		return tableView.dequeueReusableCell(withIdentifier:reuseIdentifier, for:indexPath) as! ViewableTableCell
	}
#endif
	
	func prepareViewableCell() {
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	func orderContent(_ content:Positionable) {
#if os(macOS)
		attachPositionables(content, environment:positionableEnvironment)
#else
		contentView.attachPositionables(content, environment:positionableEnvironment)
#endif
		
		ordered = content
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		
		Viewable.detach(content, prepareForReuse:true, environment:positionableEnvironment)
	}
	
#if os(macOS)
	override func layout() {
		super.layout()
		sizeMayHaveChanged(newSize:bounds.size)
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		sizeMayHaveChanged(newSize:bounds.size)
	}
#endif
	
	func invalidateLayout() { priorSize = .zero }
	func sizeChanged() { positionableContext.performLayout(content) }
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		return content.positionableSize(fitting:Layout.Limit(size:size)).data
	}
}

//	MARK: -

extension ViewablePositionable where ViewType: ViewableTableCell {
#if os(macOS)
	func lazyTableCell(tableView:PlatformTableView, row:Int) -> PlatformTableViewCell {
		let cell = ViewType.dequeue(tableView:tableView, row:row)
		
		attachToExistingView(cell)
		
		return cell
	}
#else
	func lazyTableCell(tableView:PlatformTableView, indexPath:IndexPath) -> PlatformTableViewCell {
		let cell = ViewType.dequeue(tableView:tableView, indexPath:indexPath)
		
		attachToExistingView(cell)
		
		return cell
	}
#endif
}

//	MARK: -

extension Viewable {
	static func hide(_ target:Positionable, isHidden:Bool = true, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.existing)
			.compactMap { $0 as? PlatformView }
			.forEach { $0.isHidden = isHidden }
	}
	
	static func fade(_ target:Positionable, opacity:CGFloat, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.existing)
			.compactMap { $0 as? PlatformView }
			.forEach { $0.alpha = opacity }
	}
	
	static func remove(_ target:Positionable, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.existing)
			.compactMap { $0 as? PlatformView }
			.forEach { $0.removeFromSuperview() }
	}
	
	static func detach(_ target:Positionable, prepareForReuse:Bool, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.attach)
			.compactMap { $0 as? LazyViewable }
			.forEach { $0.detachView(prepareForReuse:prepareForReuse) }
	}
	
	static func applyBackground(_ target:Positionable, color:PlatformColor?, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.existing)
			.compactMap { $0 as? PlatformView }
			.forEach { $0.backgroundColor = color }
	}
	
	static func applyBorder(_ target:Positionable, border:CALayer.Border, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.existing)
			.compactMap { ($0 as? PlatformView)?.layer }
			.forEach { $0.border = border }
	}
	
	static func applyShadow(_ target:Positionable, shadow:CALayer.Shadow, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment, order:.existing)
			.compactMap { ($0 as? PlatformView)?.layer }
			.forEach { $0.shadow = shadow }
	}
	
	struct Rounded: PositionableWithTarget {
		var target:Positionable
		
		func applyPositionableFrame(_ frame:CGRect, context: Layout.Context) {
			target.applyPositionableFrame(frame, context:context)
			target.orderablePositionables(environment:context.environment, order:.existing)
				.compactMap { ($0 as? PlatformView)?.layer }
				.forEach { $0.cornerRadius = $0.bounds.size.minimum / 2 }
		}
	}
	
	struct AttachRecognizers: PositionableWithTarget {
		var target:Positionable
		var recognizers:[Common.Recognizer]
		
		init(target:Positionable, recognizers:[Common.Recognizer]) {
			self.target = target
			self.recognizers = recognizers
			
			for view in target.orderablePositionables(environment:.current, order:.existing) {
				guard let view = view as? PlatformView else { continue }
				
				Common.Recognizer.attachRecognizers(recognizers, to:view)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let unordered = order == .create && !recognizers.isEmpty ? target.orderablePositionables(environment:environment, order:.attach)
				.compactMap { $0 as? LazyViewable }.filter { $0.existingView == nil } : []
			let result = target.orderablePositionables(environment:environment, order:order)
			
			for viewable in unordered {
				if let view = viewable.existingView {
					Common.Recognizer.attachRecognizers(recognizers, to:view)
				}
			}
			
			return result
		}
	}
}
