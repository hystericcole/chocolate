//
//  Layout.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
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
	/// Each dimension of the size specifies a minimum, maximum, fraction of available space, and constant.  The final value, once the available space is known, will be computed as `constant + fraction × available`, clamped between minimum and maximum.  The requested size will be provided when possible.
	/// - Parameter limit: The limit of available space.
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size
	
	/// Apply a frame to the element.
	///	# Layout
	/// During typical layout, a container will get the requested size of each element, fit the sizes within available space, then apply frames to elements.  The applied frames may exceed the minimum or maximum requested size depending on available space and layout options.  When containers are nested, each container will get the size of contained elements twice, once when requesting a size for itself and again when applying a frame to itself.  Deeply nested containers will request the size of elements several times during a single layout, with a more accurate limit at each pass.
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

protocol PositionableWithTarget: Positionable {
	var target:Positionable { get }
}

//	MARK: -

protocol PositionableWithTargets: Positionable {
	var targets:[Positionable] { get }
}

//	MARK: -

struct Layout {
	typealias Native = CGFloat.NativeType
	
	enum Order {
		case existing, create, attach
	}
	
	enum Axis {
		case horizontal, vertical
	}
	
	/// Position of a single element along an axis within a container.
	enum Alignment {
		/// Position each element within available bounds.  A fraction determines the ratio of empty space around the element.
		///
		/// # Example
		/// Align an element with a size of 240 in a container with a limit of 400.  The unused space is 160, and a fraction of that unused space is before the element.  For a fraction of 0.25, that is 0.25 × (400 - 240) = 40 before the element, with 120 after the element.
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
	}
	
	/// Position of a group of elements along an axis within a container.
	enum Position {
		///	Position content within available bounds.
		///
		/// # Example
		/// Position content with a size of 320 in a container with a limit of 400.  The unused space is 80, and a fraction of that unused space is before the content.  For a fraction of 0.25, that is 0.25 × (400 - 320) = 20 before the content, with 60 after the content.
		case fraction(Native)
		/// Position content within available bounds, adapting to the environment.  Equivalent to gravityAreas in a stack view.
		case adaptiveFraction(Native)
		/// Fill available bounds by stretching elements.  Equivalent to fill or fillProportionally in a stack view.
		case stretch
		/// Fill available bounds by making elements a uniform size, ignoring the measured size of the element.  Equivalent to fillEqually in a stackView.
		case uniform
		/// Fill available bounds by aligning each element within a uniform space.  Equivalent to equalCentering in a stack view, when value is 0.5.
		case uniformAlign(Native)
		/// Fill available bounds by stretching space between elements.  Equivalent to equalSpacing in a stack view.
		case distribute
		/// Position the container around the primary element, with other elements hanging outside the container.  Equivalent to constraining one arranged view of a stack view.
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
		
		var fit:Axial.Fit {
			switch self {
			case .stretch: return .stretch
			case .uniform, .uniformAlign: return .uniform
			case .distribute: return .distribute
			default: return .position
			}
		}
		
