//
//  CHCLT.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import Foundation
import simd

/// Cole Hue Chroma Luma Transform
public protocol CHCLT {
	/// Convert the components from compressed display space to linear space.
	/// 
	/// display(linear(rgb)) == rgb
	/// - Parameter vector: The display RGB components
	func linear(_ vector:CHCLT.Vector3) -> CHCLT.Vector3
	
	/// Convert the components from linear space to compressed display space.
	/// 
	/// display(linear(rgb)) == rgb
	/// - Parameter vector: The linear components
	func display(_ vector:CHCLT.Vector3) -> CHCLT.Vector3
	
	/// Convert a single component from linear space to compressed display space
	/// - Parameter scalar: The linear component
	func transfer(_ scalar:CHCLT.Linear) -> CHCLT.Scalar
	
	/// Compute the perceptual luminance of the linear components.
	/// 
	/// Usually rgb⋅c
	/// - Parameter vector: The linear components
	func luminance(_ vector:CHCLT.Vector3) -> CHCLT.Scalar
	
	/// Compute the values that would produce the given luminance.
	/// 
	/// luminance(inverseLuminance(rgb)) = ∑ rgb
	/// - Parameter vector: The linear results.
	func inverseLuminance(_ vector:CHCLT.Vector3) -> CHCLT.Vector3
	
	/// Parameters for determining the contrast value of colors
	func contrast() -> CHCL.Contrast
}

//	MARK: -

extension CHCLT {
	public typealias Scalar = Double
	public typealias Linear = Scalar
	public typealias Vector3 = SIMD3<Scalar>
	public typealias Vector4 = SIMD4<Scalar>
}

//	MARK: -

public enum CHCL {
	public typealias Scalar = CHCLT.Scalar
	public typealias Linear = CHCLT.Linear
	
	/// Parameters use to compute contrast
	public struct Contrast {
		/// The luminance value separating light and dark colors.
		/// Contrast in CHCLT is a measure of distance from medium luminance.
		/// 
		/// Colors with luminance below this value are dark and have better contrast against white than black.
		/// Colors with luminance above this value are light and have better contrast against black than white.
		/// All the contrast methods of CHCLT are primarily controlled by this value.
		///
		/// The typical value for medium luminance is `linear(0.5)` where linear is the inverse transfer function.
		/// 
		/// # Ratio
		/// Some models of contrast, such as WCAG G18 and section508, use a ratio of luminances to determine the contrast between colors.
		/// The ratio (r) and offset (1/d) are related to the medium luminance (m) by the following equations:
		/// ```
		/// m = (√(d+1)-1) / d = 1/(r + 1)
		/// d = (1 - 2m) / m² = r² - 1
		/// r = √(d+1) = 1/m - 1
		/// ```
		/// CHCLT uses an invariant medium luminance instead of a ratio to determine contrast.
		/// Using medium luminance is perceptually consistent and unambiguous.
		///
		/// # WCAG G18 and section508
		/// The WCAG G18 and section508 standards for contrast specify a fixed offset of 1/20 and ratios of 3, 4.5, or 7.
		/// With a linear power, an equivalent ratio and offset can be computed from the medium luminance.
		/// 
		/// - offset 0.5 gives 1/(1+√21) = 0.179 as medium luminance.
		/// - ratio 3 gives a 1/10 ... 3/10 range for medium luminance.  Use 1/4 (0.25) as the medium luminance.
		/// - ratio 4.5 gives a 21/120 ... 22/120 range for medium luminance.  Use 2/11 (0.182) as the medium luminance.
		/// - ratio 7 gives a 3/10 ... 1/10 range for medium luminance, excluding values in 1/10 ... 3/10.  Use 1/8 (0.125) as the medium luminance.
		///
		/// There will usually be a small range of luminances below the medium luminance where CHCLT will choose a light contrasting color and G18 or section508 would suggest a dark contrasting color.
		/// This will provide a visually higher contrast and fail the section508 and G18 standards.
		/// For sRGB and a 4.5 ratio this range will be from 0.182 to 0.214.
		public let mediumLuminance:Scalar
		
