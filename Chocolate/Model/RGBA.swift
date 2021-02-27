//
//  RGBA.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import CoreGraphics
import Foundation
import simd

public struct DisplayRGB {
	public typealias Scalar = CHCLT.Scalar
	
	public static let black = DisplayRGB(Scalar.vector4(.zero, 1.0))
	public static let white = DisplayRGB(.one)
	
	public let vector:CHCLT.Vector4
	public var clamped:DisplayRGB { return DisplayRGB(simd_min(simd_max(.zero, vector), .one)) }
	public var inverted:DisplayRGB { return DisplayRGB(Scalar.vector4(1 - vector.xyz, vector.w)) }
	
	public var red:Scalar { return vector.x }
	public var green:Scalar { return vector.y }
	public var blue:Scalar { return vector.z }
	public var alpha:Scalar { return vector.w }
	
	public var integer:(red:UInt, green:UInt, blue:UInt, alpha:UInt) {
		var scaled = vector * 255
		
		scaled.round(.toNearestOrAwayFromZero)
		
		let integer = simd_uint(scaled)
		
		return (UInt(integer.x), UInt(integer.y), UInt(integer.z), UInt(integer.w))
	}
	
	public var description:String {
		return String(format:"RGBA(%.3g, %.3g, %.3g, %.3g)", red, green, blue, alpha)
	}
	
	public init(_ rgba:CHCLT.Vector4) {
		vector = rgba
	}
	
	public init(_ red:Scalar, _ green:Scalar, _ blue:Scalar, _ alpha:Scalar = 1) {
		vector = Scalar.vector4(red, green, blue, alpha)
	}
	
	public init(gray:Scalar, _ alpha:Scalar = 1) {
		vector = Scalar.vector4(gray, gray, gray, alpha)
	}
	
	public init(_ chclt:CHCLT, hue:Scalar, chroma:Scalar, luma:Scalar, alpha:Scalar = 1) {
		let linear = CHCLT.LinearRGB.init(chclt, hue:hue, luminance:luma).applyChroma(chclt, value:chroma)
		
		vector = Scalar.vector4(chclt.display(simd_max(linear.vector, simd_double3.zero)), alpha)
	}
	
	public init(hexagonal hue:Scalar, saturation:Scalar, brightness:Scalar, alpha:Scalar = 1) {
		guard brightness > 0 && saturation > 0 else { self.init(gray:brightness, alpha); return }
		
		let hue1 = Scalar.vector3(hue, hue - 1.0/3.0, hue - 2.0/3.0)
		let hue2 = hue1 - hue1.rounded(.down) - 0.5
		let hue3 = simd_abs(hue2) * 6.0 - 1.0
		let hue4 = simd_clamp(hue3, simd_double3.zero, simd_double3.one)
		let c = saturation * brightness
		let m = brightness - c
		
		self.init(Scalar.vector4(hue4 * c + m, alpha))
	}
	
	public func web(allowFormat:Int = 0) -> String {
		let (r, g, b, a) = integer
		let format:String
		let scalar:UInt
		
		let allowCompact = allowFormat & 0x1A != 0
		let allowRegular = allowFormat & 0x144 != 0
		let isCompact = r % 17 == 0 && g % 17 == 0 && b % 17 == 0 && a % 17 == 0
		let isGray = r == g && r == b
		let isOpaque = a == 255
		
		if allowCompact && (isCompact || !allowRegular) {
			let allowOpacity = allowFormat & 0x10 != 0
			let allowGray = allowFormat & 0x02 != 0
			scalar = 17
			
			if allowGray && isGray && (isOpaque || !allowOpacity) {
				format = "#%X"
			} else if isOpaque ? allowFormat & 0x18 == 0x10 : allowOpacity {
				format = "#%X%X%X%X"
			} else {
				format = "#%X%X%X"
			}
		} else {
			let allowOpacity = allowFormat & 0x100 != 0
			let allowGray = allowFormat & 0x04 != 0
			scalar = 1
			
			if allowGray && isGray && (isOpaque || !allowOpacity) {
				format = "#%02X"
			} else if isOpaque ? allowFormat & 0x140 == 0x100 : allowOpacity {
				format = "#%02X%02X%02X%02X"
			} else {
				format = "#%02X%02X%02X"
			}
		}
		
		return String(format:format, r / scalar, g / scalar, b / scalar, a / scalar)
	}
	
