//
//  CHCLT.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import Foundation

import CoreGraphics
import Foundation
import simd

public protocol CHCLT {
	func contrastLinearity() -> CHCL.Scalar
	func linear(_ vector:CHCL.Vector3) -> CHCL.Vector3
	func display(_ vector:CHCL.Vector3) -> CHCL.Vector3
	func transfer(_ scalar:CHCL.Linear) -> CHCL.Scalar
	func luminance(_ vector:CHCL.Vector3) -> CHCL.Scalar
	func inverse(_ vector:CHCL.Vector3) -> CHCL.Vector3
}

//	MARK: -

extension CHCLT {
	public func contrastLinearity() -> CHCL.Scalar {
		return 0.3 // 1/8 ... 7/8
	}
	
	public func transferSigned(_ scalar:CHCL.Linear) -> CHCL.Scalar {
		return copysign(transfer(scalar.magnitude), scalar)
	}
	
	public func display(_ vector:CHCL.Vector3) -> CHCL.Vector3 {
		return CHCL.Scalar.vector3(transferSigned(vector.x), transferSigned(vector.y), transferSigned(vector.z))
	}
}

//	MARK: -

public enum CHCL {
	public typealias Scalar = Double
	public typealias Linear = Scalar
	public typealias Vector3 = SIMD3<Scalar>
	public typealias Vector4 = SIMD4<Scalar>
}

//	MARK: -

extension CHCL {
	/// A color in the linear RGB space reached via the CHCLT.
	/// # Range
	/// The range of the color components is 0 ... 1 and colors outside this range can be brought within the range using normalize
	/// # Stability
	/// Shifting the hue will not change the luminance, but it will usually change the chroma.  Changing the chroma will not change the luminance and will not change the hue if chroma is positive.  Changing the luminance will not change the hue unless color information is lost at the extrema, but it may change the saturation.  Changing the contrast is equivalent to changing the luminance.
	public struct LinearRGB {
		public let vector:Vector3
		public var clamped:LinearRGB { return LinearRGB(simd_min(simd_max(.zero, vector), .one)) }
		
		public init(_ rgb:Vector3) {
			vector = rgb
		}
		
		public init(_ red:Linear, _ green:Linear, _ blue:Linear) {
			vector = Linear.vector3(red, green, blue)
		}
		
		public init(gray:Linear) {
			vector = Linear.vector3(gray, gray, gray)
		}
		
		public init(_ chclt:CHCLT, hue:Linear, luminance u:Linear) {
			guard u > 0 else { self.init(.zero); return }
			guard u < 1 else { self.init(.one); return }
			
			self.init(LinearRGB(chclt.inverse(Linear.vector3(u, 0, 0))).hueShifted(chclt, luminance:u, by:hue).vector)
		}
		
		public func display(_ chclt:CHCLT, alpha:Scalar = 1) -> DisplayRGB {
			return DisplayRGB(Scalar.vector4(chclt.display(vector), alpha))
		}
		
		public func scaled(_ scalar:Scalar) -> LinearRGB {
			return LinearRGB(vector * scalar)
		}
		
		public func interpolated(towards:LinearRGB, by scalar:Scalar) -> LinearRGB {
			let t = 1 - scalar
			
			return LinearRGB(vector * t + towards.vector * scalar)
		}
		
		public func interpolated(from:Linear, by scalar:Scalar) -> LinearRGB {
			let t = 1 - scalar
			
			return LinearRGB(vector * scalar + from * t)
		}
		
		public func normalize(luminance v:Linear, leavePositive:Bool) -> LinearRGB {
			var vector = self.vector
			let negative = vector.min()
			
			if negative < 0 {
				let desaturate = v / (v - negative)
				let t = 1 - desaturate
				
				vector = t * v + desaturate * vector
			}
			
			if leavePositive {
				return LinearRGB(simd_max(vector, .zero))
			}
			
			let positive = vector.max()
			
			if positive > 1 {
				let desaturate = (v - 1) / (v - positive)
				let t = 1 - desaturate
				
				vector = t * v + desaturate * vector
			}
			
			vector.clamp(lowerBound:.zero, upperBound:.one)
			
			return LinearRGB(vector)
		}
		
		public func luminance(_ chclt:CHCLT) -> Linear {
			return chclt.luminance(vector)
		}
		
		public func scaleLuminance(by scalar:Scalar) -> LinearRGB {
			return LinearRGB(vector * scalar)
		}
		
