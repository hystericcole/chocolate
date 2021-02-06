//
//  Layout.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import CoreGraphics
import Foundation

protocol Positionable {
	var frame:CGRect { get }
	var compressionResistance:CGPoint { get }
	
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size
	func applyPositionableFrame(_ frame:CGRect, context:Layout.Context)
	func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable]
}

//	MARK: -

protocol PositionableContainer {
	func orderPositionables(_ unorderable:[Positionable], environment:Layout.Environment, options:Layout.OrderOptions)
}

//	MARK: -

struct Layout {
	typealias Native = CGFloat.NativeType
	
	enum Axis {
		case horizontal, vertical
	}
	
	enum Alignment {
		/// Position within available bounds
		case fraction(Native)
		/// Position within available bounds adapting to environment
		case adaptiveFraction(Native)
		/// Fill available bounds
		case fill
		
		static let start = Alignment.fraction(0.0)
		static let center = Alignment.fraction(0.5)
		static let end = Alignment.fraction(1.0)
		static let leading = Alignment.adaptiveFraction(0.0)
		static let trailing = Alignment.adaptiveFraction(1.0)
		static let `default` = center
		
		var isFill:Bool {
			switch self {
			case .fill: return true
			default: return false
			}
		}
		
		func value(axis:Axis, environment:Environment) -> Native? {
			switch self {
			case .fraction(let value): return value
			case .adaptiveFraction(let value): return environment.adaptiveFractionValue(value, axis:axis)
			default: return nil
			}
		}
	}
	
	enum Position {
		///	Position within available bounds
		case fraction(Native)
		/// Position within available bounds adapting to environment
		case adaptiveFraction(Native)
		/// Fill available bounds by stretching elements
		case stretch
		/// Fill available bounds by making elements a uniform size
		case uniform
		/// Fill available bounds by stretching space between elements
		case distribute
		/// Position around the primary element
		case float
		
		static let start = Position.fraction(0.0)
		static let center = Position.fraction(0.5)
		static let end = Position.fraction(1.0)
		static let leading = Position.adaptiveFraction(0.0)
		static let trailing = Position.adaptiveFraction(1.0)
		static let `default` = center
		
		var isFill:Bool {
			switch self {
			case .stretch, .uniform, .distribute: return true
			default: return false
			}
		}
		
		var fit:Axial.Fit {
			switch self {
			case .stretch: return .stretch
			case .uniform: return .uniform
			case .distribute: return .distribute
			default: return .position
			}
		}
		
		var alignment:Alignment {
			switch self {
			case .fraction(let value): return .fraction(value)
			case .adaptiveFraction(let value): return .adaptiveFraction(value)
			case .float: return .center
			case .stretch, .uniform, .distribute: return .fill
			}
		}
		
		func value(axis:Axis, environment:Environment) -> Native? {
			switch self {
			case .fraction(let value): return value
			case .adaptiveFraction(let value): return environment.adaptiveFractionValue(value, axis:axis)
			case .float: return 0.5
			default: return nil
			}
		}
	}
	
	/// Display order of elements within a container
	enum Direction: CustomStringConvertible {
		case positive, negative, natural, reverse
		
		var description:String {
			switch self {
			case .positive: return "+"
			case .negative: return "-"
			case .natural: return "±"
			case .reverse: return "∓"
			}
		}
		
		func isPositive(axis:Axis, environment:Environment) -> Bool {
			switch self {
			case .positive: return true
			case .negative: return false
			case .natural: return axis == .horizontal && environment.isRTL ? false : true
			case .reverse: return axis == .horizontal && environment.isRTL ? true : false
			}
		}
	}
	
	struct OrderOptions: OptionSet {
		let rawValue:Int
		
		static let order:OrderOptions = []
		static let add = OrderOptions(rawValue:1)
		static let remove = OrderOptions(rawValue:2)
		static let set:OrderOptions = [.add, .remove]
	}
	
	/// Environment for applying layout
	struct Environment: CustomStringConvertible {
		static var current:Environment { return Environment(isRTL:false) }
		
		let isRTL:Bool
		
		var description:String { return isRTL ? "←" : "→" }
		
		func adaptiveFractionValue(_ value:Native, axis:Axis) -> Native { return axis == .horizontal && isRTL ? 1.0 - value : value }
	}
	
	/// Context for a layout pass
	struct Context: CustomStringConvertible {
		var bounds:CGRect
		var safeBounds:CGRect
		var isDownPositive:Bool
		var scale:CGFloat
		var environment:Environment
		
		var description:String { return "\(bounds) @\(scale)x \(isDownPositive ? "↓+" : "↑+") \(environment)" }
		
		func viewFrame(_ box:CGRect) -> CGRect {
#if os(macOS)
			var box = box
			
			if !isDownPositive {
				box.origin.y = bounds.height - box.origin.y - box.size.height
			}
#endif
			
			return box.display(scale:scale)
		}
		
		func performLayout(_ layout:Positionable) {
			layout.applyPositionableFrame(safeBounds, context:self)
		}
	}
	
	/// The space available during layout
	struct Limit: CustomStringConvertible {
		static let unlimited:Native = 0x1p30
		let width:Native?
		let height:Native?
		
		var size:CGSize { return CGSize(width:width ?? .greatestFiniteMagnitude, height:height ?? .greatestFiniteMagnitude) }
		var description:String { return "Limit(\(width?.description ?? "∞"), \(height?.description ?? "∞"))" }
		
		init(width:Native? = nil, height:Native? = nil) {
			self.width = width
			self.height = height
		}
		
		init(size:CGSize?) {
			if let size = size {
				width = size.width.native < Limit.unlimited ? size.width.native : nil
				height = size.height.native < Limit.unlimited ? size.height.native : nil
			} else {
				width = nil
				height = nil
			}
		}
	}
	
	/// The space requested during layout in one direction
	struct Dimension: CustomStringConvertible {
		static let unbound = Limit.unlimited * 0x1p10
		static let zero = Dimension(value:0)
		
		var constant:Native
		var minimum:Native
		var maximum:Native
		var fraction:Native
		
		var isUnbounded:Bool { return minimum <= 0 && constant == 0 && fraction == 0 && maximum >= Limit.unlimited }
		var description:String { return "\(minimum) <= \(constant) + \(fraction) × bounds <= \(maximum < Limit.unlimited ? String(maximum) : "∞")" }
		
		init(constant:Native, range:ClosedRange<Native> = 0 ... Dimension.unbound, fraction:Native = 0) {
			self.constant = constant
			self.minimum = range.lowerBound
			self.maximum = range.upperBound
			self.fraction = fraction
		}
		
		init(value:Native) {
			constant = value
			minimum = value
			maximum = value
			fraction = 0
		}
		
		init(minimum:Native = 0, prefer:Native = 0, maximum:Native = Dimension.unbound) {
			self.constant = max(0, prefer)
			self.minimum = max(0, minimum)
			self.maximum = maximum >= 0 ? min(maximum, Dimension.unbound) : Dimension.unbound
			self.fraction = 0
		}
		
		init?(value:Native?) {
			guard let value = value else { return nil }
			
			self.init(value:value)
		}
		
