//
//  Layout.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation

protocol Positionable {
	/// The current frame
	var frame:CGRect { get }
	
	/// The compression resistance affects how positionable frames are applied.  Values range from 0, no resistance, to 1, require resistance.
	var compressionResistance:CGPoint { get }
	
	/// The requested size of the element.
	/// 
	/// Each dimension of the size specifies a minimum, maximum, fraction of available space, and constant.
	/// The final value, once the available space is known, will be computed as `constant + fraction × available`, clamped between minimum and maximum.
	/// The requested size will be provided when possible.
	/// - Parameter limit: The limit of available space.
	func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size
	
	/// Apply a frame to the element.
	///	# Layout
	/// During typical layout, a container will get the requested size of each element, fit the sizes within available space, then apply frames to elements.
	/// The applied frames may exceed the minimum or maximum requested size depending on available space and layout options.
	/// When containers are nested, each container will get the size of contained elements twice, once when requesting a size for itself and again when applying a frame to itself.
	/// Deeply nested containers will request the size of elements several times during a single layout, with a more accurate limit at each pass.
	func applyPositionableFrame(_ frame:CGRect, context:Layout.Context)
	
	/// Retrieve elements that can be ordered in a container, or attached to elements in a container.
	/// # Order create
	/// A container is adding elements to the hierarchy.  Viewables should create views as needed.
	/// # Order attach
	/// A container is being reused and attempting to reform attachments.  Viewables should return self.
	/// # Order existing
	/// A modifier is affecting views in the hierarchy.  Viewables should return existing views but not create views.
	func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable]
}

//	MARK: -

protocol PositionableContainer {
	func orderPositionables(_ unorderable:[Positionable], environment:Layout.Environment, options:Layout.OrderOptions)
}

//	MARK: -

protocol PositionableNode: Positionable {
	var positionables:[Positionable] { get }
}

//	MARK: -

protocol PositionableWithTarget: PositionableNode {
	var target:Positionable { get }
}

//	MARK: -

protocol PositionableWithTargets: PositionableNode {
	var targets:[Positionable] { get }
}

//	MARK: -

struct Layout {
	typealias Native = CGFloat.NativeType
	typealias NativeRange = ClosedRange<Native>
	typealias Timestamp = UInt64
	
	enum Order {
		case create
		case attach
		case existing
	}
	
	enum Axis: CustomStringConvertible {
		case horizontal, vertical
		
		var description:String {
			switch self {
			case .horizontal: return "―"
			case .vertical: return "|"
			}
		}
	}
	
	/// Position of a single element along an axis within a container.
	enum Alignment {
		/// Position each element within available bounds.  A fraction determines the ratio of empty space around the element.
		///
		/// # Example
		/// Align an element with a size of 240 in a container with a limit of 400.
		/// The unused space is 160, and a fraction of that unused space is before the element.
		/// For a fraction of 0.25, that is 0.25 × (400 - 240) = 40 before the element, with 120 after the element.
		case fraction(Native)
		/// Position each element within available bounds, adapting to the environment.
		case adaptiveFraction(Native)
		/// Fill available bounds, ignoring the measured size of the element.
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
		
		static func point(horizontal:Alignment, vertical:Alignment, environment:Environment) -> CGPoint {
			return CGPoint(
				x:horizontal.value(axis:.horizontal, environment:environment) ?? 0.5,
				y:vertical.value(axis:.vertical, environment:environment) ?? 0.5
			)
		}
		
		static func frame(for size:Size, box:CGRect, horizontal:Alignment, vertical:Alignment, environment:Environment) -> CGRect {
			let x, y, width, height:CGFloat
			
			if let value = vertical.value(axis:.vertical, environment:environment) {
				height = min(CGFloat(size.height.resolve(box.size.height.native, maximize:true)), box.size.height)
				y = (box.size.height - height) * CGFloat(value)
			} else {
				height = box.size.height
				y = 0
			}
			
			if let value = horizontal.value(axis:.horizontal, environment:environment) {
				width = min(CGFloat(size.width.resolve(box.size.width.native, maximize:true)), box.size.width)
				x = (box.size.width - width) * CGFloat(value)
			} else {
				width = box.size.width
				x = 0
			}
			
			let frame = CGRect(x:box.origin.x + x, y:box.origin.y + y, width:width, height:height)
			
			return frame
		}
	}
	
	/// Position of a group of elements along an axis within a container.
	enum Position {
		///	Position content within available bounds.
		///
		/// # Example
		/// Position content with a size of 320 in a container with a limit of 400.
		/// The unused space is 80, and a fraction of that unused space is before the content.
		/// For a fraction of 0.25, that is 0.25 × (400 - 320) = 20 before the content, with 60 after the content.
		case fraction(Native)
		/// Position content within available bounds, adapting to the environment.
		/// Equivalent to gravityAreas in a stack view.
		case adaptiveFraction(Native)
		/// Fill available bounds by stretching elements.
		/// Equivalent to fill or fillProportionally in a stack view.
		case stretch
		/// Fill available bounds by making elements a uniform size, ignoring the measured size of the element.
		/// Equivalent to fillEqually in a stackView.
		case uniform
		/// As `uniform` except end elements are weighted differently than interior elements.
		case uniformWithEnds(Native)
		/// Fill available bounds by aligning each element within a uniform space.
		/// Equivalent to equalCentering in a stack view, when value is 0.5.
		case uniformAlign(Native)
		/// Fill available bounds by stretching space between elements.
		/// Equivalent to equalSpacing in a stack view.
		case distribute
		/// Position the container around the primary element, with other elements hanging outside the container.
		/// Equivalent to constraining one arranged view of a stack view.
		case float
		
		static let start = Position.fraction(0.0)
		static let center = Position.fraction(0.5)
		static let end = Position.fraction(1.0)
		static let leading = Position.adaptiveFraction(0.0)
		static let trailing = Position.adaptiveFraction(1.0)
		static let `default` = center
		
		var isFill:Bool {
			switch self {
			case .stretch, .uniform, .uniformAlign, .distribute: return true
			default: return false
			}
		}
		
		var alignment:Alignment {
			switch self {
			case .fraction(let value): return .fraction(value)
			case .adaptiveFraction(let value): return .adaptiveFraction(value)
			case .uniformAlign(let value): return .adaptiveFraction(value)
			case .float: return .center
			case .stretch, .uniform, .uniformWithEnds, .distribute: return .fill
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
		
		func alignValue(axis:Axis, environment:Environment) -> Native? {
			switch self {
			case .uniformAlign(let value): return environment.adaptiveFractionValue(value, axis:axis)
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
	
	/// Options when ordering elements within a container
	struct OrderOptions: OptionSet {
		let rawValue:Int
		
		/// Only order elements. Do not add or remove elements from the container.
		static let order:OrderOptions = []
		/// Add elements to the container while ordering.
		static let add = OrderOptions(rawValue:1)
		/// Remove elements from the container that are not being ordered.
		static let remove = OrderOptions(rawValue:2)
		/// Replace the contents of the container with the ordered elements.
		static let set:OrderOptions = [.add, .remove]
	}
	
	/// Environment for applying layout
	struct Environment: Equatable, CustomStringConvertible {
		static var current:Environment { return Environment(isRTL:false) }
		
		/// Is the natural layout direction right to left.
		let isRTL:Bool
		
		var description:String { return isRTL ? "←" : "→" }
		
		func adaptiveFractionValue(_ value:Native, axis:Axis) -> Native { return axis == .horizontal && isRTL ? 1.0 - value : value }
	}
	
	/// Context for a layout pass within a container
	struct Context: Equatable, CustomStringConvertible {
		let timestamp:Timestamp
		/// The bounds of the container
		var bounds:CGRect
		/// The unobstructed bounds of the container
		var safeBounds:CGRect
		/// The number of device pixels per logical pixel
		var scale:CGFloat
		/// The layout environment
		var environment:Environment
		/// Is the positive direction of the y axis down
		var isDownPositive:Bool
		
		var description:String { return "\(bounds) @\(scale)x \(isDownPositive ? "↓+" : "↑+") \(environment)" }
		var data:Data { return withUnsafeBytes(of:self) { Data($0) } }
		
		init(bounds:CGRect, safeBounds:CGRect, isDownPositive:Bool, scale:CGFloat = 1, environment:Layout.Environment, timestamp:Timestamp? = nil) {
			self.timestamp = timestamp ?? DispatchTime.now().uptimeNanoseconds
			self.bounds = bounds
			self.safeBounds = safeBounds
			self.isDownPositive = isDownPositive
			self.scale = scale
			self.environment = environment
		}
		
		init!(data:Data) {
			guard let binaryValue:Context = data.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to:Self.self).pointee }) else { return nil }
			
			self = binaryValue
		}
		
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
		
		func withBounds(_ bounds:CGRect) -> Context {
			return Context(bounds:bounds, safeBounds:bounds.intersection(safeBounds), isDownPositive:isDownPositive, scale:scale, environment:environment)
		}
	}
	
	/// The space available during layout
	struct Limit: CustomStringConvertible {
		static let unlimited:Native = 0x1p30
		/// The available width, or nil for no limit
		let width:Native?
		/// The available height, or nil for no limit
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
		
		func fittingRatio(_ ratio:CGSize) -> Limit {
			let width = self.width ?? Limit.unlimited
			let height = self.height ?? Limit.unlimited
			
			guard width > 0 && height > 0 else { return self }
			guard width < Limit.unlimited || height < Limit.unlimited else { return self }
			
			let ratioWidth = width * ratio.height.native
			let ratioHeight = height * ratio.width.native
			
			if width < Limit.unlimited && ratioWidth < ratioHeight {
				return Limit(width:width, height:ratioWidth / ratio.width.native)
			} else {
				return Limit(width:ratioHeight / ratio.height.native, height:height)
			}
		}
		
		func minimize(width: Native, height: Native) -> Limit {
			let width = min(width, self.width ?? Limit.unlimited)
			let height = min(height, self.height ?? Limit.unlimited)
			
			return Limit(width:width < Limit.unlimited ? width : nil, height:height < Limit.unlimited ? height : nil)
		}
		
		func isEqual(to limit:Limit, on axis:Axis? = nil) -> Bool {
			if axis != .vertical {
				if let value = width, value < Limit.unlimited {
					if value != limit.width { return false }
				} else if let value = limit.width, value < Limit.unlimited {
					return false
				}
			}
			
			if axis != .horizontal {
				if let value = height, value < Limit.unlimited {
					if value != limit.height { return false }
				} else if let value = limit.height, value < Limit.unlimited {
					return false
				}
			}
			
			return true
		}
	}
	
	/// The space requested during layout, in one direction.
	///
	/// The final value, once the available space is known, will be computed as constant + fraction × available, clamped between minimum and maximum.
	/// - To require a size, set minimum and maximum equal to that size.  Constant and fraction will be ignored.
	/// - To request a range of sizes, set minimum and maximum, with constant set to the preferred value within that range.
	/// - To request a fraction of available space, set fraction, and optionally minimum and maximum.
	struct Dimension: Equatable, CustomStringConvertible {
		static let unbound = Limit.unlimited * 0x1p10
		static let unlimited = 0 ... unbound
		static let zero = Dimension(value:0)
		
		/// The preferred value is constant + fraction × limit
		var constant:Native
		/// The minimum value for the resolved dimension
		var minimum:Native
		/// The maximum value for the resolved dimension
		var maximum:Native
		/// The fraction of the current container
		var fraction:Native
		
		var isUnbounded:Bool { return minimum <= 0 && constant == 0 && fraction == 0 && maximum >= Limit.unlimited }
		var description:String { return "\(minimum) <= \(constant) + \(fraction) × limit <= \(maximum < Limit.unlimited ? String(maximum) : "∞")" }
		
		init(constant:Native, range:NativeRange = Dimension.unlimited, fraction:Native = 0) {
			self.constant = constant
			self.minimum = range.lowerBound
			self.maximum = range.upperBound
			self.fraction = fraction
		}
		
		init(value:Native) {
			constant = 0
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
		func resolve(_ limit:Native, maximize:Bool = false) -> Native {
			let prefer = min(max(minimum, constant + fraction * limit), maximum)
			
			if maximize && prefer < limit && fraction == 0 { return min(limit, maximum) }
			
			return prefer
		}
		
		/// Computes constant + fraction × limit
		/// - Parameters:
		///   - limit: Bounds of container
		///   - maximumWeight: maximum is clamped to multiple of limit
		/// - Returns: Dimension with fraction of limit added to constant
		func resolved(_ limit:Native, maximumWeight:Native = 8) -> Dimension {
			let limit = max(0, limit)
			let a = min(max(0, minimum), limit)
			let b = min(max(a, maximum), limit * maximumWeight)
			let c = min(max(a, constant + fraction * limit), b)
			
			return Dimension(constant:c, range:a ... b, fraction:0)
		}
		
		func limit(fitting limit:Native?) -> Native? {
			if let limit = limit, limit < Limit.unlimited {
				let resolved = resolve(limit, maximize:true)
				
				return min(resolved, limit)
			} else if maximum < Limit.unlimited {
				return maximum
			} else {
				return limit
			}
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
			minimum = max(minimum * scalar, 0)
			maximum = maximum < Dimension.unbound ? min(maximum * scalar, Dimension.unbound) : Dimension.unbound
			fraction *= scalar
		}
		
		mutating func increase(_ dimension:Dimension) {
			constant = max(constant, dimension.constant)
			minimum = max(minimum, dimension.minimum)
			maximum = max(maximum, dimension.maximum)
			fraction = max(fraction, dimension.fraction)
		}
		
		mutating func minimize(_ range:NativeRange) {
			minimum = min(minimum, range.lowerBound)
			maximum = min(maximum, range.upperBound)
		}
		
		mutating func intersect(_ range:NativeRange) {
			minimum = min(max(range.lowerBound, minimum), range.upperBound)
			maximum = min(max(range.lowerBound, maximum), range.upperBound)
		}
	}
	
	/// The size requested during layout
	struct Size: Equatable, CustomStringConvertible {
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
		
		/// Initialize with size, treating values as required.
		/// - Parameter size: The required size
		init(require size:CGSize) {
			self.width = Dimension(value:size.width.native)
			self.height = Dimension(value:size.height.native)
		}
		
		/// Initialize with size, treating negative values as unbounded and positive values as required
		/// - Parameter size: The intrinsic size
		init(intrinsic size:CGSize) {
			self.width = size.width < 0 ? Dimension(constant:0) : Dimension(value:size.width.native)
			self.height = size.height < 0 ? Dimension(constant:0) : Dimension(value:size.height.native)
		}
		
		init(minimum:CGSize = .zero, prefer:CGSize = .zero, maximum:CGSize = Size.unbound) {
			self.width = Dimension(minimum:minimum.width.native, prefer:prefer.width.native, maximum:maximum.width.native)
			self.height = Dimension(minimum:minimum.height.native, prefer:prefer.height.native, maximum:maximum.height.native)
		}
		
		init!(data:Data) {
			guard let binaryValue:Size = data.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to:Self.self).pointee }) else { return nil }
			
			self = binaryValue
		}
		