		/// Controls the shape of the luminance curve.
		/// Typical values are in the 1 ... 2 range.  1.0 is linear.
		/// As power increases, the contrast value of most colors will decrease, creating color pairs with higher visual contrast for the same contrast value.
		///
		/// ```
		/// v = luminance
		/// m = mediumLuminance
		/// pow(v > m ? (v - m) / (1 - m) : 1 - v / m, power)
		/// ```
		/// Colors with luminance equal to the medium luminance have a contrast of zero.
		/// Colors with luminance equal to zero (black) or one (white) have a contrast of one.
		///
		/// CHCLT is designed so that a light and dark color with contrasts adding to at least 1.0 will satisfy the minimum recommended contrast.
		/// The greatest sum of contrasts of two colors is 2.0 for black and white.
		/// The power parameter influences the luminance value of colors chosen to have a specific contrast relative to another color.
		///
		/// The typical value for power is `13m√m` where m is the medium luminance.  Use 1.0 for linear contrast.
		public let power:Scalar
		
		public init(_ mediumLuminance:Scalar, power:Scalar = 0) {
			self.mediumLuminance = mediumLuminance
			self.power = power > 0 ? power : max(1, 13 * pow(mediumLuminance, 1.5))
		}
	}
	
	public struct Adjustment {
		public let contrast:Scalar
		public let chroma:Scalar
	}
	
	/// A color in the linear RGB space reached via the CHCLT.
	/// # Range
	/// The range of the color components is 0 ... 1 and colors outside this range can be brought within the range using normalize
	/// # Stability
	/// Shifting the hue will not change the luminance, and will only change the saturation if the colors becomes denormalized, but it will usually change the chroma value.
	/// Changing the chroma will not change the luminance and will not change the hue if chroma remains positive.
	/// Changing the luminance will not change the hue unless color information is lost at the extrema, but it may change the chroma value.
	/// Changing the contrast is equivalent to changing the luminance.
	public struct LinearRGB {
		public static let black = LinearRGB(.zero)
		public static let white = LinearRGB(.one)
		
		public static let red = LinearRGB(1, 0, 0)
		public static let orange = LinearRGB(1, 0.5, 0)
		public static let yellow = LinearRGB(1, 1, 0)
		public static let chartreuse = LinearRGB(0.5, 1, 0)
		public static let green = LinearRGB(0, 1, 0)
		public static let spring = LinearRGB(0, 1, 0.5)
		public static let cyan = LinearRGB(0, 1, 1)
		public static let azure = LinearRGB(0, 0.5, 1)
		public static let blue = LinearRGB(0, 0, 1)
		public static let violet = LinearRGB(0.5, 0, 1)
		public static let magenta = LinearRGB(1, 0, 1)
		public static let rose = LinearRGB(1, 0, 0.5)
		
		public let vector:CHCLT.Vector3
		public var clamped:LinearRGB { return LinearRGB(simd_min(simd_max(.zero, vector), .one)) }
		
		public init(_ rgb:CHCLT.Vector3) {
			vector = rgb
		}
		
		public init(_ red:Linear, _ green:Linear, _ blue:Linear) {
			vector = Linear.vector3(red, green, blue)
		}
		
		public init(gray:Linear) {
			vector = Linear.vector3(gray, gray, gray)
		}
		
		public init(_ chclt:CHCLT, hue:Scalar) {
			let u = 1.0
			let axis = LinearRGB.hueAxis(chclt)
			let reference = LinearRGB.hueReference(chclt, luminance:u)
			let rotated = LinearRGB.rotate(vector:reference - u, axis:axis, turns:hue)
			let normalized = LinearRGB.normalize(vector:rotated + u, luminance:u, leavePositive:true)
			
			vector = normalized / normalized.max()
		}
		
