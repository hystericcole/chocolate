//
//  CALayerExtensions.swift
//  Chocolate
//
//  Created by Eric Cole on 2/1/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import QuartzCore

extension CALayer {
	public class AnimationBridge: NSObject, CALayerDelegate {
		weak var delegate: CALayerDelegate?
		
		@objc
		public func action(for layer:CALayer, forKey event:String) -> CAAction? {
			return delegate?.action?(for:layer, forKey:event)
		}
		
		@objc
		override public func forwardingTarget(for aSelector: Selector!) -> Any? {
			return delegate
		}
	}
	
	public struct Border {
		public var width:CGFloat
		public var radius:CGFloat
		public var color:CGColor?
		public var clips:Bool
		
		public static let `default` = Border(width:0, radius:0, color:nil, clips:false)
		public static let black = Border(width:1, radius:0, color:nil, clips:true)
		public static let round = Border(width:1, radius:-0.5, color:nil, clips:true)
		
		public init(width:CGFloat = 0, radius:CGFloat = 0, color:CGColor? = nil, clips:Bool = true) {
			self.width = width
			self.radius = radius
			self.color = color
			self.clips = clips
		}
	}
	
	public struct Shadow {
		public var offset:CGSize
		public var radius:CGFloat
		public var opacity:Float
		public var color:CGColor?
		
		public static let `default` = Shadow(radius:3, offset:CGSize(width:0, height:-3))
		public static let zero = Shadow(radius:0, offset:.zero)
		
		public init(radius:CGFloat, offset:CGSize = .zero, opacity:Float = 0, color:CGColor? = nil) {
			self.radius = radius
			self.offset = offset
			self.opacity = opacity
			self.color = color
		}
		
		public func with(radius:CGFloat? = nil, offset:CGSize? = nil, opacity:Float? = nil) -> Shadow {
			return Shadow(radius:radius ?? self.radius, offset:offset ?? self.offset, opacity:opacity ?? self.opacity, color:self.color)
		}
		
		public func with(radius:CGFloat? = nil, offset:CGSize? = nil, opacity:Float? = nil, color:CGColor) -> Shadow {
			return Shadow(radius:radius ?? self.radius, offset:offset ?? self.offset, opacity:opacity ?? self.opacity, color:color)
		}
	}
	
	public var border:Border {
		get {
			return Border(width:borderWidth, radius:cornerRadius, color:borderColor, clips:masksToBounds)
		}
		set {
			let radius = newValue.radius < 0 ? bounds.size.minimum * -newValue.radius : newValue.radius
			
			if borderWidth != newValue.width { borderWidth = newValue.width }
			if borderColor != newValue.color { borderColor = newValue.color }
			if cornerRadius != radius { cornerRadius = radius }
			if masksToBounds != newValue.clips { masksToBounds = newValue.clips }
		}
	}
	
	public var shadow:Shadow {
		get {
			return Shadow(radius:shadowRadius, offset:shadowOffset, opacity:shadowOpacity, color:shadowColor)
		}
		set {
			if shadowRadius != newValue.radius { shadowRadius = newValue.radius }
			if shadowOffset != newValue.offset { shadowOffset = newValue.offset }
			if shadowOpacity != newValue.opacity { shadowOpacity = newValue.opacity }
			if shadowColor != newValue.color { shadowColor = newValue.color }
		}
	}
	
	public func round(to factor:CGFloat = 0.5) {
		let radius = bounds.size.minimum * factor
		
		if cornerRadius != radius { cornerRadius = radius }
	}
	
	public func alignContents(size:CGSize, alignment:CGPoint) {
		let viewSize = bounds.size
		let ratioWidth = size.width * viewSize.height
		let ratioHeight = size.height * viewSize.width
		var unit:CGSize
		
		guard ratioWidth > 0 && ratioHeight > 0 else { return }
		
		if ratioWidth > ratioHeight {
			unit = CGSize(width:ratioHeight / ratioWidth, height:1)
		} else {
			unit = CGSize(width:1, height:ratioWidth / ratioHeight)
		}
		
		let origin = CGPoint(x:alignment.x * (1 - unit.width), y:alignment.y * (1 - unit.height))
		
		contentsGravity = .resizeAspectFill
		contentsRect = CGRect(origin:origin, size:unit)
	}
	