		init(stringSize:CGSize, stringLength:Int, maximumHeight:Layout.Native?, maximumLines:Int = 0) {
			self.init(require:stringSize)
			
			if maximumLines != 1 && stringLength > 1 {
				var scalar = Layout.Native(stringLength)
				
				if maximumLines > 0 {
					scalar = min(Layout.Native(maximumLines), scalar)
				}
				
				if let height = maximumHeight, height > 0 && height < scalar * stringSize.height.native {
					scalar = floor(height / stringSize.height.native)
				}
				
				if scalar > 1 {
					width.minimum = stringSize.width.native / scalar
				}
			}
		}
		
		///	Compute the resolved value for both dimensions
		func resolve(_ size:CGSize, maximize:Bool = false) -> CGSize {
			return CGSize(width:width.resolve(size.width.native, maximize:maximize), height:height.resolve(size.height.native, maximize:maximize))
		}
		
		/// Pin dimensions of box within mininum and maximum of size
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
		
		/// Constrain unbound aspects of each dimension using the bound aspects of the other dimension.
		/// # Example
		/// Given a width of `0 < 100 < ∞` and a height of `20 < 150 < ∞`, a new minimum width will be computed.
		/// The constant values are both bound (`> 0`), and the maximum values are both unbound (`>= unlimited`), so neither will be affected.
		/// If either dimension has a fraction, then neither constant will be affected.
		/// - Parameter ratio: Ratio to apply to unconstrained values
		/// - Returns: Size with additional constraints
		func constrainingWithRatio(_ ratio:CGSize) -> Size {
			var size = self
			
			if size.width.minimum <= 0 && size.height.minimum > 0 && ratio.height > 0 {
				size.width.minimum = size.height.minimum * ratio.width.native / ratio.height.native
			}
			
			if size.height.minimum <= 0 && size.width.minimum > 0 && ratio.width > 0 {
				size.height.minimum = size.width.minimum * ratio.height.native / ratio.width.native
			}
			
			if size.width.fraction == 0 && size.height.fraction == 0 {
				if size.width.constant <= 0 && size.height.constant > 0 && ratio.height > 0 {
					size.width.constant = size.height.constant * ratio.width.native / ratio.height.native
				}
				
				if size.height.constant <= 0 && size.width.constant > 0 && ratio.width > 0 {
					size.height.constant = size.width.constant * ratio.height.native / ratio.width.native
				}
			}
			
			if size.width.maximum >= Limit.unlimited && size.height.maximum < Limit.unlimited && ratio.height > 0 {
				size.width.maximum = size.height.maximum * ratio.width.native / ratio.height.native
			}
			
			if size.height.maximum >= Limit.unlimited && size.width.maximum < Limit.unlimited && ratio.width > 0 {
				size.height.maximum = size.width.maximum * ratio.height.native / ratio.width.native
			}
			
			return size
		}
		
		/// Increase a box to the minimum dimensions according to compression resistance.
		///
		/// When space constraints compress a frame to below the minimum requested size, this method may increase the frame to the minimum size.
		func decompress(_ box:CGRect, compressionResistance:CGPoint, anchor:CGPoint = CGPoint(x:0.5, y:0.5)) -> CGRect {
			var box = box
			
			if box.size.width.native < width.minimum && compressionResistance.x > 0.25 {
				box.origin.x -= CGFloat(width.minimum - box.size.width.native) * anchor.x
				box.size.width.native = width.minimum
			}
			
			if box.size.height.native < height.minimum && compressionResistance.y > 0.25 {
				box.origin.y -= CGFloat(height.minimum - box.size.height.native) * anchor.y
				box.size.height.native = height.minimum
			}
			
			return box
		}
		
		mutating func minimize(minimum:CGSize, maximum:CGSize) {
			width.minimize(minimum.width.native ... maximum.width.native)
			height.minimize(minimum.height.native ... maximum.height.native)
		}
	}
	
	/// Set of amounts to inset or pad the edges of a rectangle
	struct EdgeInsets: Equatable, CustomStringConvertible {
		static let zero = EdgeInsets(uniform:0)
		
		var minX, maxX, minY, maxY:Native
		
		/// Sum of horizontal insets
		var horizontal:Native { return minX + maxX }
		/// Sum of vertical insets
		var vertical:Native { return minY + maxY }
		var description:String { return "→\(minX) ↓\(minY) ←\(maxX) ↑\(maxY)" }
		
		init(top:Native = 0, bottom:Native = 0, leading:Native = 0, trailing:Native = 0, environment:Environment) {
			self.minX = environment.isRTL ? trailing : leading; self.maxX = environment.isRTL ? leading : trailing; self.minY = top; self.maxY = bottom
		}
		
		init(minX:Native = 0, maxX:Native = 0, minY:Native = 0, maxY:Native = 0) {
			self.minX = minX; self.maxX = maxX; self.minY = minY; self.maxY = maxY
		}
		
		init(horizontal:Native, vertical:Native) {
			minX = horizontal; maxX = horizontal; minY = vertical; maxY = vertical
		}
		
		init(uniform:Native) {
			minX = uniform; maxX = uniform; minY = uniform; maxY = uniform
		}
		
		func paddingSize(_ size:CGSize) -> CGSize {
			return CGSize(width:size.width + CGFloat(minX + maxX), height:size.height + CGFloat(minY + maxY))
		}
		
		func paddingBox(_ box:CGRect) -> CGRect {
			return CGRect(
				x:box.origin.x - CGFloat(minX),
				y:box.origin.y - CGFloat(minY),
				width:box.size.width + CGFloat(minX + maxX),
				height:box.size.height + CGFloat(minY + maxY)
			)
		}
		
		func reducingSize(_ size:CGSize) -> CGSize {
			return CGSize(width:size.width - CGFloat(minX + maxX), height:size.height - CGFloat(minY + maxY))
		}
		
		func reducingBox(_ box:CGRect) -> CGRect {
			return CGRect(
				x:box.origin.x + CGFloat(minX),
				y:box.origin.y + CGFloat(minY),
				width:box.size.width - CGFloat(minX + maxX),
				height:box.size.height - CGFloat(minY + maxY)
			)
		}
	}
	
	/// Targets that reach the safe bounds will be extended to the outer bounds.
	/// Typically used for backgrounds and full screen media.
	struct IgnoreSafeBounds: PositionableWithTarget {
		var target:Positionable
		var axis:Axis?
		
		init(_ target:Positionable, axis:Axis? = nil) {
			self.target = target
			self.axis = axis
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let epsilon = 0.5 / context.scale
			let minX = axis == .vertical || box.minX - epsilon > context.safeBounds.minX ? 0 : max(box.minX - context.bounds.minX, 0)
			let minY = axis == .horizontal || box.minY - epsilon > context.safeBounds.minY ? 0 : max(box.minY - context.bounds.minY, 0)
			let maxX = axis == .vertical || box.maxX + epsilon < context.safeBounds.maxX ? 0 : max(context.bounds.maxX - box.maxX, 0)
			let maxY = axis == .horizontal || box.maxY + epsilon < context.safeBounds.maxY ? 0 : max(context.bounds.maxY - box.maxY, 0)
			let box = CGRect(x:box.origin.x - minX, y:box.origin.y - minY, width:box.size.width + minX + maxX, height:box.size.height + minY + maxY)
			
			target.applyPositionableFrame(box, context:context)
		}
	}
	
	/// Uses space but has no content.
	struct EmptySpace: Equatable, Positionable {
		var size:CGSize
		
		var frame:CGRect { return .zero }
		var compressionResistance:CGPoint { return .zero }
		