	public func css(withAlpha:Int = 0) -> String {
		if withAlpha > 0 || (withAlpha == 0 && alpha < 1) {
			return String(format:"rgba(%.1f, %.1f, %.1f, %.3g)", red * 255, green * 255, blue * 255, alpha).replacingOccurrences(of:".0,", with:",")
		} else {
			return String(format:"rgb(%.1f, %.1f, %.1f)", red * 255, green * 255, blue * 255).replacingOccurrences(of:".0", with:"")
		}
	}
	
	public func pixel() -> UInt32 {
		var v = vector * 255.0
		
		v.round(.toNearestOrAwayFromZero)
		
		let u = simd_uint(v)
		let a = u.w << 24
		let r = u.x << 16
		let g = u.y << 8
		let b = u.z << 0
		
		return r | g | b | a
	}
	
	public func linear(_ chclt:CHCLT) -> CHCLT.LinearRGB {
		return CHCLT.LinearRGB(chclt.linear(vector.xyz))
	}
	
	public func scaled(_ scalar:Scalar) -> DisplayRGB {
		return DisplayRGB(Scalar.vector4(vector.xyz * scalar, vector.w))
	}
	
	public func normalized(_ chclt:CHCLT) -> DisplayRGB {
		return linear(chclt).normalized(chclt).display(chclt, alpha:vector.w)
	}
	
	public func luma(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).luminance(chclt)
	}
	
	public func scaleLuma(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return scaled(scalar > 0 ? chclt.transfer(scalar) : 0)
	}
	
	public func applyLuma(_ chclt:CHCLT, value u:Scalar) -> DisplayRGB {
		//return linear(chclt).applyLuminance(chclt, value:u).display(chclt, alpha:vector.w)
		
		guard u > 0 else { return DisplayRGB(Scalar.vector4(.zero, vector.w)) }
		guard u < 1 else { return DisplayRGB(Scalar.vector4(.one, vector.w)) }
		
		let l = chclt.linear(vector.xyz)
		let v = chclt.luminance(l)
		
		guard v > 0 else { return DisplayRGB(gray:chclt.transfer(u), vector.w) }
		
		let n = CHCLT.LinearRGB.normalize(vector:l, luminance:v, leavePositive:true)
		let rgb = chclt.display(n)
		let s = chclt.transfer(u / v)
		let d = rgb.max()
		
		guard s * d > 1 else { return DisplayRGB(Scalar.vector4(rgb * s, vector.w)) }
		
		let maximumPreservingHue = rgb / d
		let m = chclt.linear(maximumPreservingHue)
		let w = chclt.luminance(m)
		let distanceFromWhite = (1 - u) / (1 - w)
		let interpolated = 1 - distanceFromWhite + distanceFromWhite * m
		
		return DisplayRGB(Scalar.vector4(chclt.display(interpolated), vector.w))
	}
	
	public func contrast(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).contrast(chclt)
	}
	
	public func scaleContrast(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return linear(chclt).scaleContrast(chclt, by:scalar).display(chclt, alpha:vector.w)
	}
	
	public func applyContrast(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).applyContrast(chclt, value:value).display(chclt, alpha:vector.w)
	}
	
	public func contrasting(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).contrasting(chclt, value:value).display(chclt, alpha:vector.w)
	}
	
	public func chroma(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).chroma(chclt)
	}
	
	public func scaleChroma(_ chclt:CHCLT, by scalar:Scalar) -> DisplayRGB {
		return linear(chclt).scaleChroma(chclt, by:scalar).display(chclt, alpha:vector.w)
	}
	
	public func applyChroma(_ chclt:CHCLT, value:Scalar) -> DisplayRGB {
		return linear(chclt).applyChroma(chclt, value:value).display(chclt, alpha:vector.w)
	}
	
	public func vectorHue(_ chclt:CHCLT) -> Scalar {
		return linear(chclt).hue(chclt)
	}
	
	public func hueShifted(_ chclt:CHCLT, by shift:Scalar) -> DisplayRGB {
		return linear(chclt).hueShifted(chclt, by:shift).display(chclt, alpha:vector.w)
	}
	
	public func hsb() -> (hue:Scalar, saturation:Scalar, brightness:Scalar) {
		let domain, maximum, mid_minus_min, max_minus_min:Scalar
		let r = vector.x, g = vector.y, b = vector.z
		
		if r < g {
			if g < b {
				maximum = b
				mid_minus_min = r - g
				max_minus_min = b - r
				domain = 4
			} else {
				maximum = g
				mid_minus_min = b - r
				max_minus_min = g - min(r, b)
				domain = 2
			}
		} else {
			if r < b {
				maximum = b
				mid_minus_min = r - g
				max_minus_min = b - g
				domain = 4
			} else {
				maximum = r
				mid_minus_min = g - b
				max_minus_min = r - min(g, b)
				domain = 0
			}
		}
		
		guard max_minus_min > 0 else { return (1, 0, 0) }
		
		let hue6 = domain + mid_minus_min / max_minus_min
		let hue = hue6 / 6
		
		return (hue < 0 ? 1 + hue : hue, max_minus_min, maximum)
	}
	
	public func hcl(_ chclt:CHCLT) -> (hue:Scalar, chroma:Scalar, luma:Scalar) {
		let l = linear(chclt)
		
		return (l.hue(chclt), l.chroma(chclt), l.luminance(chclt))
	}
}

