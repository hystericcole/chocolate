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
			view.prepareViewableGroup()
			view.content = model.content
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return model.content.positionableSize(fitting:limit)
		}
	}
	
	class Color: ViewablePositionable {
		typealias ViewType = PlatformTaggableView
		
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
		var color:PlatformColor? { get { return view?.backgroundColor ?? model.color } set { model.color = newValue; view?.backgroundColor = newValue } }
		var intrinsicSize:CGSize { get { return model.intrinsicSize } set { model.intrinsicSize = newValue; view?.invalidateIntrinsicContentSize() } }
		
		init(tag:Int = 0, color:PlatformColor?, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
			self.model = Model(tag:tag, color:color, intrinsicSize:intrinsicSize)
		}
		
		func attachView(_ view:ViewType) {
			view.tag = model.tag
			view.backgroundColor = model.color
			view.prepareViewableColor(isOpaque:model.color?.cgColor.alpha ?? 0 < 1)
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(intrinsicSize:model.intrinsicSize)
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
			view.prepareViewableLabel(intrinsicWidth:model.intrinsicWidth, maximumLines:model.maximumLines)
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard let string = model.string else { return .zero }
			
			var sizeLimit = limit.size
			
			if model.intrinsicWidth > 0 && model.intrinsicWidth < sizeLimit.width { sizeLimit.width = intrinsicWidth }
			
			return Layout.Size(size:PlatformLabel.sizeMeasuringString(string, with:sizeLimit))
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
			view.prepareViewableImage(image:model.image, color:model.color)
			
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
		
		var zoom:CGFloat {
			get { return view?.zoomScale ?? 1 }
			set { view?.zoomScale = newValue }
		}
		
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
			view.prepareViewableScroll()
			view.content = model.content
			
			self.view = view
		}
		
		func flashScrollers() {
			view?.flashScrollers()
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
			get { if let slider = view { model.value = slider.doubleValue }; return model.value }
			set { model.value = newValue; view?.doubleValue = newValue }
		}
		
		var range:ClosedRange<Double> {
			get { if let slider = view { model.range = slider.valueRange }; return model.range }
			set { model.range = newValue; view?.valueRange = newValue }
		}
		
		init(tag:Int = 0, value:Double = 0, range:ClosedRange<Double> = 0 ... 1, target:AnyObject? = nil, action:Selector?, minimumTrackColor:PlatformColor? = nil) {
			self.model = Model(tag:tag, value:value, range:range, target:target, action:action, minimumTrackColor:minimumTrackColor)
		}
		
		func attachView(_ view:PlatformSlider) {
			view.tag = model.tag
			view.valueRange = model.range
			view.doubleValue = model.value
			view.prepareViewableSlider(target:model.target, action:model.action, minimumTrackColor:model.minimumTrackColor)
			
			self.view = view
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			view?.applyVieawbleAction(target:target, action:action)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard let view = view else { return Layout.Size(intrinsicSize:model.intrinsicSize) }
			
			model.intrinsicSize = view.intrinsicContentSize
			
			return view.positionableSize(fitting:limit)
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
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var path:CGPath? { get { return shapeLayer?.path ?? model.path } set { model.path = newValue; shapeLayer?.path = newValue; shapeLayer?.shadowPath = newValue } }
		var style:Style { get { return shapeLayer?.shapeStyle ?? model.style } set { model.style = newValue; shapeLayer?.shapeStyle = newValue } }
		var shadow:Shadow? { get { return shapeLayer?.shadow ?? model.shadow } set { model.shadow = newValue; shapeLayer?.shadow = newValue ?? .default } }
		var shapeLayer:CAShapeLayer? { return view?.shapeLayer }
		
		var pathSize:CGSize {
			let box:CGRect
			
			if let existing = model.boundingBox {
				box = existing
			} else if let path = path {
				box = path.boundingBoxOfPath
				
				model.boundingBox = box
			} else {
				return .zero
			}
			
			return CGSize(width:box.size.width + max(0, box.origin.x), height:box.size.height + max(0, box.origin.y))
		}
		
		init(tag:Int = 0, path:CGPath? = nil, style:Style, shadow:Shadow? = nil) {
			self.model = Model(tag:tag, path:path, style:style, shadow:shadow)
		}
		
		func attachView(_ view:ViewableShapeView) {
			view.tag = model.tag
			view.prepareViewableColor(isOpaque:false)
			
			if let layer = view.shapeLayer {
				layer.path = model.path
				layer.shapeStyle = model.style
				layer.shadow = model.shadow ?? .default
				layer.shadowPath = model.path
			}
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(size:pathSize)
		}
	}
	
	class Gradient {
		typealias ViewType = ViewableGradientView
		typealias Descriptor = CAGradientLayer.Gradient
		
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
		var descriptor:Descriptor { get { return gradientLayer?.gradient ?? model.gradient } set { model.gradient = newValue; gradientLayer?.gradient = newValue } }
		var intrinsicSize:CGSize { get { return model.intrinsicSize } set { model.intrinsicSize = newValue; view?.invalidateIntrinsicContentSize() } }
		var gradientLayer:CAGradientLayer? { return view?.gradientLayer }
		
		init(tag:Int = 0, gradient:Descriptor, intrinsicSize:CGSize = Viewable.noIntrinsicSize) {
			self.model = Model(tag:tag, gradient:gradient, intrinsicSize:intrinsicSize)
		}
		
		func attachView(_ view:ViewableGradientView) {
			view.tag = model.tag
			view.prepareViewableColor(isOpaque:false)
			
			if let layer = view.gradientLayer {
				layer.gradient = model.gradient
			}
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(intrinsicSize:model.intrinsicSize)
		}
	}
	
	class Spinner: ViewablePositionable {
		typealias ViewType = PlatformSpinner
		
		struct Model {
			var isAnimating:Bool
			var isHiddenWhenStopped:Bool
			var intrinsicSize:CGSize
			
			init(isAnimating:Bool = true, isHiddenWhenStopped:Bool = true) {
				self.isAnimating = isAnimating
				self.isHiddenWhenStopped = isHiddenWhenStopped
				self.intrinsicSize = Viewable.noIntrinsicSize
			}
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
		
		func attachView(_ view:PlatformSpinner) {
			view.isHiddenWhenStopped = model.isHiddenWhenStopped
			view.prepareViewableSpinner()
			view.applyAnimating(isAnimating)
			
			self.view = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard let view = view else { return Layout.Size(intrinsicSize:model.intrinsicSize) }
			
			model.intrinsicSize = view.intrinsicContentSize
			
			return view.positionableSize(fitting:limit)
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

class ViewableShapeView: PlatformTaggableView {
#if os(macOS)
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

class ViewableGradientView: PlatformTaggableView {
#if os(macOS)
	override func makeBackingLayer() -> CALayer { return CAGradientLayer() }
#else
	override class var layerClass: AnyClass { return CAGradientLayer.self }
#endif
	
	var gradientLayer:CAGradientLayer? { return layer as? CAGradientLayer }
}

//	MARK: -

class ViewableGroupView: PlatformTaggableView, ViewControllerAttachable {
	var priorSize:CGSize = .zero
	var content:Positionable = Layout.EmptySpace() { didSet { applyContent() } }
	
#if os(macOS)
	override var acceptsFirstResponder: Bool { return true }
#endif
	
	func prepareViewableGroup() {
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	func applyContent() {
		orderPositionables([content], environment:positionableEnvironment, options:.set)
		
#if os(macOS)
		sizeChanged()
#else
		invalidateLayout()
		setNeedsLayout()
#endif
	}
	
	func attachViewController(_ controller:PlatformViewController) {
		autoresizingMask = .flexibleSize
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

class ViewableScrollingView: PlatformScrollingView, ViewControllerAttachable {
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
	var content:Positionable = Layout.EmptySpace() { didSet { applyContent() } }
	
	func attachViewController(_ controller:PlatformViewController) {
		autoresizingMask = .flexibleSize
	}
	
	func prepareViewableScroll() {
		translatesAutoresizingMaskIntoConstraints = false
		
#if os(macOS)
		contentView = ViewableScrollingClipView()
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
	
	func applyContent() {
#if os(macOS)
		containerView.orderPositionables([content], environment:positionableEnvironment, options:.set)
		
		sizeChanged()
#else
		invalidateLayout()
		setNeedsLayout()
		
		if containerView.superview !== self {
			insertSubview(containerView, at:0)
		}
		
		containerView.orderPositionables([content], environment:positionableEnvironment, options:.set)
#endif
	}
	
	func invalidateLayout() { priorSize = .zero }
	
#if os(macOS)
	override func resizeSubviews(withOldSize oldSize:NSSize) {
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
		
		containerView.frame = CGRect(origin:.zero, size:displaySize)
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