		init(width:Native = 0, height:Native = 0) { self.size = CGSize(width:width, height:height) }
		init(_ size:CGSize) { self.size = size }
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			return Layout.Size(prefer:size, maximum:size)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {}
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] { return [] }
	}
	
	/// Specify padding around the target.
	/// Positive insets will increase the distance between adjacent targets.
	/// Negative insets may cause adjacent targets to overlap.
	/// Affects both measured size and applied frame.
	struct Padding: PositionableWithTarget {
		var target:Positionable
		var insets:EdgeInsets
		
		var frame:CGRect { return insets.paddingBox(target.frame) }
		
		init(_ target:Positionable, insets:EdgeInsets) {
			self.target = target
			self.insets = insets
		}
		
		init(_ target:Positionable, uniform:Native) {
			self.target = target
			self.insets = EdgeInsets(uniform:uniform)
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			let paddingLimit = Limit(
				width:limit.width?.advanced(by:-insets.horizontal),
				height:limit.height?.advanced(by:-insets.vertical)
			)
			
			var result = target.positionableSize(fitting:paddingLimit, context:context)
			
			result.width.add(value:insets.horizontal)
			result.height.add(value:insets.vertical)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			target.applyPositionableFrame(insets.reducingBox(box), context:context)
		}
	}
	
	/// Replace the normal dimensions of the target when being measured.  Does not affect the assigned frame.
	///
	/// When both the width and height are specified, the target will not be measured during layout.
	/// This can improve performance with complex targets.
	/// When only one dimension is specified, the limits passed to the target during measurement will be adjusted.
	struct Sizing: PositionableWithTarget {
		var target:Positionable
		var width:Dimension?
		var height:Dimension?
		
		init(_ target:Positionable, width:Dimension?, height:Dimension?) {
			self.target = target
			self.width = width
			self.height = height
		}
		
		init(_ target:Positionable, width:Native?, height:Native?) {
			self.init(target, width:Dimension(value:width), height:Dimension(value:height))
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			if let width = width, let height = height {
				return Layout.Size(width:width, height:height)
			}
			
			let limit = Limit(width:width?.limit(fitting:limit.width) ?? limit.width, height:height?.limit(fitting:limit.height) ?? limit.height)
			let size = target.positionableSize(fitting:limit, context:context)
			
			return Layout.Size(width:width ?? size.width, height:height ?? size.height)
		}
	}
	
	struct Limiting: PositionableWithTarget {
		var target:Positionable
		var width:NativeRange
		var height:NativeRange
		
		init(_ target:Positionable, width:NativeRange, height:NativeRange) {
			self.target = target
			self.width = width
			self.height = height
		}
		
		init(_ target:Positionable, minimumWidth:Native = 0, minimumHeight:Native = 0) {
			self.init(target, width:minimumWidth ... Dimension.unbound, height:minimumHeight ... Dimension.unbound)
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			if width.lowerBound == width.upperBound && height.lowerBound == height.upperBound {
				return Layout.Size(width:Dimension(constant:0, range:width), height:Dimension(constant:0, range:height))
			}
			
			let limit = limit.minimize(width:width.upperBound, height:height.upperBound)
			var size = target.positionableSize(fitting:limit, context:context)
			
			size.width.intersect(width)
			size.height.intersect(height)
			
			return size
		}
	}
	
	/// Impose aspect fit on the target.  The assigned frame will be reduced to fit the specified aspect ratio.
	/// The measured size of the target may also be changed.
	struct Aspect: PositionableWithTarget {
		/// The affected target.
		var target:Positionable
		/// The position of the reduced frame within the available frame.  Defaults to centered.
		var position:CGPoint
		/// The aspect ratio.
		var ratio:CGSize
		
		init(_ target:Positionable, ratio:Native, position:Native = 0.5) {
			self.init(target, ratio:CGSize(width:ratio, height:1), position:CGPoint(x:position, y:position))
		}
		
		init(_ target:Positionable, ratio:CGSize, position:CGPoint = CGPoint(x:0.5, y:0.5)) {
			self.target = target
			self.ratio = ratio
			self.position = position
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			let size = target.positionableSize(fitting:limit, context:context)
			
			return size.constrainingWithRatio(ratio)
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
	}
	
	/// Arrange an element within available space
	struct Align: PositionableWithTarget {
		var target:Positionable
		var vertical:Alignment
		var horizontal:Alignment
		
		init(_ target:Positionable, horizontal:Alignment = .center, vertical:Alignment = .center) {
			self.target = target
			self.vertical = vertical
			self.horizontal = horizontal
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let isFilling = vertical.isFill && horizontal.isFill
			let limit = Layout.Limit(width:box.size.width.native, height:box.size.height.native)
			let size = isFilling ? Layout.Size.zero : target.positionableSize(fitting:limit, context:context)
			let frame = Alignment.frame(for:size, box:box, horizontal:horizontal, vertical:vertical, environment:context.environment)
			
			target.applyPositionableFrame(frame, context:context)
		}
		
		func point(environment:Layout.Environment = .current) -> CGPoint {
			return Alignment.point(horizontal:horizontal, vertical:vertical, environment:environment)
		}
	}
	
	struct ThumbTrackHorizontal:PositionableWithTarget {
		var thumb:Positionable
		var trackBelow:Positionable
		var trackAbove:Positionable
		var trackWhole:Positionable
		var thumbPosition:Native
		var trackInset:EdgeInsets
		
		var target:Positionable {
			let position = min(max(0, thumbPosition), 1)
			
			return Overlay(
				horizontal:.fill,
				vertical:.fill,
				primary:3,
				trackWhole.padding(trackInset),
				trackAbove.fraction(width:1 - position, height:1).align(horizontal:.end, vertical:.fill).padding(trackInset),
				trackBelow.fraction(width:position, height:1).align(horizontal:.start, vertical:.fill).padding(trackInset),
				thumb.align(horizontal:.fraction(position), vertical:.center)
			)
		}
	}
	
	/// Arrange a group of elements into the same space with the same alignment.
	///
	/// Use an overlay to
	/// - align a single element within available space
	/// - put a background behind an element
	/// - put an overlay above an element
	/// - have independent layouts share the same space
	struct Overlay: PositionableWithTargets {
		/// The elements to arrange
		var targets:[Positionable]
		/// The vertical alignment.  Defaults to fill.
		var vertical:Alignment
		/// The horizontal alignment.  Defaults to fill.
		var horizontal:Alignment
		/// When specified, the primary element is measured and aligned then the same frame is applied to all elements.
		var primaryIndex:Int
		
		var frame:CGRect {
			guard !targets.indices.contains(primaryIndex) else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return targets.indices.contains(primaryIndex) ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], horizontal:Alignment = .fill, vertical:Alignment = .fill, primary:Int = -1) {
			self.targets = targets
			self.vertical = vertical
			self.horizontal = horizontal
			self.primaryIndex = primary
		}
		
		init(horizontal:Alignment = .fill, vertical:Alignment = .fill, primary:Int = -1, _ targets:Positionable...) {
			self.targets = targets
			self.vertical = vertical
			self.horizontal = horizontal
			self.primaryIndex = primary
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.indices.contains(primaryIndex) else { return targets[primaryIndex].positionableSize(fitting:limit, context:context) }
			
			var result:Layout.Size = .zero
			
			for target in targets {
				let size = target.positionableSize(fitting:limit, context:context)
				
				result.width.increase(size.width)
				result.height.increase(size.height)
			}
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let isFilling = vertical.isFill && horizontal.isFill
			let limit = Layout.Limit(width:box.size.width.native, height:box.size.height.native)
			let zero = Layout.Size.zero
			
			if targets.indices.contains(primaryIndex) {
				let size = isFilling ? zero : targets[primaryIndex].positionableSize(fitting:limit, context:context)
				let frame = Alignment.frame(for:size, box:box, horizontal:horizontal, vertical:vertical, environment:context.environment)
				
				for target in targets {
					target.applyPositionableFrame(frame, context:context)
				}
			} else {
				for target in targets {
					let size = isFilling ? zero : target.positionableSize(fitting:limit, context:context)
					let frame = Alignment.frame(for:size, box:box, horizontal:horizontal, vertical:vertical, environment:context.environment)
					
					target.applyPositionableFrame(frame, context:context)
				}
			}
		}
	}
	
	/// Arrange a group of elements in a vertical stack.
	struct Vertical: PositionableWithTargets {
		/// The elements to arrange.
		var targets:[Positionable]
		/// The horizontal alignment of elements.
		var alignment:Alignment
		/// The vertical position of the elements within the stack.
		var position:Position
		/// Setting a primary element may affect how position is applied.
		/// - For a filling position, the primary element has no effect.
		/// - For a fractional position, the primary element is positioned and other elements follow, not exceeding the limits of the container.
		/// - For the float position, the container is measured and positioned as the primary element, and other elements are positioned outside the container.
		var primaryIndex:Int
		/// The spacing between elements.  Use padding to affect spacing around indiviual elements.
		var spacing:Native
		/// The display order of the elements, with positive being down.
		var direction:Direction
		
		/// When true, the primary element is measured and positioned independent of other elements, then other elements float around the primary element.
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		/// When true, the alignment and position exclude the need to measure elements when applying a frame.
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
		
		init(spacing:Native = 0, alignment:Alignment = .default, position:Position = .default, primary:Int = -1, direction:Direction = .natural, _ targets:Positionable...) {
			self.targets = targets
			self.spacing = spacing
			self.position = position
			self.alignment = alignment
			self.primaryIndex = primary
			self.direction = direction
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting: limit, context:context) }
			
			return Axial.sizeVertical(targets:targets, limit:limit, context:context, spacing:spacing, position:position)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context, axial:inout Axial, sizes:[Size], available:Native, isFloating:Bool) {
			let isPositive = direction.isPositive(axis:.vertical, environment:context.environment)
			let align = alignment.value(axis:.horizontal, environment:context.environment)
			let uniformAlign = position.alignValue(axis:.vertical, environment:context.environment)
			
			let offset = axial.offset(
				isFloating:isFloating,
				position:position,
				axis:.vertical,
				environment:context.environment,
				available:available,
				index:primaryIndex,
				isPositive:isPositive
			)
			
			axial.computeFramesVertical(offset:offset, alignment:align, uniformAlign:uniformAlign, sizes:sizes, bounds:box, isPositive:isPositive)
			axial.applyFrames(targets:targets, sizes:sizes, context:context)
		}
		
		func approximateLimit(_ box:CGRect, isFloating:Bool) -> Limit {
			let approximateHeight = Axial.approximateLimit(box.size.height.native, count:isFloating ? 1 : targets.count)
			let limit = Limit(width:box.size.width.native, height:approximateHeight)
			
			return limit
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let isFloating = self.isFloating
			let available = isFloating ? context.bounds.size.height.native : box.size.height.native
			let sizes = Axial.sizes(targets:targets, fitting:approximateLimit(box, isFloating:isFloating), context:context, isUnused:isUniform)
			var axial = Axial(sizes.map { $0.height }, available:available, spacing:spacing, position:position)
			
			applyPositionableFrame(box, context:context, axial:&axial, sizes:sizes, available:available, isFloating:isFloating)
		}
		
		func availableSizeAxial(_ box:CGRect, context:Context) -> AvailableSizeAxial {
			let isFloating = self.isFloating
			let available = isFloating ? context.bounds.size.height.native : box.size.height.native
			let sizes = Axial.sizes(targets:targets, fitting:approximateLimit(box, isFloating:isFloating), context:context, isUnused:isUniform)
			let axial = Axial(sizes.map { $0.height }, available:available, spacing:spacing, position:position)
			
			return AvailableSizeAxial(available:available, sizes:sizes, axial:axial)
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.vertical, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Arrange a group of elements in a horizontal stack.
	struct Horizontal: PositionableWithTargets {
		/// The elements to arrange.
		var targets:[Positionable]
		/// The vertical alignment of elements.
		var alignment:Alignment
		/// The horizontal position of the elements within the stack.
		var position:Position
		/// When provided and the position is not filling, the position aligns this element and other elements follow.
		var primaryIndex:Int
		/// The spacing between elements.  Use padding to affect spacing around indiviual elements.
		var spacing:Native
		/// The display order of the elements, with positive being right.
		var direction:Direction
		
		/// When true, the primary element is measured and positioned independent of other elements, then other elements float around the primary element.
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		/// When true, the alignment and position exclude the need to measure elements when applying a frame.
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
		
		init(spacing:Native = 0, alignment:Alignment = .default, position:Position = .default, primary:Int = -1, direction:Direction = .natural, _ targets:Positionable...) {
			self.targets = targets
			self.spacing = spacing
			self.position = position
			self.alignment = alignment
			self.primaryIndex = primary
			self.direction = direction
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit, context:context) }
			
			return Axial.sizeHorizontal(targets:targets, limit:limit, context:context, spacing:spacing, position:position)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context, axial:inout Axial, sizes:[Size], available:Native, isFloating:Bool) {
			let isPositive = direction.isPositive(axis:.horizontal, environment:context.environment)
			let align = alignment.value(axis:.vertical, environment:context.environment)
			let uniformAlign = position.alignValue(axis:.horizontal, environment:context.environment)
			
			let offset = axial.offset(
				isFloating:isFloating,
				position:position,
				axis:.horizontal,
				environment:context.environment,
				available:available,
				index:primaryIndex,
				isPositive:isPositive
			)
			
			axial.computeFramesHorizontal(offset:offset, alignment:align, uniformAlign:uniformAlign, sizes:sizes, bounds:box, isPositive:isPositive)
			axial.applyFrames(targets:targets, sizes:sizes, context:context)
		}
		
		func approximateLimit(_ box:CGRect, isFloating:Bool) -> Limit {
			let approximateWidth = Axial.approximateLimit(box.size.width.native, count:isFloating ? 1 : targets.count)
			let limit = Limit(width:approximateWidth, height:box.size.height.native)
			
			return limit
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let isFloating = self.isFloating
			let available = isFloating ? context.bounds.size.width.native : box.size.width.native
			let sizes = Axial.sizes(targets:targets, fitting:approximateLimit(box, isFloating:isFloating), context:context, isUnused:isUniform)
			var axial = Axial(sizes.map { $0.width }, available:available, spacing:spacing, position:position)
			
			applyPositionableFrame(box, context:context, axial:&axial, sizes:sizes, available:available, isFloating:isFloating)
		}
		
		func availableSizeAxial(_ box:CGRect, context:Context) -> AvailableSizeAxial {
			let isFloating = self.isFloating
			let available = isFloating ? context.bounds.size.width.native : box.size.width.native
			let sizes = Axial.sizes(targets:targets, fitting:approximateLimit(box, isFloating:isFloating), context:context, isUnused:isUniform)
			let axial = Axial(sizes.map { $0.width }, available:available, spacing:spacing, position:position)
			
			return AvailableSizeAxial(available:available, sizes:sizes, axial:axial)
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Arrange a group of elements in vertical columns.
	struct Columns: PositionableWithTargets {
		/// The elements to arrange.
		var targets:[Positionable]
		/// The number of columns to create.
		var columnCount:Int
		/// The template for each row.  Targets in the template are ignored.
		var rowTemplate:Horizontal
		/// The vertical position of rows within the stack.
		var position:Position
		/// When specified, affects how position is applied.
		var primaryIndex:Int
		/// The spacing between columns.
		var spacing:Native
		/// When true elements are ordered along columns, filling each column before wrapping to the next.
		/// When false, elements are ordered across columns, filling each row before wrapping to the next.  The default is false.
		var columnMajor:Bool
		/// The display order of rows, with positive being down.
		var direction:Direction
		
		var singleColumn:Vertical {
			return Vertical(targets:targets, spacing:spacing, alignment:rowTemplate.position.alignment, position:position, primary:primaryIndex, direction:direction)
		}
		
		/// When true, the primary element is measured and positioned independent of other elements, then other elements float around the primary element.
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		var isUniform:Bool {
			if case .uniform = position, rowTemplate.isUniform { return true }
			
			return false
		}
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return isFloating ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], columnCount:Int, spacing:Native = 0, template:Horizontal, position:Position = .default, primary:Int = -1, direction:Direction = .natural, major:Bool = false) {
			self.targets = targets
			self.columnCount = columnCount
			self.spacing = spacing
			self.position = position
			self.rowTemplate = template
			self.primaryIndex = primary
			self.columnMajor = major
			self.direction = direction
			
			self.rowTemplate.targets.removeAll()
		}
		
		init(spans:[Positionable], columnCount:Int, spacing:Native = 0, template:Horizontal, position:Position = .default) {
			self.init(targets:Span.resolve(spans, axis:.vertical, axisCount:columnCount), columnCount:columnCount, spacing:spacing, template:template, position:position, primary:-1, direction:.positive, major:false)
		}
		
		init(columnCount:Int, spacing:Native = 0, template:Horizontal, position:Position = .default, primary:Int = -1, direction:Direction = .natural, major:Bool = false, _ targets:Positionable...) {
			self.init(targets:targets, columnCount:columnCount, spacing:spacing, template:template, position:position, primary:primary, direction:direction, major:major)
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard columnCount > 1 else { return singleColumn.positionableSize(fitting:limit, context:context) }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit, context:context) }
			
			return Axial.sizeColumns(
				fitting:limit,
				context:context,
				splittingTargets:targets,
				intoColumns:columnCount,
				columnMajor:columnMajor,
				columnSpacing:spacing,
				rowSpacing:rowTemplate.spacing,
				rowPosition:rowTemplate.position
			)
		}
		
		func approximateLimit(_ box:CGRect, rowCount:Int) -> Limit {
			let approximateHeight = Axial.approximateLimit(box.size.height.native, count:rowCount)
			let limit = Limit(width:box.size.width.native, height:approximateHeight)
			
			return limit
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			guard columnCount > 1 else { return singleColumn.applyPositionableFrame(box, context:context) }
			
			let itemLimit = targets.count - 1
			let rowCount = 1 + itemLimit / columnCount
			var rowHeights = Array(repeating:Dimension.zero, count:rowCount)
			var columnWidths = Array(repeating:Dimension.zero, count:columnCount)
			let sizes = Axial.sizes(targets:targets, fitting:approximateLimit(box, rowCount:rowCount), context:context, isUnused:isUniform)
			
			if columnMajor {
				for index in sizes.indices {
					rowHeights[index % rowCount].increase(sizes[index].height)
					columnWidths[index / rowCount].increase(sizes[index].width)
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
			let axial = Axial(rowHeights, available:available, spacing:spacing, position:position)
			var rowAxial = Axial(columnWidths, available:rowAvailable, spacing:row.spacing, position:row.position)
			let spacing = axial.space
			let primaryRow:Int
			
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
			
			var offset = axial.offset(
				isFloating:isFloating,
				position:position,
				axis:.horizontal,
				environment:context.environment,
				available:available,
				index:primaryRow,
				isPositive:isPositive
			)
			
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
				let y = offset
				var height = axial.spans[rowIndex]
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
				
				if height < 0 {
					height = 0
				} else {
					offset += height + spacing
				}
				
				let rowBox = CGRect(x:box.origin.x, y:box.origin.y + CGFloat(y), width:box.size.width, height:CGFloat(height))
				
				row.applyPositionableFrame(rowBox, context:context, axial:&rowAxial, sizes:rowSizes, available:rowAvailable, isFloating:isFloating)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Arrange a group of elements in horizontal rows.
	struct Rows: PositionableWithTargets {
		/// The elements to arrange.
		var targets:[Positionable]
		/// The number of rows to create.
		var rowCount:Int
		/// The template for each column.  Targets in the template are ignored.
		var columnTemplate:Vertical
		/// The horizontal position of columns within the stack.
		var position:Position
		/// When specified, affects how position is applied.
		var primaryIndex:Int
		/// The spacing between rows.
		var spacing:Native
		/// When true elements are ordered along rows, filling each row before wrapping to the next.
		/// When false, elements are ordered across rows, filling each column before wrapping to the next.  The default is false.
		var rowMajor:Bool
		/// The display order of columns, with positive being right.
		var direction:Direction
		
		var singleRow:Horizontal {
			return Horizontal(targets:targets, spacing:spacing, alignment:columnTemplate.position.alignment, position:position, primary:primaryIndex, direction:direction)
		}
		
		/// When true, the primary element is measured and positioned independent of other elements, then other elements float around the primary element.
		var isFloating:Bool {
			guard case .float = position, targets.indices.contains(primaryIndex) else { return false }
			
			return true
		}
		
		var isUniform:Bool {
			if case .uniform = position, columnTemplate.isUniform { return true }
			
			return false
		}
		
		var frame:CGRect {
			guard !isFloating else { return targets[primaryIndex].frame }
			
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return isFloating ? targets[primaryIndex].compressionResistance : .zero
		}
		
		init(targets:[Positionable], rowCount:Int, spacing:Native = 0, template:Vertical, position:Position = .default, primary:Int = -1, direction:Direction = .natural, major:Bool = false) {
			self.targets = targets
			self.rowCount = rowCount
			self.spacing = spacing
			self.position = position
			self.columnTemplate = template
			self.primaryIndex = primary
			self.rowMajor = major
			self.direction = direction
			
			self.columnTemplate.targets.removeAll()
		}
		
		init(spans:[Positionable], rowCount:Int, spacing:Native = 0, template:Vertical, position:Position = .default) {
			self.init(targets:Span.resolve(spans, axis:.horizontal, axisCount:rowCount), rowCount:rowCount, spacing:spacing, template:template, position:position, primary:-1, direction:.positive, major:false)
		}
		
		init(rowCount:Int, spacing:Native = 0, template:Vertical, position:Position = .default, primary:Int = -1, direction:Direction = .natural, major:Bool = false, _ targets:Positionable...) {
			self.init(targets:targets, rowCount:rowCount, spacing:spacing, template:template, position:position, primary:primary, direction:direction, major:major)
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard rowCount > 1 else { return singleRow.positionableSize(fitting:limit, context:context) }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit, context:context) }
			
			return Axial.sizeRows(
				fitting:limit,
				context:context,
				splittingTargets:targets,
				intoRows:rowCount,
				rowMajor:rowMajor,
				rowSpacing:spacing,
				columnSpacing:columnTemplate.spacing,
				columnPosition:columnTemplate.position
			)
		}
		
		func approximateLimit(_ box:CGRect, columnCount:Int) -> Limit {
			let approximateWidth = Axial.approximateLimit(box.size.width.native, count:columnCount)
			let limit = Limit(width:approximateWidth, height:box.size.height.native)
			
			return limit
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			guard rowCount > 1 else { return singleRow.applyPositionableFrame(box, context:context) }
			
			let itemLimit = targets.count - 1
			let columnCount = 1 + itemLimit / rowCount
			var rowHeights = Array(repeating:Dimension.zero, count:rowCount)
			var columnWidths = Array(repeating:Dimension.zero, count:columnCount)
			let sizes = Axial.sizes(targets:targets, fitting:approximateLimit(box, columnCount:columnCount), context:context, isUnused:isUniform)
			
			if rowMajor {
				for index in sizes.indices {
					rowHeights[index / columnCount].increase(sizes[index].height)
					columnWidths[index % columnCount].increase(sizes[index].width)
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
			let axial = Axial(columnWidths, available:available, spacing:spacing, position:position)
			var columnAxial = Axial(rowHeights, available:columnAvailable, spacing:column.spacing, position:column.position)
			let spacing = axial.space
			let primaryColumn:Int
			
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
			
			var offset = axial.offset(
				isFloating:isFloating,
				position:position,
				axis:.horizontal,
				environment:context.environment,
				available:available,
				index:primaryColumn,
				isPositive:isPositive
			)
			
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
				let x = offset
				var width = axial.spans[columnIndex]
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
				
				if width < 0 {
					width = 0
				} else {
					offset += width + spacing
				}
				
				let columnBox = CGRect(x:box.origin.x + CGFloat(x), y:box.origin.y, width:CGFloat(width), height:box.size.height)
				
				column.applyPositionableFrame(
					columnBox,
					context:context,
					axial:&columnAxial,
					sizes:columnSizes,
					available:columnAvailable,
					isFloating:isFloating
				)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Support various layouts along an axis
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
		/// Ratio of available to reqested space
		let ratio:Native
		/// Computed sizes along axis
		let spans:[Native]
		/// Computed frames
		var frames:[CGRect]
		
		init(uniformCount:Int, available:Native, spacing:Native) {
			let count = Native(uniformCount)
			let spaceCount = count - 1
			let space = spacing * spaceCount
			let maximumSize = (available - space) / count
			let uniformSize = max(1, maximumSize)
			
			self.frames = []
			self.empty = 0
			self.ratio = min(max(0, maximumSize), 1)
			self.space = available < space + count ? max(0, (available - count) / spaceCount) : spacing
			self.spans = Array(repeating:uniformSize, count:uniformCount)
		}
		
		init(_ dimensions:[Dimension], available:Native, spacing:Native, position:Position) {
			let count = dimensions.count
			let fit:Fit
			
			switch position {
			case .uniformWithEnds(let weight) where count > 2:
				var weights = Array(repeating:1.0, count:count)
				weights[0] = weight
				weights[count - 1] = weight
				self.init(weights:weights, available:available, spacing:spacing)
				return
			
			case .uniform, .uniformAlign, .uniformWithEnds:
				self.init(uniformCount:count, available:available, spacing:spacing)
				return
			
			case .stretch: fit = .stretch
			case .distribute: fit = .distribute
			case .fraction, .adaptiveFraction, .float: fit = .position
			}
			
			var minimum = 0.0, maximum = 0.0, prefer = 0.0
			var dimensions = dimensions
			var visibleCount = 0
			
			for index in dimensions.indices {
				let dimension = dimensions[index].resolved(available)
				
				dimensions[index] = dimension
				
				minimum += dimension.minimum
				maximum += dimension.maximum
				prefer += dimension.constant
				
				if dimension.maximum > 0 { visibleCount += 1 }
			}
			
			let aggregate = Dimension(minimum:minimum, prefer:prefer, maximum:maximum)
			
			self.init(dimensions, aggregate:aggregate, visibleCount:visibleCount, available:available, spacing:spacing, fit:fit)
		}
		
		init(_ dimensions:[Dimension], aggregate:Dimension, visibleCount:Int, available:Native, spacing:Native, fit:Fit) {
			self.frames = []
			
			guard visibleCount > 0 else {
				self.empty = available
				self.space = 0
				self.ratio = 1
				self.spans = Array(repeating:-1, count:dimensions.count)
				
				return
			}
			
			let emptyWithNoSpacing = -1.0
			let count = Native(visibleCount)
			let spaceCount = count - 1
			let aggregateSpacing = spacing * spaceCount
			let empty:Native
			let ratio:Native
			let space:Native
			var spans:[Native]
			
			if available < aggregate.minimum + aggregateSpacing {
				if available < aggregate.minimum || fit == .stretch {
					let reduceSpacing = fit == .stretch ? aggregateSpacing : 0
					let reduction = aggregate.minimum - max(0, available - reduceSpacing)
					let denominator = aggregate.minimum
					
					empty = 0
					space = fit == .stretch ? min(spacing, available / spaceCount) : 0
					spans = dimensions.map { $0.minimum - $0.minimum * reduction / denominator }
				} else {
					empty = 0
					space = (available - aggregate.minimum) / spaceCount
					spans = dimensions.map { $0.minimum }
				}
				
				ratio = available / (aggregate.minimum + aggregateSpacing)
			} else if available < aggregate.constant + aggregateSpacing {
				let reduction = aggregate.constant + aggregateSpacing - available
				let denominator = aggregate.constant - aggregate.minimum
				
				ratio = 1
				empty = 0
				space = spacing
				spans = dimensions.map { $0.constant - ($0.constant - $0.minimum) * reduction / denominator }
			} else if available < aggregate.maximum + aggregateSpacing {
				let expansion = available - aggregate.constant - aggregateSpacing
				let denominator = aggregate.maximum - aggregate.constant
				
				ratio = 1
				empty = 0
				space = spacing
				spans = dimensions.map { $0.constant + ($0.maximum - $0.constant) * expansion / denominator }
			} else if fit == .stretch {
				let expansion = available - aggregate.maximum - aggregateSpacing
				let denominator = count
				
				empty = 0
				space = spacing
				ratio = available / (aggregate.maximum + aggregateSpacing)
				spans = dimensions.map { $0.maximum + expansion / denominator }
			} else {
				if fit == .position {
					empty = available - aggregate.maximum - aggregateSpacing
					space = spacing
				} else {
					empty = 0
					space = (available - aggregate.maximum) / spaceCount
				}
				
				ratio = 1
				spans = dimensions.map { $0.maximum }
			}
			
			if visibleCount < dimensions.count {
				for index in dimensions.indices where !(dimensions[index].maximum > 0) {
					spans[index] = emptyWithNoSpacing
				}
			}
			
			self.empty = empty
			self.space = space
			self.ratio = ratio
			self.spans = spans
		}
		
		init(weights:[Native], available:Native, spacing:Native) {
			let sum = weights.reduce(0) { $0 + ($1 > 0 ? $1 : 0) }
			let visibleCount = weights.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
			let count = Native(visibleCount)
			let spaceCount = count - 1
			let space = spacing * spaceCount
			let content = available - space
			let emptyWithNoSpacing = -1.0
			
			self.frames = []
			self.empty = 0
			
			if content > count && sum > 0 {
				self.ratio = 1
				self.space = spacing
				self.spans = weights.map { $0 > 0 ? content * $0 / sum : emptyWithNoSpacing }
			} else {
				self.ratio = count > 0 ? content / count : 0
				self.space = max(0, available - count) / spaceCount
				self.spans = weights.map { $0 > 0 ? 1 : emptyWithNoSpacing }
			}
		}
		
		static func approximateLimit(_ limit:Native, count:Int) -> Native {
			return limit / max(1.0, Native(count).squareRoot())
		}
		
		static func sizes(targets:[Positionable], fitting limit:Layout.Limit, context:Layout.Context, isUnused:Bool) -> [Layout.Size] {
			return isUnused ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit, context:context) }
		}
		
		static func sizeHorizontal(targets:[Positionable], limit:Layout.Limit, context:Layout.Context, spacing:Native, position:Position) -> Layout.Size {
			var limit = limit
			var result:Layout.Size = .zero
			var spaceCount = -1
			
			if let width = limit.width, width < Limit.unlimited {
				limit = Layout.Limit(width:approximateLimit(width, count:targets.count), height:limit.height)
			}
			
			switch position {
			case .uniform, .uniformAlign, .uniformWithEnds:
				for target in targets {
					let size = target.positionableSize(fitting:limit, context:context)
					
					result.height.increase(size.height)
					result.width.increase(size.width)
				}
				
				spaceCount += targets.count
				result.width.multiply(Native(targets.count))
			case .float, .stretch, .distribute, .fraction, .adaptiveFraction:
				for target in targets {
					let size = target.positionableSize(fitting:limit, context:context)
					
					result.width.add(size.width)
					result.height.increase(size.height)
					if size.width.maximum > 0 { spaceCount += 1 }
				}
			}
			
			if spaceCount > 0 {
				result.width.add(value:spacing * Native(spaceCount))
			}
			
			return result
		}
		
		static func sizeVertical(targets:[Positionable], limit:Layout.Limit, context:Layout.Context, spacing:Native, position:Position) -> Layout.Size {
			var limit = limit
			var result:Layout.Size = .zero
			var spaceCount = -1
			
			if let height = limit.height, height < Limit.unlimited {
				limit = Layout.Limit(width:limit.width, height:approximateLimit(height, count:targets.count))
			}
			
			switch position {
			case .uniform, .uniformAlign, .uniformWithEnds:
				for target in targets {
					let size = target.positionableSize(fitting:limit, context:context)
					
					result.height.increase(size.height)
					result.width.increase(size.width)
				}
				
				spaceCount += targets.count
				result.height.multiply(Native(targets.count))
			case .float, .stretch, .distribute, .fraction, .adaptiveFraction:
				for target in targets {
					let size = target.positionableSize(fitting:limit, context:context)
					
					result.height.add(size.height)
					result.width.increase(size.width)
					if size.height.maximum > 0 { spaceCount += 1 }
				}
			}
			
			if spaceCount > 0 {
				result.height.add(value:spacing * Native(spaceCount))
			}
			
			return result
		}
		
		static func sizeRows(
			fitting limit:Layout.Limit,
			context:Layout.Context,
			splittingTargets:[Positionable],
			intoRows rowCount:Int,
			rowMajor:Bool,
			rowSpacing:Native,
			columnSpacing:Native,
			columnPosition:Position
		) -> Layout.Size {
			var result:Layout.Size = .zero
			let itemLimit = splittingTargets.count - 1
			let columnCount = 1 + itemLimit / rowCount
			var spaceCount = -1
			
			for index in 0 ..< columnCount {
				var targets:[Positionable]
				
				if rowMajor {
					targets = []
					
					for row in 0 ..< 1 + (itemLimit - index) / columnCount {
						targets.append(splittingTargets[row * columnCount + index])
					}
				} else {
					targets = Array(splittingTargets.suffix(from:index * rowCount).prefix(rowCount))
				}
				
				let size = sizeVertical(targets:targets, limit:limit, context:context, spacing:columnSpacing, position:columnPosition)
				
				result.width.add(size.width)
				result.height.increase(size.height)
				if size.width.maximum > 0 { spaceCount += 1 }
			}
			
			if spaceCount > 0 {
				result.width.add(value:rowSpacing * Native(spaceCount))
			}
			
			return result
		}
		
		static func sizeColumns(
			fitting limit:Layout.Limit,
			context:Layout.Context,
			splittingTargets:[Positionable],
			intoColumns columnCount:Int,
			columnMajor:Bool,
			columnSpacing:Native,
			rowSpacing:Native,
			rowPosition:Position
		) -> Layout.Size {
			var result:Layout.Size = .zero
			let itemLimit = splittingTargets.count - 1
			let rowCount = 1 + itemLimit / columnCount
			var spaceCount = -1
			
			for index in 0 ..< rowCount {
				var targets:[Positionable]
				
				if columnMajor {
					targets = []
					
					for column in 0 ..< 1 + (itemLimit - index) / rowCount {
						targets.append(splittingTargets[column * rowCount + index])
					}
				} else {
					targets = Array(splittingTargets.suffix(from:index * columnCount).prefix(columnCount))
				}
				
				let size = sizeHorizontal(targets:targets, limit:limit, context:context, spacing:rowSpacing, position:rowPosition)
				
				result.width.increase(size.width)
				result.height.add(size.height)
				if size.height.maximum > 0 { spaceCount += 1 }
			}
			
			if spaceCount > 0 {
				result.height.add(value:columnSpacing * Native(spaceCount))
			}
			
			return result
		}
		
		func sizeBeforeElement(index:Int, isPositive:Bool) -> Native {
			let space = self.space
			
			if isPositive {
				return spans.prefix(index).reduce(0.0) { $1 < 0 ? $0 : $0 + $1 + space }
			} else {
				return spans.suffix(from:index + 1).reduce(0.0) { $1 < 0 ? $0 : $0 + $1 + space }
			}
		}
		
		func offset(fraction:Native, available:Native, index:Int, isPositive:Bool) -> Native {
			guard empty > 0 else { return 0 }
			guard spans.indices.contains(index) else { return fraction * empty }
			
			let size = spans[index]
			let remainder = available - size
			let nominal = remainder * fraction
			
			let beforePrimary = sizeBeforeElement(index:index, isPositive:isPositive)
			let afterPrimary = sizeBeforeElement(index:index, isPositive:!isPositive)
			
			return min(max(beforePrimary, nominal), available - size - afterPrimary) - beforePrimary
		}
		
		func offset(isFloating:Bool, position:Position, axis:Axis, environment:Environment, available:Native, index:Int, isPositive:Bool) -> Native {
			if isFloating {
				return -sizeBeforeElement(index:index, isPositive:isPositive)
			} else if let fraction = position.value(axis:axis, environment:environment) {
				return offset(fraction:fraction, available:available, index:index, isPositive:isPositive)
			} else {
				return 0
			}
		}
		
		mutating func computeFramesHorizontal(offset:Native, alignment:Native?, uniformAlign:Native?, sizes:[Size], bounds:CGRect, isPositive:Bool) {
			let size = bounds.size.height.native
			let end = spans.count - 1
			let spacing = space
			var frames:[CGRect] = []
			var offset = offset
			
			frames.reserveCapacity(end + 1)
			
			for index in spans.indices {
				let index = isPositive ? index : end - index
				let width = spans[index]
				var box = CGRect.zero
				
				box.origin.x.native = offset
				
				if width < 0 {
					box.size.width = 0
				} else {
					box.size.width.native = width
					offset += width + spacing
				}
				
				if let value = alignment {
					let height = min(sizes[index].height.resolve(size, maximize:true), size)
					
					box.size.height.native = height
					box.origin.y.native = (size - height) * value
				} else {
					box.size.height.native = size
					box.origin.y = 0
				}
				
				if let value = uniformAlign {
					let inner = sizes[index].width.resolve(bounds.size.width.native, maximize:true)
					
					if inner < box.size.width.native {
						box.origin.x.native += (width - inner) * value
						box.size.width.native = inner
					}
				}
				
				frames.append(box.offsetBy(dx:bounds.origin.x, dy:bounds.origin.y))
			}
			
			if !isPositive {
				frames.reverse()
			}
			
			self.frames = frames
		}
		
		mutating func computeFramesVertical(offset:Native, alignment:Native?, uniformAlign:Native?, sizes:[Size], bounds:CGRect, isPositive:Bool) {
			let size = bounds.size.width.native
			let end = spans.count - 1
			let spacing = space
			var frames:[CGRect] = []
			var offset = offset
			
			frames.reserveCapacity(end + 1)
			
			for index in spans.indices {
				let index = isPositive ? index : end - index
				let height = spans[index]
				var box = CGRect.zero
				
				box.origin.y.native = offset
				
				if height < 0 {
					box.size.height = 0
				} else {
					box.size.height.native = height
					offset += height + spacing
				}
				
				if let value = alignment {
					let width = min(sizes[index].width.resolve(size, maximize:true), size)
					
					box.size.width.native = width
					box.origin.x.native = (size - width) * value
				} else {
					box.size.width.native = size
					box.origin.x = 0
				}
				
				if let value = uniformAlign {
					let inner = sizes[index].height.resolve(bounds.size.height.native, maximize:true)
					
					if inner < box.size.height.native {
						box.origin.y.native += (height - inner) * value
						box.size.height.native = inner
					}
				}
				
				frames.append(box.offsetBy(dx:bounds.origin.x, dy:bounds.origin.y))
			}
			
			if !isPositive {
				frames.reverse()
			}
			
			self.frames = frames
		}
		
		func applyFrames(targets:[Positionable], sizes:[Size], context:Context) {
			for index in targets.indices {
				let frame = frames[index]
				let target = targets[index]
				let decompressed = sizes[index].decompress(frame, compressionResistance:target.compressionResistance)
				
				target.applyPositionableFrame(decompressed, context:context)
			}
		}
	}
	
	struct AvailableSizeAxial {
		var available:Native
		var sizes:[Size]
		var axial:Axial
	}
	
	/// Arrange a group of elements in a flow that uses available space along an axis then wraps to continue using available space.
	///
	/// The targets will be arranged into a row of columns when vertical or a column of rows when horizontal.
	/// The flow will use available space along the axis and ignore available space in the other direction while separating targets into rows or columns.
	/// The flow is best suited to limited space in the direction of the axis and unlimited space in the other direction.
	/// Each target will be affected by both the row template and column template.
	/// Nesting a Flow in another Flow is not generally supported.
	struct Flow: PositionableWithTargets {
		/// The elements to arrange into a row of columns or a column of rows
		var targets:[Positionable]
		/// When axis is vertical, the row template is used to arrange columns of targets.
		/// When axis is horizontal, targets are grouped into rows using the row template then all the rows are arranged as a single column.
		/// Defaults to leading alignment and position.  Targets in the template are ignored.
		var rowTemplate:Horizontal
		/// When axis is vertical, targets are grouped into columns using the column template then all the columns are arranged as a single row.
		/// When axis is horizontal, the column template is used to arrange rows of targets.
		/// Defaults to leading alignment and position.  Targets in the template are ignored.
		var columnTemplate:Vertical
		/// Controls the order in which targets are added to rows or columns.
		/// Use the direction in the row and column templates to match the environment.
		/// Defaults to positive.
		var direction:Direction
		/// When axis is vertical, each target is added to a vertical column, filling available vertical space before wrapping to the next column, and all the columns are added to a horizontal row for final layout.
		/// When axis is horizontal, each target is added to a horizontal row, filling available horizontal space before wrapping to the next row, and all rows are added to a vertical column for final layout.
		/// Defaults to korizontal.
		var axis:Axis
		
		var frame:CGRect {
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return .zero
		}
		
		init(
			targets:[Positionable],
			rowTemplate:Horizontal = Horizontal(alignment:.leading, position:.leading),
			columnTemplate:Vertical = Vertical(alignment:.leading, position:.leading),
			direction:Direction = .positive,
			axis:Axis = .horizontal)
		{
			self.targets = targets
			self.columnTemplate = columnTemplate
			self.rowTemplate = rowTemplate
			self.direction = direction
			self.axis = axis
		}
		
		init(
			rowTemplate:Horizontal = Horizontal(alignment:.leading, position:.leading),
			columnTemplate:Vertical = Vertical(alignment:.leading, position:.leading),
			direction:Direction = .positive,
			axis:Axis = .horizontal,
			_ targets:Positionable...)
		{
			self.targets = targets
			self.columnTemplate = columnTemplate
			self.rowTemplate = rowTemplate
			self.direction = direction
			self.axis = axis
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			
			var result:Layout.Size = .zero
			
			switch axis {
			case .horizontal:
				if let width = limit.width, width < Limit.unlimited {
					var rowSize:Layout.Size = .zero
					var itemCount = 0
					
					for target in targets {
						let size = target.positionableSize(fitting:limit, context:context)
						var sum = rowSize.width
						
						if size.width.maximum + sum.maximum > width {
							let fit = Limit(width:min(width, size.width.resolve(width)), height:limit.height)
							rowSize.height.increase(target.positionableSize(fitting:fit, context:context).height)
						}
						
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
					
					result = row.positionableSize(fitting:limit, context:context)
				}
			
			case .vertical:
				if let height = limit.height, height < Limit.unlimited {
					var columnSize:Layout.Size = .zero
					var itemCount = 0
					
					for target in targets {
						let size = target.positionableSize(fitting:limit, context:context)
						var sum = columnSize.height
						
						if size.height.maximum + sum.maximum > height {
							let fit = Limit(width:limit.width, height:min(height, size.height.resolve(height)))
							columnSize.width.increase(target.positionableSize(fitting:fit, context:context).width)
						}
						
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
					
					return column.positionableSize(fitting:limit, context:context)
				}
			}
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let isPositive = direction.isPositive(axis:axis, environment:context.environment)
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			var measured:[(target:Positionable, size:Size)] = targets.map { ($0, $0.positionableSize(fitting:limit, context:context)) }
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
					
					horizontal.targets.append(element.target)
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
					
					vertical.targets.append(element.target)
					height.add(value:vertical.spacing)
				}
				
				horizontal.targets.append(vertical)
				horizontal.applyPositionableFrame(box, context:context)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:axis, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	struct Orient: PositionableWithTargets {
		enum Mode {
			/// Measure along axis.
			case axis
			/// Measure each axis and choose least compression if primary axis is compressed.
			case fit
			/// Use opposite axis if ratio is not satisfied by available area.
			case ratio(Native)
			/// Use opposite axis if ratio is not satisfied by available area of container.
			case containerRatio(Native)
		}
		
		/// The elements to arrange into a row or column.
		var targets:[Positionable]
		/// The layout to use for horizontal orientation.
		var rowTemplate:Horizontal
		/// The layout to use for vertical orientation.
		var columnTemplate:Vertical
		/// The preferred layout axis.
		var axis:Axis
		/// When to orient opposite axis.
		var mode:Mode
		
		init(
			targets:[Positionable],
			rowTemplate:Horizontal = Horizontal(alignment:.leading, position:.leading),
			columnTemplate:Vertical = Vertical(alignment:.leading, position:.leading),
			axis:Axis = .horizontal,
			mode:Mode)
		{
			self.targets = targets
			self.columnTemplate = columnTemplate
			self.rowTemplate = rowTemplate
			self.axis = axis
			self.mode = mode
		}
		
		init(
			rowTemplate:Horizontal = Horizontal(alignment:.leading, position:.leading),
			columnTemplate:Vertical = Vertical(alignment:.leading, position:.leading),
			axis:Axis = .horizontal,
			mode:Mode,
			_ targets:Positionable...)
		{
			self.targets = targets
			self.columnTemplate = columnTemplate
			self.rowTemplate = rowTemplate
			self.axis = axis
			self.mode = mode
		}
		
		func axisForSize(_ size:CGSize, containerSize:CGSize) -> Axis {
			let ratio, width, height:Native
			
			switch mode {
			case .axis, .fit: return axis
			case .ratio(let value): ratio = value; width = size.width.native; height = size.height.native
			case .containerRatio(let value): ratio = value; width = containerSize.width.native; height = containerSize.height.native
			}
			
			switch axis {
			case .horizontal: return width < height * ratio ? .vertical : .horizontal
			case .vertical: return height < width * ratio ? .horizontal : .vertical
			}
		}
		
		func template(isHorizontal:Bool) -> Positionable {
			if isHorizontal {
				var template = rowTemplate
				template.targets = targets
				return template
			} else {
				var template = columnTemplate
				template.targets = targets
				return template
			}
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			
			let axisToTryFirst = axisForSize(CGSize(width:limit.width ?? Limit.unlimited, height:limit.height ?? Limit.unlimited), containerSize:context.safeBounds.size)
			let isHorizontal = axisToTryFirst == .horizontal
			
			let size1 = template(isHorizontal:isHorizontal).positionableSize(fitting:limit, context:context)
			guard case .fit = mode else { return size1 }
			guard let maximum1 = isHorizontal ? limit.width : limit.height else { return size1 }
			let require1 = isHorizontal ? size1.width.resolve(maximum1) : size1.height.resolve(maximum1)
			guard require1 > maximum1 else { return size1 }
			
			let size2 = template(isHorizontal:!isHorizontal).positionableSize(fitting:limit, context:context)
			guard let maximum2 = !isHorizontal ? limit.width : limit.height else { return size2 }
			let require2 = !isHorizontal ? size2.width.resolve(maximum2) : size2.height.resolve(maximum2)
			guard require2 > maximum2 else { return size2 }
			
			return maximum2 * require1 > maximum1 * require2 ? size2 : size1
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let axisToTryFirst = axisForSize(box.size, containerSize:context.safeBounds.size)
			
			switch axisToTryFirst {
			case .horizontal:
				var preferTemplate = rowTemplate
				preferTemplate.targets = targets
				var preferMeasured = preferTemplate.availableSizeAxial(box, context:context)
				
				if preferMeasured.axial.ratio < 1 {
					var crossTemplate = columnTemplate
					crossTemplate.targets = targets
					var crossMeasured = crossTemplate.availableSizeAxial(box, context:context)
					
					if crossMeasured.axial.ratio > preferMeasured.axial.ratio {
						crossTemplate.applyPositionableFrame(box, context:context, axial:&crossMeasured.axial, sizes:crossMeasured.sizes, available:crossMeasured.available, isFloating:crossTemplate.isFloating)
						return
					}
				}
				
				preferTemplate.applyPositionableFrame(box, context:context, axial:&preferMeasured.axial, sizes:preferMeasured.sizes, available:preferMeasured.available, isFloating:preferTemplate.isFloating)
			case .vertical:
				var preferTemplate = columnTemplate
				preferTemplate.targets = targets
				var preferMeasured = preferTemplate.availableSizeAxial(box, context:context)
				
				if preferMeasured.axial.ratio < 1 {
					var crossTemplate = rowTemplate
					crossTemplate.targets = targets
					var crossMeasured = crossTemplate.availableSizeAxial(box, context:context)
					
					if crossMeasured.axial.ratio > preferMeasured.axial.ratio {
						crossTemplate.applyPositionableFrame(box, context:context, axial:&crossMeasured.axial, sizes:crossMeasured.sizes, available:crossMeasured.available, isFloating:crossTemplate.isFloating)
						return
					}
				}
				
				preferTemplate.applyPositionableFrame(box, context:context, axial:&preferMeasured.axial, sizes:preferMeasured.sizes, available:preferMeasured.available, isFloating:preferTemplate.isFloating)
			}
		}
	}
	
	struct Circle: PositionableWithTargets {
		var targets:[Positionable]
		var radius:Native
		var scalar:Native
		var turned:Native
		var clockwise:Bool
		
		var frame:CGRect {
			return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
		}
		
		var compressionResistance:CGPoint {
			return .zero
		}
		
		init(targets:[Positionable], scalar:Native = 1, radius:Native = 0, turned:Native = -0.25, clockwise:Bool = true) {
			self.targets = targets
			self.scalar = scalar
			self.radius = radius
			self.turned = turned
			self.clockwise = clockwise
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			let count = targets.count
			
			guard count > 1 else { return targets.first?.positionableSize(fitting:limit, context:context) ?? .zero }
			
			if radius > 0 {
				let dimension = Dimension(value:radius * 2)
				
				return Layout.Size(width:dimension, height:dimension)
			}
			
			var result:Layout.Size = .zero
			let ratio = 1.0 + 1.0 / (scalar * sin(.pi / Native(count)))
			
			for target in targets {
				let size = target.positionableSize(fitting:limit, context:context)
				
				result.width.increase(size.width)
				result.height.increase(size.height)
			}
			
			result.width.multiply(ratio)
			result.height.multiply(ratio)
			
			return result
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			let count = targets.count
			
			guard count > 1 else { targets.first?.applyPositionableFrame(box, context:context); return }
			
			let diameter = box.size.minimum.native
			let fraction = scalar * sin(.pi / Native(count))
			let radius = 0.5 * diameter / (1 + fraction)
			let center = box.center
			let size = CGSize(square:CGFloat(radius * fraction * 2))
			
			for index in 0 ..< count {
				let turn = turned + Native(clockwise ? index : count - index) / Native(count)
				let sc = __sincospi_stret(turn * 2)
				let cx = CGFloat(radius * sc.__cosval)
				let cy = CGFloat(radius * sc.__sinval)
				let frame = CGRect(center:CGPoint(x:center.x + cx, y:center.y + cy), size:size)
				
				targets[index].applyPositionableFrame(frame, context:context)
			}
		}
	}
	
	class Span: PositionableWithTarget {
		struct Maker: PositionableWithTarget {
			let target:Positionable
			let columns:Int
			let rows:Int
			
			init(_ target:Positionable, columns:Int = 1, rows:Int = 1) {
				self.target = target
				self.columns = columns
				self.rows = rows
			}
		}
		
		let target:Positionable
		var scaleWidth:Native
		var scaleHeight:Native
		var positions:Int
		var cacheSize:Layout.Size
		var cacheLimit:Layout.Limit
		var cacheTimestamp:Timestamp
		var applyFrame:CGRect
		var applyCount:Int
		var applyTimestamp:Timestamp
		
		init(_ target:Positionable, positions:Int, scaleWidth:Native = 1, scaleHeight:Native = 1) {
			self.target = target
			self.scaleWidth = 1
			self.scaleHeight = 1
			self.positions = positions
			self.applyFrame = .zero
			self.applyCount = 0
			self.applyTimestamp = 0
			self.cacheSize = .zero
			self.cacheLimit = Limit()
			self.cacheTimestamp = 0
		}
		
		convenience init(_ target:Positionable, columns:Int = 1, rows:Int = 1) {
			self.init(target, positions:columns * rows, scaleWidth:1.0 / Native(columns), scaleHeight:1.0 / Native(rows))
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			if cacheTimestamp != context.timestamp || !cacheLimit.isEqual(to:limit) {
				var size = target.positionableSize(fitting:limit, context:context)
				
				size.width.multiply(scaleWidth)
				size.height.multiply(scaleHeight)
				
				cacheTimestamp = context.timestamp
				cacheLimit = limit
				cacheSize = size
			}
			
			return cacheSize
		}
		
		func applyPositionableFrame(_ frame:CGRect, context:Layout.Context) {
			if applyTimestamp == context.timestamp {
				applyFrame = applyFrame.union(frame)
				applyCount += 1
			} else {
				applyTimestamp = context.timestamp
				applyFrame = frame
				applyCount = 1
			}
			
			if applyCount == positions {
				target.applyPositionableFrame(applyFrame, context:context)
			}
		}
		
		static func resolve(_ targets:[Positionable], axis:Axis, axisCount:Int) -> [Positionable] {
			var result:[Positionable] = []
			var spans:[Int:[Span]] = [:]
			var index:Int = 0
			let count:Int = targets.count
			var position:Int = 0
			
			while index < count || !spans.isEmpty {
				if let spanned = spans[position] {
					spans[position] = nil
					
					if spanned.count == 1 {
						result.append(spanned[0])
					} else {
						result.append(Layout.Overlay(targets:spanned))
					}
				} else if index >= count {
					result.append(Layout.empty)
				} else if let maker = targets[index] as? Span.Maker {
					index += 1
					
					if maker.rows < 1 || maker.columns < 1 {
						continue
					}
					
					let rowStart, rowLimit, columnStart, columnLimit:Int
					
					switch axis {
					case .horizontal:
						rowStart = position % axisCount
						rowLimit = min(rowStart + maker.rows, axisCount)
						columnStart = position / axisCount
						columnLimit = columnStart + maker.columns
					case .vertical:
						rowStart = position / axisCount
						rowLimit = rowStart + maker.rows
						columnStart = position % axisCount
						columnLimit = min(columnStart + maker.columns, axisCount)
					}
					
					let span = Span(maker.target, columns:columnLimit - columnStart, rows:rowLimit - rowStart)
					
					for columnIndex in columnStart ..< columnLimit {
						for rowIndex in rowStart ..< rowLimit {
							let order:Int
							
							switch axis {
							case .horizontal: order = columnIndex * axisCount + rowIndex
							case .vertical: order = rowIndex * axisCount + columnIndex
							}
							
							if spans[order]?.append(span) == nil {
								spans[order] = [span]
							}
						}
					}
					
					spans[position] = nil
					result.append(span)
				} else {
					result.append(targets[index])
					index += 1
				}
				
				position += 1
			}
			
			return result
		}
	}
	
	/// Measure all targets as the largest target, optionally limited to one axis.
	class Largest {
		struct Item: PositionableWithTarget {
			let largest:Largest
			let index:Int
			
			var target: Positionable { return largest.targets[index] }
			
			func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
				return largest.positionableSize(index:index, fitting:limit, context:context)
			}
		}
		
		var targets:[Positionable]
		var axis:Axis?
		var cacheLargest:Size
		var cacheSizes:[Size]
		var previousLimit:Limit
		var previousTimestamp:Timestamp
		
		init(axis:Axis? = nil, _ targets: Positionable...) {
			self.targets = targets
			self.axis = axis
			self.cacheSizes = []
			self.cacheLargest = .zero
			self.previousLimit = Limit()
			self.previousTimestamp = 0
		}
		
		subscript(_ index:Int) -> Positionable {
			return Item(largest:self, index:index)
		}
		
		func append(_ target:Positionable) -> Positionable {
			let index = targets.count
			
			targets.append(target)
			
			return Item(largest:self, index:index)
		}
		
		func positionableSize(index:Int, fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			guard targets.indices.contains(index) else { return .zero }
			
			if !previousLimit.isEqual(to:limit, on:axis) || previousTimestamp != context.timestamp {
				cacheSizes.removeAll()
				previousLimit = limit
				previousTimestamp = context.timestamp
			}
			
			if cacheSizes.count <= index {
				for index in cacheSizes.count ..< targets.count {
					cacheSizes.append(targets[index].positionableSize(fitting: limit, context: context))
				}
				
				var maximum = Size()
				
				for size in cacheSizes {
					maximum.width.increase(size.width)
					maximum.height.increase(size.height)
				}
				
				cacheLargest = maximum
			}
			
			switch axis {
			case .none: return cacheLargest
			case .horizontal: return Size(width:cacheLargest.width, height:cacheSizes[index].height)
			case .vertical: return Size(width:cacheSizes[index].width, height:cacheLargest.height)
			}
		}
	}
	
	static let empty = EmptySpace()
}

//	MARK: -

extension Positionable {
	/// Any edge that reaches safe bounds will extend to bounds.
	/// - Parameters:
	///   - axis: Optionally limit to a single axis.
	/// - Returns: Positionable.
	func ignoringSafeBounds(_ axis:Layout.Axis? = nil) -> Positionable {
		return Layout.IgnoreSafeBounds(self, axis:axis)
	}
	
	/// Add empty space around edges.  Negative values may cause adjacent elements to overlap.
	/// - Parameters:
	///   - uniform: The padding.
	/// - Returns: Positionable.
	func padding(_ insets:Layout.EdgeInsets) -> Positionable {
		return Layout.Padding(self, insets:insets)
	}
	
	/// Add empty space around edges.  Negative values may cause adjacent elements to overlap.
	/// - Parameters:
	///   - uniform: The padding for each edge.
	/// - Returns: Positionable.
	func padding(_ uniform:Layout.Native = 8) -> Positionable {
		return Layout.Padding(self, uniform:uniform)
	}
	
	/// Add empty space around edges.  Negative values may cause adjacent elements to overlap.
	/// - Parameters:
	///   - horizontal: The left and right padding.
	///   - vertical: The left and right padding.
	/// - Returns: Positionable.
	func padding(horizontal:Layout.Native, vertical:Layout.Native) -> Positionable {
		return Layout.Padding(self, insets:Layout.EdgeInsets(horizontal:horizontal, vertical:vertical))
	}
	
	/// Use a fixed width and height.
	/// - Parameters:
	///   - width: The fixed width.  Use nil to measure the width normally.
	///   - height: The fixed height.  Use nil to measure the height normally.
	/// - Returns: Positionable.
	func fixed(width:Layout.Native? = nil, height:Layout.Native? = nil) -> Positionable {
		guard width != nil || height != nil else { return self }
		
		return Layout.Sizing(self, width:width, height:height)
	}
	
	func fraction(width:Layout.Native?, minimumWidth:Layout.Native = 0, maximumWidth:Layout.Native = Layout.Dimension.unbound, height:Layout.Native?, minimumHeight:Layout.Native = 0, maximumHeight:Layout.Native = Layout.Dimension.unbound) -> Positionable {
		return Layout.Sizing(
			self,
			width:width != nil ? Layout.Dimension(constant:0, range:minimumWidth ... maximumWidth, fraction:width ?? 0) : nil,
			height:height != nil ? Layout.Dimension(constant:0, range:minimumHeight ... maximumHeight, fraction:height ?? 0) : nil
		)
	}
	
	func fraction(origin x:Layout.Native, _ y:Layout.Native, size width:Layout.Native, _ height:Layout.Native) -> Positionable {
		return fraction(width:width, height:height).align(horizontal:.fraction(width != 1.0 ? x / (1.0 - width) : 0.0), vertical:.fraction(height != 1.0 ? y / (1.0 - height) : 0.0))
	}
	
	/// Increase the minimum width and height.
	/// - Parameters:
	///   - width: The minimum width.
	///   - height: The minimum height.
	/// - Returns: Positionable.
	func minimum(width:Layout.Native = 0, height:Layout.Native = 0) -> Positionable {
		guard width > 0 || height > 0 else { return self }
		
		return Layout.Limiting(self, minimumWidth:width, minimumHeight:height)
	}
	
	/// Increase the minimum width and height, and decrease the maximum width and height.
	/// - Parameters:
	///   - width: The minimum and maximum width.
	///   - height: The minimum and maximum height.
	/// - Returns: Positionable.
	func limiting(width:Layout.NativeRange = Layout.Dimension.unlimited, height:Layout.NativeRange = Layout.Dimension.unlimited) -> Positionable {
		return Layout.Limiting(self, width:width, height:height)
	}
	
	/// Span rows and columns in a `Layout.Rows` or `Layout.Columns` initialized with `init(spans:[...])`.
	/// Mutating a `Layout.Rows` or `Layout.Columns` with spans is undefined.
	/// - Parameters:
	///   - columns: Columns to span.
	///   - rows: Rows to span.
	/// - Returns: Positionable
	func span(columns:Int = 1, rows:Int = 1) -> Positionable {
		guard columns > 1 || rows > 1 else { return self }
		
		return Layout.Span.Maker(self, columns:columns, rows:rows)
	}
	
	/// Set the minimum and maximum to unbounded.
	/// - Returns: Positionable.
	func useAvailableSpace() -> Positionable {
		return Layout.Sizing(self, width:Layout.Dimension(minimum:0), height:Layout.Dimension(minimum:0))
	}
	
	/// Align the element within available bounds instead of filling available space.
	/// - Parameters:
	///   - horizontal: The horizontal alignment.  Default is center.
	///   - vertical: The vertical alignment.  Default is center.
	/// - Returns: Positionable.
	func align(horizontal:Layout.Alignment = .center, vertical:Layout.Alignment = .center) -> Positionable {
		guard !horizontal.isFill || !vertical.isFill else { return self }
		
		return Layout.Align(self, horizontal:horizontal, vertical:vertical)
	}
	
	/// Preserve the given aspect ratio when positioning element within available bounds.
	/// - Parameters:
	///   - ratio: The aspect ratio width/height.  Values greater than 1 are wide.  Values less than 1 are tall.
	///   - position: The position of the element within available bounds.  Defaults to center.
	/// - Returns: Positionable.
	func aspect(ratio:Layout.Native, position:Layout.Native = 0.5) -> Positionable {
		return Layout.Aspect(self, ratio:ratio, position:position)
	}
}

//	MARK: -

extension PositionableWithTarget {
	var positionables:[Positionable] { return [target] }
	var frame:CGRect { return target.frame }
	var compressionResistance:CGPoint { return target.compressionResistance }
	
	func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
		return target.positionableSize(fitting:limit, context:context)
	}
	
	func applyPositionableFrame(_ box:CGRect, context:Layout.Context) {
		target.applyPositionableFrame(box, context:context)
	}
	
	func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
		return target.orderablePositionables(environment:environment, order:order)
	}
}

//	MARK: -

extension PositionableWithTargets {
	var positionables:[Positionable] { return targets }
	var frame:CGRect { return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) } }
	var compressionResistance:CGPoint { return .zero }
	
	func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
		return targets.flatMap { $0.orderablePositionables(environment:environment, order:order) }
	}
}