		var alignment:Alignment {
			switch self {
			case .fraction(let value): return .fraction(value)
			case .adaptiveFraction(let value): return .adaptiveFraction(value)
			case .uniformAlign(let value): return .adaptiveFraction(value)
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
	struct Environment: CustomStringConvertible {
		static var current:Environment { return Environment(isRTL:false) }
		
		/// Is the natural layout direction right to left.
		let isRTL:Bool
		
		var description:String { return isRTL ? "←" : "→" }
		
		func adaptiveFractionValue(_ value:Native, axis:Axis) -> Native { return axis == .horizontal && isRTL ? 1.0 - value : value }
	}
	
	/// Context for a layout pass within a container
	struct Context: CustomStringConvertible {
		/// The bounds of the container
		var bounds:CGRect
		/// The unobstructed bounds of the container
		var safeBounds:CGRect
		/// Is the positive direction of the y axis down
		var isDownPositive:Bool
		/// The number of device pixels per logical pixel
		var scale:CGFloat
		/// The layout environment
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
			
			return Limit(width: width < Limit.unlimited ? width : nil, height: height < Limit.unlimited ? height : nil)
		}
	}
	
	/// The space requested during layout, in one direction.
	///
	/// The final value, once the available space is known, will be computed as constant + fraction × available, clamped between minimum and maximum.
	/// - To require a size, set minimum and maximum equal to that size.  Constant and fraction will be ignored.
	/// - To request a range of sizes, set minimum and maximum, with constant set to the preferred value within that range.
	/// - To request a fraction of available space, set fraction, and optionally minimum and maximum.
	struct Dimension: CustomStringConvertible {
		static let unbound = Limit.unlimited * 0x1p10
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
		
		/// Computes constant + fraction × limit
		/// - Parameters:
		///   - limit: Bounds of container
		///   - maximumWeight: maximum is clamped to multiple of limit
		/// - Returns: Dimension with fraction of limit added to constant
		func resolved(_ limit:Native, maximumWeight:Native = 8) -> Dimension {
			let a = min(max(0, minimum), limit)
			let b = min(max(a, maximum), limit * maximumWeight)
			let c = min(max(a, constant + fraction * limit), b)
			
			return Dimension(constant:c, range:a ... b, fraction:0)
		}
		
		func limit(fitting limit:Native?) -> Native? {
			if let limit = limit, limit < Limit.unlimited {
				let resolved = resolve(limit)
				
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
		
		mutating func minimize(_ range:ClosedRange<Double>) {
			minimum = min(minimum, range.lowerBound)
			maximum = min(maximum, range.upperBound)
		}
		
		mutating func intersect(_ range:ClosedRange<Double>) {
			minimum = max(minimum, range.lowerBound)
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
		
		init?(data:Data) {
			guard let size:Size = data.withUnsafeBytes({ $0.baseAddress?.assumingMemoryBound(to:Self.self).pointee }) else { return nil }
			
			self = size
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
		func resolve(_ size:CGSize) -> CGSize {
			return CGSize(width:width.resolve(size.width.native), height:height.resolve(size.height.native))
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
		/// Given a width of `0 < 100 < ∞` and a height of `20 < 150 < ∞`, a new minimum width will be computed.  The constant values are both bound (`> 0`), and the maximum values are both unbound (`>= unlimited`), so neither will be affected.  If either dimension has a fraction, then neither constant will be affected.
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
	struct EdgeInsets: CustomStringConvertible {
		var minX, maxX, minY, maxY:Native
		
		/// Sum of horizontal insets
		var horizontal:Native { return minX + maxX }
		/// Sum of vertical insets
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
	
	/// Targets that reach the safe bounds will be extended to the outer bounds.  Typically used for backgrounds and full screen media.
	struct IgnoreSafeBounds: PositionableWithTarget {
		var target:Positionable
		
		init(target:Positionable) {
			self.target = target
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
	}
	
	/// Uses space but has no content.
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
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] { return [] }
	}
	
	/// Specify padding around the target.  Positive insets will increase the distance between adjacent targets.  Negative insets may cause adjacent targets to overlap.  Affects both measured size and applied frame.
	struct Padding: PositionableWithTarget {
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
	}
	
	/// Replace the normal dimensions of the target when being measured.  Does not affect the assigned frame.
	///
	/// When both the width and height are specified, the target will not be measured during layout.  This can improve performance with complex targets.  When only one dimension is specified, the limits passed to the target during measurement will be adjusted.
	struct Sizing: PositionableWithTarget {
		var target:Positionable
		var width:Dimension?
		var height:Dimension?
		
		init(target:Positionable, width:Dimension?, height:Dimension?) {
			self.target = target
			self.width = width
			self.height = height
		}
		
		init(target:Positionable, width:Native?, height:Native?) {
			self.init(target:target, width:Dimension(value:width), height:Dimension(value:height))
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			if let width = width, let height = height {
				return Layout.Size(width:width, height:height)
			}
			
			let limit = Limit(width:width?.limit(fitting:limit.width) ?? limit.width, height:height?.limit(fitting:limit.height) ?? limit.height)
			let size = target.positionableSize(fitting:limit)
			
			return Layout.Size(width:width ?? size.width, height:height ?? size.height)
		}
	}
	
	struct Limiting: PositionableWithTarget {
		var target:Positionable
		var width:ClosedRange<Native>
		var height:ClosedRange<Native>
		
		init(target:Positionable, width:ClosedRange<Native>, height:ClosedRange<Native>) {
			self.target = target
			self.width = width
			self.height = height
		}
		
		init(target:Positionable, minimumWidth:Native = 0, minimumHeight:Native = 0) {
			self.init(target:target, width:minimumWidth ... Dimension.unbound, height:minimumHeight ... Dimension.unbound)
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			let limit = limit.minimize(width:width.upperBound, height:height.upperBound)
			var size = target.positionableSize(fitting:limit)
			
			size.width.intersect(width)
			size.height.intersect(height)
			
			return size
		}
	}
	
	/// Record the measured dimensions of the target
	struct Measured: PositionableWithTarget {
		let target:Positionable
		let size:Size
		
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
	}
	
	/// Impose aspect fit on the target.  The assigned frame will be reduced to fit the specified aspect ratio.  The measured size of the target may also be changed.
	struct Aspect: PositionableWithTarget {
		/// The affected target.
		var target:Positionable
		/// The position of the reduced frame within the available frame.  Defaults to centered.
		var position:CGPoint
		/// The aspect ratio.
		var ratio:CGSize
		
		init(target:Positionable, ratio:Native, position:Native = 0.5) {
			self.init(target:target, ratio:CGSize(width:ratio, height:1), position:CGPoint(x:position, y:position))
		}
		
		init(target:Positionable, ratio:CGSize, position:CGPoint = CGPoint(x:0.5, y:0.5)) {
			self.target = target
			self.ratio = ratio
			self.position = position
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			let size = target.positionableSize(fitting:limit)
			
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
	
	/// Arrange a group of elements in a vertical stack.
	struct Vertical: Positionable {
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
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting: limit) }
			
			return Axial.sizeVertical(targets:targets, limit:limit, spacing:spacing, position:position)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context, axial:inout Axial, sizes:[Size], available:Native, isFloating:Bool) {
			let isPositive = direction.isPositive(axis:.vertical, environment:context.environment)
			let align = alignment.value(axis:.horizontal, environment:context.environment)
			let offset = axial.offset(isFloating:isFloating, position:position, axis:.vertical, environment:context.environment, available:available, index:primaryIndex, isPositive:isPositive)
			let uniformAlign = position.alignValue(axis:.vertical, environment:context.environment)
			
			axial.computeFramesVertical(offset:offset, alignment:align, uniformAlign:uniformAlign, sizes:sizes, bounds:box, isPositive:isPositive)
			axial.applyFrames(targets:targets, sizes:sizes, context:context)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let isFloating = self.isFloating
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			let available = isFloating ? context.bounds.size.height.native : box.size.height.native
			let sizes = isUniform ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit) }
			var axial = Axial(sizes.map { $0.height }, available:available, spacing:spacing, fit:position.fit)
			
			applyPositionableFrame(box, context:context, axial:&axial, sizes:sizes, available:available, isFloating:isFloating)
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.vertical, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Arrange a group of elements in a horizontal stack.
	struct Horizontal: Positionable {
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
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit) }
			
			return Axial.sizeHorizontal(targets:targets, limit:limit, spacing:spacing, position:position)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context, axial:inout Axial, sizes:[Size], available:Native, isFloating:Bool) {
			let isPositive = direction.isPositive(axis:.horizontal, environment:context.environment)
			let align = alignment.value(axis:.vertical, environment:context.environment)
			let offset = axial.offset(isFloating:isFloating, position:position, axis:.horizontal, environment:context.environment, available:available, index:primaryIndex, isPositive:isPositive)
			let uniformAlign = position.alignValue(axis:.horizontal, environment:context.environment)
			
			axial.computeFramesHorizontal(offset:offset, alignment:align, uniformAlign:uniformAlign, sizes:sizes, bounds:box, isPositive:isPositive)
			axial.applyFrames(targets:targets, sizes:sizes, context:context)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			
			let isFloating = self.isFloating
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			let available = isFloating ? context.bounds.size.width.native : box.size.width.native
			let sizes = isUniform ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit) }
			var axial = Axial(sizes.map { $0.width }, available:available, spacing:spacing, fit:position.fit)
			
			applyPositionableFrame(box, context:context, axial:&axial, sizes:sizes, available:available, isFloating:isFloating)
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Arrange a group of elements in vertical columns.
	struct Columns: Positionable {
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
		/// When true elements are ordered along columns, filling each column before wrapping to the next.  When false, elements are ordered across columns, filling each row before wrapping to the next.  The default is false.  
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
			
			rowTemplate.targets.removeAll()
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard columnCount > 1 else { return singleColumn.positionableSize(fitting:limit) }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit) }
			
			return Axial.sizeColumns(fitting:limit, splittingTargets:targets, intoColumns:columnCount, columnMajor:columnMajor, columnSpacing:spacing, rowSpacing:rowTemplate.spacing, rowPosition:rowTemplate.position)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			guard columnCount > 1 else { return singleColumn.applyPositionableFrame(box, context:context) }
			
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			let sizes = isUniform ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit) }
			