		public func applyLuminance(_ chclt:CHCLT, value u:Linear) -> LinearRGB {
			guard u > 0 else { return LinearRGB(.zero) }
			guard u < 1 else { return LinearRGB(.one) }
			
			let v = chclt.luminance(vector)
			
			guard v > 0 else { return LinearRGB(gray:u) }
			
			let n = normalize(luminance:v, leavePositive:true)
			let rgb = chclt.display(n.vector)
			let s = u / v
			let t = chclt.transfer(s)
			let d = rgb.max()
			
			guard t * d > 1 else { return n.scaleLuminance(by:s) }
			
			let maximumPreservingHue = rgb / d
			let m = chclt.linear(maximumPreservingHue)
			let w = chclt.luminance(m)
			let distanceFromWhite = (1 - u) / (1 - w)
			
			return LinearRGB(1 - distanceFromWhite + m * distanceFromWhite)
		}
		
		public func maximumLuminancePreservingRatio(_ chclt:CHCLT) -> Linear {
			let d = vector.max()
			
			return d > 0 ? luminance(chclt) / d : 1
		}
		
		public func isDark(_ chclt:CHCLT) -> Bool {
			return luminance(chclt) < 0.5
		}
		
		public func contrast(_ chclt:CHCLT) -> Linear {
			let d = chclt.contrastLinearity()
			let v = luminance(chclt)
			let k = v > 0.5 ? (1 - v) / (1 - v + d) : v / (v + d)
			let c = k * (1 + 2 * d) - 1
			
			return c.magnitude
		}
		
		public func scaleContrast(_ chclt:CHCLT, by scalar:Linear) -> LinearRGB {
			let d = chclt.contrastLinearity()
			let v = luminance(chclt)
			let k = v > 0.5 ? (1 - v) / (1 - v + d) : v / (v + d)
			let c = k * (1 + 2 * d) - 1
			let s = c * scalar
			let t = s < 0 ? (1 + s) * d / (2 * d - s) : 1 - (1 - s) * d / (2 * d + s)
			let u = v > 0.5 ? 1 - t : t
			
			return applyLuminance(chclt, value:u)
		}
		
		public func contrasting(_ chclt:CHCLT, value:Linear) -> LinearRGB {
			let d = chclt.contrastLinearity()
			let v = luminance(chclt)
			let s = value
			let t = s < 0 ? (1 + s) * d / (2 * d - s) : 1 - (1 - s) * d / (2 * d + s)
			let u = v > 0.5 ? 1 - t : t
			
			return applyLuminance(chclt, value:u)
		}
		
		public func applyContrast(_ chclt:CHCLT, value:Linear) -> LinearRGB {
			return contrasting(chclt, value:-value)
		}
		
		public func maximumChroma(luminance v:Linear) -> Linear {
			guard v > 0 else { return .infinity }
			
			let l = vector
			let w = 1 - v
			let x = v - l.x
			let y = v - l.y
			let z = v - l.z
			let r = x.magnitude > 0x1p-30 ? x < 0 ? w / -x : v / x : .infinity
			let g = y.magnitude > 0x1p-30 ? y < 0 ? w / -y : v / y : .infinity
			let b = z.magnitude > 0x1p-30 ? z < 0 ? w / -z : v / z : .infinity
			
			return min(r, g, b)
		}
		
		public func minimumChroma(luminance v:Linear) -> Linear {
			guard v > 0 else { return .infinity }
			
			let l = vector
			let w = 1 - v
			let x = v - l.x
			let y = v - l.y
			let z = v - l.z
			let r = x.magnitude > 0x1p-30 ? x > 0 ? w / -x : v / x : -.infinity
			let g = y.magnitude > 0x1p-30 ? y > 0 ? w / -y : v / y : -.infinity
			let b = z.magnitude > 0x1p-30 ? z > 0 ? w / -z : v / z : -.infinity
			
			return max(r, g, b)
		}
		
		public func chroma(_ chclt:CHCLT) -> Linear {
			let v = chclt.luminance(vector)
			let m = maximumChroma(luminance:v)
			
			return m.isFinite ? 1 / m : 0
		}
		
		public func scaleChroma(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			return interpolated(from:chclt.luminance(vector), by:scalar)
		}
		
		public func applyChroma(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return applyChroma(chclt, value:value, luminance:luminance(chclt))
		}
		
		public func applyChroma(_ chclt:CHCLT, value:Scalar, luminance v:Linear) -> LinearRGB {
			let m = value < 0 ? minimumChroma(luminance:v) : maximumChroma(luminance:v)
			let s = m.isFinite ? value.magnitude * m : 0
			
			return interpolated(from:v, by:s)
		}
		
		public func hue(_ chclt:CHCLT) -> Linear {
			let v = chclt.luminance(vector)
			
			let hueSaturation = vector - v
			let hueSaturationLengthSquared = simd_length_squared(hueSaturation)
			
			guard hueSaturationLengthSquared > 0.0 else { return 0.0 }
			
			let hueSaturationUnit = hueSaturation / hueSaturationLengthSquared.squareRoot()
			let red = Linear.vector3(1, 0, 0)
			let referenceRed = chclt.inverse(red) - 1
			let referenceUnit = simd_normalize(referenceRed)
			
			let dot = min(max(-1.0, simd_dot(hueSaturationUnit, referenceUnit)), 1.0)
			let turns = acos(dot) * 0.5 / .pi
			
			return vector.y < vector.z ? 1.0 - turns : turns
		}
		