//	MARK: -

extension PlatformView: Positionable {
	var compressionResistance:CGPoint {
		get {
			let maximum = PlatformPriority.required.rawValue
			
			return CGPoint(
				x:CGFloat(contentCompressionResistancePriority(for:.horizontal).rawValue / maximum),
				y:CGFloat(contentCompressionResistancePriority(for:.vertical).rawValue / maximum)
			)
		}
		set {
			let maximum = PlatformPriority.required.rawValue
			
			setContentCompressionResistancePriority(PlatformPriority(max(Float(min(1, newValue.x)) * maximum, 1)), for:.horizontal)
			setContentCompressionResistancePriority(PlatformPriority(max(Float(min(1, newValue.y)) * maximum, 1)), for:.vertical)
		}
	}
	
	@objc
	func positionableSizeFitting(_ size:CGSize, context:Data) -> Data {
		let intrinsicSize = intrinsicContentSize
		
		return Layout.Size(intrinsic:intrinsicSize).data
	}
	
	func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
		return Layout.Size(data:positionableSizeFitting(limit.size, context:context.data)) ?? .zero
	}
	
	@objc
	func applyPositionableFrame(_ box:CGRect) {
#if os(macOS)
		let apply = frame(forAlignmentRect:box)
		let current = frame
		
		if apply.size != current.size {
			frame = apply
		} else if apply.origin != current.origin {
			setFrameOrigin(apply.origin)
		}
#else
		if box.size != bounds.size {
			frame = box
		} else if box.center != center {
			center = box.center
		}
#endif
	}
	
	func applyPositionableFrame(_ box:CGRect, context:Layout.Context) {
		let frame = context.viewFrame(box)
		
		applyPositionableFrame(frame)
	}
	
	func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
		return [self]
	}
}