			let itemLimit = targets.count - 1
			let rowCount = 1 + itemLimit / columnCount
			var rowHeights = Array(repeating:Dimension.zero, count:rowCount)
			var columnWidths = Array(repeating:Dimension.zero, count:columnCount)
			
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
			let axial = Axial(rowHeights, available:available, spacing:spacing, fit:position.fit)
			var rowAxial = Axial(columnWidths, available:rowAvailable, spacing:row.spacing, fit:row.position.fit)
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
			
			var offset = axial.offset(isFloating:isFloating, position:position, axis:.horizontal, environment:context.environment, available:available, index:primaryRow, isPositive:isPositive)
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
	struct Rows: Positionable {
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
		/// When true elements are ordered along rows, filling each row before wrapping to the next.  When false, elements are ordered across rows, filling each column before wrapping to the next.  The default is false.  
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
		}
		
		func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
			guard !targets.isEmpty else { return .zero }
			guard rowCount > 1 else { return singleRow.positionableSize(fitting:limit) }
			guard !isFloating else { return targets[primaryIndex].positionableSize(fitting:limit) }
			
			return Axial.sizeRows(fitting:limit, splittingTargets:targets, intoRows:rowCount, rowMajor:rowMajor, rowSpacing:spacing, columnSpacing:columnTemplate.spacing, columnPosition:columnTemplate.position)
		}
		