//	MARK: -

extension DisplayRGB {
	public static var colorSpace = displayColorSpace()
	
	public static func displayColorSpace() -> CGColorSpace {
		if #available(macOS 11.0, iOS 14.0, *), let extended = CGColorSpace(name:CGColorSpace.extendedDisplayP3) { return extended }
		if #available(macOS 10.12, iOS 10.0, *), let extended = CGColorSpace(name:CGColorSpace.extendedSRGB) { return extended }
		if #available(macOS 10.11.2, iOS 9.3, *), let display = CGColorSpace(name:CGColorSpace.displayP3) { return display }
		
		return CGColorSpace(name:CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
	}
	
	public var cg:CGColor? { return color() }
	
	public init?(_ color:CGColor?) {
		guard
			let color = color,
			color.numberOfComponents == 4,
			color.colorSpace?.model ?? .rgb == CGColorSpaceModel.rgb,
			let components = color.components
		else { return nil }
		
		self.init(components[0].native, components[1].native, components[2].native, components[3].native)
	}
	
	public func color(colorSpace:CGColorSpace? = nil) -> CGColor? {
		let space:CGColorSpace
		
		if let colorSpace = colorSpace, colorSpace.model == .rgb {
			space = colorSpace
		} else {
			space = DisplayRGB.colorSpace
		}
		
		var components:[CGFloat] = [CGFloat(vector.x), CGFloat(vector.y), CGFloat(vector.z), CGFloat(vector.w)]
		
		return CGColor(colorSpace:space, components:&components)
	}
}

//	MARK: -

extension CHCLT.LinearRGB {
	public static var colorSpace = linearColorSpace()
	
	public static func linearColorSpace() -> CGColorSpace? {
		if #available(macOS 10.14.3, iOS 12.3, *), let linear = CGColorSpace(name:CGColorSpace.extendedLinearDisplayP3) { return linear }
		if #available(macOS 10.12, iOS 10.0, *), let linear = CGColorSpace(name:CGColorSpace.linearSRGB) { return linear }
		
		return CGColorSpace(name:CGColorSpace.genericRGBLinear)
	}
	
	public init?(_ color:CGColor?) {
		guard
			#available(macOS 10.11, iOS 9.0, *),
			let space = CHCLT.LinearRGB.colorSpace,
			let color = color?.converted(to:space, intent:CGColorRenderingIntent.absoluteColorimetric, options:nil),
			let components = color.components
		else { return nil }
		
		self.init(components[0].native, components[1].native, components[2].native)
	}
	
	public func color(colorSpace:CGColorSpace? = nil, alpha:CGFloat = 1) -> CGColor? {
		let space:CGColorSpace
		
		if let colorSpace = colorSpace, colorSpace.model == .rgb {
			space = colorSpace
		} else if let linear = CHCLT.LinearRGB.colorSpace {
			space = linear
		} else {
			return nil
		}
		
		var components:[CGFloat] = [CGFloat(vector.x), CGFloat(vector.y), CGFloat(vector.z), alpha]
		
		return CGColor(colorSpace:space, components:&components)
	}
	
