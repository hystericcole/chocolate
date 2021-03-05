//
//  GeometryExtensions.swift
//  Chocolate
//
//  Created by Eric Cole on 1/26/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics

extension CGPoint {
	public static let unit = CGPoint(x:1, y:1)
	
	public var angle:CGFloat.NativeType { return atan2(y.native, x.native) }
	
	public func dot(_ point:CGPoint) -> CGFloat { return x * point.x + y * point.y }
	public func distance(to point:CGPoint) -> CGFloat { return hypot(x - point.x, y - point.y) }
	public func interpolate(towards point:CGPoint, by:CGFloat) -> CGPoint { return CGPoint(x:x * (1 - by) + point.x * by, y:y * (1 - by) + point.y * by) }
	
	public func rounded(rule:FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGPoint {
		return CGPoint(x:x.rounded(rule), y:y.rounded(rule))
	}
	
	public static prefix func - (rhs:CGPoint) -> CGPoint { return CGPoint(x:-rhs.x, y:-rhs.y) }
	public static func + (lhs:CGPoint, rhs:CGPoint) -> CGPoint { return CGPoint(x:lhs.x + rhs.x, y:lhs.y + rhs.y) }
	public static func - (lhs:CGPoint, rhs:CGPoint) -> CGPoint { return CGPoint(x:lhs.x - rhs.x, y:lhs.y - rhs.y) }
	public static func * (lhs:CGPoint, rhs:CGPoint) -> CGPoint { return CGPoint(x:lhs.x * rhs.x, y:lhs.y * rhs.y) }
	public static func / (lhs:CGPoint, rhs:CGPoint) -> CGPoint { return CGPoint(x:lhs.x / rhs.x, y:lhs.y / rhs.y) }
	
	public static func + (lhs:CGPoint, rhs:CGSize) -> CGPoint { return CGPoint(x:lhs.x + rhs.width, y:lhs.y + rhs.height) }
	public static func - (lhs:CGPoint, rhs:CGSize) -> CGPoint { return CGPoint(x:lhs.x - rhs.width, y:lhs.y - rhs.height) }
	public static func * (lhs:CGPoint, rhs:CGSize) -> CGPoint { return CGPoint(x:lhs.x * rhs.width, y:lhs.y * rhs.height) }
	public static func / (lhs:CGPoint, rhs:CGSize) -> CGPoint { return CGPoint(x:lhs.x / rhs.width, y:lhs.y / rhs.height) }
	public static func * (lhs:CGPoint, rhs:CGFloat) -> CGPoint { return CGPoint(x:lhs.x * rhs, y:lhs.y * rhs) }
	public static func * (lhs:CGPoint, rhs:(x:CGFloat, y:CGFloat)) -> CGPoint { return CGPoint(x:lhs.x * rhs.x, y:lhs.y * rhs.y) }
	public static func / (lhs:CGPoint, rhs:CGFloat) -> CGPoint { return CGPoint(x:lhs.x / rhs, y:lhs.y / rhs) }
	
	public static func | (lhs:CGPoint, rhs:CGPoint) -> CGRect { return CGRect(corner:lhs, rhs) }
	public static func | (lhs:CGPoint, rhs:CGSize) -> CGRect { return CGRect(origin:lhs, size:rhs) }
}

extension CGSize {
	public var minimum:CGFloat { return min(width, height) }
	public var maximum:CGFloat { return max(width, height) }
	public var hypotenuse:CGFloat { return hypot(width, height) }
	
	public init(square:CGFloat) { self.init(width:square, height:square) }
	
	public func with(width:CGFloat) -> CGSize {
		return CGSize(width:width, height:height)
	}
	
	public func with(height:CGFloat) -> CGSize {
		return CGSize(width:width, height:height)
	}
	
	public func insetBy(_ amount:CGFloat) -> CGSize {
		return CGSize(width:max(0, width - amount * 2), height:max(0, height - amount * 2))
	}
	
	public func fitting(_ size:CGSize) -> CGSize {
		if width * size.height > size.width * height {
			return CGSize(width:size.width, height:size.height * height / width)
		} else {
			return CGSize(width:size.width * width / height, height:size.height)
		}
	}
	
	public func shrinkingToFit(_ size:CGSize) -> CGSize {
		if width * size.height > size.width * height {
			return width > size.width ? CGSize(width:size.width, height:size.height * height / width) : self
		} else {
			return height > size.height ? CGSize(width:size.width * width / height, height:size.height) : self
		}
	}
	
	public func filling(_ size:CGSize) -> CGSize {
		if width * size.height > size.width * height {
			return CGSize(width:size.width * width / height, height:size.height)
		} else {
			return CGSize(width:size.width, height:size.height * height / width)
		}
	}
	