	public func removeAnimations(keys:[String]? = nil, recursive:Bool = false, applyPresentationValue:Bool = false) {
		if recursive, let layers = sublayers {
			for layer in layers {
				layer.removeAnimations(keys:keys, recursive:recursive, applyPresentationValue:applyPresentationValue)
			}
		}
		
		guard keys != nil || applyPresentationValue else { return removeAllAnimations() }
		guard let keys = keys ?? animationKeys(), !keys.isEmpty else { return }
		
		for key in keys {
			guard let animation = animation(forKey:key) else { continue }
			
			if applyPresentationValue, let keyPath = (animation as? CAPropertyAnimation)?.keyPath, let current = presentation() {
				setValue(current.value(forKeyPath:keyPath), forKeyPath:keyPath)
			}
			
			removeAnimation(forKey:key)
		}
	}
}

// MARK: -

extension CAShapeLayer {
	typealias StrokeRange = ClosedRange<CGFloat>
	
	struct Style {
		var fill:CGColor?
		var rule:CAShapeLayerFillRule
		var stroke:CGColor?
		var width:CGFloat
		var opacity:Float
		var miterLimit:CGFloat
		var lineCap:CAShapeLayerLineCap
		var lineJoin:CAShapeLayerLineJoin
		
		var isStroked:Bool { return width > 0 && stroke?.alpha ?? 0 > 0 }
		var isFilled:Bool { return fill?.alpha ?? 0 > 0 }
		
		var unstroked:Style {
			return Style(fill:fill, rule:rule, stroke:nil, width:0, opacity:opacity, miterLimit:miterLimit, lineCap:lineCap, lineJoin:lineJoin)
		}
		
		var unfilled:Style {
			return Style(fill:nil, rule:rule, stroke:stroke, width:width, opacity:opacity, miterLimit:miterLimit, lineCap:lineCap, lineJoin:lineJoin)
		}
		
		init(fill:CGColor?, rule:CAShapeLayerFillRule = .nonZero, stroke:CGColor? = nil, width:CGFloat = 1, opacity:Float = 1, miterLimit:CGFloat = 10, lineCap:CAShapeLayerLineCap = .butt, lineJoin:CAShapeLayerLineJoin = .miter) {
			self.fill = fill
			self.rule = rule
			self.stroke = stroke
			self.width = width
			self.miterLimit = miterLimit
			self.lineCap = lineCap
			self.lineJoin = lineJoin
			self.opacity = opacity
		}
		
		func with(fill:CGColor?, stroke:CGColor?, width:CGFloat, opacity:Float) -> Style {
			return Style(fill:fill, rule:rule, stroke:stroke, width:width, opacity:opacity, miterLimit:miterLimit, lineCap:lineCap, lineJoin:lineJoin)
		}
		
		func applying(_ transform:CGAffineTransform) -> Style {
			let half = CGFloat(0.5.squareRoot())
			let widthSize = CGSize(square:width * half).applying(transform)
			let miterSize = CGSize(square:miterLimit * half).applying(transform)
			
			return Style(fill:fill, rule:rule, stroke:stroke, width:widthSize.hypotenuse, opacity:opacity, miterLimit:miterSize.hypotenuse, lineCap:lineCap, lineJoin:lineJoin)
		}
	}
	
	struct Shape {
		var path:CGPath
		var style:CAShapeLayer.Style
		var range:CAShapeLayer.StrokeRange
		var name:String?
		
		var unstroked:Shape { return Shape(path, style:style.unstroked, range:range, name:name) }
		var unfilled:Shape { return Shape(path, style:style.unfilled, range:range, name:name) }
		
		init(_ path:CGPath, fill:CGColor? = nil, stroke:CGColor? = nil, width:CGFloat = 0, opacity:Float = 1, range:CAShapeLayer.StrokeRange = 0 ... 1, name:String? = nil) {
			self.path = path
			self.style = CAShapeLayer.Style(fill:fill, stroke:stroke, width:width, opacity:opacity)
			self.range = range
			self.name = name
		}
		
		init(_ path:CGPath, style:CAShapeLayer.Style, range:CAShapeLayer.StrokeRange = 0 ... 1, name:String? = nil) {
			self.path = path
			self.style = style
			self.range = range
			self.name = name
		}
		
