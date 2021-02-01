//
//  Viewable.swift
//  ChocolateTests
//
//  Created by Eric Cole on 2/1/21.
//

import QuartzCore
import Foundation

protocol ViewablePositionable: Positionable {
	associatedtype ViewType: PlatformView
	var view:ViewType? { get }
	
	func makeView() -> ViewType
	func attachView(_ view:ViewType)
}

//	MARK: -

enum Viewable {
	class Reference<T:AnyObject> {
		weak var value:T?
	}
	
	struct Group: ViewablePositionable {
		typealias ViewType = ViewableGroupView
		
		class Model {
			let tag:Int
			var content:Positionable
			
			init(tag:Int = 0, content:Positionable) {
				self.tag = tag
				self.content = content
			}
		}
		
		let reference = Reference<ViewType>()
		let model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var content:Positionable { get { return reference.value?.content ?? model.content } set { model.content = newValue; reference.value?.content = newValue } }
		var view:ViewType? { return reference.value }
		
		init(tag:Int = 0, content:Positionable) {
			self.model = Model(tag:tag, content:content)
		}
		
		func attachView(_ view:ViewableGroupView) {
			view.tag = model.tag
			view.content = model.content
			
			reference.value = view
			
			PlatformView.orderPositionables([model.content], environment:view.positionableEnvironment, hierarchyRoot:view)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return model.content.positionableSize(fitting:limit)
		}
	}
	
	struct Color: ViewablePositionable {
#if os(macOS)
		class ViewType: PlatformView {
			var _tag = 0
			override var tag:Int { get { return _tag } set { _tag = newValue } }
		}
#else
		typealias ViewType = PlatformView
#endif
		
		class Model {
			let tag:Int
			var color:PlatformColor?
			var size:CGSize
			
			init(tag:Int = 0, color:PlatformColor? = nil, size:CGSize = Viewable.noIntrinsicSize) {
				self.tag = tag
				self.color = color
				self.size = size
			}
		}
		
		let reference = Reference<ViewType>()
		let model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var color:PlatformColor? { get { return view?.backgroundColor ?? model.color } set { model.color = newValue; reference.value?.backgroundColor = newValue } }
		var size:CGSize { get { return view?.bounds.size ?? model.size } set { model.size = newValue; view?.invalidateIntrinsicContentSize() } }
		var view:ViewType? { return reference.value }
		
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
			
