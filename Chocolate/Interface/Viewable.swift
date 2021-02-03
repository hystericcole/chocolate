//
//  Viewable.swift
//  ChocolateTests
//
//  Created by Eric Cole on 2/1/21.
//

import QuartzCore
import Foundation

protocol LazyViewable: Positionable {
	var lazyView:PlatformView { get }
}

protocol ViewablePositionable: LazyViewable {
	associatedtype ViewType: PlatformView
	var view:ViewType? { get }
	
	func makeView() -> ViewType
	func attachView(_ view:ViewType)
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
		var content:Positionable { get { return view?.content ?? model.content } set { model.content = newValue; view?.content = newValue } }
		
		init(tag:Int = 0, content:Positionable) {
			self.model = Model(tag:tag, content:content)
		}
		
		func attachView(_ view:ViewableGroupView) {
			view.tag = model.tag
			view.prepare()
			view.content = model.content
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return model.content.positionableSize(fitting:limit)
		}
	}
	
	class Color: ViewablePositionable {
#if os(macOS)
		class ViewType: PlatformView {
			var _tag = 0
			override var tag:Int { get { return _tag } set { _tag = newValue } }
		}
#else
		typealias ViewType = PlatformView
#endif
		
		struct Model {
			let tag:Int
			var color:PlatformColor?
			var size:CGSize
			
			init(tag:Int = 0, color:PlatformColor? = nil, size:CGSize = Viewable.noIntrinsicSize) {
				self.tag = tag
				self.color = color
				self.size = size
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var color:PlatformColor? { get { return view?.backgroundColor ?? model.color } set { model.color = newValue; view?.backgroundColor = newValue } }
		var size:CGSize { get { return view?.bounds.size ?? model.size } set { model.size = newValue; view?.invalidateIntrinsicContentSize() } }
		
		init(tag:Int = 0, color:PlatformColor?, size:CGSize = Viewable.noIntrinsicSize) {
			self.model = Model(tag:tag, color:color, size:size)
		}
		
		func attachView(_ view:ViewType) {
			view.tag = model.tag
			view.backgroundColor = model.color
			
#if os(macOS)
			view.wantsLayer = true
#else
			view.isUserInteractionEnabled = false
			view.isOpaque = model.color?.cgColor.alpha ?? 0 < 1
#endif
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(intrinsicSize:model.size)
		}
	}
	
	class Label: ViewablePositionable {
		typealias ViewType = PlatformLabel
		
		struct Model {
			let tag:Int
			var string:NSAttributedString?
			var intrinsicWidth:CGFloat
			var maximumLines:Int
			
			init(tag:Int = 0, string:NSAttributedString? = nil, intrinsicWidth:CGFloat = 0, maximumLines:Int = 0) {
				self.tag = tag
				self.string = string
				self.intrinsicWidth = intrinsicWidth
				self.maximumLines = maximumLines
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var attributedText:NSAttributedString? { get { return view?.attributedText ?? model.string } set { model.string = newValue; view?.attributedText = newValue } }
		var intrinsicWidth:CGFloat { get { return view?.preferredMaxLayoutWidth ?? model.intrinsicWidth } set { model.intrinsicWidth = newValue; view?.preferredMaxLayoutWidth = newValue } }
		var textColor:PlatformColor? { get { return view?.textColor } set { view?.textColor = newValue } }
		
		init(tag:Int = 0, string:NSAttributedString?, intrinsicWidth:CGFloat = 0, maximumLines:Int = 0) {
			self.model = Model(tag:tag, string:string, intrinsicWidth:intrinsicWidth, maximumLines:maximumLines)
		}
		
		convenience init(tag:Int = 0, text:String, attributes:[NSAttributedString.Key:Any]? = nil, intrinsicWidth:CGFloat = 0, maximumLines:Int = 0) {
			self.init(tag:tag, string:NSAttributedString(string:text, attributes:attributes), intrinsicWidth:intrinsicWidth, maximumLines:maximumLines)
		}
		
		func attachView(_ view:PlatformLabel) {
			view.tag = model.tag
			view.attributedText = model.string
			
#if os(macOS)
			view.drawsBackground = false
			view.refusesFirstResponder = true
			view.isBezeled = false
			view.isBordered = false
			view.isEditable = false
			view.preferredMaxLayoutWidth = model.intrinsicWidth
			view.cell?.usesSingleLineMode = model.maximumLines == 1
			view.cell?.wraps = model.maximumLines == 1 ? false : true
			view.lineBreakMode = model.maximumLines == 1 ? .byTruncatingMiddle : .byWordWrapping
			
			if #available(OSX 10.11, *) {
				view.maximumNumberOfLines = model.maximumLines
			}
#else
			view.preferredMaxLayoutWidth = model.intrinsicWidth
			view.numberOfLines = model.maximumLines
			view.lineBreakMode = model.maximumLines == 1 ? .byTruncatingMiddle : .byWordWrapping
			view.adjustsFontSizeToFitWidth = model.maximumLines > 0
#endif
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard let string = model.string else { return .zero }
			
			var sizeLimit = limit.size
			if model.intrinsicWidth > 0 && model.intrinsicWidth < sizeLimit.width { sizeLimit.width = intrinsicWidth }
			
#if os(macOS)
			let bounds = string.boundingRect(with:sizeLimit, options:.usesLineFragmentOrigin)
#else
			let bounds = string.boundingRect(with:sizeLimit, options:.usesLineFragmentOrigin, context:nil)
#endif
			
			return Layout.Size(size:bounds.size)
		}
	}
	
	class Image: ViewablePositionable {
		typealias ViewType = PlatformImageView
		
		struct Model {
			let tag:Int
			var image:PlatformImage?
			var color:PlatformColor?
			
			init(tag:Int = 0, image:PlatformImage? = nil, color:PlatformColor? = nil) {
				self.tag = tag
				self.image = image
				self.color = color
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var image:PlatformImage? { get { return view?.image ?? model.image } set { model.image = newValue; view?.image = newValue } }
		
		init(tag:Int = 0, image:PlatformImage?, color:PlatformColor? = nil) {
			self.model = Model(tag:tag, image:image, color:color)
		}
		
		func attachView(_ view:PlatformImageView) {
			view.tag = model.tag
			view.image = model.image
			
#if os(macOS)
			if #available(OSX 10.14, *), let color = model.color {
				view.contentTintColor = color
			}
#else
			if let color = model.color {
				view.tintColor = color
			}
			
			view.clipsToBounds = true
#endif
			
			self.view = view
		}
		
		func intrinsicSize() -> CGSize {
			return image?.size ?? Viewable.noIntrinsicSize
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsicSize:intrinsicSize())
		}
	}
	
	class Scroll: ViewablePositionable {
		typealias ViewType = ViewableScrollingView
		typealias ZoomRange = ClosedRange<CGFloat>
		
		struct Model {
			static let unbound = CGSize(width:Layout.Dimension.unbound, height:Layout.Dimension.unbound)
			
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
		var minimum:CGSize { get { return model.minimum } set { model.minimum = newValue } }
		var maximum:CGSize { get { return model.maximum } set { model.maximum = newValue } }
		var content:Positionable { get { return view?.content ?? model.content } set { model.content = newValue; view?.content = newValue } }
		
#if os(macOS)
		var zoom:CGFloat {
			get { return view?.magnification ?? 1 }
			set { view?.magnification = newValue }
		}
#else
		var zoom:CGFloat {
			get { return view?.zoomScale ?? 1 }
			set { view?.zoomScale = newValue }
		}
#endif
		
		var zoomRange:ZoomRange {
			get { if let view = view { model.zoomRange = view.zoomRange }; return model.zoomRange }
			set { model.zoomRange = newValue; view?.zoomRange = newValue }
		}
		
		init(tag:Int = 0, content:Positionable, minimum:CGSize? = nil, maximum:CGSize? = nil, zoomRange:ZoomRange = 1 ... 1) {
			self.model = Model(tag:tag, content:content, minimum:minimum ?? .zero, maximum:maximum ?? Model.unbound, zoomRange:zoomRange)
		}
		
		func attachView(_ view:ViewableScrollingView) {
			view.tag = model.tag
			view.zoomRange = model.zoomRange
			view.prepare()
			view.content = model.content
			
			self.view = view
		}
		
		func flashIndicators() {
#if os(macOS)
			view?.flashScrollers()
#else
			view?.flashScrollIndicators()
#endif
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			var size = model.content.positionableSize(fitting:limit)
			
			size.decreaseRange(minimum:model.minimum, maximum:model.maximum)
			
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
			
			init(tag:Int = 0, value:Double, range:ClosedRange<Double> = 0 ... 1, target:AnyObject? = nil, action:Selector? = nil, minimumTrackColor:PlatformColor? = nil) {
				self.tag = tag
				self.value = value
				self.range = range
				self.target = target
				self.action = action
				self.minimumTrackColor = minimumTrackColor
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		
#if os(macOS)
		var value:Double {
			get { if let slider = view { model.value = slider.doubleValue }; return model.value }
			set { model.value = newValue; view?.doubleValue = newValue }
		}
		
		var range:ClosedRange<Double> {
			get { if let slider = view { model.range = slider.minValue ... max(slider.minValue, slider.maxValue) }; return model.range }
			set { model.range = newValue; view?.minValue = newValue.lowerBound; view?.maxValue = newValue.upperBound }
		}
#else
		var value:Double {
			get { if let slider = view { model.value = Double(slider.value) }; return model.value }
			set { model.value = newValue; view?.value = Float(newValue) }
		}
		
		var range:ClosedRange<Double> {
			get { if let slider = view { model.range = Double(slider.minimumValue) ... Double(max(slider.minimumValue, slider.maximumValue)) }; return model.range }
			set { model.range = newValue; view?.minimumValue = Float(newValue.lowerBound); view?.maximumValue = Float(newValue.upperBound) }
		}
#endif
		
		init(tag:Int = 0, value:Double = 0, range:ClosedRange<Double> = 0 ... 1, target:AnyObject? = nil, action:Selector?, minimumTrackColor:PlatformColor? = nil) {
			self.model = Model(tag:tag, value:value, range:range, target:target, action:action, minimumTrackColor:minimumTrackColor)
		}
		
		func attachView(_ view:PlatformSlider) {
			view.tag = model.tag
			
#if os(macOS)
			view.sliderType = .linear
			view.minValue = model.range.lowerBound
			view.maxValue = model.range.upperBound
			view.doubleValue = model.value
			
			if #available(OSX 10.12.2, *) {
				view.trackFillColor = model.minimumTrackColor
			}
			
			if #available(OSX 11.0, *) {
				view.controlSize = .large
			} else {
				view.controlSize = .regular
			}
			
			view.target = model.target
			view.action = model.action
			view.isContinuous = true
#else
			view.minimumValue = Float(model.range.lowerBound)
			view.maximumValue = Float(model.range.upperBound)
			view.value = Float(model.value)
			view.minimumTrackTintColor = model.minimumTrackColor
			
			view.removeTarget(nil, action:nil, for:.valueChanged)
			
			if let action = model.action {
				view.addTarget(model.target, action:action, for:.valueChanged)
			}
#endif
			
			self.view = view
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			guard let view = view else { return }
			
#if os(macOS)
			view.target = target
			view.action = action
#else
			view.removeTarget(nil, action:nil, for:view.allControlEvents)
			
			if let action = action {
				view.addTarget(target, action:action, for:.valueChanged)
			}
#endif
		}
		
		func intrinsicSize() -> CGSize {
#if os(macOS)
			return CGSize(width:-1, height:15)
#else
			return CGSize(width:-1, height:33)
#endif
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsicSize:intrinsicSize())
		}
	}
	
	class Shape: ViewablePositionable {
		typealias ViewType = ViewableShapeView
		typealias Style = CAShapeLayer.Style
		typealias Shadow = CALayer.Shadow
		
		struct Model {
			let tag:Int
			var path:CGPath?
			var style:Style
			var shadow:Shadow?
			
			init(tag:Int = 0, path:CGPath? = nil, style:Style, shadow:Shadow? = nil) {
				self.tag = tag
				self.path = path
				self.style = style
				self.shadow = shadow
			}
		}
		
		init(tag:Int = 0, path:CGPath? = nil, style:Style, shadow:Shadow? = nil) {
			self.model = Model(tag:tag, path:path, style:style, shadow:shadow)
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var path:CGPath? { get { return shapeLayer?.path ?? model.path } set { model.path = newValue; shapeLayer?.path = newValue } }
		var style:Style { get { return shapeLayer?.shapeStyle ?? model.style } set { model.style = newValue; shapeLayer?.shapeStyle = newValue } }
		var shadow:Shadow? { get { return shapeLayer?.shadow ?? model.shadow } set { model.shadow = newValue; shapeLayer?.shadow = newValue ?? .default } }
		var shapeLayer:CAShapeLayer? { return view?.shapeLayer }
		
		func attachView(_ view:ViewableShapeView) {
			view.tag = model.tag
			
			if let shape = shapeLayer {
				shape.path = model.path
				shape.shapeStyle = model.style
				shape.shadow = model.shadow ?? .default
			}
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard let path = shapeLayer?.path else { return .zero }
			
			let box = path.boundingBoxOfPath
			let size = CGSize(width:box.size.width + max(0, box.origin.x), height:box.size.height + max(0, box.origin.y))
			
			return Layout.Size(size:size)
		}
	}
	
	class Spinner: ViewablePositionable {
		typealias ViewType = PlatformSpinner
		
		struct Model {
			var isAnimating:Bool
			var isHiddenWhenStopped:Bool
			
			init(isAnimating:Bool = true, isHiddenWhenStopped:Bool = true) {
				self.isAnimating = isAnimating
				self.isHiddenWhenStopped = isHiddenWhenStopped
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { return view?.tag ?? 0 }
		
#if os(macOS)
		var isAnimating:Bool {
			get { return model.isAnimating }
			set { model.isAnimating = newValue; if newValue { view?.startAnimation(nil) } else { view?.stopAnimation(nil) } }
		}
		
		var isHiddenWhenStopped:Bool {
			get { return !(view?.isDisplayedWhenStopped ?? !model.isHiddenWhenStopped) }
			set { model.isHiddenWhenStopped = newValue; view?.isDisplayedWhenStopped = !newValue }
		}
#else
		var isAnimating:Bool {
			get { return view?.isAnimating ?? model.isAnimating }
			set { model.isAnimating = newValue; if newValue { view?.startAnimating() } else { view?.stopAnimating() } }
		}
		
		var isHiddenWhenStopped:Bool {
			get { return view?.hidesWhenStopped ?? model.isHiddenWhenStopped }
			set { model.isHiddenWhenStopped = newValue; view?.hidesWhenStopped = newValue }
		}
#endif
		
		init(isAnimating:Bool = true, isHiddenWhenStopped:Bool = true) {
			self.model = Model(isAnimating:isAnimating, isHiddenWhenStopped:isHiddenWhenStopped)
		}
		
		func attachView(_ view:PlatformSpinner) {
#if os(macOS)
			view.style = .spinning
			view.isIndeterminate = true
			view.isDisplayedWhenStopped = !model.isHiddenWhenStopped
			view.isBezeled = false
			
			if model.isAnimating {
				view.startAnimation(nil)
			} else {
				view.stopAnimation(nil)
			}
#else
			view.hidesWhenStopped = model.isHiddenWhenStopped
			
			if model.isAnimating {
				view.startAnimating()
			} else {
				view.stopAnimating()
			}
#endif
			
			self.view = view
		}
		
		func intrinsicSize() -> CGSize {
			return Viewable.noIntrinsicSize
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsicSize:intrinsicSize())
		}
	}
	
	static let noIntrinsicSize = CGSize(width:-1, height:-1)
}

//	MARK: -

extension ViewablePositionable {
	var frame: CGRect { return view?.frame ?? .zero }
	var lazyView:PlatformView { return makeView() }
	
	func applyPositionableFrame(_ frame:CGRect, context:Layout.Context) {
		view?.applyPositionableFrame(frame, context:context)
	}
	
	func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
		return makeView().orderablePositionables(environment:environment)
	}
	
	func makeView() -> ViewType {
		if let view = view { return view }
		
		let view = ViewType()
		
		attachView(view)
		
		return view
	}
}

//	MARK: -

class ViewableShapeView: PlatformView {
#if os(macOS)
	var _tag = 0
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	override var isFlipped:Bool { return true }
	override func makeBackingLayer() -> CALayer { return CAShapeLayer() }
#else
	override class var layerClass: AnyClass { return CAShapeLayer.self }
#endif
	
	var shapeLayer:CAShapeLayer? { return layer as? CAShapeLayer }
	
	override var intrinsicContentSize:CGSize {
		guard let path = shapeLayer?.path else { return .zero }
		
		let box = path.boundingBoxOfPath
		
		return CGSize(width:box.size.width + max(0, box.origin.x), height:box.size.height + max(0, box.origin.y))
	}
}

//	MARK: -

class ViewableGroupView: PlatformView, ViewControllerAttachable {
#if os(macOS)
	var _tag = 0
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	override var isFlipped:Bool { return true }
	override var acceptsFirstResponder: Bool { return true }
#endif
	
	var priorSize:CGSize = .zero
	var content:Positionable = Layout.EmptySpace() { didSet { applyContent() } }
	
	func prepare() {
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	func applyContent() {
#if os(macOS)
		sizeChanged()
#else
		invalidateLayout()
		setNeedsLayout()
#endif
		
		self.orderPositionables([content], environment:positionableEnvironment, options:.set)
	}
	
	func attachViewController(_ controller:PlatformViewController) {
#if os(macOS)
		autoresizingMask = [.width, .height]
#else
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
#endif
	}
	
#if os(macOS)
	override func resizeSubviews(withOldSize oldSize: NSSize) {
		super.resizeSubviews(withOldSize:oldSize)
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged()
			priorSize = size
		}
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged()
			priorSize = size
		}
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
#else
class ViewableScrollingContainerView: PlatformView, PlatformScrollingDelegate {
	func viewForZooming(in scroll:PlatformScrollingView) -> PlatformView? {
		return self
	}
}
#endif

//	MARK: -

class ViewableScrollingView: PlatformScrollingView, ViewControllerAttachable {
#if os(macOS)
	var _tag = 0
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	override var isFlipped:Bool { return true }
	override var acceptsFirstResponder: Bool { return true }
	
	var container: PlatformView {
		if let existing = documentView {
			return existing
		}
		
		let view = ViewableScrollingContainerView()
		
		documentView = view
		
		view.nextResponder = self
		
		return view
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
#else
	var zoomRange:Viewable.Scroll.ZoomRange {
		get {
			return minimumZoomScale ... max(minimumZoomScale, maximumZoomScale)
		}
		set {
			minimumZoomScale = newValue.lowerBound
			maximumZoomScale = newValue.upperBound
		}
	}
	
	let container = ViewableScrollingContainerView()
#endif
	
	var priorSize:CGSize = .zero
	var content:Positionable = Layout.EmptySpace() { didSet { applyContent() } }
	
	func attachViewController(_ controller:PlatformViewController) {
#if os(macOS)
		autoresizingMask = [.width, .height]
#else
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
#endif
	}
	
	func prepare() {
		translatesAutoresizingMaskIntoConstraints = false
		
#if os(macOS)
		scrollerStyle = .overlay
		borderType = .noBorder
		autohidesScrollers = true
		hasVerticalScroller = true
		hasHorizontalScroller = true
#else
		contentInsetAdjustmentBehavior = .always
		
		if delegate == nil {
			delegate = container
		}
#endif
	}
	
	func applyContent() {
#if os(macOS)
		sizeChanged()
#else
		invalidateLayout()
		setNeedsLayout()
		
		if container.superview !== self {
			insertSubview(container, at:0)
		}
#endif
		
		container.orderPositionables([content], environment:positionableEnvironment, options:.set)
	}
	
	func invalidateLayout() { priorSize = .zero }
	
#if os(macOS)
	override func resizeSubviews(withOldSize oldSize: NSSize) {
		super.resizeSubviews(withOldSize:oldSize)
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged()
			priorSize = size
		}
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged()
			priorSize = size
		}
	}
#endif
	
	func applyLayout() {
#if os(macOS)
		container.positionableContext.performLayout(content)
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
#else
		let available = bounds.size
		let insets = contentInsetAdjustmentBehavior == .always ? adjustedContentInset : safeAreaInsets
		let limit = CGRect(origin:.zero, size:available).inset(by:insets).size
		let intrinsicSize = content.positionableSize(fitting:Layout.Limit(size:limit))
		let resolved = intrinsicSize.resolve(limit)
		let size = CGSize(width:max(resolved.width, limit.width), height:max(resolved.height, limit.height))
		let displaySize = size.display(scale:positionableScale)
		
		container.frame = CGRect(origin:.zero, size:displaySize)
		contentSize = displaySize
#endif
		
		applyLayout()
	}
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		return content.positionableSize(fitting:Layout.Limit(size:size)).data
	}
}

//	MARK: -

extension Viewable {
	class Controller: BaseViewController {
		func makeViewable() -> LazyViewable { return Viewable.Label(text:String(describing:type(of:self))) }
		
		override func loadView() {
			view = makeViewable().lazyView
		}
	}
}

//	MARK: -

extension Viewable {
	static func hide(_ target:Positionable, isHidden:Bool = true, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment).compactMap { $0 as? PlatformView }.forEach { $0.isHidden = isHidden }
	}
	
	static func fade(_ target:Positionable, opacity:CGFloat, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment).compactMap { $0 as? PlatformView }.forEach { $0.alpha = opacity }
	}
	
	static func remove(_ target:Positionable, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment).compactMap { $0 as? PlatformView }.forEach { $0.removeFromSuperview() }
	}
	
	static func applyBackground(_ target:Positionable, color:PlatformColor?, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment).compactMap { $0 as? PlatformView }.forEach { $0.backgroundColor = color }
	}
	
	static func applyBorder(_ target:Positionable, border:CALayer.Border, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment).compactMap { ($0 as? PlatformView)?.layer }.forEach { $0.border = border }
	}
	
	static func applyShadow(_ target:Positionable, shadow:CALayer.Shadow, environment:Layout.Environment = .current) {
		target.orderablePositionables(environment:environment).compactMap { ($0 as? PlatformView)?.layer }.forEach { $0.shadow = shadow }
	}
	
	struct Rounded: Positionable {
		var target:Positionable
		var frame:CGRect { return target.frame }
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size { return target.positionableSize(fitting:limit) }
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] { return target.orderablePositionables(environment:environment) }
		
		func applyPositionableFrame(_ frame:CGRect, context: Layout.Context) {
			target.applyPositionableFrame(frame, context:context)
			target.orderablePositionables(environment:context.environment).compactMap { ($0 as? PlatformView)?.layer }.forEach { $0.cornerRadius = $0.bounds.size.minimum / 2 }
		}
	}
}