		func applyPositionableFrame(_ box:CGRect, context:Context) {
			guard !targets.isEmpty else { return }
			guard rowCount > 1 else { return singleRow.applyPositionableFrame(box, context:context) }
			
			let limit = Limit(width:box.size.width.native, height:box.size.height.native)
			let sizes = isUniform ? Array(repeating:.zero, count:targets.count) : targets.map { $0.positionableSize(fitting:limit) }
			
			let itemLimit = targets.count - 1
			let columnCount = 1 + itemLimit / rowCount
			var rowHeights = Array(repeating:Dimension.zero, count:rowCount)
			var columnWidths = Array(repeating:Dimension.zero, count:columnCount)
			
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
			let axial = Axial(columnWidths, available:available, spacing:spacing, fit:position.fit)
			var columnAxial = Axial(rowHeights, available:columnAvailable, spacing:column.spacing, fit:column.position.fit)
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
			
			var offset = axial.offset(isFloating:isFloating, position:position, axis:.horizontal, environment:context.environment, available:available, index:primaryColumn, isPositive:isPositive)
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
				
				column.applyPositionableFrame(columnBox, context:context, axial:&columnAxial, sizes:columnSizes, available:columnAvailable, isFloating:isFloating)
			}
		}
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:.horizontal, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
		}
	}
	
	/// Arrange a group of elements into the same space with the same alignment.
	struct Overlay: Positionable {
		/// The elements to arrange
		var targets:[Positionable]
		/// The vertical alignment.  Defaults to fill.
		var vertical:Alignment
		/// The horizontal alignment.  Defaults to fill.
		var horizontal:Alignment
		/// When specified, the primary element is measured and aligned with the same frame applied to all elements.
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
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			return targets.flatMap { $0.orderablePositionables(environment:environment, order:order) }
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
		let spans:[Native]
		/// Computed frames
		var frames:[CGRect]
		
		init(_ dimensions:[Dimension], available:Native, spacing:Native, fit:Fit) {
			self.frames = []
			
			if fit == .uniform {
				let count = Native(dimensions.count)
				let spaceCount = count - 1
				let space = spacing * spaceCount
				let uniformSize = max(1, (available - space) / count)
				
				self.empty = 0
				self.space = available < space + count ? max(0, (available - count) / spaceCount) : spacing
				self.spans = Array(repeating:uniformSize, count:dimensions.count)
				
				return
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
			
			guard visibleCount > 0 else {
				self.empty = available
				self.space = 0
				self.spans = Array(repeating:-1, count:dimensions.count)
				
				return
			}
			
			let emptyWithNoSpacing = -1.0
			let count = Native(visibleCount)
			let spaceCount = count - 1
			let aggregateSpacing = spacing * spaceCount
			let empty:Native
			let space:Native
			var spans:[Native]
			
			if available < minimum + aggregateSpacing {
				if available < minimum || fit == .stretch {
					let reduceSpacing = fit == .stretch ? aggregateSpacing : 0
					let reduction = minimum - max(0, available - reduceSpacing)
					let denominator = minimum
					
					empty = 0
					space = fit == .stretch ? min(spacing, available / spaceCount) : 0
					spans = dimensions.map { $0.minimum - $0.minimum * reduction / denominator }
				} else {
					empty = 0
					space = (available - minimum) / spaceCount
					spans = dimensions.map { $0.minimum }
				}
			} else if available < prefer + aggregateSpacing {
				let reduction = prefer + aggregateSpacing - available
				let denominator = prefer - minimum
				
				empty = 0
				space = spacing
				spans = dimensions.map { $0.constant - ($0.constant - $0.minimum) * reduction / denominator }
			} else if available < maximum + aggregateSpacing {
				let expansion = available - prefer - aggregateSpacing
				let denominator = maximum - prefer
				
				empty = 0
				space = spacing
				spans = dimensions.map { $0.constant + ($0.maximum - $0.constant) * expansion / denominator }
			} else if fit == .stretch {
				let expansion = available - maximum - aggregateSpacing
				let denominator = count
				
				empty = 0
				space = spacing
				spans = dimensions.map { $0.maximum + expansion / denominator }
			} else {
				if fit == .position {
					empty = available - maximum - aggregateSpacing
					space = spacing
				} else {
					empty = 0
					space = (available - maximum) / spaceCount
				}
				
				spans = dimensions.map { $0.maximum }
			}
			
			if visibleCount < dimensions.count {
				for index in dimensions.indices where !(dimensions[index].maximum > 0) {
					spans[index] = emptyWithNoSpacing
				}
			}
			
			self.empty = empty
			self.space = space
			self.spans = spans
		}
		
		static func sizeHorizontal(targets:[Positionable], limit:Layout.Limit, spacing:Native, position:Position) -> Layout.Size {
			var result:Layout.Size = .zero
			var spaceCount = -1
			
			switch position {
			case .uniform, .uniformAlign:
				for target in targets {
					let size = target.positionableSize(fitting:limit)
					
					result.height.increase(size.height)
					result.width.increase(size.width)
				}
				
				spaceCount += targets.count
				result.width.multiply(Native(targets.count))
			default:
				for target in targets {
					let size = target.positionableSize(fitting:limit)
					
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
		
		static func sizeVertical(targets:[Positionable], limit:Layout.Limit, spacing:Native, position:Position) -> Layout.Size {
			var result:Layout.Size = .zero
			var spaceCount = -1
			
			switch position {
			case .uniform, .uniformAlign:
				for target in targets {
					let size = target.positionableSize(fitting: limit)
					
					result.height.increase(size.height)
					result.width.increase(size.width)
				}
				
				spaceCount += targets.count
				result.height.multiply(Native(targets.count))
			default:
				for target in targets {
					let size = target.positionableSize(fitting: limit)
					
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
		
		static func sizeRows(fitting limit:Layout.Limit, splittingTargets:[Positionable], intoRows rowCount:Int, rowMajor:Bool, rowSpacing:Native, columnSpacing:Native, columnPosition:Position) -> Layout.Size {
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
				
				let size = sizeVertical(targets:targets, limit:limit, spacing:columnSpacing, position:columnPosition)
				
				result.width.add(size.width)
				result.height.increase(size.height)
				if size.width.maximum > 0 { spaceCount += 1 }
			}
			
			if spaceCount > 0 {
				result.width.add(value:rowSpacing * Native(spaceCount))
			}
			
			return result
		}
		
		static func sizeColumns(fitting limit:Layout.Limit, splittingTargets:[Positionable], intoColumns columnCount:Int, columnMajor:Bool, columnSpacing:Native, rowSpacing:Native, rowPosition:Position) -> Layout.Size {
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
				
				let size = sizeHorizontal(targets:targets, limit:limit, spacing:rowSpacing, position:rowPosition)
				
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
			if isPositive {
				return spans.prefix(index).reduce(0) { $0 + ($1 < 0 ? 0 : $1 + space) }
			} else {
				return spans.suffix(from:index + 1).reduce(0) { $0 + ($1 < 0 ? 0 : $1 + space) }
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
					let height = min(sizes[index].height.resolve(size), size)
					
					box.size.height.native = height
					box.origin.y.native = (size - height) * value
				} else {
					box.size.height.native = size
					box.origin.y = 0
				}
				
				if let value = uniformAlign {
					let inner = sizes[index].width.resolve(bounds.size.width.native)
					
					if inner < box.size.width.native {
						box.origin.x.native += (width - inner) * value
						box.size.width.native = inner
					}
				}
				
				frames.append(box.offsetBy(dx:bounds.origin.x, dy:bounds.origin.y))
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
					let width = min(sizes[index].width.resolve(size), size)
					
					box.size.width.native = width
					box.origin.x.native = (size - width) * value
				} else {
					box.size.width.native = size
					box.origin.x = 0
				}
				
				if let value = uniformAlign {
					let inner = sizes[index].height.resolve(bounds.size.height.native)
					
					if inner < box.size.height.native {
						box.origin.y.native += (height - inner) * value
						box.size.height.native = inner
					}
				}
				
				frames.append(box.offsetBy(dx:bounds.origin.x, dy:bounds.origin.y))
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
	
	/// Arrange a group of elements in a flow that uses available space along an axis then wraps to continue using available space.
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
		
		func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
			let isPositive = direction.isPositive(axis:axis, environment:environment)
			let ordered = isPositive ? targets.reversed() : targets
			
			return ordered.flatMap { $0.orderablePositionables(environment:environment, order:order) }
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
	
	func minimum(width:Layout.Native = 0, height:Layout.Native = 0) -> Positionable {
		return Layout.Limiting(target:self, minimumWidth:width, minimumHeight:height)
	}
	
	func useAvailableSpace() -> Positionable {
		return Layout.Sizing(target:self, width:Layout.Dimension(minimum:0), height:Layout.Dimension(minimum:0))
	}
	
	func align(horizontal:Layout.Alignment = .center, vertical:Layout.Alignment = .center) -> Positionable {
		return Layout.Overlay(targets:[self], horizontal:horizontal, vertical:vertical)
	}
	
	func aspect(ratio:Layout.Native, position:Layout.Native = 0.5) -> Positionable {
		return Layout.Aspect(target:self, ratio:ratio, position:position)
	}
}

//	MARK: -

extension PositionableWithTarget {
	var frame:CGRect { return target.frame }
	var compressionResistance:CGPoint { return target.compressionResistance }
	
	func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
		return target.positionableSize(fitting:limit)
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
	var frame:CGRect { return targets.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) } }
	var compressionResistance:CGPoint { return .zero }
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
		
		return Layout.Context(bounds:stableBounds, safeBounds:safeBounds, isDownPositive:isDownPositive, scale:positionableScale, environment:positionableEnvironment)
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
		PlatformView.orderPositionables(unorderable, environment:environment, options:options, hierarchyRoot:self)
	}
}

//	MARK: -

extension PlatformLabel {
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		guard let text = text else { return super.positionableSizeFitting(size) }
		
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