		init?(minimum:Native?) {
			guard let minimum = minimum else { return nil }
			
			self.init(constant:minimum, range:minimum ... Dimension.unbound, fraction:0)
		}
		
		/// Computes constant + fraction × limit, clamped between minimum and maximum
		/// - Parameter limit: Bounds of container
		/// - Returns: Resolved value
		func resolve(_ limit:Native) -> Native {
			return min(max(minimum, constant + fraction * limit), maximum)
		}
		
		mutating func add(value:Native) {
			constant += value
			minimum = max(minimum + value, 0)
			maximum = max(minimum, maximum + value)
		}
		
		mutating func add(_ dimension:Dimension) {
			constant += dimension.constant
			minimum = max(minimum + dimension.minimum, 0)
			maximum = min(max(minimum, maximum + dimension.maximum), Dimension.unbound)
			fraction += dimension.fraction
		}
		
		mutating func multiply(_ scalar:Native) {
			constant *= scalar
			minimum *= scalar
			maximum = min(maximum * scalar, Dimension.unbound)
			fraction *= scalar
		}
		
		mutating func increase(_ dimension:Dimension) {
			constant = max(constant, dimension.constant)
			minimum = max(minimum, dimension.minimum)
			maximum = max(maximum, dimension.maximum)
			fraction = max(fraction, dimension.fraction)
		}
		
		mutating func decreaseRange(_ range:ClosedRange<Double>) {
			minimum = min(minimum, range.lowerBound)
			maximum = min(maximum, range.upperBound)
		}
	}
	
	/// The size requested during layout
	struct Size: CustomStringConvertible {
		static let unbound = CGSize(width:Dimension.unbound, height:Dimension.unbound)
		static let zero = Size(width:.zero, height:.zero)
		
		var width:Dimension
		var height:Dimension
		
		var constant:CGSize { return CGSize(width:width.constant, height:height.constant) }
		var minimum:CGSize { return CGSize(width:width.minimum, height:height.minimum) }
		var maximum:CGSize { return CGSize(width:width.maximum, height:height.maximum) }
		var data:Data { return withUnsafeBytes(of:self) { Data($0) } }
		var description:String { return "\(width) by \(height)" }
		
		init(width:Dimension, height:Dimension) {
			self.width = width
			self.height = height
		}
		
		init(require size:CGSize) {
			self.width = Dimension(value:size.width.native)
			self.height = Dimension(value:size.height.native)
		}
		
		init(intrinsic size:CGSize) {
			self.width = size.width < 0 ? Dimension(constant:0) : Dimension(value:size.width.native)
			self.height = size.height < 0 ? Dimension(constant:0) : Dimension(value:size.height.native)
		}
		
		init(minimum:CGSize = .zero, prefer:CGSize = .zero, maximum:CGSize = Size.unbound) {
			self.width = Dimension(minimum:minimum.width.native, prefer:prefer.width.native, maximum:maximum.width.native)
			self.height = Dimension(minimum:minimum.height.native, prefer:prefer.height.native, maximum:maximum.height.native)
		}
		