	static func drawPlaneFromPolarCubeHCL(_ chclt:CHCLT, axis:Int, value:CHCLT.Scalar, pixels:UnsafeMutablePointer<UInt32>, width:Int, height:Int, rowLength:Int) {
		for x in 0 ..< width {
			let a = CHCLT.Scalar(x) / CHCLT.Scalar(width - 1)
			
			for y in 0 ..< height {
				let b = CHCLT.Scalar(y) / CHCLT.Scalar(height - 1)
				let r = min(hypot(b * 2 - 1, a * 2 - 1), 1)
				let t = atan2(b * 2 - 1, a * 2 - 1) / .pi
				let h, c, l:CHCLT.Scalar
				
				switch axis % 6 {
				case 0: h = value; c = 1 - t.magnitude * 2; l = 1 - r
				case 1: h = t * -0.5; c = value; l = 1 - r
				case 2: h = t * -0.5; c = r; l = value
				case 3: h = value; c = copysign(r, -t); l = t.magnitude
				case 4: h = r; c = value; l = t.magnitude
				default: h = r; c = 1 - t.magnitude * 2; l = value
				}
				
				let color = CHCLT.LinearRGB(chclt, hue:h, luminance:l).applyChroma(chclt, value:c, luminance:l)
				
				pixels[y * rowLength + x] = color.pixel()
			}
		}
	}
	
	static func drawPlaneFromCubeHCL(_ chclt:CHCLT, axis:Int, value:CHCLT.Scalar, pixels:UnsafeMutablePointer<UInt32>, width:Int, height:Int, rowLength:Int) {
		let isFlipped = (axis / 3) & 1 != 0
		let count = isFlipped ? height : width
		let hues = axis % 3 == 0 ? [CHCLT.LinearRGB(chclt, hue:value)] : CHCLT.LinearRGB.hueRange(chclt, start:0, shift:1 / CHCLT.Scalar(count), count:count)
		
		for x in 0 ..< width {
			let a = CHCLT.Scalar(x) / CHCLT.Scalar(width - 1)
			
			for y in 0 ..< height {
				let b = CHCLT.Scalar(y) / CHCLT.Scalar(height - 1)
				let h:Int, c, l:CHCLT.Scalar
				
				switch axis % 6 {
				case 0: h = 0; c = 1 - b; l = a
				case 1: h = x; c = value; l = 1 - b
				case 2: h = x; c = 1 - b; l = value
				case 3: h = 0; c = a; l = 1 - b
				case 4: h = y; c = value; l = a
				default: h = y; c = a; l = value
				}
				
				let color = hues[h].applyLuminance(chclt, value:l).applyChroma(chclt, value:c, luminance:l)
				
				pixels[y * rowLength + x] = color.pixel()
			}
		}
	}
	
	static func drawPlaneFromCubeHCL(_ chclt:CHCLT, axis:Int, value:CHCLT.Scalar, image:MutableImage) {
		guard image.image.bitsPerPixel == 32 && image.image.colorSpace?.model == .rgb else { return }
		
		let width = image.image.width
		let height = image.image.height
		let data = image.data as NSMutableData
		let pixels = data.mutableBytes.assumingMemoryBound(to:UInt32.self)
		let rowLength = image.image.bytesPerRow / MemoryLayout<UInt32>.stride
		
		if axis < 0 {
			drawPlaneFromPolarCubeHCL(chclt, axis:-axis, value:value, pixels:pixels, width:width, height:height, rowLength:rowLength)
		} else {
			drawPlaneFromCubeHCL(chclt, axis:axis, value:value, pixels:pixels, width:width, height:height, rowLength:rowLength)
		}
	}
}

//	MARK: -

public struct CHCLTShading {
	public struct ColorLocation {
		public let color:CHCLT.LinearRGB
		public let alpha:CHCLT.Scalar
		public let location:CHCLT.Scalar
		
		func display(_ model:CHCLT) -> DisplayRGB { return color.display(model, alpha:alpha) }
		func vector() -> CHCLT.Scalar.Vector4 { return CHCLT.Scalar.vector4(color.vector, alpha) }
	}