		public func hueShifted(_ chclt:CHCLT, luminance v:Linear, by shift:Linear) -> LinearRGB {
			let hueSaturation = vector - v
			
			guard simd_length_squared(hueSaturation) > 0 else { return self }
			
			let inverse = chclt.inverse(.one)
			let red_cross_green = Linear.vector3(inverse.y, inverse.x, inverse.x * inverse.y - inverse.x - inverse.y)
			let axisUnit = simd_normalize(red_cross_green)
			
			//	use rodrigues rotation to shift hue saturation vector around axis
			let sc = __sincospi_stret(shift * 2)
			let v1 = hueSaturation * sc.__cosval
			let v2 = simd_cross(axisUnit, hueSaturation) * sc.__sinval
			let v3 = axisUnit * simd_dot(axisUnit, hueSaturation) * (1 - sc.__cosval)
			let sum = v1 + v2 + v3
			
			return LinearRGB(sum + v).normalize(luminance:v, leavePositive:false)
		}
		
		public func hueShifted(_ chclt:CHCLT, by shift:Linear) -> LinearRGB {
			return hueShifted(chclt, luminance:luminance(chclt), by:shift)
		}
	}
}



public typealias CHCLTScalar = Double
public typealias CHCLTVector = SIMD3<CHCLTScalar>

/// Cole Color Model : CHCLT : Cole Hue Chroma Luma Transform : Chocolate
/// # Perceptual
/// The transfer and luma functions are chosen to reflect how the human eye percieves light and color.  The Cole color space attempts to preserve the perceptual quality of colors.
/// # Relative
/// Designed to move from one color to another by adjusting the luma, saturation, or hue.  It is not necessary to convert to Cole color and back to get a new RGB color, especially for luma and saturation.
/// # Lightness Preserving
/// Changes to hue and saturation preserve luma.  Changes to luma may change hue and saturation.  Increasing luma will change hue if any individual components are already at the maximum value.  Decreasing luma will generally decrease saturation.  Luma of 0 and 1 discard all hue and saturation information.
/// # Uniform
/// The RGB cube maps to the Cole cube, and the Cole cube maps to the RGB cube.  Any Cole color with components in the 0 ... 1 range will map to a valid RGB color and fill the RGB cube.  The actual shape of the Cole space is a bicone.
/// # Contrast
/// My initial goal was to pick a few colors that would look good as foreground and background colors given an arbitrary starting color that could change based on light and dark modes. Luma is both perceptual and reversible, which allows for a useful definition of contrast.  A color with a high contrast will make a good foreground or background color relative to the starting color.
/// # Complex
/// Compared to the standard HSL and HSV models, the Cole model is more computationally demanding, especially with hue.  The Cole model can work with the faster hexagonal hue model.  The Cole model is well suited to choosing a few colors that look good together.
/// # Relative Saturation
/// For a given hue and luma, there is an arbitrary color with a maximum saturation.  The saturation value is the position between gray and that maximum color.  The saturation is not perceptual in any absolute sense.
/// # Abstract
/// The Cole color space can uniformly distribute colors given any continuous reversible transfer and luma functions.
/// # Normal Colors
/// A normal color is a color with all components in the 0 ... 1 range.  Some display systems support color components outside this range.  Scaling luma, contrast and hue do not limit colors to normal.  Applying a saturation outside the -1 ... 1 range will result in colors outside the normal range.
public protocol CHCLT1 {
	/// Convert RGB component to linear color component.  Inputs may be negative.  Addition must be well defined for linear color components.
	/// # Invert transfer
	/// transfer(linear(rgb)) = rgb
	/// - Parameter value: RGB component
	func linear(_ value:CHCLTScalar) -> CHCLTScalar
	
	/// Convert linear color component to RGB component.  Inputs will not be negative.
	/// # Invert linear
	/// transfer(linear(rgb)) = rgb
	/// - Parameter value: linear color component
	func transfer(_ value:CHCLTScalar) -> CHCLTScalar
	
	/// Compute the luma of a color with three linear components 
	/// - Parameter vector: linear color components
	func linearLuma(_ vector:CHCLTVector) -> CHCLTScalar
	
	/// Compute linear color components that would have the given luma
	/// # Invert linearLuma
	/// linearLuma(inverseLuma(...)) = ∑ ...
	/// - Parameter luma: luma per component
	func inverseLuma(luma:CHCLTVector) -> CHCLTVector
}

//	MARK: -