			reference.value = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(intrinsicSize:model.size)
		}
	}
	
	struct Label: ViewablePositionable {
		typealias ViewType = PlatformLabel
		
		class Model {
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
		
		let reference = Reference<ViewType>()
		let model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var attributedText:NSAttributedString? { get { return reference.value?.attributedText ?? model.string } set { model.string = newValue; reference.value?.attributedText = newValue } }
		var intrinsicWidth:CGFloat { get { return reference.value?.preferredMaxLayoutWidth ?? model.intrinsicWidth } set { model.intrinsicWidth = newValue; reference.value?.preferredMaxLayoutWidth = newValue } }
		var textColor:PlatformColor? { get { return reference.value?.textColor } set { reference.value?.textColor = newValue } }
		var view:ViewType? { return reference.value }
		
		init(tag:Int = 0, string:NSAttributedString?, intrinsicWidth:CGFloat = 0, maximumLines:Int = 0) {
			self.model = Model(tag:tag, string:string, intrinsicWidth:intrinsicWidth, maximumLines:maximumLines)
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
			
			reference.value = view
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
	
	struct Image: ViewablePositionable {
		typealias ViewType = PlatformImageView
		
		class Model {
			let tag:Int
			var image:PlatformImage?
			var color:PlatformColor?
			
			init(tag:Int = 0, image:PlatformImage? = nil, color:PlatformColor? = nil) {
				self.tag = tag
				self.image = image
				self.color = color
			}
		}
		
		let reference = Reference<ViewType>()
		let model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var image:PlatformImage? { get { return reference.value?.image ?? model.image } set { model.image = newValue; reference.value?.image = newValue } }
		var view:ViewType? { return reference.value }
		
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
			
			reference.value = view
		}
		
		func intrinsicSize() -> CGSize {
			return image?.size ?? Viewable.noIntrinsicSize
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return view?.positionableSize(fitting:limit) ?? Layout.Size(intrinsicSize:intrinsicSize())
		}
	}
	
	struct Slider: ViewablePositionable {
		typealias ViewType = PlatformSlider
		
		class Model {
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
		
		let reference = Reference<ViewType>()
		let model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var view:ViewType? { return reference.value }
		
#if os(macOS)
		var value:Double { get { return reference.value?.doubleValue ?? model.value } set { model.value = newValue; reference.value?.doubleValue = newValue } }
		
		var range:ClosedRange<Double> {
			get { guard let slider = reference.value else { return model.range }; return slider.minValue ... max(slider.minValue, slider.maxValue) }
			set { model.range = newValue; reference.value?.minValue = newValue.lowerBound; reference.value?.maxValue = newValue.upperBound }
		}
#else
		var value:Double {
			get { guard let slider = reference.value else { return model.value }; return Double(slider.value) }
			set { model.value = newValue; reference.value?.value = Float(newValue) }
		}
		
		var range:ClosedRange<Double> {
			get { guard let slider = reference.value else { return model.range }; return Double(slider.minimumValue) ... Double(max(slider.minimumValue, slider.maximumValue)) }
			set { model.range = newValue; reference.value?.minimumValue = Float(newValue.lowerBound); reference.value?.maximumValue = Float(newValue.upperBound) }
		}
#endif
		
		init(tag:Int = 0, value:Double = 0, range:ClosedRange<Double> = 0 ... 1, target:AnyObject? = nil, action:Selector?, minimumTrackColor:PlatformColor? = nil) {
			self.model = Model(tag:tag, value:value, range:range, target:target, action:action, minimumTrackColor:minimumTrackColor)
		}
		
		func attachView(_ view:PlatformSlider) {
			view.tag = tag
			
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
			
			reference.value = view
		}
		
		func applyAction(target:AnyObject?, action:Selector?) {
			model.target = target
			model.action = action
			
			guard let view = reference.value else { return }
			
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
	
	struct Shape: ViewablePositionable {
		typealias ViewType = ViewableShapeView
		
		class Model {
			let tag:Int
			var path:CGPath?
			
			init(tag:Int = 0, path:CGPath? = nil) {
				self.tag = tag
				self.path = path
			}
		}
		
		let reference = Reference<ViewType>()
		let model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var path:CGPath? { get { return shapeLayer?.path ?? model.path } set { model.path = newValue; shapeLayer?.path = newValue } }
		var view:ViewType? { return reference.value }
		var shapeLayer:CAShapeLayer? { return reference.value?.shapeLayer }
		
		func attachView(_ view:ViewableShapeView) {
			view.tag = tag
			
			reference.value = view
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard let path = shapeLayer?.path else { return .zero }
			
			let box = path.boundingBoxOfPath
			let size = CGSize(width:box.size.width + max(0, box.origin.x), height:box.size.height + max(0, box.origin.y))
			
			return Layout.Size(size:size)
		}
	}
	
	static let noIntrinsicSize = CGSize(width:-1, height:-1)
}

//	MARK: -

extension ViewablePositionable {
	var frame: CGRect { return view?.frame ?? .zero }
	
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

class ViewableGroupView: PlatformView {
#if os(macOS)
	var _tag = 0
	override var tag:Int { get { return _tag } set { _tag = newValue } }
	override var isFlipped:Bool { return true }
	override var acceptsFirstResponder: Bool { return true }
#endif
	
	var priorSize:CGSize = .zero
	var content:Positionable = Layout.EmptySpace()
	
	func prepare() {
		translatesAutoresizingMaskIntoConstraints = false
		
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