	public let model:CHCLT
	public let colors:[ColorLocation]
	var previousAbove = 0
	
	public init(model:CHCLT, colors:[ColorLocation]) {
		self.model = model
		self.colors = colors
	}
	
	public init(model:CHCLT, colors:[DisplayRGB]) {
		let scalar = CHCLT.Scalar(colors.count - 1)
		
		self.init(model:model, colors:colors.indices.map { ColorLocation(color:colors[$0].linear(model), alpha:colors[$0].vector.w, location:CHCLT.Scalar($0) / scalar) })
	}
	
	public init(model:CHCLT, colors:[DisplayRGB], locations:[CHCLT.Scalar]) {
		let indices = 0 ..< min(colors.count, locations.count)
		
		self.init(model:model, colors:indices.map { ColorLocation(color:colors[$0].linear(model), alpha:colors[$0].vector.w, location:locations[$0]) })
	}
	
	public mutating func interpolate(by scalar:CHCLT.Scalar) -> CHCLT.Scalar.Vector4 {
		let count = colors.count
		
		guard count > 1 else { return colors.first?.vector() ?? .zero }
		
		let above, below:Int
		let location = scalar
		
		if previousAbove > 0 && previousAbove < count && colors[previousAbove].location > location && colors[previousAbove - 1].location < location {
			above = previousAbove
			below = above - 1
		} else {
			above = colors.binarySearch(location) { $0.location < $1 }
			below = above - 1
			
			previousAbove = above
		}
		
		guard above < count else { return colors[below].vector() }
		guard above > 0 else { return colors[0].vector() }
		
		let colorAbove = colors[above]
		let colorBelow = colors[below]
		let fraction = (location - colorBelow.location) / (colorAbove.location - colorBelow.location)
		let alpha = colorBelow.alpha * (1 - fraction) + colorAbove.alpha * fraction
		let color = colorBelow.color.interpolated(towards:colorAbove.color, by:fraction)
		
		return CHCLT.Scalar.vector4(color.vector, alpha)
	}
	
	public func shadingFunction() -> CGFunction? {
		let context = UnsafeMutablePointer<CHCLTShading>.allocate(capacity:1)
		
		context.initialize(to:self)
		
		let evaluate:CGFunctionEvaluateCallback = { pointer, input, output in
			guard let shadingPointer = pointer?.assumingMemoryBound(to:CHCLTShading.self) else { return }
			
			let rgba = shadingPointer.pointee.interpolate(by:CHCLT.Scalar(input.pointee))
			
			output[0] = CGFloat(rgba.x)
			output[1] = CGFloat(rgba.y)
			output[2] = CGFloat(rgba.z)
			output[3] = CGFloat(rgba.w)
		}
		
		let release:CGFunctionReleaseInfoCallback = { pointer in
			guard let context = pointer?.assumingMemoryBound(to:CHCLTShading.self) else { return }
			
			context.deinitialize(count:1)
			context.deallocate()
		}
		
		var callbacks = CGFunctionCallbacks(version:0, evaluate:evaluate, releaseInfo:release)
		
		return CGFunction(info:context, domainDimension:1, domain:nil, rangeDimension:4, range:nil, callbacks:&callbacks)
	}
	
	public func shading(linearColorSpace:CGColorSpace, start:CGPoint, end:CGPoint, extendStart:Bool = true, extendEnd:Bool = true) -> CGShading? {
		guard linearColorSpace.model == .rgb, let function = shadingFunction() else { return nil }
		
		return CGShading(
			axialSpace:linearColorSpace,
			start:start,
			end:end,
			function:function,
			extendStart:extendStart,
			extendEnd:extendEnd
		)
	}
	
	public func shading(linearColorSpace:CGColorSpace, start:CGPoint, startRadius:CGFloat = 0, end:CGPoint, endRadius:CGFloat, extendStart:Bool = true, extendEnd:Bool = true) -> CGShading? {
		guard linearColorSpace.model == .rgb, let function = shadingFunction() else { return nil }
		
		return CGShading(
			radialSpace:linearColorSpace,
			start:start,
			startRadius:startRadius,
			end:end, endRadius:endRadius,
			function:function,
			extendStart:extendStart,
			extendEnd:extendEnd
		)
	}
}