extension CHCLT1 {
	public typealias Scalar = CHCLTScalar
	public typealias Curved = Scalar
	public typealias Linear = Scalar
	public typealias Vector3 = SIMD3<Scalar>
	public typealias Vector4 = SIMD4<Scalar>
	
	//	MARK: Conversion
	
	/// Convert vector to linear space.  Addition is valid on linear values.
	public func linear(_ vector:Vector4) -> Vector3 {
		return Linear.vector3(linear(vector.x), linear(vector.y), linear(vector.z))
	}
	
	/// Convert vector from linear space.  Addition is not valid on transfer values.
	public func transfer(_ linear:Vector3, alpha:Scalar) -> Vector4 {
		return Curved.vector4(transfer(linear.x), transfer(linear.y), transfer(linear.z), alpha)
	}
	
	/// Convert luma to monochrome color.
	public func transfer(luma:Linear, alpha:Scalar) -> Vector4 {
		let value = transfer(luma)
		
		return Curved.vector4(value, value, value, alpha)
	}
	
	/// Convert signed value from linear space.  Addition is not valid on transfer values.
	public func transferSigned(_ value:Linear) -> Curved {
		return copysign(transfer(value.magnitude), value)
	}
	
	/// Convert signed vector from linear space.  Addition is not valid on transfer values.
	public func transferSigned(_ linear:Vector3, alpha:Scalar) -> Vector4 {
		return Curved.vector4(transferSigned(linear.x), transferSigned(linear.y), transferSigned(linear.z), alpha)
	}
	
	/// Convert gray to monochrome color.
	public func monochrome(gray:Curved, alpha:Scalar) -> Vector4 {
		return Curved.vector4(gray, gray, gray, alpha)
	}
	
	/// Scale color values
	public func scaleColor(_ rgb:Vector4, by scalar:Curved) -> Vector4 {
		return Curved.vector4(scalar * rgb.x, scalar * rgb.y, scalar * rgb.z, rgb.w)
	}
	
	func linearInterpolate(_ a:Linear, _ b:Vector3, by scalar:Linear) -> Vector3 {
		let t = 1 - scalar
		let a = a * t
		let b = b * scalar
		
		return a + b
	}
	
	func linearInterpolate(_ a:Vector3, _ b:Vector3, by scalar:Linear) -> Vector3 {
		let t = 1 - scalar
		let a = a * t
		let b = b * scalar
		
		return a + b
	}
	
	/// Interpolate between colors by converting to linear space.
	public func interpolate(_ rgb0:Vector4, _ rgb1:Vector4, by scalar:Linear) -> Vector4 {
		let t = 1 - scalar
		let alpha = t * rgb0.w + scalar * rgb1.w
		
		return transferSigned(linearInterpolate(linear(rgb0), linear(rgb1), by:scalar), alpha:alpha)
	}
	
	/// Interpolate between multiple colors with relative locations by converting to linear space.
	public func interpolate(colorLocations:[(color:Vector4, location:Scalar)], by scalar:Linear) -> Vector4 {
		guard colorLocations.count > 1 else { return colorLocations.first?.color ?? .zero }
		
		let location = Double(scalar)
		
		let above = colorLocations.binarySearch(location) { $0.location < $1 }
		let below = above - 1
		
		guard above < colorLocations.count else { return colorLocations[below].color }
		guard above > 0 else { return colorLocations[0].color }
		
		let colorAbove = colorLocations[above]
		let colorBelow = colorLocations[below]
		let fraction = colorBelow.location.interpolate(towards:colorAbove.location, by:location)
		
		return interpolate(colorBelow.color, colorAbove.color, by:fraction)
	}
	
	//	MARK: Luma
	
	/// Calculate the perceptual lightness of a color.
	public func luma(_ rgb:Vector4) -> Linear {
		return linearLuma(linear(rgb))
	}
	
	/// Scale the perceptual lightness of a color.  Zero is black.  Scalars above one may denormalize the color.
	public func scaleLuma(_ rgb:Vector4, by scalar:Linear) -> Vector4 {
		return scaleColor(rgb, by:scalar > 0 ? transfer(scalar) : 0)
	}
	
	/// Apply perceptual lightness to a color.  Zero is black and one is white.  Increasing luma may change hue and saturation.  Decreasing luma will decrease saturation.
	public func applyLuma(_ rgb:Vector4, luma u:Linear) -> Vector4 {
		guard u > 0 else { return monochrome(gray:0, alpha:rgb.w) }
		guard u < 1 else { return monochrome(gray:1, alpha:rgb.w) }
		
		let l = linear(rgb)
		let v = linearLuma(l)
		
		guard v > 0 else { return transfer(luma:u, alpha:rgb.w) }
		
		let rgb = transfer(normalizeLinear(l, luma:v, leavePositive:true), alpha:rgb.w)
		let s = transfer(u / v)
		let d = max(rgb.x, rgb.y, rgb.z)
		
		guard s * d > 1 else { return scaleColor(rgb, by:s) }
		
		let maximumPreservingHue = rgb / d
		let m = linear(maximumPreservingHue)
		let w = linearLuma(m)
		let distanceFromWhite = (1 - u) / (1 - w)
		let interpolated = 1 - distanceFromWhite + distanceFromWhite * m
		
		return transfer(interpolated, alpha:rgb.w)
	}
	