		public init(_ chclt:CHCLT, hue:Scalar, luminance u:Linear) {
			guard u > 0 else { self.init(.zero); return }
			guard u < 1 else { self.init(.one); return }
			
			let axis = LinearRGB.hueAxis(chclt)
			let reference = LinearRGB.hueReference(chclt, luminance:u)
			let rotated = LinearRGB.rotate(vector:reference - u, axis:axis, turns:hue)
			let normalized = LinearRGB.normalize(vector:rotated + u, luminance:u, leavePositive:false)
			
			self.init(normalized)
		}
		
		public func pixel() -> UInt32 {
			var v = vector * 255.0
			
			v.round(.toNearestOrAwayFromZero)
			
			let u = simd_uint(v)
			let r = u.x << 16
			let g = u.y << 8
			let b = u.z << 0
			
			return r | g | b
		}
		
		/// Transfer from linear RGB to display ready, gamma compressed RGB
		public func display(_ chclt:CHCLT, alpha:Scalar = 1) -> DisplayRGB {
			return DisplayRGB(Scalar.vector4(chclt.display(vector), alpha))
		}
		
		/// Interpolate each component towards the component in the target color
		public func interpolated(towards:LinearRGB, by scalar:Scalar) -> LinearRGB {
			let t = 1 - scalar
			let a = vector * t
			let b = towards.vector * scalar
			
			return LinearRGB(a + b)
		}
		
		/// Interpolate each component from gray towards the component in this color
		public func interpolated(from:Linear, by scalar:Scalar) -> LinearRGB {
			let t = 1 - scalar
			let a = from * t
			let b = vector * scalar
			
			return LinearRGB(a + b)
		}
		
		/// Bring each component within the 0 ... 1 range by desaturating
		public func normalized(_ chclt:CHCLT) -> LinearRGB {
			return LinearRGB(LinearRGB.normalize(vector:vector, luminance:luminance(chclt), leavePositive:false))
		}
		
		//	MARK: - Luminance
		
		/// The luminance of this color in the given color space
		/// 
		/// Computed as the dot product of the linear components with the weighting coefficients of the color space.
		/// This is typically equivalent to conversion to the XYZ color space, where Y is the luminance.
		/// - Parameter chclt: The color space
		/// - Returns: The luminance
		public func luminance(_ chclt:CHCLT) -> Linear {
			return chclt.luminance(vector)
		}
		
		/// Apply a uniform scale to each component.  The color may become denormalized.
		public func scaleLuminance(by scalar:Linear) -> LinearRGB {
			return LinearRGB(vector * scalar)
		}
		
		/// Create a new color with the same hue and given luminance.
		/// Increasing the luminance to the point where it would be denormalized will instead desaturate the color, in which case decreasing the luminance to the original value will not produce the original color.
		/// The chroma value may change while the perceptual chroma is preserved.
		/// - Parameters:
		///   - chclt: The color space
		///   - u: Value from 0 ... 1 to apply.  Zero is black, one is white.
		/// - Returns: The adjusted color
		public func applyLuminance(_ chclt:CHCLT, value u:Linear) -> LinearRGB {
			guard u > 0 else { return LinearRGB(.zero) }
			guard u < 1 else { return LinearRGB(.one) }
			
			let v = chclt.luminance(vector)
			
			guard v > 0 else { return LinearRGB(gray:u) }
			
			let n = LinearRGB.normalize(vector:vector, luminance:v, leavePositive:true)
			let rgb = chclt.display(n)
			let s = u / v
			let t = chclt.transfer(s)
			let d = rgb.max()
			
			guard t * d > 1 else { return LinearRGB(n).scaleLuminance(by:s) }
			
			let maximumPreservingHue = rgb / d
			let m = chclt.linear(maximumPreservingHue)
			let w = chclt.luminance(m)
			let distanceFromWhite = (1 - u) / (1 - w)
			
			return LinearRGB(1 - distanceFromWhite + m * distanceFromWhite)
		}
		