		func applying(_ transform:CGAffineTransform) -> Shape {
			var transform = transform
			
			return Shape(path.copy(using:&transform) ?? path, style:style.applying(transform), range:range, name:name)
		}
		
		func strokingPath() -> Shape {
			let strokePath = path.copy(strokingWithWidth:style.width, lineCap:style.lineCap.lineCap, lineJoin:style.lineJoin.lineJoin, miterLimit:style.miterLimit)
			let strokeStyle = Style(fill:style.stroke, rule:style.rule, stroke:nil, width:0, opacity:style.opacity, miterLimit:style.miterLimit, lineCap:style.lineCap, lineJoin:style.lineJoin)
			
			return Shape(strokePath, style:strokeStyle, name:name)
		}
	}
	
	struct ShapeWithShadow {
		var shape:Shape
		var shadow:Shadow
		
		init(shape:Shape, shadow:Shadow = .default) {
			self.shape = shape
			self.shadow = shadow
		}
	}
	
	struct Dash {
		var phase:CGFloat
		var pattern:[NSNumber]
	}
	
	var shapeStyle:Style {
		get {
			return Style(
				fill:fillColor, rule:fillRule,
				stroke:strokeColor, width:lineWidth, opacity:opacity,
				miterLimit:miterLimit, lineCap:lineCap, lineJoin:lineJoin
			)
		}
		set {
			if fillColor != newValue.fill { fillColor = newValue.fill }
			if fillRule != newValue.rule { fillRule = newValue.rule }
			if strokeColor != newValue.stroke { strokeColor = newValue.stroke }
			if lineWidth != newValue.width { lineWidth = newValue.width }
			if opacity != newValue.opacity { opacity = newValue.opacity }
			if miterLimit != newValue.miterLimit { miterLimit = newValue.miterLimit }
			if lineCap != newValue.lineCap { lineCap = newValue.lineCap }
			if lineJoin != newValue.lineJoin { lineJoin = newValue.lineJoin }
		}
	}
	
	var shape:Shape {
		get { return Shape(path ?? CGMutablePath(), style:shapeStyle, range:strokeRange, name:name) }
		set {
			path = newValue.path.isEmpty ? nil : newValue.path
			shapeStyle = newValue.style
			strokeRange = newValue.range
			name = newValue.name
		}
	}
	
	var shapeWithShadow:ShapeWithShadow {
		get {
			let shape = Shape(path ?? shadowPath ?? CGMutablePath(), style:shapeStyle, range:strokeRange, name:name)
			
			return ShapeWithShadow(shape:shape, shadow:shadow)
		}
		set {
			shape = newValue.shape
			shadow = newValue.shadow
			shadowPath = newValue.shape.path
		}
	}
	
	var dash:Dash? {
		get {
			guard let pattern = lineDashPattern else { return nil }
			
			return Dash(phase:lineDashPhase, pattern:pattern)
		}
		set {
			lineDashPhase = newValue?.phase ?? 0
			lineDashPattern = newValue?.pattern
		}
	}
	
	var strokeRange:StrokeRange {
		get {
			return strokeStart ... max(strokeEnd, strokeStart)
		}
		set {
			if strokeStart != newValue.lowerBound { strokeStart = newValue.lowerBound }
			if strokeEnd != newValue.upperBound { strokeEnd = newValue.upperBound }
		}
	}
}

//	MARK: -

extension CAGradientLayer {
	enum Direction {
		case angle(CGFloat)
		case turn(CGFloat)
		
		static let minY = Direction.turn(0.75)
		static let maxY = Direction.turn(0.25)
		static let maxX = Direction.turn(0.0)
		static let minX = Direction.turn(0.5)
		
		static let down = maxY
		static let up = minY
		static let right = maxX
		static let left = minX
		
		var radians:CGFloat {
			switch self {
			case .angle(let value): return value
			case .turn(let value): return value * 2 * .pi
			}
		}
		
		init(start:CGPoint, end:CGPoint) {
			let angle = atan2(end.y - start.y, end.x - start.x)
			
			self = .angle(angle)
		}
		