	/// Increasing luma above this value will alter hue.
	public func maximumLumaPreservingHue(_ rgb:Vector4) -> Linear {
		let d = max(rgb.x, rgb.y, rgb.z)
		
		return d > 0 ? linear(1 / d) * luma(rgb) : 1
	}
	
	//	MARK: Contrast
	
	public func contrastFactor() -> Linear {
		return 0.3 // 1/8 ... 7/8
	}
	
	/// Is the perceptual lightness of this color below half.
	public func isDark(_ rgb:Vector4) -> Bool {
		return luma(rgb) < 0.5
	}
	
	/// Contrast is a measure of distance from medium luminance.  Darker and Lighter colors have higher contrast.  Medium colors have lower contrast.
	/// - Parameter rgb: The color to measure.
	/// - Returns: The contrast from 0.0, low contrast, to 1.0, high contrast.
	public func contrast(_ rgb:Vector4) -> Linear {
		let d = contrastFactor()
		let v = luma(rgb)
		let k = v > 0.5 ? (1 - v) / (1 - v + d) : v / (v + d)
		let c = k * (1 + 2 * d) - 1
		
		return c.magnitude
	}
	
	/// Scale the contrast of this color.  Magnitudes greater than one move away from medium, and magnitudes less than one move towards medium.  Negative values generate colors that contrast with the given color.
	/// # Scalar
	/// - 0 : low contrast, medium luminance color.
	/// - ½ : color that contrasts half as well.
	/// - 1 : the same color.
	/// - 2 : color that contrasts twice as well.
	/// - Parameters:
	///   - rgb: The color to scale.
	///   - scalar: The contrast scalar.
	/// - Returns: The scaled color.
	public func scaleContrast(_ rgb:Vector4, by scalar:Linear) -> Vector4 {
		let d = contrastFactor()
		let v = luma(rgb)
		let k = v > 0.5 ? (1 - v) / (1 - v + d) : v / (v + d)
		let c = k * (1 + 2 * d) - 1
		let s = c * scalar
		let t = s < 0 ? (1 + s) * d / (2 * d - s) : 1 - (1 - s) * d / (2 * d + s)
		let u = v > 0.5 ? 1 - t : t
		
		return applyLuma(rgb, luma:u)
	}
	
	/// Adjust the luminance of the given color to generate a contrasting color.
	/// # Contrast
	/// - 0 : low contrast, medium luminance color.
	/// - ½ : medium contrast color that contrasts well but retains saturation.
	/// - 1 : black for light colors, white for dark colors.
	/// - Parameters:
	///   - rgb: The color to adjust.
	///   - contrast: The contrast of the color.
	/// - Returns: The contrasting color.
	public func contrasting(_ rgb:Vector4, contrast:Linear) -> Vector4 {
		let d = contrastFactor()
		let v = luma(rgb)
		let t = contrast < 0 ? (1 + contrast) * d / (2 * d - contrast) : 1 - (1 - contrast) * d / (2 * d + contrast)
		let u = v > 0.5 ? 1 - t : t
		
		return applyLuma(rgb, luma:u)
	}
	
	/// Adjust the contrast of this color.  High magnitudes approach black or white, and low magnitudes approach medium colors.
	/// # Contrast
	/// - -1 : black for light colors, white for dark colors.
	/// - -½ : medium contrast color that contrasts against input color.
	/// - 0 : low contrast, medium luminance color.
	/// - ½ : medium contrast color similar to input color.
	/// - 1 : black for dark colors, white for light colors.
	/// - Parameters:
	///   - rgb: The color to adjust.
	///   - contrast: The new contrast to apply to the color.
	/// - Returns: The adjusted color.
	public func applyContrast(_ rgb:Vector4, contrast:Linear) -> Vector4 {
		return contrasting(rgb, contrast:-contrast)
	}
	
	//	MARK: Saturation
	
	/// The least positive saturation scale that does not exceed unit components.
	public func maximumSaturation(_ linear:Vector3, luma v:Linear) -> Linear {
		guard v > 0 else { return .infinity }
		
		let l = linear
		let w = 1 - v
		let x = v - l.x
		let y = v - l.y
		let z = v - l.z
		let r = x.magnitude > 0x1p-30 ? x < 0 ? w / -x : v / x : .infinity
		let g = y.magnitude > 0x1p-30 ? y < 0 ? w / -y : v / y : .infinity
		let b = z.magnitude > 0x1p-30 ? z < 0 ? w / -z : v / z : .infinity
		
		return min(r, g, b)
	}
	