		/// The maximum luminance value that can be applied without changing the ratio of the components and desaturating the color.
		public func maximumLuminancePreservingRatio(_ chclt:CHCLT) -> Linear {
			let d = vector.max()
			
			return d > 0 ? luminance(chclt) / d : 1
		}
		
		/// Applies the maximum luminance that preserves the ratio of the components.
		public func illuminated() -> LinearRGB {
			return LinearRGB(vector / vector.max())
		}
		
		public func matchLuminance(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			let n = 1 - value
			let v = luminance(chclt)
			let u = color.luminance(chclt)
			
			return applyLuminance(chclt, value:v * n + u * value)
		}
		
		//	MARK: - Contrast
		
		/// True if the luminance is below the medium luminance of the color space.
		public func isDark(_ chclt:CHCLT) -> Bool {
			return luminance(chclt) < chclt.contrast().mediumLuminance
		}
		
		/// The contrast of a color is a measure of the distance from medium luminance.
		/// Both black and white have a contrast of 1.
		/// The contrast is computed such that light and dark color pairs with contrasts that add to at least 1.0 satisfy the minimum recommended contrast.
		/// - Parameter chclt: The color space
		/// - Returns: The contrast
		public func contrast(_ chclt:CHCLT) -> Linear {
			let p = chclt.contrast()
			let m = p.mediumLuminance
			let v = luminance(chclt)
			let c = v > m ? (v - m) / (1 - m) : 1 - v / m
			
			return pow(c.magnitude, p.power)
		}
		
		/// Scale the luminance of the color so that the resulting contrast will be scaled by the given amount.
		/// For example, scale by 0.5 to produce a color that contrasts half as much against the same background.
		/// Scaling to 0 will result in a color with medium luminance.
		/// Scaling to negative will result in contrasting colors.
		public func scaleContrast(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			let p = chclt.contrast()
			let m = p.mediumLuminance
			let v = luminance(chclt)
			let t = scalar < 0 ? v < m ? (1 - m) / m : m / (1 - m) : 1
			let u = m - pow(scalar.magnitude, 1 / p.power) * (m - v) * t
			
			return applyLuminance(chclt, value:u)
		}
		
		/// Adjust the luminance to create a color that contrasts against the same colors as this color.
		/// 
		/// Use a value less than `contrast(chclt) - 1` for a color with the suggested minimum contrast.
		/// - Parameters:
		///   - chclt: The color space
		///   - value: The contrast of the adjusted color.  Negative values create contrasting colors.  Values near zero contrast poorly.  Values near one contrast well.
		/// - Returns: The adjusted color
		public func applyContrast(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			let p = chclt.contrast()
			let m = p.mediumLuminance
			let v = luminance(chclt)
			let t = pow(value.magnitude, 1 / p.power)
			let u = (v < m) == (value < 0) ? (1 - m) * t + m : m * (1 - t)
			
			return applyLuminance(chclt, value:u)
		}
		
		/// Adjust the luminance to create a color that contrasts well against this color.
		/// 
		/// Use a value greater than `1 - contrast(chclt)` for a color with the suggested minimum contrast.
		/// - Parameters:
		///   - chclt: The color space
		///   - value: The contrast of the adjusted color.  Negative values create colors that do not contrast with this color.  Values near zero contrast poorly.  Values near one contrast well.
		/// - Returns: The adjusted color
		public func opposing(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return applyContrast(chclt, value:-value)
		}
		