		init?(data:Data) {
			guard let size:Size = data.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to:Self.self).pointee }) else { return nil }
			
			self = size
		}
		
		func resolve(_ size:CGSize) -> CGSize { return CGSize(width:width.resolve(size.width.native), height:height.resolve(size.height.native)) }
		
		func pin(_ box:CGRect, anchor:CGPoint = CGPoint(x:0.5, y:0.5)) -> CGRect {
			var box = box
			
			if box.size.width.native < width.minimum {
				box.origin.x -= CGFloat(width.minimum - box.size.width.native) * anchor.x
				box.size.width = CGFloat(width.minimum)
			} else if box.size.width.native > width.maximum {
				box.origin.x += CGFloat(box.size.width.native - width.maximum) * anchor.x
				box.size.width = CGFloat(width.maximum)
			}
			
			if box.size.height.native < height.minimum {
				box.origin.y -= CGFloat(height.minimum - box.size.height.native) * anchor.y
				box.size.height = CGFloat(height.minimum)
			} else if box.size.height.native > height.maximum {
				box.origin.y += CGFloat(box.size.height.native - height.maximum) * anchor.y
				box.size.height = CGFloat(height.maximum)
			}
			
			return box
		}
		
		func decompress(_ box:CGRect, compressionResistance:CGPoint, anchor:CGPoint = CGPoint(x:0.5, y:0.5)) -> CGRect {
			var box = box
			
			if box.size.width.native < width.minimum && compressionResistance.x > 0.25 {
				box.origin.x -= CGFloat(width.minimum - box.size.width.native) * anchor.x
				box.size.width = CGFloat(width.minimum)
			}
			
			if box.size.height.native < height.minimum && compressionResistance.y > 0.25 {
				box.origin.y -= CGFloat(height.minimum - box.size.height.native) * anchor.y
				box.size.height = CGFloat(height.minimum)
			}
			
			return box
		}
		
		mutating func decreaseRange(minimum:CGSize, maximum:CGSize) {
			width.decreaseRange(minimum.width.native ... maximum.width.native)
			height.decreaseRange(minimum.height.native ... maximum.height.native)
		}
	}
	
	struct EdgeInsets: CustomStringConvertible {
		var minX, maxX, minY, maxY:Native
		
		var horizontal:Native { return minX + maxX }
		var vertical:Native { return minY + maxY }
		var description:String { return "→\(minX) ↓\(minY) ←\(maxX) ↑\(maxY)" }
		
		init(top:Native = 0, bottom:Native = 0, leading:Native = 0, trailing:Native = 0, environment:Environment) { self.minX = environment.isRTL ? trailing : leading; self.maxX = environment.isRTL ? leading : trailing; self.minY = top; self.maxY = bottom }
		init(minX:Native = 0, maxX:Native = 0, minY:Native = 0, maxY:Native = 0) { self.minX = minX; self.maxX = maxX; self.minY = minY; self.maxY = maxY }
		init(horizontal:Native, vertical:Native) { minX = horizontal; maxX = horizontal; minY = vertical; maxY = vertical }
		init(uniform:Native) { minX = uniform; maxX = uniform; minY = uniform; maxY = uniform }
		
		func paddingSize(_ size:CGSize) -> CGSize { return CGSize(width:size.width + CGFloat(minX + maxX), height:size.height + CGFloat(minY + maxY)) }
		func paddingBox(_ box:CGRect) -> CGRect { return CGRect(x:box.origin.x - CGFloat(minX), y:box.origin.y - CGFloat(minY), width:box.size.width + CGFloat(minX + maxX), height:box.size.height + CGFloat(minY + maxY)) }
		
		func reducingSize(_ size:CGSize) -> CGSize { return CGSize(width:size.width - CGFloat(minX + maxX), height:size.height - CGFloat(minY + maxY)) }
		func reducingBox(_ box:CGRect) -> CGRect { return CGRect(x:box.origin.x + CGFloat(minX), y:box.origin.y + CGFloat(minY), width:box.size.width - CGFloat(minX + maxX), height:box.size.height - CGFloat(minY + maxY)) }
		
		static let zero = EdgeInsets(uniform:0)
	}
	
	/// Targets that reach the safe bounds will be extended to the outer bounds
	struct IgnoreSafeBounds: Positionable {
		var target:Positionable
		
		var frame:CGRect { return target.frame }
		var compressionResistance:CGPoint { return target.compressionResistance }
		
		init(target:Positionable) {
			self.target = target
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return target.positionableSize(fitting:limit)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let epsilon = 0.5 / context.scale
			let minX = box.minX - epsilon > context.safeBounds.minX ? 0 : max(box.minX - context.bounds.minX, 0) 
			let minY = box.minY - epsilon > context.safeBounds.minY ? 0 : max(box.minY - context.bounds.minY, 0)
			let maxX = box.maxX + epsilon < context.safeBounds.maxX ? 0 : max(context.bounds.maxX - box.maxX, 0)
			let maxY = box.maxY + epsilon < context.safeBounds.maxY ? 0 : max(context.bounds.maxY - box.maxY, 0)
			let box = CGRect(x:box.origin.x - minX, y:box.origin.y - minY, width:box.size.width + minX + maxX, height:box.size.height + minY + maxY)
			
			target.applyPositionableFrame(box, context:context)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			return target.orderablePositionables(environment:environment, attachable:attachable)
		}
	}
	
	struct EmptySpace: Positionable {
		var size:CGSize
		
		var frame:CGRect { return .zero }
		var compressionResistance:CGPoint { return .zero }
		
		init(width:Native = 0, height:Native = 0) { self.size = CGSize(width:width, height:height) }
		init(_ size:CGSize) { self.size = size }
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(prefer:size, maximum:size)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {}
		func orderablePositionables(environment:Layout.Environment, attachable: Bool) -> [Positionable] { return [] }
	}
	
	/// Specify padding around the target.  Positive insets will increase the distance between adjacent targets.  Negative insets may cause adjacent targets to overlap.
	struct Padding: Positionable {
		var target:Positionable
		var insets:EdgeInsets
		
		var frame:CGRect { return insets.paddingBox(target.frame) }
		var compressionResistance:CGPoint { return target.compressionResistance }
		
		init(target:Positionable, insets:EdgeInsets) {
			self.target = target
			self.insets = insets
		}
		
		init(target:Positionable, uniform:Native) {
			self.target = target
			self.insets = EdgeInsets(uniform:uniform)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			let paddingLimit = Limit(
				width:limit.width?.advanced(by:-insets.horizontal),
				height:limit.height?.advanced(by:-insets.vertical)
			)
			
			var result = target.positionableSize(fitting:paddingLimit)
			
			result.width.add(value:insets.horizontal)
			result.height.add(value:insets.vertical)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			target.applyPositionableFrame(insets.reducingBox(box), context:context)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			return target.orderablePositionables(environment:environment, attachable:attachable)
		}
	}
	
	/// Replace the normal dimensions of the target
	struct Sizing: Positionable {
		var target:Positionable
		var width:Dimension?
		var height:Dimension?
		
		var frame:CGRect { return target.frame }
		var compressionResistance:CGPoint { return target.compressionResistance }
		
		init(target:Positionable, width:Dimension? = nil, height:Dimension? = nil) {
			self.target = target
			self.width = width
			self.height = height
		}
		
		init(target:Positionable, width:Native? = nil, height:Native? = nil) {
			self.init(target:target, width:Dimension(value:width), height:Dimension(value:height))
		}
		
		init(target:Positionable, minimumWidth:Native? = nil, minimumHeight:Native? = nil) {
			self.init(target:target, width:Dimension(minimum:minimumWidth), height:Dimension(minimum:minimumHeight))
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			if let width = width, let height = height {
				return Layout.Size(width:width, height:height)
			}
			
			let size = target.positionableSize(fitting:limit)
			
			return Layout.Size(width:width ?? size.width, height:height ?? size.height)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			target.applyPositionableFrame(box, context:context)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			return target.orderablePositionables(environment:environment, attachable:attachable)
		}
	}
	
	/// Record the measured dimensions of the target
	struct Measured: Positionable {
		let target:Positionable
		let size:Size
		
		var frame:CGRect { return target.frame }
		var compressionResistance:CGPoint { return target.compressionResistance }
		
		init(target:Positionable, size:Size) {
			self.target = target
			self.size = size
		}
		
		init(target:Positionable, limit:Limit) {
			self.init(target:target, size:target.positionableSize(fitting:limit))
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return size
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			target.applyPositionableFrame(box, context:context)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			return target.orderablePositionables(environment:environment, attachable:attachable)
		}
	}
	
	/// Impose aspect fit on the target
	struct Aspect: Positionable {
		var target:Positionable
		var position:CGPoint
		var ratio:CGSize
		
		var frame:CGRect { return target.frame }
		var compressionResistance:CGPoint { return target.compressionResistance }
		
		init(target:Positionable, ratio:Native, position:Native = 0.5) {
			self.init(target:target, ratio:CGSize(width:ratio, height:1), position:CGPoint(x:position, y:position))
		}
		
		init(target:Positionable, ratio:CGSize, position:CGPoint = CGPoint(x:0.5, y:0.5)) {
			self.target = target
			self.ratio = ratio
			self.position = position
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			var size = target.positionableSize(fitting:limit)
			
			if size.width.isUnbounded && size.height.fraction == 0 && ratio.height > 0 {
				size.width.constant = size.height.constant * ratio.width.native / ratio.height.native
				size.width.minimum = size.height.minimum * ratio.width.native / ratio.height.native
			}
			
			if size.height.isUnbounded && size.width.fraction == 0 && ratio.width > 0 {
				size.height.constant = size.width.constant * ratio.height.native / ratio.width.native
				size.height.minimum = size.width.minimum * ratio.height.native / ratio.width.native
			}
			
			return size
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			var box = box
			let ratioWidth = box.size.width * ratio.height
			let ratioHeight = box.size.height * ratio.width
			
			if ratioWidth > ratioHeight {
				let width = ratioHeight / ratio.height
				
				box.origin.x += (box.size.width - width) * position.x
				box.size.width = width
			} else {
				let height = ratioWidth / ratio.width
				
				box.origin.y += (box.size.height - height) * position.y
				box.size.height = height
			}
			
			target.applyPositionableFrame(box, context:context)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			return target.orderablePositionables(environment:environment, attachable:attachable)
		}
	}
	
	/// Arrange a group of targets vertically
	struct Vertical: Positionable {
		var targets:[Positionable]
		var alignment:Alignment
		var position:Position
		var primaryIndex:Int
		var spacing:Native
		var direction:Direction
		
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		var isUniform:Bool {
			if case .uniform = position, alignment.isFill { return true }
			
			return false
		}
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return isFloating ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], spacing:Native = 0, alignment:Alignment = .default, position:Position = .default, primary:Int = -1, direction:Direction = .natural) {
			self.targets = targets
			self.spacing = spacing
			self.position = position
			self.alignment = alignment
			self.primaryIndex = primary
			self.direction = direction
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting: limit) }
			
			var result:Layout.Size = .zero
			let spacingSum = spacing * Native(targets.count - 1)
			
			if case .uniform = position {
				for target in targets {
					let size = target.positionableSize(fitting: limit)
					
					result.height.increase(size.height)
					result.width.increase(size.width)
				}
				
				result.height.multiply(Native(targets.count))
			} else {
				for target in targets {
					let size = target.positionableSize(fitting: limit)
					
					result.height.add(size.height)
					result.width.increase(size.width)
				}
			}
			
			result.height.add(value:spacingSum)
			
			return result
		}
		
		mutating func positionableSize(fitting limit:Layout.Limit, splittingTargets:[Positionable], intoRows rowCount:Int, rowMajor:Bool) -> Layout.Size {
			var result:Layout.Size = .zero
			let itemLimit = splittingTargets.count - 1
			let columnCount = 1 + itemLimit / rowCount
			
			for index in 0 ..< columnCount {
				if rowMajor {
					targets.removeAll()
					
					for row in 0 ..< 1 + (itemLimit - index) / columnCount {
						targets.append(splittingTargets[row * columnCount + index])
					}
				} else {
					targets = Array(splittingTargets.suffix(from:index * rowCount).prefix(rowCount))
				}
				
				let size = positionableSize(fitting:limit)
				
				result.width.add(size.width)
				result.height.increase(size.height)
			}
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context, axial:Axial, sizes:[Size], available:Native, isFloating:Bool) {
			let isPositive = direction.isPositive(axis:.vertical, environment:context.environment)
			let end = targets.count - 1
			let spacing = axial.space
			var offset = 0.0
			
			if isFloating {
				offset = -axial.sizeBeforeElement(primaryIndex, isPositive:isPositive)
			} else if let value = position.value(axis:.vertical, environment:context.environment) {
				offset = axial.offset(fraction:value, available:available, index:primaryIndex, isPositive:isPositive)
			}
			
			for index in targets.indices {
				let index = isPositive ? index : end - index
				let target = targets[index]
				let y = offset, height = axial.sizes[index]
				let x, width:CGFloat
				
				offset += height + spacing
				
				if let value = alignment.value(axis:.horizontal, environment:context.environment) {
					width = min(CGFloat(sizes[index].width.resolve(box.size.width.native)), box.size.width)
					x = (box.size.width - width) * CGFloat(value)
				} else {
					width = box.size.width
					x = 0
				}
				
				let frame = CGRect(x:box.origin.x + x, y:box.origin.y + CGFloat(y), width:width, height:CGFloat(height))
				let decompressed = sizes[index].decompress(frame, compressionResistance:target.compressionResistance)
				
				target.applyPositionableFrame(decompressed, context:context)
			}
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let isFloating = self.isFloating
			let limit = Limit(width:box.size.width.native, height:nil)
			let available = isFloating ? context.bounds.size.height.native : box.size.height.native
			let sizes = isUniform ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit) }
			let axial = Axial(sizes.map { $0.height }, available:available, spacing:spacing, fit:position.fit)
			
			applyPositionableFrame(box, context:context, axial:axial, sizes:sizes, available:available, isFloating:isFloating)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.vertical, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, attachable:attachable) }
		}
	}
	
	/// Arrange a group of targets horizontally
	struct Horizontal: Positionable {
		var targets:[Positionable]
		var alignment:Alignment
		var position:Position
		var spacing:Native
		var primaryIndex:Int
		var direction:Direction
		
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		var isUniform:Bool {
			if case .uniform = position, alignment.isFill { return true }
			
			return false
		}
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return isFloating ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], spacing:Native = 0, alignment:Alignment = .default, position:Position = .default, primary:Int = -1, direction:Direction = .natural) {
			self.targets = targets
			self.spacing = spacing
			self.position = position
			self.alignment = alignment
			self.primaryIndex = primary
			self.direction = direction
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit) }
			
			var result:Layout.Size = .zero
			let spacingSum = spacing * Native(targets.count - 1)
			
			if case .uniform = position {
				for target in targets {
					let size = target.positionableSize(fitting: limit)
					
					result.height.increase(size.height)
					result.width.increase(size.width)
				}
				
				result.width.multiply(Native(targets.count))
			} else {
				for target in targets {
					let size = target.positionableSize(fitting:limit)
					
					result.width.add(size.width)
					result.height.increase(size.height)
				}
			}
			
			result.width.add(value:spacingSum)
			
			return result
		}
		
		mutating func positionableSize(fitting limit:Layout.Limit, splittingTargets:[Positionable], intoColumns columnCount:Int, columnMajor:Bool) -> Layout.Size {
			var result:Layout.Size = .zero
			let itemLimit = splittingTargets.count - 1
			let rowCount = 1 + itemLimit / columnCount
			
			for index in 0 ..< rowCount {
				if columnMajor {
					targets.removeAll()
					
					for column in 0 ..< 1 + (itemLimit - index) / rowCount {
						targets.append(splittingTargets[column * rowCount + index])
					}
				} else {
					targets = Array(splittingTargets.suffix(from:index * columnCount).prefix(columnCount))
				}
				
				let size = positionableSize(fitting:limit)
				
				result.width.increase(size.width)
				result.height.add(size.height)
			}
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context, axial:Axial, sizes:[Size], available:Native, isFloating:Bool) {
			let isPositive = direction.isPositive(axis:.horizontal, environment:context.environment)
			let end = targets.count - 1
			let spacing = axial.space
			var offset = 0.0
			
			if isFloating {
				offset = -axial.sizeBeforeElement(primaryIndex, isPositive:isPositive)
			} else if let value = position.value(axis:.horizontal, environment:context.environment) {
				offset = axial.offset(fraction:value, available:available, index:primaryIndex, isPositive:isPositive)
			}
			
			for index in targets.indices {
				let index = isPositive ? index : end - index
				let target = targets[index]
				let x = offset, width = axial.sizes[index]
				let y, height:CGFloat
				
				offset += width + spacing
				
				if let value = alignment.value(axis:.vertical, environment:context.environment) {
					height = min(CGFloat(sizes[index].height.resolve(box.size.height.native)), box.size.height)
					y = (box.size.height - height) * CGFloat(value)
				} else {
					height = box.size.height
					y = 0
				}
				
				let frame = CGRect(x:box.origin.x + CGFloat(x), y:box.origin.y + y, width:CGFloat(width), height:height)
				let decompressed = sizes[index].decompress(frame, compressionResistance:target.compressionResistance)
				
				target.applyPositionableFrame(decompressed, context:context)
			}
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let isFloating = self.isFloating
			let limit = Limit(width:nil, height:box.size.height.native)
			let available = isFloating ? context.bounds.size.width.native : box.size.width.native
			let sizes = isUniform ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit) }
			let axial = Axial(sizes.map { $0.width }, available:available, spacing:spacing, fit:position.fit)
			
			applyPositionableFrame(box, context:context, axial:axial, sizes:sizes, available:available, isFloating:isFloating)
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, attachable:attachable) }
		}
	}
	
	/// Arrange a group of targets into vertical columns
	struct Columns: Positionable {
		var targets:[Positionable]
		var columnCount:Int
		var rowTemplate:Horizontal
		var position:Position
		var primaryIndex:Int
		var spacing:Native
		var columnMajor:Bool
		var direction:Direction
		
		var singleColumn:Vertical {
			return Vertical(targets:targets, spacing:spacing, alignment:rowTemplate.position.alignment, position:position, primary:primaryIndex, direction:direction)
		}
		
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return isFloating ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], columnCount:Int, spacing:Native = 0, template:Horizontal, position:Position = .default, primary:Int = -1, direction:Direction = .natural) {
			self.targets = targets
			self.columnCount = columnCount
			self.spacing = spacing
			self.position = position
			self.rowTemplate = template
			self.primaryIndex = primary
			self.columnMajor = false
			self.direction = direction
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard columnCount > 1 else { return singleColumn.positionableSize(fitting:limit) }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting: limit) }
			
			var row = rowTemplate
			var result = row.positionableSize(fitting:limit, splittingTargets:targets, intoColumns:columnCount, columnMajor:columnMajor)
			let rowLimit = (targets.count - 1) / columnCount
			let spacingSum = spacing * Native(rowLimit)
			
			result.height.add(value:spacingSum)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			guard columnCount > 1 else { return singleColumn.applyPositionableFrame(box, context:context) }
			
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			let sizes = targets.map { $0.positionableSize(fitting:limit) }
			
			let itemLimit = targets.count - 1
			let rowCount = 1 + itemLimit / columnCount
			var rowHeights = Array(repeating:Dimension.zero, count:rowCount)
			var columnWidths = Array(repeating:Dimension.zero, count:columnCount)
			
			if columnMajor {
				for index in sizes.indices {
					rowHeights[index % columnCount].increase(sizes[index].height)
					columnWidths[index / columnCount].increase(sizes[index].width)
				}
			} else {
				for index in sizes.indices {
					rowHeights[index / columnCount].increase(sizes[index].height)
					columnWidths[index % columnCount].increase(sizes[index].width)
				}
			}
			
			var row = rowTemplate
			let isFloating = self.isFloating
			let isPositive = direction.isPositive(axis:.vertical, environment:context.environment)
			let available = isFloating ? context.bounds.size.height.native : box.size.height.native
			let rowAvailable = box.size.width.native
			let axial = Axial(rowHeights, available:available, spacing:spacing, fit:position.fit)
			let rowAxial = Axial(columnWidths, available:rowAvailable, spacing:row.spacing, fit:row.position.fit)
			let spacing = axial.space
			let primaryRow:Int
			var offset = 0.0
			
			if !targets.indices.contains(primaryIndex) {
				row.primaryIndex = -1
				primaryRow = -1
			} else if columnMajor {
				row.primaryIndex = primaryIndex / columnCount
				primaryRow = primaryIndex % columnCount
			} else {
				row.primaryIndex = primaryIndex % columnCount
				primaryRow = primaryIndex / columnCount
			}
			
			if isFloating {
				offset = -axial.sizeBeforeElement(primaryRow, isPositive:isPositive)
			} else if let value = position.value(axis:.horizontal, environment:context.environment) {
				offset = axial.offset(fraction:value, available:available, index:primaryRow, isPositive:isPositive)
			}
			
			var readyTargets = targets
			var readySizes = sizes
			let incompleteRow = readyTargets.count % columnCount
			let end = rowCount * columnCount - 1
			
			if incompleteRow > 0 {
				let emptyTargets = Array(repeating:EmptySpace(), count:columnCount - incompleteRow)
				let emptySizes = Array(repeating:Size.zero, count:columnCount - incompleteRow)
				
				readyTargets.append(contentsOf:emptyTargets)
				readySizes.append(contentsOf:emptySizes)
			}
			
			for index in 0 ..< rowCount {
				let rowIndex = isPositive ? index : end - index
				let y = offset, height = axial.sizes[rowIndex]
				var rowSizes:[Size]
				
				if columnMajor {
					row.targets.removeAll()
					rowSizes = []
					
					for column in 0 ..< columnCount {
						row.targets.append(readyTargets[column * rowCount + rowIndex])
						rowSizes.append(readySizes[column * rowCount + rowIndex])
					}
				} else {
					row.targets = Array(readyTargets.suffix(from:rowIndex * columnCount).prefix(columnCount))
					rowSizes = Array(readySizes.suffix(from:rowIndex * columnCount).prefix(columnCount))
				}
				
				offset += height + spacing
				
				let rowBox = CGRect(x:box.origin.x, y:box.origin.y + CGFloat(y), width:box.size.width, height:CGFloat(height))
				
				row.applyPositionableFrame(rowBox, context:context, axial:rowAxial, sizes:rowSizes, available:rowAvailable, isFloating:isFloating)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, attachable:attachable) }
		}
	}
	
	/// Arrange a group of targets into horizontal rows
	struct Rows: Positionable {
		var targets:[Positionable]
		var rowCount:Int
		var columnTemplate:Vertical
		var position:Position
		var primaryIndex:Int
		var spacing:Native
		var rowMajor:Bool
		var direction:Direction
		
		var singleRow:Horizontal {
			return Horizontal(targets:targets, spacing:spacing, alignment:columnTemplate.position.alignment, position:position, primary:primaryIndex, direction:direction)
		}
		
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return isFloating ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], rowCount:Int, spacing:Native = 0, template:Vertical, position:Position = .default, primary:Int = -1, direction:Direction = .natural) {
			self.targets = targets
			self.rowCount = rowCount
			self.spacing = spacing
			self.position = position
			self.columnTemplate = template
			self.primaryIndex = primary
			self.rowMajor = false
			self.direction = direction
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard rowCount > 1 else { return singleRow.positionableSize(fitting:limit) }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting: limit) }
			
			var column = columnTemplate
			var result = column.positionableSize(fitting:limit, splittingTargets:targets, intoRows:rowCount, rowMajor:rowMajor)
			let columnLimit = (targets.count - 1) / rowCount
			let spacingSum = spacing * Native(columnLimit)
			
			result.width.add(value:spacingSum)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			guard rowCount > 1 else { return singleRow.applyPositionableFrame(box, context:context) }
			
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			let sizes = targets.map { $0.positionableSize(fitting:limit) }
			
			let itemLimit = targets.count - 1
			let columnCount = 1 + itemLimit / rowCount
			var rowHeights = Array(repeating:Dimension.zero, count:rowCount)
			var columnWidths = Array(repeating:Dimension.zero, count:columnCount)
			
			if rowMajor {
				for index in sizes.indices {
					rowHeights[index / rowCount].increase(sizes[index].height)
					columnWidths[index % rowCount].increase(sizes[index].width)
				}
			} else {
				for index in sizes.indices {
					rowHeights[index % rowCount].increase(sizes[index].height)
					columnWidths[index / rowCount].increase(sizes[index].width)
				}
			}
			
			var column = columnTemplate
			let isFloating = self.isFloating
			let isPositive = direction.isPositive(axis:.horizontal, environment:context.environment)
			let available = isFloating ? context.bounds.size.width.native : box.size.width.native
			let columnAvailable = box.size.height.native
			let axial = Axial(columnWidths, available:available, spacing:spacing, fit:position.fit)
			let columnAxial = Axial(rowHeights, available:columnAvailable, spacing:column.spacing, fit:column.position.fit)
			let spacing = axial.space
			let primaryColumn:Int
			var offset = 0.0
			
			if !targets.indices.contains(primaryIndex) {
				column.primaryIndex = -1
				primaryColumn = -1
			} else if rowMajor {
				column.primaryIndex = primaryIndex / rowCount
				primaryColumn = primaryIndex % rowCount
			} else {
				column.primaryIndex = primaryIndex % rowCount
				primaryColumn = primaryIndex / rowCount
			}
			
			if isFloating {
				offset = -axial.sizeBeforeElement(primaryColumn, isPositive:isPositive)
			} else if let value = position.value(axis:.horizontal, environment:context.environment) {
				offset = axial.offset(fraction:value, available:available, index:primaryColumn, isPositive:isPositive)
			}
			
			var readyTargets = targets
			var readySizes = sizes
			let incompleteColumn = readyTargets.count % rowCount
			let end = rowCount * columnCount - 1
			
			if incompleteColumn > 0 {
				let emptyTargets = Array(repeating:EmptySpace(), count:rowCount - incompleteColumn)
				let emptySizes = Array(repeating:Size.zero, count:rowCount - incompleteColumn)
				
				readyTargets.append(contentsOf:emptyTargets)
				readySizes.append(contentsOf:emptySizes)
			}
			
			for index in 0 ..< columnCount {
				let columnIndex = isPositive ? index : end - index
				let x = offset, width = axial.sizes[columnIndex]
				var columnSizes:[Size]
				
				if rowMajor {
					column.targets.removeAll()
					columnSizes = []
					
					for row in 0 ..< rowCount {
						column.targets.append(readyTargets[row * columnCount + columnIndex])
						columnSizes.append(readySizes[row * columnCount + columnIndex])
					}
				} else {
					column.targets = Array(readyTargets.suffix(from:columnIndex * rowCount).prefix(rowCount))
					columnSizes = Array(readySizes.suffix(from:columnIndex * rowCount).prefix(rowCount))
				}
				
				offset += width + spacing
				
				let columnBox = CGRect(x:box.origin.x + CGFloat(x), y:box.origin.y, width:CGFloat(width), height:box.size.height)
				
				column.applyPositionableFrame(columnBox, context:context, axial:columnAxial, sizes:columnSizes, available:columnAvailable, isFloating:isFloating)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, attachable:attachable) }
		}
	}
	
	/// Arrange a group of targets into the same space with the same alignment.
	struct Overlay: Positionable {
		var targets:[Positionable]
		var vertical:Alignment
		var horizontal:Alignment
		var primaryIndex:Int
		
		var frame:CGRect {
			guard !targets.indices.contains(primaryIndex) else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return targets.indices.contains(primaryIndex) ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], vertical:Alignment = .fill, horizontal:Alignment = .fill, primary:Int = -1) {
			self.targets = targets
			self.vertical = vertical
			self.horizontal = horizontal
			self.primaryIndex = primary
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.indices.contains(primaryIndex) else { return targets[primaryIndex].positionableSize(fitting:limit) }
			
			var result:Layout.Size = .zero
			
			for target in targets {
				let size = target.positionableSize(fitting:limit)
				
				result.width.increase(size.width)
				result.height.increase(size.height)
			}
			
			return result
		}
		
		func positionableFrame(for size:Size, box:CGRect, context:Context) -> CGRect {
			let x, y, width, height:CGFloat
			
			if let value = vertical.value(axis:.vertical, environment:context.environment) {
				height = min(CGFloat(size.height.resolve(box.size.height.native)), box.size.height)
				y = (box.size.height - height) * CGFloat(value)
			} else {
				height = box.size.height
				y = 0
			}
			
			if let value = horizontal.value(axis:.horizontal, environment:context.environment) {
				width = min(CGFloat(size.width.resolve(box.size.width.native)), box.size.width)
				x = (box.size.width - width) * CGFloat(value)
			} else {
				width = box.size.width
				x = 0
			}
			
			let frame = CGRect(x:box.origin.x + x, y:box.origin.y + y, width:width, height:height)
			
			return frame
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let isFilling = vertical.isFill && horizontal.isFill
			let limit = Layout.Limit(width:box.size.width.native, height:box.size.height.native)
			let zero = Layout.Size.zero
			
			if targets.indices.contains(primaryIndex) {
				let size = isFilling ? zero : targets[primaryIndex].positionableSize(fitting:limit)
				let frame = positionableFrame(for:size, box:box, context:context)
				
				for target in targets {
					target.applyPositionableFrame(frame, context:context)
				}
			} else {
				for target in targets {
					let size = isFilling ? zero : target.positionableSize(fitting:limit)
					let frame = positionableFrame(for:size, box:box, context:context)
					
					target.applyPositionableFrame(frame, context:context)
				}
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			return targets.flatMap { $0.orderablePositionables(environment:environment, attachable:attachable) }
		}
	}
	
	/// Support various layouts along an axis
	struct Axial {
		enum Fit {
			/// Do not fill available space and compress spacing as needed
			case position
			/// Fill available space by expanding or compressing content
			case stretch
			/// Fill available space by making all content a uniform size
			case uniform
			/// Fill available space by expanding or compressing spacing
			case distribute
		}
		
		/// Unused space
		let empty:Native
		/// Uniform distance between sizes
		let space:Native
		/// Computed sizes along axis
		let sizes:[Native]
		
		init(_ dimensions:[Dimension], available:Native, spacing:Native, fit:Fit) {
			let spaceCount = Native(dimensions.count - 1)
			let space = spacing * spaceCount
			
			if fit == .uniform {
				let count = Native(dimensions.count)
				let uniformSize = max(1, (available - space) / count)
				
				self.empty = 0
				self.space = available < space + count ? max(0, (available - count) / spaceCount) : spacing
				self.sizes = Array(repeating:uniformSize, count:dimensions.count)
				
				return
			}
			
			var minimum = 0.0, maximum = 0.0, prefer = 0.0
			var dimensions = dimensions
			
			for index in dimensions.indices {
				var dimension = dimensions[index]
				
				dimension.minimum = min(max(0, dimension.minimum), available)
				dimension.maximum = min(max(dimension.minimum, dimension.maximum), available * 4)
				dimension.constant = min(max(dimension.minimum, dimension.constant + dimension.fraction * available), dimension.maximum)
				dimensions[index] = dimension
				
				minimum += dimension.minimum
				maximum += dimension.maximum
				prefer += dimension.constant
			}
			
			if available < minimum + space {
				if available < minimum || fit == .distribute {
					let space = fit == .stretch ? 0 : space
					let reduction = minimum + space - available
					let denominator = Native(dimensions.count)
					
					self.empty = 0
					self.space = fit == .stretch ? 0 : spacing
					self.sizes = dimensions.map { $0.minimum - reduction / denominator }
				} else {
					self.empty = 0
					self.space = (available - minimum) / spaceCount
					self.sizes = dimensions.map { $0.minimum }
				}
			} else if available < prefer + space {
				let reduction = prefer + space - available
				let denominator = prefer - minimum
				
				self.empty = 0
				self.space = spacing
				self.sizes = dimensions.map { $0.constant - ($0.constant - $0.minimum) * reduction / denominator }
			} else if available < maximum + space {
				let expansion = available - prefer - space
				let denominator = maximum - prefer
				
				self.empty = 0
				self.space = spacing
				self.sizes = dimensions.map { $0.constant + ($0.maximum - $0.constant) * expansion / denominator }
			} else if fit == .stretch {
				let expansion = available - maximum - space
				let denominator = Native(dimensions.count)
				
				self.empty = 0
				self.space = spacing
				self.sizes = dimensions.map { $0.maximum + expansion / denominator }
			} else {
				if fit == .position {
					self.empty = available - maximum - space
					self.space = spacing
				} else {
					self.empty = 0
					self.space = (available - maximum) / spaceCount
				}
				
				self.sizes = dimensions.map { $0.maximum }
			}
		}
		
		func sizeBeforeElement(_ index:Int, isPositive:Bool) -> Native {
			if isPositive {
				return sizes.prefix(index).reduce(0, +) + Native(index) * space
			} else {
				return sizes.suffix(from:index + 1).reduce(0, +) + Native(sizes.count - 1 - index) * space
			}
		}
		
		func offset(fraction:Native, available:Native, index:Int, isPositive:Bool) -> Native {
			guard empty > 0 else { return 0 }
			guard sizes.indices.contains(index) else { return fraction * empty }
			
			let size = sizes[index]
			let remainder = available - size
			let nominal = remainder * fraction
			
			let beforePrimary = sizeBeforeElement(index, isPositive:isPositive)
			let afterPrimary = sizeBeforeElement(index, isPositive:!isPositive)
			
			return min(max(beforePrimary, nominal), available - size - afterPrimary) - beforePrimary
		}
	}
	
	/// Arrange a group of elements in a flow that uses available space in one direction then wraps to continue using available space.
	struct Flow: Positionable {
		var targets:[Positionable]
		var rowTemplate:Horizontal
		var columnTemplate:Vertical
		var direction:Direction
		var axis:Axis
		
		var frame:CGRect {
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return .zero
		}
		
		init(
			targets:[Positionable],
			rowTemplate:Horizontal = Horizontal(targets:[], alignment:.leading, position:.leading),
			columnTemplate:Vertical = Vertical(targets:[], alignment:.leading, position:.leading),
			direction:Direction = .positive,
			axis:Axis = .horizontal)
		{
			self.targets = targets
			self.columnTemplate = columnTemplate
			self.rowTemplate = rowTemplate
			self.direction = direction
			self.axis = axis
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			
			var result:Layout.Size = .zero
			
			switch axis {
			case .horizontal:
				if let width = limit.width, width < Limit.unlimited {
					var rowSize:Layout.Size = .zero
					var itemCount = 0
					
					for target in targets {
						let size = target.positionableSize(fitting:limit)
						var sum = rowSize.width
						
						sum.add(size.width)
						
						if itemCount > 0 && sum.resolve(width) > width {
							rowSize.width.add(value:rowTemplate.spacing * Native(itemCount - 1))
							result.width.increase(rowSize.width)
							result.height.add(rowSize.height)
							result.height.add(value:columnTemplate.spacing)
							rowSize = size
							itemCount = 1
						} else {
							rowSize.height.increase(size.height)
							rowSize.width = sum
							itemCount += 1
						}
					}
					
					rowSize.width.add(value:rowTemplate.spacing * Native(itemCount - 1))
					result.width.increase(rowSize.width)
					result.height.add(rowSize.height)
				} else {
					var row = rowTemplate
					
					row.targets = targets
					
					result = row.positionableSize(fitting:limit)
				}
			
			case .vertical:
				if let height = limit.height, height < Limit.unlimited {
					var columnSize:Layout.Size = .zero
					var itemCount = 0
					
					for target in targets {
						let size = target.positionableSize(fitting:limit)
						var sum = columnSize.height
						
						sum.add(size.height)
						
						if itemCount > 0 && sum.resolve(height) > height {
							columnSize.height.add(value:columnTemplate.spacing * Native(itemCount - 1))
							result.height.increase(columnSize.height)
							result.width.add(columnSize.width)
							result.width.add(value:rowTemplate.spacing)
							columnSize = size
							itemCount = 1
						} else {
							columnSize.width.increase(size.width)
							columnSize.height = sum
							itemCount += 1
						}
					}
					
					columnSize.height.add(value:columnTemplate.spacing * Native(itemCount - 1))
					result.height.increase(columnSize.height)
					result.width.add(columnSize.width)
				} else {
					var column = columnTemplate
					
					column.targets = targets
					
					return column.positionableSize(fitting:limit)
				}
			}
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let isPositive = direction.isPositive(axis:axis, environment:context.environment)
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			var measured = targets.map { Measured(target:$0, limit:limit) }
			var vertical = columnTemplate
			var horizontal = rowTemplate
			
			if !isPositive {
				measured = measured.reversed()
			}
			
			vertical.targets.removeAll()
			horizontal.targets.removeAll()
			vertical.primaryIndex = -1
			horizontal.primaryIndex = -1
			
			switch axis {
			case .horizontal:
				var width = Dimension.zero
				
				for element in measured {
					width.add(element.size.width)
					
					if !horizontal.targets.isEmpty && width.resolve(box.size.width.native) > box.size.width.native {
						vertical.targets.append(horizontal)
						horizontal.targets.removeAll()
						width = element.size.width
					}
					
					horizontal.targets.append(element)
					width.add(value:horizontal.spacing)
				}
				
				vertical.targets.append(horizontal)
				vertical.applyPositionableFrame(box, context:context)
			case .vertical:
				var height = Dimension.zero
				
				for element in measured {
					height.add(element.size.height)
					
					if !vertical.targets.isEmpty && height.resolve(box.size.height.native) > box.size.height.native {
						horizontal.targets.append(vertical)
						vertical.targets.removeAll()
						height = element.size.height
					}
					
					vertical.targets.append(element)
					height.add(value:vertical.spacing)
				}
				
				horizontal.targets.append(vertical)
				horizontal.applyPositionableFrame(box, context:context)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, attachable:Bool) -> [Positionable] {
			let isPositive = direction.isPositive(axis:axis, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, attachable:attachable) }
		}
	}
}