	public func rounded(rule:FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGSize {
		return CGSize(width:width.rounded(rule), height:height.rounded(rule))
	}
	
	public func display(scale:CGFloat = 1) -> CGSize {
		return CGSize(width:ceil(width * scale) / scale, height:ceil(height * scale) / scale)
	}
	
	public static func + (lhs:CGSize, rhs:CGSize) -> CGSize { return CGSize(width:lhs.width + rhs.width, height:lhs.height + rhs.height) }
	public static func - (lhs:CGSize, rhs:CGSize) -> CGSize { return CGSize(width:lhs.width - rhs.width, height:lhs.height - rhs.height) }
	public static func * (lhs:CGSize, rhs:CGSize) -> CGSize { return CGSize(width:lhs.width * rhs.width, height:lhs.height * rhs.height) }
	public static func / (lhs:CGSize, rhs:CGSize) -> CGSize { return CGSize(width:lhs.width / rhs.width, height:lhs.height / rhs.height) }
	public static func * (lhs:CGSize, rhs:CGFloat) -> CGSize { return CGSize(width:lhs.width * rhs, height:lhs.height * rhs) }
	public static func * (lhs:CGSize, rhs:CGPoint) -> CGSize { return CGSize(width:lhs.width * rhs.x, height:lhs.height * rhs.y) }
	public static func * (lhs:CGSize, rhs:(x:CGFloat, y:CGFloat)) -> CGSize { return CGSize(width:lhs.width * rhs.x, height:lhs.height * rhs.y) }
	public static func / (lhs:CGSize, rhs:CGFloat) -> CGSize { return CGSize(width:lhs.width / rhs, height:lhs.height / rhs) }
}

extension CGRect {
	public var center:CGPoint {
		get { return origin + size * 0.5 }
		set { origin = newValue - size * 0.5 }
	}
	
	public var corner:CGPoint {
		get { return origin + size }
		set { origin = newValue - size }
	}
	
	public init(center:CGPoint, size:CGSize) { self.init(origin:center - size * 0.5, size:size) }
	public init(corner c1:CGPoint, _ c2:CGPoint) { self.init(x:min(c1.x, c2.x), y:min(c1.y, c2.y), width:abs(c1.x - c2.x), height:abs(c1.y - c2.y)) }
	
	public func display(scale:CGFloat = 1) -> CGRect {
		let width = ceil(size.width * scale)
		let height = ceil(size.height * scale)
		let x = round(origin.x * scale + (size.width * scale - width) / 2)
		let y = round(origin.y * scale + (size.height * scale - height) / 2)
		
		return CGRect(x:x / scale, y:y / scale, width:width / scale, height:height / scale)
	}
	
	public func square(size:CGFloat) -> CGRect { return CGRect(center:center, size:CGSize(square:size)) }
	
	public func unit(_ scalar:CGPoint) -> CGPoint { return origin + size * scalar }
	public func unit(x:CGFloat, y:CGFloat) -> CGPoint { return origin + size * (x, y) }
	public func unit(_ c1:CGPoint, _ c2:CGPoint) -> CGRect { return CGRect(corner:unit(c1), unit(c2)) }
	
	public func relative(_ scalar:CGPoint, size:CGSize) -> CGRect { return CGRect(origin:origin + (self.size - size) * scalar, size:size) }
	public func relative(x:CGFloat, y:CGFloat, size:CGSize) -> CGRect { return relative(CGPoint(x:x, y:y), size:size) }
	public func relative(_ scalar:CGPoint, relativeSize:CGSize) -> CGRect { return relative(scalar, size:size * relativeSize) }
	public func relative(x:CGFloat, y:CGFloat, relativeSize:CGSize) -> CGRect { return relative(CGPoint(x:x, y:y), size:size * relativeSize) }
	
	public func polar(turns:Double, radius:Double) -> CGPoint {
		let sc = __sincospi_stret(2 * turns)
		
		return CGPoint(
			x:origin.x + CGFloat(1 + radius * sc.__cosval) * size.width * 0.5,
			y:origin.y + CGFloat(1 + radius * sc.__sinval) * size.height * 0.5
		)
	}
	
	public func cell(column:CGFloat, of columns:CGFloat, row:CGFloat, of rows:CGFloat) -> CGRect {
		return CGRect.init(
			x:origin.x + (columns > 0 ? size.width * column / columns : 0),
			y:origin.y + (rows > 0 ? size.height * row / rows : 0),
			width:(columns > 0 ? size.width / columns : size.width),
			height:(rows > 0 ? size.height / rows : size.height)
		)
	}
	
	public static func + (lhs:CGRect, rhs:CGPoint) -> CGRect { return CGRect(origin:lhs.origin + rhs, size:lhs.size) }
	public static func - (lhs:CGRect, rhs:CGPoint) -> CGRect { return CGRect(origin:lhs.origin - rhs, size:lhs.size) }
	public static func + (lhs:CGRect, rhs:CGSize) -> CGRect { return CGRect(origin:lhs.origin, size:lhs.size + rhs) }
	public static func - (lhs:CGRect, rhs:CGSize) -> CGRect { return CGRect(origin:lhs.origin, size:lhs.size - rhs) }
	public static func * (lhs:CGRect, rhs:CGFloat) -> CGRect { return CGRect(origin:lhs.origin * rhs, size:lhs.size * rhs) }
}