		/// Adjust the luminance to create a color that contrasts well against this color, relative to the minimum suggested contrast.
		/// 
		/// A light and dark color pair with contrasts that add to at least 1.0 satisfy the minimum suggested contrast.
		/// This method will generate the second color of that contrasting color pair.
		/// A value of zero will apply the minimum suggested contrast between the colors.
		/// Positive values are the fraction of maximum possible contrast, up to 1.0 which result in black or white and have the maximum contrast.
		/// Negative values are a fraction of the range below the minimum suggested contrast towards medium luminance.
		/// - Parameters:
		///   - chclt: The color space
		///   - value: The contrast adjustment in the range -1 (medium luminance) to 0 (minimum contrast) to 1 (maximum contrast).
		/// - Returns: The adjusted color
		public func contrasting(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			let p = chclt.contrast()
			let m = p.mediumLuminance
			let v = luminance(chclt)
			let cc = v > m ? (v - m) / (1 - m) : 1 - v / m
			let c = pow(cc, p.power)
			let tt = value < 0 ? (1 - c) * (1 + value) : (1 - c) + c * value
			let t = pow(tt, 1 / p.power)
			let u = v > m ? m * (1 - t) : (1 - m) * t + m
			
			return applyLuminance(chclt, value:u)
		}
		
		public func matchContrast(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			let p = chclt.contrast()
			let m = p.mediumLuminance
			let v = luminance(chclt)
			let u = color.luminance(chclt)
			let n = 1 - value
			let c = contrast(chclt) * n + color.contrast(chclt) * value
			let s = v < m ? u > m ? -1.0 : 1.0 : u < m ? -1.0 : 1.0
			
			return applyContrast(chclt, value:c * s)
		}
		
		//	MARK: - Chroma
		
		/// The maximum amount that the chroma can be scaled without denormalizing the color.
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
		
		/// The maximum amount that the chroma can be scaled in the negative direction without denormalizing the color.
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
		
		///	A color with all components equal is desaturated and has a chroma of zero.
		///	A color with a component at 0 or 1 cannot have the saturation increased without denormalizing the color and has a chroma of one.
		///	The chroma of a color is the desaturation scale that would be applied to the maximum color to reach this color.
		/// - Parameter chclt: The color space
		/// - Returns: The croma
		public func chroma(_ chclt:CHCLT) -> Scalar {
			let v = chclt.luminance(vector)
			let m = maximumChroma(luminance:v)
			let c = m.isFinite ? 1 / m : 0
			
			return c
		}
		
		/// Scale the chroma of the color.
		/// The color approaches gray as the value approaches zero.
		/// Values greater than one increase vibrancy and may denormalize the color.
		/// The hue is preserved for positive, inverted for nagative, and lost at zero.
		/// The luminance is preserved.
		public func scaleChroma(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			let v = chclt.luminance(vector)
			let s = scalar
			
			return interpolated(from:v, by:s)
		}
		
		/// Adjust the chroma to create a color with the given relative color intensity.
		public func applyChroma(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return applyChroma(chclt, value:value, luminance:luminance(chclt))
		}
		
		public func applyChroma(_ chclt:CHCLT, value:Scalar, luminance v:Linear) -> LinearRGB {
			let m = value < 0 ? minimumChroma(luminance:v) : maximumChroma(luminance:v)
			let value = value.magnitude
			let s = m.isFinite ? value * m : 0
			
			return interpolated(from:v, by:s)
		}
		
		public func matchChroma(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			let c = chroma(chclt)
			let d = color.chroma(chclt)
			let n = 1 - value
			
			return applyChroma(chclt, value:c * n + d * value)
		}
		
		//	MARK: - Saturation
		
		public func saturation(_ chclt:CHCLT) -> Scalar {
			let v = chclt.luminance(vector)
			let hueSaturation = vector - v
			
			return simd_length(hueSaturation)
		}
		
		public func applySaturation(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			let s = saturation(chclt)
			
			return s > 0 ? scaleChroma(chclt, by: value / s) : self
		}
		
		public func matchSaturation(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			let s = saturation(chclt)
			let t = color.saturation(chclt)
			let n = 1 - value
			
			return applySaturation(chclt, value:s * n + t * value)
		}
		
		//	MARK: - Hue
		