//	MARK: -

extension Positionable {
	func ignoringSafeBounds() -> Positionable {
		return Layout.IgnoreSafeBounds(target:self)
	}
	
	func padding(_ insets:Layout.EdgeInsets) -> Positionable {
		return Layout.Padding(target:self, insets:insets)
	}
	
	func padding(_ uniform:Layout.Native = 8) -> Positionable {
		return Layout.Padding(target:self, uniform:uniform)
	}
	
	func padding(horizontal:Layout.Native, vertical:Layout.Native) -> Positionable {
		return Layout.Padding(target:self, insets:Layout.EdgeInsets(horizontal:horizontal, vertical:vertical))
	}
	
	func fixed(width:Layout.Native? = nil, height:Layout.Native? = nil) -> Positionable {
		return Layout.Sizing(target:self, width:width, height:height)
	}
	
	func minimum(width:Layout.Native? = nil, height:Layout.Native? = nil) -> Positionable {
		return Layout.Sizing(target:self, minimumWidth:width, minimumHeight:height)
	}
	
	func useAvailableSpace() -> Positionable {
		return Layout.Sizing(target:self, minimumWidth:0, minimumHeight:0)
	}
	
	func aspect(ratio:Layout.Native, position:Layout.Native = 0.5) -> Positionable {
		return Layout.Aspect(target:self, ratio:ratio, position:position)
	}
}

