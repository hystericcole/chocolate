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
	
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size
	func applyPositionableFrame(_ frame:CGRect, context:Layout.Context)
	
	func orderablePositionables(environment:Layout.Environment) -> [Positionable]
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
		/// Fill available bounds by stretching space
		case distribute
		/// Position around the primary element
		case float
		
		static let start = Position.fraction(0.0)
		static let center = Position.fraction(0.5)
		static let end = Position.fraction(1.0)
		static let leading = Alignment.adaptiveFraction(0.0)
		static let trailing = Alignment.adaptiveFraction(1.0)
		static let `default` = center
		
		var isFill:Bool {
			switch self {
			case .stretch, .distribute: return true
			default: return false
			}
		}
		
		var fit:Axial.Fit {
			switch self {
			case .stretch: return .stretch
			case .distribute: return .distribute
			default: return .position
			}
		}
		
		var alignment:Alignment {
			switch self {
			case .fraction(let value): return .fraction(value)
			case .adaptiveFraction(let value): return .adaptiveFraction(value)
			case .float: return .center
			case .stretch, .distribute: return .fill
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
	
	enum Direction {
		case positive, negative, natural, reverse
		
		func isPositive(axis:Axis, environment:Environment) -> Bool {
			switch self {
			case .positive: return true
			case .negative: return false
			case .natural: return axis == .horizontal && environment.isRTL ? false : true
			case .reverse: return axis == .horizontal && environment.isRTL ? true : false
			}
		}
	}
	
	struct Environment {
		static var current:Environment { return Environment(isRTL:false) }
		
		let isRTL:Bool
		
		func adaptiveFractionValue(_ value:Native, axis:Axis) -> Native { return axis == .horizontal && isRTL ? 1.0 - value : value }
	}
	
	struct Context {
		var bounds:CGRect
		var safeBounds:CGRect
		var isDownPositive:Bool
		var environment:Environment
		
		func performLayout(_ layout:Positionable) {
			layout.applyPositionableFrame(safeBounds, context:self)
		}
	}
	
	struct Limit {
		static let unlimited:Native = 0x1p30
		let width:Native?
		let height:Native?
		
		var size:CGSize { return CGSize(width:width ?? .greatestFiniteMagnitude, height:height ?? .greatestFiniteMagnitude) }
		
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
	
	struct Dimension {
		static let unbound = Limit.unlimited * 0x1p10
		static let zero = Dimension(value:0)
		
		var constant:Native
		var minimum:Native
		var maximum:Native
		var fraction:Native
		
		var isUnbounded:Bool { return minimum <= 0 && constant == 0 && fraction == 0 && maximum >= Limit.unlimited }
		
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
		
		init?(value:Native?) {
			guard let value = value else { return nil }
			
			self.init(value:value)
		}
		
		init?(minimum:Native?) {
			guard let minimum = minimum else { return nil }
			
			self.init(constant:minimum, range:minimum ... Dimension.unbound, fraction:0)
		}
		
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
		
		mutating func increase(_ dimension:Dimension) {
			constant = max(constant, dimension.constant)
			minimum = max(minimum, dimension.minimum)
			maximum = max(maximum, dimension.maximum)
			fraction = max(fraction, dimension.fraction)
		}
	}
	
	struct Size {
		static let zero = Size(width:.zero, height:.zero)
		
		var width:Dimension
		var height:Dimension
		
		var constant:CGSize { return CGSize(width:width.constant, height:height.constant) }
		var minimum:CGSize { return CGSize(width:width.minimum, height:height.minimum) }
		var maximum:CGSize { return CGSize(width:width.maximum, height:height.maximum) }
		var data:Data { return withUnsafeBytes(of:self) { Data($0) } }
		
		init(width:Dimension, height:Dimension) {
			self.width = width
			self.height = height
		}
		
		init(size:CGSize) {
			self.width = Dimension(value:size.width.native)
			self.height = Dimension(value:size.height.native)
		}
		
		init(intrinsicSize size:CGSize) {
			self.width = size.width < 0 ? Dimension(constant:0) : Dimension(value:size.width.native)
			self.height = size.height < 0 ? Dimension(constant:0) : Dimension(value:size.height.native)
		}
		
		init?(data:Data) {
			guard let size:Size = data.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to:Self.self).pointee }) else { return nil }
			
			self = size
		}
		
		func resolve(_ size:CGSize) -> CGSize { return CGSize(width:width.resolve(size.width.native), height:height.resolve(size.height.native)) }
	}
	
	struct EdgeInsets {
		var minX, maxX, minY, maxY:Native
		
		var horizontal:Native { return minX + maxX }
		var vertical:Native { return minY + maxY }
		
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
	
	struct IgnoreSafeBounds: Positionable {
		var target:Positionable
		
		var frame:CGRect { return target.frame }
		
		init(target:Positionable) {
			self.target = target
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return target.positionableSize(fitting:limit)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let minX = box.minX > context.safeBounds.minX ? 0 : max(box.minX - context.bounds.minX, 0) 
			let minY = box.minY > context.safeBounds.minY ? 0 : max(box.minY - context.bounds.minY, 0)
			let maxX = box.maxX < context.safeBounds.maxX ? 0 : max(context.bounds.maxX - box.maxX, 0)
			let maxY = box.maxY < context.safeBounds.maxY ? 0 : max(context.bounds.maxY - box.maxY, 0)
			let box = CGRect(x:box.origin.x - minX, y:box.origin.y - minY, width:box.size.width + minX + maxX, height:box.size.height + minY + maxY)
			
			target.applyPositionableFrame(box, context:context)
		}
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			return target.orderablePositionables(environment:environment)
		}
	}
	
	struct EmptySpace: Positionable {
		var size:CGSize
		
		var frame:CGRect { return .zero }
		
		init(width:Native = 0, height:Native = 0) { self.size = CGSize(width:width, height:height) }
		init(_ size:CGSize) { self.size = size }
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			return Layout.Size(intrinsicSize:size)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {}
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] { return [] }
	}
	
	struct Padding: Positionable {
		var target:Positionable
		var insets:EdgeInsets
		
		var frame:CGRect { return insets.paddingBox(target.frame) }
		
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
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			return target.orderablePositionables(environment:environment)
		}
	}
	
	struct Sizing: Positionable {
		var target:Positionable
		var width:Dimension?
		var height:Dimension?
		
		var frame:CGRect {
			var result = target.frame
			if let width = width { result.size.width = CGFloat(width.constant) }
			if let height = height { result.size.height = CGFloat(height.constant) }
			return result
		}
		
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
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			return target.orderablePositionables(environment:environment)
		}
	}
	
	struct Aspect: Positionable {
		var target:Positionable
		var position:CGPoint
		var ratio:CGSize
		
		var frame:CGRect {
			return target.frame
		}
		
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
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			return target.orderablePositionables(environment:environment)
		}
	}
	
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
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
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
			
			for target in targets {
				let size = target.positionableSize(fitting: limit)
				
				result.height.add(size.height)
				result.width.increase(size.width)
			}
			
			result.height.add(value:spacingSum)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let limit = Limit(width:box.size.width.native, height:nil)
			let available = isFloating ? context.bounds.size.height.native : box.size.height.native
			let sizes = targets.map { $0.positionableSize(fitting:limit) }
			let axial = Axial(sizes.map { $0.height }, available:available, spacing:spacing, fit:position.fit)
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
				
				target.applyPositionableFrame(frame, context:context)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.vertical, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment) }
		}
	}
	
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
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
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
			
			for target in targets {
				let size = target.positionableSize(fitting:limit)
				
				result.width.add(size.width)
				result.height.increase(size.height)
			}
			
			result.width.add(value:spacingSum)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let limit = Limit(width:nil, height:box.size.height.native)
			let available = isFloating ? context.bounds.size.width.native : box.size.width.native
			let sizes = targets.map { $0.positionableSize(fitting:limit) }
			let axial = Axial(sizes.map { $0.width }, available:available, spacing:spacing, fit:position.fit)
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
				
				target.applyPositionableFrame(frame, context:context)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment) }
		}
	}
	
	struct Overlay: Positionable {
		var targets:[Positionable]
		var vertical:Alignment
		var horizontal:Alignment
		var primaryIndex:Int
		
		var frame:CGRect {
			guard !targets.indices.contains(primaryIndex) else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		init(targets:[Positionable], vertical:Alignment = .center, horizontal:Alignment = .center, primary:Int = -1) {
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
		
		func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
			return targets.flatMap { $0.orderablePositionables(environment:environment) }
		}
	}
	
	struct Axial {
		enum Fit {
			/// Do not fill available space and compress spacing as needed
			case position
			/// Fill available space by expanding or compressing content
			case stretch
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
			var minimum = 0.0, maximum = 0.0, prefer = 0.0
			var dimensions = dimensions
			let spaceCount = Native(dimensions.count - 1)
			let space = spacing * spaceCount
			
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
					self.space = spacing
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
				return sizes.suffix(from:index + 1).reduce(0, +) + Native(sizes.count - index) * space
			}
		}
		
		func offset(fraction:Native, available:Native, index:Int, isPositive:Bool) -> Native {
			guard sizes.indices.contains(index) else { return fraction * empty }
			
			let size = sizes[index]
			let remainder = available - size
			let nominal = remainder * fraction
			
			let minimumBeforeOffset = sizeBeforeElement(index, isPositive:isPositive)
			let minimumAfterOffset = sizeBeforeElement(index, isPositive:!isPositive)
			
			return min(max(minimumBeforeOffset, nominal), available - minimumAfterOffset)
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
	
	func padding(uniform:Layout.Native = 8) -> Positionable {
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
	
	var positionableContext:Layout.Context {
#if os(macOS)
		let isDownPositive = isFlipped
#else
		let isDownPositive = true
#endif
		
		return Layout.Context(bounds:stableBounds, safeBounds:safeBounds, isDownPositive:isDownPositive, environment:positionableEnvironment)
	}
	
	@objc
	func positionableSizeFitting(_ size:CGSize) -> Data {
		let intrinsicSize = intrinsicContentSize
		
		return Layout.Size(intrinsicSize:intrinsicSize).data
	}
	
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
		return Layout.Size(data:positionableSizeFitting(limit.size)) ?? .zero
	}
	
	@objc
	func applyPositionableFrame(_ box:CGRect) {
		let box = box.integral
		
#if os(macOS)
		frame = self.frame(forAlignmentRect:box)
#else
		if box.size == bounds.size {
			center = box.center
		} else {
			frame = box
		}
#endif
	}
	
	func applyPositionableFrame(_ box:CGRect, context:Layout.Context) {
#if os(macOS)
		var box = box
		
		if !context.isDownPositive {
			box.origin.y = context.bounds.height - box.origin.y - box.size.height
		}
#endif
		
		applyPositionableFrame(box)
	}
	
	func orderablePositionables(environment:Layout.Environment) -> [Positionable] {
		return [self]
	}
	
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
	
	static func orderPositionables(_ targets:[Positionable], environment:Layout.Environment, addingToHierarchy:Bool = false, hierarchyRoot:PlatformView? = nil) {
		let (groups, ancestor) = siblingGroups(targets.map { $0.orderablePositionables(environment:environment).compactMap { $0 as? PlatformView } }, includeOrphans:addingToHierarchy)
		
		guard let parent = ancestor ?? hierarchyRoot else { return }
		
		let siblings = groups.flatMap { $0 }
		let current = parent.subviews
		let anchor = current.lastIndex { siblings.contains($0) } ?? current.count
		
		parent.insertSubviews(siblings, at:anchor)
	}
}

//	MARK: -

extension PlatformLabel {
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		guard size.width.native < Layout.Limit.unlimited || size.height.native < Layout.Limit.unlimited else { return super.positionableSizeFitting(size) }
		
		let fits = sizeThatFits(size)
		
		return Layout.Size(size:fits).data
	}
}