		/// Hue is the angle between the color and red, normalized to the 0 ... 1 range.
		/// Reds are near 0 or 1, greens are near ⅓, and blues are near ⅔ but the actual angles vary by color space.
		/// - Parameter chclt: The color space
		/// - Returns: The hue
		public func hue(_ chclt:CHCLT) -> Linear {
			let v = chclt.luminance(vector)
			
			let hueSaturation = vector - v
			let hueSaturationLengthSquared = simd_length_squared(hueSaturation)
			
			guard hueSaturationLengthSquared > 0.0 else { return 0.0 }
			
			let hueSaturationUnit = hueSaturation / hueSaturationLengthSquared.squareRoot()
			let reference = LinearRGB.hueReference(chclt, luminance:1)
			let referenceUnit = simd_normalize(reference - 1)
			
			let dot = min(max(-1.0, simd_dot(hueSaturationUnit, referenceUnit)), 1.0)
			let turns = acos(dot) * 0.5 / .pi
			
			return vector.y < vector.z ? 1.0 - turns : turns
		}
		
		/// Rotate the deluminated color vector around the normal.
		public func hueShifted(_ chclt:CHCLT, by shift:Scalar, luminance v:Linear) -> LinearRGB {
			let hueSaturation = vector - v
			
			guard simd_length_squared(hueSaturation) > 0 else { return self }
			
			let shifted = LinearRGB.rotate(vector:hueSaturation, axis:LinearRGB.hueAxis(chclt), turns:shift)
			let normalized = LinearRGB.normalize(vector:shifted + v, luminance:v, leavePositive:false)
			
			return LinearRGB(normalized)
		}
		
		/// Rotate the color around the normal axis, changing the ratio of the components.
		/// Shifting the hue will preserve the luminance, and changes the chroma value.
		/// The perceptual chroma is preserved unless the color needs to be normalized after rotation.
		/// - Parameters:
		///   - chclt: The color space.
		///   - shift: The amount to shift.  Shifting by zero or one has no effect.  Shifting by half gives the same hue as negating chroma.
		/// - Returns: The adjusted color.
		public func hueShifted(_ chclt:CHCLT, by shift:Linear) -> LinearRGB {
			return hueShifted(chclt, by:shift, luminance:luminance(chclt))
		}
		
		public func huePushed(_ chclt:CHCLT, from color:LinearRGB, minimumShift shift:Linear) -> LinearRGB {
			guard color.chroma(chclt) > 1/32 else { return self }
			
			let h = hue(chclt)
			let g = color.hue(chclt)
			let d = h - g
			let e = d.magnitude > 0.5 ? d < 0 ? d + 1 : d - 1 : d
			let s = shift.magnitude.integerFraction.1
			let t = s > 0.5 ? 1 - s : s
			
			guard e.magnitude < t else { return self }
			
			return hueShifted(chclt, by:e < 0 ? -e - t : t - e)
		}
		
		public static func rotate(vector:Linear.Vector3, axis:Linear.Vector3, turns:Linear) -> Linear.Vector3 {
			//	use rodrigues rotation to rotate vector around normalized axis
			let sc = __sincospi_stret(turns * 2)
			let v1 = vector * sc.__cosval
			let v2 = simd_cross(axis, vector) * sc.__sinval
			let v3 = axis * simd_dot(axis, vector) * (1 - sc.__cosval)
			let sum = v1 + v2 + v3
			
			return sum
		}
		
		public static func normalize(vector:Linear.Vector3, luminance v:Linear, leavePositive:Bool) -> Linear.Vector3 {
			var vector = vector
			let negative = vector.min()
			
			if negative < 0 {
				let desaturate = v / (v - negative)
				let t = 1 - desaturate
				
				vector = desaturate * vector + t * v
			}
			
			if leavePositive {
				return simd_max(vector, .zero)
			}
			
			let positive = vector.max()
			
			if positive > 1 {
				let desaturate = (v - 1) / (v - positive)
				let t = 1 - desaturate
				
				vector = desaturate * vector + t * v
			}
			
			vector.clamp(lowerBound:.zero, upperBound:.one)
			
			return vector
		}
		