//	MARK: -

extension PlatformView: Positionable {
	var positionableEnvironment:Layout.Environment {
#if os(macOS)
		let isRTL = userInterfaceLayoutDirection == .rightToLeft
#else
		let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
#endif
		
		return Layout.Environment(isRTL:isRTL)
	}
	
	var positionableScale:CGFloat {
#if os(macOS)
		let scale = convertToBacking(CGSize(width:1, height:1)).minimum
#else
		let scale = window?.screen.scale ?? contentScaleFactor
#endif
		
		return scale
	}
	
	var positionableContext:Layout.Context {
#if os(macOS)
		let isDownPositive = isFlipped
#else
		let isDownPositive = true
#endif
		
		return Layout.Context(bounds:stableBounds, safeBounds:safeBounds, isDownPositive:isDownPositive, scale:positionableScale, environment:positionableEnvironment)
	}
	
	var compressionResistance:CGPoint {
		let maximum = PlatformPriority.required.rawValue
		
		return CGPoint(
			x:CGFloat(contentCompressionResistancePriority(for:.horizontal).rawValue / maximum),
			y:CGFloat(contentCompressionResistancePriority(for:.vertical).rawValue / maximum)
		)
	}
	
	@objc
	func positionableSizeFitting(_ size:CGSize) -> Data {
		let intrinsicSize = intrinsicContentSize
		
		return Layout.Size(intrinsic:intrinsicSize).data
	}
	
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
		return Layout.Size(data:positionableSizeFitting(limit.size)) ?? .zero
	}
	
	@objc
	func applyPositionableFrame(_ box:CGRect) {
#if os(macOS)
		self.frame = self.frame(forAlignmentRect:box)
#else
		if box.size == bounds.size {
			center = box.center
		} else {
			frame = box
		}
#endif
	}
	
	func applyPositionableFrame(_ box:CGRect, context:Layout.Context) {
		let frame = context.viewFrame(box)
		
		applyPositionableFrame(frame)
	}
	
	func orderablePositionables(environment:Layout.Environment, attachable: Bool) -> [Positionable] {
		return [self]
	}
}