	/// The least negative saturation scale that does not exceed unit components.
	public func minimumSaturation(_ linear:Vector3, luma v:Linear) -> Linear {
		guard v > 0 else { return -.infinity }
		
		let l = linear
		let w = 1 - v
		let x = v - l.x
		let y = v - l.y
		let z = v - l.z
		let r = x.magnitude > 0x1p-30 ? x > 0 ? w / -x : v / x : -.infinity
		let g = y.magnitude > 0x1p-30 ? y > 0 ? w / -y : v / y : -.infinity
		let b = z.magnitude > 0x1p-30 ? z > 0 ? w / -z : v / z : -.infinity
		
		return max(r, g, b)
	}
	
	/// The saturation relative to a color with equal hue and luma and maximum saturation.
	public func saturation(_ rgb:Vector4) -> Linear {
		let l = linear(rgb)
		let v = linearLuma(l)
		let m = maximumSaturation(l, luma:v)
		
		return m.isFinite ? 1 / m : 0
	}
	
	/// Scale saturation preserving luma.  Positive values preserve hue.  Zero is gray.  Scalars outside the 0 ... 1 range may denormalize the color.
	public func scaleSaturation(_ rgb:Vector4, by scalar:Linear) -> Vector4 {
		let l = linear(rgb)
		let v = linearLuma(l)
		
		return transferSigned(linearInterpolate(v, l, by:scalar), alpha:rgb.w)
	}
	
	/// Apply saturation preserving luma.  Positive values preserve hue.  Zero is gray.  Negative values invert hue.
	public func applySaturation(_ rgb:Vector4, saturation:Linear) -> Vector4 {
		let l = linear(rgb)
		let v = linearLuma(l)
		let m, s:Scalar
		
		if saturation < 0 {
			m = minimumSaturation(l, luma:v)
			s = m.isFinite ? -saturation * m : 0
		} else {
			m = maximumSaturation(l, luma:v)
			s = m.isFinite ? saturation * m : 0
		}
		
		return transferSigned(linearInterpolate(v, l, by:s), alpha:rgb.w)
	}
	
	public func normalizeLinear(_ linear:Vector3, luma v:Linear, leavePositive:Bool) -> Vector3 {
		var linear = linear
		
		let negative = min(linear.x, linear.y, linear.z)
		
		if negative < 0 {
			let desaturate = v / (v - negative)
			
			linear = linearInterpolate(v, linear, by:desaturate)
		}
		
		if leavePositive {
			return simd_max(linear, .zero)
		}
		
		let positive = max(linear.x, linear.y, linear.z)
		
		if positive > 1 {
			let desaturate = (v - 1) / (v - positive)
			
			linear = linearInterpolate(v, linear, by:desaturate)
		}
		
		linear.clamp(lowerBound:.zero, upperBound:.one)
		
		return linear
	}
	
	/// A normal color has all components in the 0 ... 1 range.  Normalization desaturates a color as needed to restore all components to that range.
	public func normalize(_ rgb:Vector4) -> Vector4 {
		let l = linear(rgb)
		let v = linearLuma(l)
		let n = normalizeLinear(l, luma:v, leavePositive:false)
		
		return transfer(n, alpha:rgb.w)
	}
	
	//	MARK: Hue
	
	/// Angle between the color and pure red, scaled to the 0 ... 1 range.
	public func vectorHue(_ rgb:Vector4) -> Scalar {
		let l = linear(rgb)
		let v = linearLuma(l)
		
		let hueSaturation = l - v
		let hueSaturationLengthSquared = simd_length_squared(hueSaturation)
		
		guard hueSaturationLengthSquared > 0.0 else { return 0.0 }
		
		let hueSaturationUnit = hueSaturation / hueSaturationLengthSquared.squareRoot()
		let red = Linear.vector3(1, 0, 0)
		let referenceRed = inverseLuma(luma:red) - 1
		let referenceUnit = simd_normalize(referenceRed)
		
		let dot = min(max(-1.0, simd_dot(hueSaturationUnit, referenceUnit)), 1.0)
		let turns = acos(dot) * 0.5 / .pi
		
		return rgb.y < rgb.z ? 1.0 - turns : turns
	}
	