		public static func hueReference(_ chclt:CHCLT, luminance v:Linear) -> Linear.Vector3 {
			return chclt.inverseLuminance(Linear.vector3(v, 0, 0))
		}
		
		public static func hueAxis(_ chclt:CHCLT) -> Linear.Vector3 {
			let inverse = chclt.inverseLuminance(.one)
			let red_cross_green = Linear.vector3(inverse.y, inverse.x, inverse.x * inverse.y - inverse.x - inverse.y)
			
			return simd_normalize(red_cross_green)
		}
		
		public static func hueRange(_ chclt:CHCLT, start:Scalar = 0, shift:Scalar, count:Int) -> [LinearRGB] {
			let v = 1.0
			let reference = hueReference(chclt, luminance:v)
			let hueSaturation = reference - v
			let axis = hueAxis(chclt)
			
			return Array<LinearRGB>(unsafeUninitializedCapacity:count) { buffer, initialized in
				var hue = start
				
				for index in 0 ..< count {
					let rotated = rotate(vector:hueSaturation, axis:axis, turns:hue)
					let normalized = LinearRGB.normalize(vector:rotated + v, luminance:v, leavePositive:true)
					
					buffer[index] = LinearRGB(normalized / normalized.max())
					hue += shift
				}
				
				initialized = count
			}
		}
	}
}

//	MARK: -

extension CHCLT {
	public func offset() -> CHCLT.Scalar {
		let m = contrast().mediumLuminance
		
		return m * m / (1 - 2*m)
	}
	
	public func transferSigned(_ scalar:CHCLT.Linear) -> CHCLT.Scalar {
		return copysign(transfer(scalar.magnitude), scalar)
	}
	
	public func display(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return CHCLT.Scalar.vector3(transferSigned(vector.x), transferSigned(vector.y), transferSigned(vector.z))
	}
}

//	MARK: -

public struct CHCLTSquare: CHCLT {
	public let coefficients:CHCLT.Vector3
	
	public init(_ coefficients:CHCLT.Vector3) {
		self.coefficients = coefficients
	}
	
	public func linear(_ value:CHCLT.Scalar) -> CHCLT.Linear {
		return value * value.magnitude
	}
	
	public func transfer(_ value:CHCLT.Linear) -> CHCLT.Scalar {
		return value.squareRoot()
	}
	
	public func linear(_ value:CHCLT.Vector3) -> CHCLT.Vector3 {
		return value * simd_abs(value)
	}
	
	public func luminance(_ vector: CHCLT.Vector3) -> CHCLT.Scalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverseLuminance(_ luma:CHCLT.Vector3) -> CHCLT.Vector3 {
		return luma / coefficients
	}
	
	public func contrast() -> CHCL.Contrast {
		return CHCL.Contrast(0.25)
	}
	
	public static let y240 = CHCLTSquare(CHCLT.Linear.vector3(0.212, 0.701, 0.087))	//	39:129:16
}

//	MARK: -

public struct CHCLTPower: CHCLT {
	public let coefficients:CHCLT.Vector3
	public let transferExponent:CHCLT.Linear
	
	public init(_ coefficients:CHCLT.Vector3, exponent:CHCLT.Linear = 0.5) {
		self.coefficients = coefficients
		self.transferExponent = exponent
	}
	
	public func linear(_ value:CHCLT.Scalar) -> CHCLT.Linear {
		return pow(value.magnitude, 1.0 / transferExponent - 1.0) * value
	}
	
	public func transfer(_ value:CHCLT.Linear) -> CHCLT.Scalar {
		return pow(value, transferExponent)
	}
	
	public func linear(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return CHCLT.Linear.vector3(linear(vector.x), linear(vector.y), linear(vector.z))
	}
	
	public func luminance(_ vector:CHCLT.Vector3) -> CHCLT.Scalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverseLuminance(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return vector / coefficients
	}
	