//	MARK: -

extension PlatformView: PositionableContainer {
	func insertSubviews<S:Sequence>(_ views:S, at index:Int) where S.Element == PlatformView {
#if os(macOS)
		var current = subviews
		var changed = false
		var index = index
		
		if index < current.count {
			for view in views where view !== current[index] {
				if view.superview === self, let order = current.firstIndex(of:view) {
					current.remove(at:order)
					
					if order < index { index -= 1 }
				}
				
				current.insert(view, at:index)
				changed = true
				index += 1
			}
		} else {
			current.removeAll { views.contains($0) }
			current.append(contentsOf:views)
			changed = true
		}
		
		if changed {
			subviews = current
		}
#else
		var index = index
		
		if index < subviews.count {
			for view in views where view !== subviews[index] {
				let isMovingForward = view.superview === self && subviews.firstIndex(of:view) ?? .max < index
				insertSubview(view, at:index)
				if !isMovingForward { index += 1 }
			}
		} else {
			for view in views {
				addSubview(view)
			}
		}
#endif
	}
	
	static func siblingGroups(_ list:[[PlatformView]], includeOrphans:Bool = false) -> (groups:[[PlatformView]], ancestor:PlatformView?) {
		var ancestor:PlatformView? = nil
		var groups:[[PlatformView]] = []
		
		for group in list {
			var siblings:[PlatformView] = []
			
			for view in group {
				guard let parent = view.superview else {
					if includeOrphans { siblings.append(view) }
					continue
				}
				
				guard let current = ancestor else {
					ancestor = parent
					siblings.append(view)
					continue
				}
				
				guard parent !== current else {
					siblings.append(view)
					continue
				}
				
				guard !parent.isDescendant(of:current) else {
					continue
				}
				
				var ascend = current
				
				while let next = ascend.superview, next !== parent { ascend = next }
				
				guard ascend.superview === parent else {
					continue // disjoint hierarchies
				}
				
				siblings.removeAll { $0.superview === current }
				siblings.append(ascend)
				siblings.append(view)
				ancestor = parent
				
				for index in groups.indices {
					groups[index].removeAll { $0.superview === current }
				}
			}
			
			groups.append(siblings)
		}
		
		groups.removeAll { $0.isEmpty }
		
		return (groups, ancestor)
	}
	