	public func shiftLinearHue(_ linear:Vector3, luma v:Linear, by shift:Scalar) -> Vector3 {
		let hueSaturation = linear - v
		
		guard simd_length_squared(hueSaturation) > 0 else { return linear }
		
		//	inverseLuma(1,0,0)-1 cross inverseLuma(0,1,0)-1, assuming inverseLuma(0) = 0
		let inverse = inverseLuma(luma:.one)
		let red_cross_green = Linear.vector3(inverse.y, inverse.x, inverse.x * inverse.y - inverse.x - inverse.y)
		let axisUnit = simd_normalize(red_cross_green)
		
		//	use rodrigues rotation to shift hue saturation vector around axis
		let sc = __sincospi_stret(shift * 2)
		let v1 = hueSaturation * sc.__cosval
		let v2 = simd_cross(axisUnit, hueSaturation) * sc.__sinval
		let v3 = axisUnit * simd_dot(axisUnit, hueSaturation) * (1 - sc.__cosval)
		let sum = v1 + v2 + v3
		let result = normalizeLinear(sum + v, luma:v, leavePositive:false)
		
		return result
	}
	
	public func shiftVectorHue(_ rgb:Vector4, by shift:Scalar) -> Vector4 {
		let l = linear(rgb)
		let v = linearLuma(l)
		
		guard v > 0.0 else { return rgb }
		
		return transfer(shiftLinearHue(l, luma:v, by:shift), alpha:rgb.w)
	}
	
	public func color(hue:Scalar, saturation:Linear, luma:Linear, alpha:Scalar) -> Vector4 {
		guard luma > 0 else { return monochrome(gray:0, alpha:alpha) }
		guard luma < 1 else { return monochrome(gray:1, alpha:alpha) }
		guard saturation.magnitude > 0 else { return transfer(luma:luma, alpha:alpha) }
		
		let red = inverseLuma(luma:Linear.vector3(luma, 0, 0))
		let linear = shiftLinearHue(red, luma:luma, by:hue)
		
		let v = luma
		let m = saturation < 0 ? minimumSaturation(linear, luma:v) : maximumSaturation(linear, luma:v)
		let s = m.isFinite ? m * saturation.magnitude : 0
		let saturated = simd_max(linearInterpolate(v, linear, by:s), .zero)
		
		return transfer(saturated, alpha:alpha)
	}
	
	public func hexagonal(hue:Scalar, saturation:Linear, luma:Linear, alpha:Scalar) -> Vector4 {
		guard luma > 0 else { return monochrome(gray:0, alpha:alpha) }
		guard luma < 1 else { return monochrome(gray:1, alpha:alpha) }
		guard saturation.magnitude > 0 else { return transfer(luma:luma, alpha:alpha) }
		
		let hue1 = Curved.vector3(hue, hue - 1/3, hue - 2/3)
		let hue2 = hue1 - hue1.rounded(.down) - 0.5
		let hue3 = simd_abs(hue2) * 6.0 - 1.0
		let hexagonal = simd_clamp(Curved.vector4(hue3, alpha), .zero, .one)
		let lightened = applyLuma(hexagonal, luma:luma)
		let saturated = transferSigned(linearInterpolate(luma, linear(lightened), by:saturation), alpha:alpha)
		
		return saturated
	}
	
	public func shiftHexagonal(_ rgb:Vector4, by shift:Scalar) -> Vector4 {
		return hexagonal(hue:RGBA1.hsb(rgb).hue + shift, saturation:saturation(rgb), luma:luma(rgb), alpha:rgb.w)
	}
	
	public func applyHexagonal(_ rgb:Vector4, hue:Scalar) -> Vector4 {
		return hexagonal(hue:hue, saturation:saturation(rgb), luma:luma(rgb), alpha:rgb.w)
	}
}

//	MARK: -

public struct CHCLTSquare: CHCLT1, CHCLT {
	public let coefficients:Vector3
	
	public func linear(_ value:Curved) -> Linear {
		return value * value.magnitude
	}
	
	public func transfer(_ value:Linear) -> Curved {
		return value.squareRoot()
	}
	
	public func linearLuma(_ vector:CHCLTVector) -> CHCLTScalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverseLuma(luma:CHCLTVector) -> CHCLTVector {
		return luma / coefficients
	}
	
	public func linear(_ value:CHCLTVector) -> CHCLTVector {
		return value * simd_abs(value)
	}
	
	public func luminance(_ vector: CHCL.Vector3) -> CHCL.Scalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverse(_ luma:CHCL.Vector3) -> CHCL.Vector3 {
		return luma / coefficients
	}
}

//	MARK: -

public struct CHCLTPower: CHCLT1, CHCLT {
	public let coefficients:Vector3
	public let transferExponent:Linear
	
	public init(_ coefficients:Vector3, exponent:Linear = 0.5) {
		self.coefficients = coefficients
		self.transferExponent = exponent
	}
	
	public func linear(_ value:Curved) -> Linear {
		return pow(value.magnitude, 1.0 / transferExponent - 1.0) * value
	}
	
	public func transfer(_ value:Linear) -> Curved {
		return pow(value, transferExponent)
	}
	