	public func contrast() -> CHCL.Contrast {
		return CHCL.Contrast(linear(0.5))
	}
	
	public static let y601 = CHCLTPower(CHCLT_BT.y601.coefficients, exponent:10 / 19)
	public static let y709 = CHCLTPower(CHCLT_BT.y709.coefficients, exponent:10 / 19)
	public static let y2020 = CHCLTPower(CHCLT_BT.y2020.coefficients, exponent:10 / 19)
	public static let sRGB = CHCLTPower(CHCLT_sRGB.coefficients, exponent:5 / 11)
}

//	MARK: -

public struct CHCLT_sRGB: CHCLT {
	public static let coefficients:CHCLT.Vector3 = CHCLT.Linear.vector3(0.21263901, 0.71516867, 0.07219232)
	public static let standard = CHCLT_sRGB(contrast:CHCL.Contrast(CHCLT_sRGB.linear(0.5)))
	public static let g18 = CHCLT_sRGB(contrast:CHCL.Contrast(2 / 11, power:1.0))
	
	public let useContrast:CHCL.Contrast
	
	public init(contrast:CHCL.Contrast) {
		useContrast = contrast
	}
	
	public func contrast() -> CHCL.Contrast {
		return useContrast
	}
	
	public static func linear(_ value:CHCLT.Scalar) -> CHCLT.Linear {
		return value > 11.0 / 280.0 ? pow((200.0 * value + 11.0) / 211.0, 12.0 / 5.0) : value / 12.9232102
	}
	
	public func transfer(_ value:CHCLT.Linear) -> CHCLT.Scalar {
		return value > 11.0 / 280.0 / 12.9232102 ? (211.0 * pow(value, 5.0 / 12.0) - 11.0) / 200.0 : value * 12.9232102
	}
	
	public func linear(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return CHCLT.Linear.vector3(CHCLT_sRGB.linear(vector.x), CHCLT_sRGB.linear(vector.y), CHCLT_sRGB.linear(vector.z))
	}
	
	public func luminance(_ vector:CHCLT.Vector3) -> CHCLT.Scalar {
		return simd_dot(vector, CHCLT_sRGB.coefficients)
	}
	
	public func inverseLuminance(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return vector / CHCLT_sRGB.coefficients
	}
}

//	MARK: -

public struct CHCLT_BT: CHCLT {
	public static let y601 = CHCLT_BT(CHCLT.Linear.vector3(0.299, 0.587, 0.114))		//	34:67:13	SDTV
	public static let y709 = CHCLT_BT(CHCLT.Linear.vector3(0.2126, 0.7152, 0.0722))		//	53:178:18	HDTV
	public static let y2020 = CHCLT_BT(CHCLT.Linear.vector3(0.2627, 0.6780, 0.0593))	//	31:80:7		UHDTV
	
	public let coefficients:CHCLT.Vector3
	
	public init(_ coefficients:CHCLT.Vector3) {
		self.coefficients = coefficients
	}
	
	public func linear(_ value:CHCLT.Scalar) -> CHCLT.Linear {
		return value > 0.081 ? pow((value + 0.099) / 1.099, 20.0 / 9.0) : value / 4.5
	}
	
	public func transfer(_ value:CHCLT.Linear) -> CHCLT.Scalar {
		return value > 0.018 ? 1.099 * pow(value, 9.0 / 20.0) - 0.099 : value * 4.5
	}
	
	public func linear(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return CHCLT.Linear.vector3(linear(vector.x), linear(vector.y), linear(vector.z))
	}
	
	public func luminance(_ vector:CHCLT.Vector3) -> CHCLT.Scalar {
		return simd_dot(vector, coefficients)
	}
	
	public func inverseLuminance(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return vector / coefficients
	}
	
	public func contrast() -> CHCL.Contrast {
		return CHCL.Contrast(linear(0.5))
	}
}