	static func orderPositionables(_ unorderable:[Positionable], environment:Layout.Environment, options:Layout.OrderOptions = .order, hierarchyRoot:PlatformView? = nil) {
		let views = unorderable.map { $0.orderablePositionables(environment:environment, attachable:false).compactMap { $0 as? PlatformView } }
		let (groups, ancestor) = siblingGroups(views, includeOrphans:options.contains(.add))
		
		guard let parent = ancestor ?? hierarchyRoot else { return }
		
		let siblings = groups.flatMap { $0 }
		let current = parent.subviews
		
		if parent === hierarchyRoot && options.contains(.remove) {
			for view in current where !siblings.contains(view) { view.removeFromSuperview() }
			
			parent.insertSubviews(siblings, at:parent.subviews.count)
		} else {
			let anchor = current.lastIndex { siblings.contains($0) } ?? current.count
			
			parent.insertSubviews(siblings, at:anchor)
		}
	}
	
	func orderPositionables(_ unorderable:[Positionable], environment:Layout.Environment, options:Layout.OrderOptions = .add) {
		PlatformView.orderPositionables(unorderable, environment:environment, options:options, hierarchyRoot:self)
	}
}

//	MARK: -

extension PlatformLabel {
	static func positionableSize(fitting height:Layout.Native?, stringSize:CGSize, stringLength:Int, maximumLines:Int = 0) -> Layout.Size {
		var size = Layout.Size(require:stringSize)
		
		if maximumLines != 1 && stringLength > 1 {
			let count = Layout.Native(min(maximumLines > 0 ? maximumLines : 256, stringLength))
			
			if let height = height, height < stringSize.height.native * count {
				let scalar = floor(height / stringSize.height.native)
				
				size.width.minimum = stringSize.width.native / scalar
			} else {
				size.width.minimum = stringSize.width.native / count
			}
		}
		
		return size
	}
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		guard let text = text else { return super.positionableSizeFitting(size) }
		
#if os(macOS)
		let insets = alignmentRectInsets
		let size = CGSize(width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
#endif
		
		let fits = sizeThatFits(size)
		
		return PlatformLabel.positionableSize(
			fitting:size.height.native,
			stringSize:fits,
			stringLength:text.count,
			maximumLines:maximumLines
		).data
	}
}