		func points(inset:CGFloat = 0) -> (start:CGPoint, end:CGPoint) {
			let sc:__double2
			
			switch self {
			case .angle(let value): sc = value.native.sincos()
			case .turn(let value): sc = value.native.sincosturns()
			}
			
			let (s, c) = (sc.__sinval, sc.__cosval)
			let (x, y) = s.magnitude < c.magnitude ? (copysign(1, c), s / c.magnitude) : (c / s.magnitude, copysign(1, s))
			
			let r = 1.0 - 2.0 * inset.native
			let (rx, ry) = (r * x, r * y)
			
			let from = CGPoint(x:0.5 - rx / 2, y:0.5 - ry / 2)
			let to = CGPoint(x:0.5 + rx / 2, y:0.5 + ry / 2)
			
			return (start:from, end:to)
		}
	}
	
	struct Gradient {
		var colorSpace:CGColorSpace?
		var colors:[CGColor]
		var locations:[NSNumber]?
		var start:CGPoint
		var startRadius:CGFloat
		var end:CGPoint
		var endRadius:CGFloat
		var type:CAGradientLayerType
		
		var direction:Direction {
			get { return Direction(start:start, end:end) }
			set { (start, end) = newValue.points() }
		}
		
		init(colors:[CGColor], locations:[NSNumber]? = nil, start:CGPoint = CGPoint(x:0.5, y:0), startRadius:CGFloat = 0, end:CGPoint = CGPoint(x:0.5, y:1), endRadius:CGFloat = 0, type:CAGradientLayerType = .axial) {
			self.colors = colors
			self.locations = locations
			self.start = start
			self.startRadius = startRadius
			self.end = end
			self.endRadius = endRadius
			self.type = type
		}
		
		init(colors:[CGColor], locations:[NSNumber]? = nil, direction:Direction, startRadius:CGFloat = 0, endRadius:CGFloat = 0, type:CAGradientLayerType = .axial) {
			let (start, end) = direction.points()
			
			self.init(colors:colors, locations:locations, start:start, startRadius:startRadius, end:end, endRadius:endRadius, type:type)
		}
		
		func applying(_ transform:CGAffineTransform) -> Gradient {
			let half = CGFloat(0.5.squareRoot())
			let startSize = CGSize(square:startRadius * half).applying(transform)
			let endSize = CGSize(square:endRadius * half).applying(transform)
			
			return Gradient(colors:colors, locations:locations, start:start.applying(transform), startRadius:startSize.hypotenuse, end:end.applying(transform), endRadius:endSize.hypotenuse, type:type)
		}
		
		func gradient() -> CGGradient? {
			guard !colors.isEmpty else { return nil }
			
			let locations = self.locations?.map { CGFloat($0.doubleValue) }
			let space = colorSpace ?? colors.first?.colorSpace
			
			return CGGradient(colorsSpace:space, colors:colors as CFArray, locations:locations)
		}
		
		func drawInContext(_ context:CGContext) {
			guard let gradient = self.gradient() else { return }
			
			let options:CGGradientDrawingOptions = [.drawsAfterEndLocation, .drawsBeforeStartLocation]
			
			if type == .radial {
				context.drawRadialGradient(gradient, startCenter:start, startRadius:startRadius, endCenter:end, endRadius:endRadius, options:options)
			} else {
				context.drawLinearGradient(gradient, start:start, end:end, options:options)
			}
		}
	}
	
	var gradient:Gradient {
		get { return Gradient(colors:colors as? [CGColor] ?? [], locations:locations, start:startPoint, end:endPoint, type:type) }
		set {
			colors = newValue.colors
			if locations != newValue.locations { locations = newValue.locations }
			if startPoint != newValue.start { startPoint = newValue.start }
			if endPoint != newValue.end { endPoint = newValue.end }
			if type != newValue.type { type = newValue.type }
		}
	}
	
	var direction:Direction {
		get { return Direction(start:startPoint, end:endPoint) }
		set { (startPoint, endPoint) = newValue.points() }
	}
	
	func applyDirection(_ direction:Direction, inset:CGFloat) {
		(startPoint, endPoint) = direction.points(inset:inset)
	}
}

//	MARK: -

extension CAShapeLayerLineCap {
	var lineCap:CGLineCap {
		switch self {
		case .butt: return .butt
		case .round: return .round
		case .square: return .square
		default: return .butt
		}
	}
}

//	MARK: -

extension CAShapeLayerLineJoin {
	var lineJoin:CGLineJoin {
		switch self {
		case .bevel: return .bevel
		case .miter: return .miter
		case .round: return .round
		default: return .miter
		}
	}
}