//	MARK: -

#if os(macOS)
extension PlatformWindow {
	var positionableContext:Layout.Context {
		let isDownPositive = false
		let isRTL = PlatformApplication.shared.userInterfaceLayoutDirection == .rightToLeft
		let scale = convertToBacking(CGRect(x:0, y:0, width:1, height:1)).size.minimum
		let bounds = CGRect(origin:.zero, size:screen?.frame.size ?? frame.size)
		let safeBounds = CGRect(origin:.zero, size:contentRect(forFrameRect:screen?.visibleFrame ?? frame).size)
		let environment = Layout.Environment(isRTL:isRTL)
		
		return Layout.Context(bounds:bounds, safeBounds:safeBounds, isDownPositive:isDownPositive, scale:scale, environment:environment)
	}
}
#endif

//	MARK: -

extension PlatformView: PositionableContainer {
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
		
		return Layout.Context(
			bounds:stableBounds,
			safeBounds:safeBounds,
			isDownPositive:isDownPositive,
			scale:positionableScale,
			environment:positionableEnvironment
		)
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
	
	static func orderPositionables(_ unorderable:[Positionable], environment:Layout.Environment, options:Layout.OrderOptions = .order, hierarchyRoot:PlatformView? = nil) {
		let views = unorderable.map { $0.orderablePositionables(environment:environment, order:.create).compactMap { $0 as? PlatformView } }
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
		let views = unorderable.flatMap { $0.orderablePositionables(environment:environment, order:.create).compactMap { $0 as? PlatformView } }
		var siblings:[PlatformView] = []
		var added:Set<PlatformView> = []
		let isAdding = options.contains(.add)
		let current = subviews
		let index:Int
		
		for view in views {
			if let owner = view.superview {
				guard owner === self else { continue }
			} else {
				guard isAdding else { continue }
			}
			
			if added.insert(view).inserted {
				siblings.append(view)
			}
		}
		
		if options.contains(.remove) {
			for view in current where !added.contains(view) { view.removeFromSuperview() }
			
			index = subviews.count
		} else {
			index = current.lastIndex { siblings.contains($0) } ?? current.count
		}
		
		insertSubviews(siblings, at:index)
		
		//PlatformView.orderPositionables(unorderable, environment:environment, options:options, hierarchyRoot:self)
	}
}

//	MARK: -

extension PlatformLabel {
	override func positionableSizeFitting(_ size:CGSize, context:Data) -> Data {
		guard let text = text else { return super.positionableSizeFitting(size, context:context) }
		
#if os(macOS)
		let insets = alignmentRectInsets
		let size = CGSize(width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
#endif
		
		let fits = sizeThatFits(size)
		
		return Layout.Size(
			stringSize:fits,
			stringLength:text.count,
			maximumHeight:size.height.native,
			maximumLines:maximumLines
		).data
	}
}