	public func linearLuma(_ vector:CHCLTVector) -> CHCLTScalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverseLuma(luma:CHCLTVector) -> CHCLTVector {
		return luma / coefficients
	}
	
	public func linear(_ vector:CHCL.Vector3) -> CHCL.Vector3 {
		return CHCL.Linear.vector3(linear(vector.x), linear(vector.y), linear(vector.z))
	}
	
	public func luminance(_ vector:CHCL.Vector3) -> CHCL.Scalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverse(_ vector:CHCL.Vector3) -> CHCL.Vector3 {
		return vector / coefficients
	}
	
	public static let y240 = CHCLTPower(Linear.vector3(0.212, 0.701, 0.087), exponent:0.5)			//	39:129:16
	public static let y601 = CHCLTPower(Linear.vector3(0.299, 0.587, 0.114), exponent:0.45)			//	34:67:13	SDTV
	public static let y709 = CHCLTPower(Linear.vector3(0.2126, 0.7152, 0.0722), exponent:0.45)		//	53:178:18	HDTV
	public static let y2020 = CHCLTPower(Linear.vector3(0.2627, 0.6780, 0.0593), exponent:0.45)		//	31:80:7		UHDTV
	public static let sRGB = CHCLTPower(Linear.vector3(0.21263901, 0.71516867, 0.07219232), exponent:5 / 12)	//	53:178:18	HDTV
}

//	MARK: -

public struct CHCLTShading {
	public struct ColorLocation {
		public let color:CHCL.LinearRGB
		public let alpha:CHCL.Linear
		public let location:CHCL.Scalar
		
		func display(_ model:CHCLT) -> DisplayRGB { return color.display(model, alpha:alpha) }
	}

	public let model:CHCLT
	public let colors:[ColorLocation]
	var previousAbove = 0
	
	public init(model:CHCLT, colors:[ColorLocation]) {
		self.model = model
		self.colors = colors
	}
	
	public init(model:CHCLT, colors:[DisplayRGB]) {
		let scalar = CHCL.Linear(colors.count - 1)
		
		self.init(model:model, colors:colors.indices.map { ColorLocation(color:colors[$0].linear(model), alpha:colors[$0].vector.w, location:CHCLT1.Linear($0) / scalar) })
	}
	
	public init(model:CHCLT, colors:[DisplayRGB], locations:[CHCL.Scalar]) {
		let indices = 0 ..< min(colors.count, locations.count)
		
		self.init(model:model, colors:indices.map { ColorLocation(color:colors[$0].linear(model), alpha:colors[$0].vector.w, location:locations[$0]) })
	}
	
	public mutating func interpolate(by scalar:CHCL.Scalar) -> DisplayRGB {
		let count = colors.count
		
		guard count > 1 else { return colors.first?.display(model) ?? DisplayRGB(.zero) }
		
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
		
		guard above < count else { return colors[below].display(model) }
		guard above > 0 else { return colors[0].display(model) }
		
		let colorAbove = colors[above]
		let colorBelow = colors[below]
		let fraction = colorBelow.location.interpolate(towards:colorAbove.location, by:location)
		let alpha = colorBelow.alpha * (1 - fraction) + colorAbove.alpha * fraction
		
		return colorBelow.color.interpolated(towards:colorAbove.color, by:fraction).display(model, alpha:alpha)
	}
	
	public func shadingFunction() -> CGFunction? {
		let context = UnsafeMutablePointer<CHCLTShading>.allocate(capacity:1)
		
		context.initialize(to:self)
		
		let evaluate:CGFunctionEvaluateCallback = { pointer, input, output in
			guard let shadingPointer = pointer?.assumingMemoryBound(to:CHCLTShading.self) else { return }
			
			let display = shadingPointer.pointee.interpolate(by:CHCL.Scalar(input.pointee))
			let rgba = display.vector
			
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
	
	public func shading(colorSpace:CGColorSpace, start:CGPoint, end:CGPoint, extendStart:Bool = true, extendEnd:Bool = true) -> CGShading? {
		guard colorSpace.model == .rgb, let function = shadingFunction() else { return nil }
		
		return CGShading(axialSpace:colorSpace, start:start, end:end, function:function, extendStart:extendStart, extendEnd:extendEnd)
	}
	
	public func shading(colorSpace:CGColorSpace, start:CGPoint, startRadius:CGFloat = 0, end:CGPoint, endRadius:CGFloat, extendStart:Bool = true, extendEnd:Bool = true) -> CGShading? {
		guard colorSpace.model == .rgb, let function = shadingFunction() else { return nil }
		
		return CGShading(radialSpace:colorSpace, start:start, startRadius:startRadius, end:end, endRadius:endRadius, function:function, extendStart:extendStart, extendEnd:extendEnd)
	}
}
