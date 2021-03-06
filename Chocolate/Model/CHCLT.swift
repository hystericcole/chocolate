//
//  CHCLT.swift
//  Chocolate
//
//  Created by Eric Cole on 1/26/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import simd

/// Cole Hue Chroma Luma Transform
public class CHCLT {
	public typealias Scalar = Double
	public typealias Linear = Scalar
	public typealias Vector3 = SIMD3<Scalar>
	public typealias Vector4 = SIMD4<Scalar>
	
	public let coefficients:Vector3
	public let contrast:Contrast
	public let hueGeometry:HueGeometry
	
	public let toCIEXYZ:Scalar.Matrix3x3
	public let fromCIEXYZ:Scalar.Matrix3x3
	
	public init(_ toCIEXYZ:Scalar.Matrix3x3, contrast:Contrast, coefficients:Vector3? = nil) {
		self.coefficients = coefficients ?? CIEXYZ.luminanceCoefficients(toCIEXYZ)
		self.contrast = contrast
		self.toCIEXYZ = toCIEXYZ
		self.fromCIEXYZ = toCIEXYZ.inverse
		self.hueGeometry = HueGeometry(coefficients:self.coefficients)
	}
	
	//	MARK: Transfer
	
	public func linear(_ value:Scalar) -> Linear {
		return value
	}
	
	/// Convert the components from display space to gamma expanded linear space.
	///
	/// display(linear(rgb)) == rgb
	/// - Parameter vector: The display RGB components
	public func linear(_ vector:Vector3) -> Vector3 {
		return Scalar.vector3(linear(vector.x), linear(vector.y), linear(vector.z))
	}
	
	/// Convert the components from linear space to gamma compressed display space.
	///
	/// display(linear(rgb)) == rgb
	/// - Parameter vector: The linear components
	public func display(_ vector:Vector3) -> Vector3 {
		return Scalar.vector3(transferSigned(vector.x), transferSigned(vector.y), transferSigned(vector.z))
	}
	
	/// Convert a single component from linear space to compressed display space
	/// - Parameter scalar: The linear component
	public func transfer(_ value:Linear) -> Scalar {
		return value
	}
	
	public func transferSigned(_ value:Linear) -> Scalar {
		return copysign(transfer(value.magnitude), value)
	}
	
	//	MARK: Luminance
	
	/// Compute the perceptual luminance of the linear components.
	///
	/// Usually `rgb⋅c` where c is the weighting coefficients.
	///
	/// This is often equivalent to computing the Y value of the XYZ or Yuv color space.
	/// - Parameter linear: The linear components
	public func luminance(_ linear:Vector3) -> Linear {
		return simd_dot(linear, coefficients)
	}
	
	public func luminance(luma:Scalar) -> Linear {
		return linear(luma)
	}
	
	public func luma(luminance:Linear) -> Scalar {
		return transfer(luminance)
	}
	
	//	MARK: Hue
	
	public func hue(_ linear:Linear.Vector3, luminance v:Linear) -> Linear {
		return hueGeometry.hue(linear, luminance:v)
	}
	
	public func hueShift(_ linear:Linear.Vector3, luminance v:Linear, by shift:Linear) -> Linear.Vector3 {
		return hueGeometry.hueShift(linear, luminance:v, by:shift)
	}
	
	public func hueRange(start:Scalar = 0, shift:Scalar, count:Int) -> [Linear.Vector3] {
		return hueGeometry.hueRange(start:start, shift:shift, count:count)
	}
	
	public func pure(hue:Scalar) -> Linear.Vector3 {
		return hueGeometry.pure(hue:hue)
	}
	
	public func pure(hue:Scalar, luminance u:Linear) -> Linear.Vector3 {
		return hueGeometry.pure(hue:hue, luminance:u)
	}
	
	//	MARK: Comparison
	
	public func isEqual(to chclt:CHCLT) -> Bool {
		return coefficients == chclt.coefficients && contrast == chclt.contrast && type(of:self) == type(of:chclt)
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(coefficients)
		hasher.combine(contrast)
	}
}

//	MARK: - Conversion

extension CHCLT {
	public func whitepoint() -> Vector3 {
		return toCIEXYZ * Vector3.one
	}
	
	public func ciexyz(linearRGB:Vector3) -> Vector3 {
		return toCIEXYZ * linearRGB
	}
	
	public func linearRGB(ciexyz:Vector3) -> Vector3 {
		return fromCIEXYZ * ciexyz
	}
	
	public func convert(linearRGB:Vector3, from chclt:CHCLT) -> Vector3 {
		if toCIEXYZ == chclt.toCIEXYZ {
			return linearRGB
		} else {
			return self.linearRGB(ciexyz:chclt.ciexyz(linearRGB:linearRGB))
		}
	}
	
	public func convert(rgb:Vector3, from chclt:CHCLT) -> Vector3 {
		return display(convert(linearRGB:chclt.linear(rgb), from:chclt))
	}
}

//	MARK: - Equatable

extension CHCLT: Equatable, Hashable {
	public static func == (lhs: CHCLT, rhs: CHCLT) -> Bool {
		return lhs.isEqual(to:rhs)
	}
}

//	MARK: -

extension CHCLT {
	public struct HueGeometry {
		public var reference:Linear.Vector3
		public var axis:Linear.Vector3
		
		public init(reference:Linear.Vector3, axis:Linear.Vector3) {
			self.reference = reference
			self.axis = axis
		}
		
		public init(coefficients:CHCLT.Vector3) {
			let inverse = .one / coefficients
			let reference = Linear.vector3(inverse.x, 0, 0) - 1.0
			let red_cross_green = Linear.vector3(inverse.y, inverse.x, inverse.x * inverse.y - inverse.x - inverse.y)
			
			self.init(reference:reference, axis:simd_normalize(red_cross_green))
		}
		
		public static func rotate(_ linear:Linear.Vector3, axis:Linear.Vector3, turns:Linear) -> Linear.Vector3 {
			//	use rodrigues rotation to rotate vector around normalized axis
			let sc = turns.sincosturns()
			let v1 = linear * sc.__cosval
			let v2 = simd_cross(axis, linear) * sc.__sinval
			let v3 = axis * simd_dot(axis, linear) * (1 - sc.__cosval)
			let sum = v1 + v2 + v3
			
			return sum
		}
		
		/// Hue is the angle between the color and red, normalized to the 0 ... 1 range.
		/// Reds are near 0 or 1, greens are near ⅓, and blues are near ⅔ but the actual angles vary.
		/// - Parameters:
		///   - linear: The color.
		///   - v: The luminance of color.
		/// - Returns: The hue
		public func hue(_ linear:Linear.Vector3, luminance v:Linear) -> Linear {
			let v = max(v, linear.min())
			let hueSaturation = linear - v
			let hueSaturationLengthSquared = simd_length_squared(hueSaturation)
			
			guard hueSaturationLengthSquared > 0.0 else { return 0.0 }
			
			let hueSaturationUnit = hueSaturation / hueSaturationLengthSquared.squareRoot()
			let referenceUnit = simd_normalize(reference)
			
			let dot = min(max(-1.0, simd_dot(hueSaturationUnit, referenceUnit)), 1.0)
			let turns = acos(dot) * 0.5 / .pi
			
			return linear.y < linear.z ? 1.0 - turns : turns
		}
		
		/// Rotate the color around the normal axis, changing the ratio of the components.
		/// Shifting the hue preserves the luminance, and changes the chroma value.
		/// The saturation is preserved unless the color needs to be normalized after rotation.
		/// - Parameters:
		///   - linear: The color.
		///   - v: The luminance of color.
		///   - shift: The amount to shift.  Shifting by zero or one has no effect.  Shifting by half gives the same hue as negating chroma.
		/// - Returns: The adjusted color.
		public func hueShift(_ linear:Linear.Vector3, luminance v:Linear, by shift:Linear) -> Linear.Vector3 {
			let hueSaturation = linear - v
			
			guard simd_length_squared(hueSaturation) > 0 else { return linear }
			
			let shifted = CHCLT.HueGeometry.rotate(hueSaturation, axis:axis, turns:shift)
			let normalized = CHCLT.normalize(shifted + v, luminance:v, leavePositive:false)
			
			return normalized
		}
		
		public func hueRange(start:Scalar = 0, shift:Scalar, count:Int) -> [Linear.Vector3] {
			return Array<Linear.Vector3>(unsafeUninitializedCapacity:count) { buffer, initialized in
				var hue = start
				
				for index in 0 ..< count {
					buffer[index] = pure(hue:hue)
					hue += shift
				}
				
				initialized = count
			}
		}
		
		public func pure(hue:Scalar) -> Linear.Vector3 {
			let rotated = CHCLT.HueGeometry.rotate(reference, axis:axis, turns:hue)
			let normalized = CHCLT.saturate(rotated)
			
			return normalized
		}
		
		public func pure(hue:Scalar, luminance u:Linear) -> Linear.Vector3 {
			guard u > 0 else { return .zero }
			guard u < 1 else { return .one }
			
			let rotated = CHCLT.HueGeometry.rotate(reference * u, axis:axis, turns:hue)
			let normalized = CHCLT.normalize(rotated + u, luminance:u, leavePositive:false)
			
			return normalized
		}
	}
}

//	MARK: -

extension CHCLT {
	/// Parameters used to compute contrast.
	///
	/// Contrast in CHCLT is the distance from medium luma.
	/// Colors with luma below medium are dark and have better contrast against white than black.
	/// Colors with luma above medium are light and have better contrast against black than white.
	/// The typical value for medium luma is 0.5, the perceptual midpoint of luma.
	/// The typical value for medium luminance is the linear value computed from mudium luma.
	///
	/// # Hue
	/// Complementary colors, colors with oppisite hue, are described as having high contrast.
	/// Contrast in CHCLT refers to luminance based contrast, not hue based contrast.
	///
	/// # Ratio
	/// Some models of contrast, such as WCAG G18 and section508, use an offset luminance ratio to measure the contrast between colors.
	///
	/// Ratios are ambiguous and perceptually inconsistent.
	///
	/// The ratio (r) and offset (1/d) are related to the medium luminance (m) by the following equations:
	/// ```
	/// m = (√(d+1)-1) / d = 1/(r + 1)
	/// d = (1 - 2m) / m² = r² - 1
	/// r = √(d+1) = 1/m - 1
	/// ```
	///
	/// # WCAG G18 and section508
	/// The WCAG G18 and section508 standards for contrast specify a fixed offset of 1/20 and ratios of 3, 4.5, or 7.
	/// To conforman with a ratio based standard, use a medium luma derived from the medium luminance for the ratio or offset being applied.
	///
	/// - offset 0.05 gives 1/(1+√21) ≅ 0.179 as medium luminance.
	/// - ratio 3 gives a 1/10 ... 3/10 range for medium luminance.  Use 1/4 (0.25) as the medium luminance.
	/// - ratio 4.5 gives a 21/120 ... 22/120 range for medium luminance.  Use 2/11 (0.182) as the medium luminance.
	/// - ratio 7 gives a 3/10 ... 1/10 range for medium luminance, excluding values in 1/10 ... 3/10.  Use 1/8 (0.125) as the medium luminance.
	///
	/// When using a medium luma other than 0.5 there will be a range of colors that satisfy the chosen ratio but would have better perceptual contrast against opposite colors.
	/// For sRGB and a 4.5 ratio this will be colors with luminance in the range 0.182 to 0.214.
	public struct Contrast: Equatable, Hashable {
		/// The luminance value separating light and dark colors.  Must equal `luminance(luma:mediumLuma)`
		public let mediumLuminance:Linear
		/// The luma value separating light and dark colors.  Must equal `luma(luminance:mediumLuminance)`
		public let mediumLuma:Scalar
		
		public var linearOffset:Scalar {
			return mediumLuminance * mediumLuminance / (1 - 2 * mediumLuminance)
		}
		
		public var linearRatio:Scalar {
			return 1.0 / mediumLuminance - 1.0
		}
		
		/// Create a Contrast
		/// # Luma
		/// To create a luma based contrast, choose the value for medium luma (typically 0.5) then compute the medium luminance.
		/// ```
		/// mediumLuminance:luminance(luma:mediumLuma)
		/// ```
		/// # Luminance
		/// To create a luminance based contrast, choose the value for medium luminance (e.g. 2/11) then compute the medium luma.
		/// ```
		/// mediumLuma:luma(luminance:mediumLuminance)
		/// ```
		///
		/// - Parameters:
		///   - mediumLuminance: The medium luminance, typically computed as `luminance(luma:0.5)`
		///   - mediumLuma: The medium luma, typically 0.5
		public init(_ mediumLuminance:Linear, mediumLuma:Scalar = 0.5) {
			self.mediumLuminance = mediumLuminance
			self.mediumLuma = mediumLuma
		}
		
		/// True if the given luminance contrast better against white than black.
		public func luminanceIsDark(_ luminance:Linear) -> Bool {
			return luminance < mediumLuminance
		}
		
		/// True if the given luma contrast better against white than black.
		public func lumaIsDark(_ luma:Scalar) -> Bool {
			return luma < mediumLuma
		}
		
		/// Contrast is a measure of the distance from medium luma.
		/// Both black and white have a contrast of one, and medium colors have a contrast of zero.
		/// - Parameters:
		///   - luma: Luma value of a color, in 0 ... 1
		/// - Returns: The contrast computed from luma
		public func lumaContrast(_ luma:Scalar) -> Scalar {
			return luma < mediumLuma ? (mediumLuma - luma) / mediumLuma : (luma - mediumLuma) / (1 - mediumLuma)
		}
		
		/// Compute the luma that should be applied in order to scale the contrast of a color.
		/// - Parameters:
		///   - luma: Luma value of a color, in 0 ... 1
		///   - scalar: Amount to scale contrast, in -1 ... 1
		/// - Returns: The luma value for the scaled contrast.
		public func lumaScaleContrast(_ luma:Scalar, by scalar:Scalar) -> Scalar {
			return lumaApplyContrast(luma, value:lumaContrast(luma) * scalar)
		}
		
		/// Compute the luma that should be applied in order to set the contrast of a color.
		/// - Parameters:
		///   - luma: Luma value of a color, in 0 ... 1
		///   - value: Contrast of result, in -1 ... 1
		/// - Returns: The luma value for the applied contrast.
		public func lumaApplyContrast(_ luma:Scalar, value:Scalar) -> Scalar {
			let sign = luma - mediumLuma
			let one = value * sign < 0 ? 0 : value.magnitude
			
			return mediumLuma - value.magnitude * mediumLuma + one
		}
		
		/// Compute the luma that should be applied in order to create a contrasting color.
		///
		/// - Positive values apply more than the minimum suggested contrast, approaching black or white as value approaches one.
		/// - Negative values apply less than the minimum suggested contrast, approaching medium luminance as value approaches negative one.
		/// - Zero applies the minimum suggested contrast.
		/// - Parameters:
		///   - luma: Luma value of a color, in 0 ... 1
		///   - value: Degree of contrast, in -1 ... 1
		/// - Returns: The luma value for the contrasting color.
		public func lumaContrasting(_ luma:Scalar, value:Scalar) -> Scalar {
			let current = lumaContrast(luma)
			let apply = (1 - value.magnitude) * (current - copysign(1, current)) - copysign(max(0, value), current)
			
			return lumaApplyContrast(luma, value:apply)
		}
		
		public func lumaMatchContrast(_ v:Scalar, _ u:Scalar, by value:Scalar) -> Scalar {
			let m = mediumLuma
			let n = 1 - value
			let c = lumaContrast(v) * n + lumaContrast(u) * value
			let s = copysign(1, (v - m) * (u - m))
			
			return lumaApplyContrast(v, value:c * s)
		}
		
		/// Compute the contrast ratio between two luminances using the offset equation defined by the G18 and section508 standards.
		/// - Parameters:
		///   - u: Luminance computed using the sRGB color space.
		///   - v: Luminance computed using the sRGB color space.
		///   - offset: The offset, typically 0.05 for G18.
		/// - Returns: The contrast ratio.
		public static func luminanceRatioG18(_ u:Linear, _ v:Linear, offset:Linear = 0.05) -> Linear {
			let uo = u + offset
			let vo = v + offset
			
			return max(uo, vo) / min(uo, vo)
		}
		
		public static func luminanceContrastingG18(_ luminance:Linear, ratio:Linear = 4.5, offset:Linear = 0.05) -> Linear {
			let m = 1 / (ratio + 1)
			
			guard luminance > 0 else { return m }
			
			let vo = luminance + offset
			let uo = luminance > m ? vo / ratio : vo * ratio
			let u = uo - offset
			
			return u
		}
	}
}

//	MARK: -

extension CHCLT {
	public struct Transform {
		public struct Effect {
			public enum Mode { case relative, absolute }
			
			public let scalar:Scalar
			public let mode:Mode
			
			public init(_ scalar:Scalar, mode:Mode = .absolute) {
				self.scalar = scalar
				self.mode = mode
			}
		}
		
		public let contrast:Effect?
		public let hue:Effect?
		public let chroma:Effect?
		public let luminance:Effect?
		
		public init(contrast:Effect? = nil, hue:Effect? = nil, chroma:Effect? = nil, luminance:Effect? = nil) {
			self.contrast = contrast
			self.hue = hue
			self.chroma = chroma
			self.luminance = luminance
		}
		
		public static func applyContrast(_ value:Scalar) -> Transform { return Transform(contrast:Effect(value, mode:.absolute)) }
		public static func scaleContrast(_ value:Scalar) -> Transform { return Transform(contrast:Effect(value, mode:.relative)) }
		
		public static func applyHue(_ value:Scalar) -> Transform { return Transform(hue:Effect(value, mode:.absolute)) }
		public static func hueShift(_ value:Scalar) -> Transform { return Transform(hue:Effect(value, mode:.relative)) }
		
		public static func applyChroma(_ value:Scalar) -> Transform { return Transform(chroma:Effect(value, mode:.absolute)) }
		public static func scaleChroma(_ value:Scalar) -> Transform { return Transform(chroma:Effect(value, mode:.relative)) }
	}
}

//	MARK: -

extension CHCLT {
	public struct Adjustment {
		public static let half = Adjustment(contrast:0.5, chroma:0.5)
		
		public let contrast:Scalar
		public let chroma:Scalar
		
		public init(contrast:Scalar = 1.0, chroma:Scalar = 1.0) {
			self.contrast = contrast
			self.chroma = chroma
		}
	}
}

//	MARK: -

extension CHCLT {
	/// Bring each component of vector within the 0 ... 1 range by desaturating
	public static func normalize(_ linear:Linear.Vector3, luminance v:Linear, leavePositive:Bool) -> Linear.Vector3 {
		let v = max(v, 0)
		var vector = linear
		let negative = vector.min()
		
		if negative < 0 {
			let desaturate = v / (v - negative)
			let t = 1 - desaturate
			
			vector *= desaturate
			vector += t * v
		}
		
		if leavePositive {
			return simd_max(vector, .zero)
		}
		
		let positive = vector.max()
		
		if positive > 1 {
			let desaturate = (v - 1) / (v - positive)
			let t = 1 - desaturate
			
			vector *= desaturate
			vector += t * v
		}
		
		vector.clamp(lowerBound:.zero, upperBound:.one)
		
		return vector
	}
	
	//	MARK: Luminance
	
	/// Create a new color with the same hue and given luminance.
	/// Increasing the luminance to the point where the color would be denormalized will instead desaturate the color.
	/// When the color is desaturated, the chroma value is maximized and applying the original luminance will not produce the original color.
	/// When the color is not desaturated, the chroma value may change but the perceptual saturation is preserved.
	/// - Parameters:
	///   - vector: The color.
	///   - v: The luminance of color.
	///   - u: Value from 0 ... 1 to apply to color.  Zero is black, one is white.
	/// - Returns: The adjusted color
	public func applyLuminance(_ vector:Linear.Vector3, luminance v:Linear, apply u:Linear) -> Linear.Vector3 {
		guard u > 0 else { return Vector3.zero }
		guard u < 1 else { return Vector3.one }
		guard v > 0 else { return Linear.vector3(u, u, u) }
		
		let n = CHCLT.normalize(vector, luminance:v, leavePositive:true)
		let s = u / v
		let t = s * n.max()
		
		guard transfer(t) > 1 else { return n * s }
		
		let rgb = display(n)
		let d = rgb.max()
		let maximumPreservingHue = rgb / d
		let m = linear(maximumPreservingHue)
		let w = luminance(m)
		let distanceFromWhite = (1 - u) / (1 - w)
		let whitened = 1 - distanceFromWhite + m * distanceFromWhite
		
		return whitened
	}
	
	public func matchLuminance(_ linear:Linear.Vector3, to color:Linear.Vector3, by value:Scalar) -> Linear.Vector3 {
		let n = 1 - value
		let v = luminance(linear)
		let u = luminance(color)
		
		return applyLuminance(linear, luminance:v, apply:v * n + u * value)
	}
	
	/// Apply the maximum luminance that preserves the ratio of the components.
	public static func illuminate(_ linear:Linear.Vector3) -> Linear.Vector3 {
		let maximum = linear.max()
		
		return maximum.magnitude > 0 ? linear / maximum : .one
	}
	
	//	MARK: Luma
	
	public func luma(_ linear:Vector3) -> Scalar {
		return luma(luminance:luminance(linear))
	}
	
	public func scaleLuma(_ vector:Linear.Vector3, luminance v:Linear, by scalar:Linear) -> Linear.Vector3 {
		return applyLuminance(vector, luminance:v, apply:luminance(luma:luma(luminance:v) * scalar))
	}
	
	public func applyLuma(_ vector:Linear.Vector3, luminance v:Linear, apply u:Linear) -> Linear.Vector3 {
		return applyLuminance(vector, luminance:v, apply:luminance(luma:u))
	}
	
	//	MARK: Contrast
	
	/// True if luminance is below the medium luminance.
	public func isDark(_ linear:Linear.Vector3) -> Bool {
		return contrast.luminanceIsDark(luminance(linear))
	}
	
	/// The contrast of a color is a measure of the distance from medium luminance.
	/// Both black and white have a contrast of 1 and colors with medium luminance have a contrast of 0.
	/// The contrast is computed such that liminal color pairs with contrasts that add to at least 1.0 satisfy the minimum recommended contrast.
	/// - Parameters:
	///   - vector: The color.
	///   - v: The luminance of color.
	/// - Returns: The contrast of color.
	public func contrast(luminance v:Linear) -> Linear {
		return contrast.lumaContrast(luma(luminance:v))
	}
	
	/// Scale the luminance of the color so that the resulting contrast will be scaled by the given amount.
	/// For example, scale by 0.5 to produce a color that contrasts half as much against the same background.
	/// Scaling to 0 will result in a color with medium luminance.
	/// Scaling to negative will result in a contrasting color.
	/// - Parameters:
	///   - linear: The color.
	///   - v: The luminance of color.
	///   - scalar: The scaling factor.
	/// - Returns: The adjusted color.
	public func scaleContrast(_ linear:Linear.Vector3, luminance v:Linear, by scalar:Scalar) -> Linear.Vector3 {
		return applyLuma(linear, luminance:v, apply:contrast.lumaScaleContrast(luma(luminance:v), by:scalar))
	}
	
	/// Adjust the luminance to create a color that contrasts against the same colors as this color.  Negative values create contrasting colors.
	///
	/// Use a value less than `contrast(chclt) - 1` for a contrasting color with the suggested minimum contrast.
	/// - Parameters:
	///   - linear: The color.
	///   - v: The luminance of color.
	///   - value: The contrast of the adjusted color.  Negative values create contrasting colors.  Values near zero contrast poorly.  Values near one contrast well.
	/// - Returns: The adjusted color
	public func applyContrast(_ linear:Linear.Vector3, luminance v:Linear, apply value:Linear) -> Linear.Vector3 {
		return applyLuma(linear, luminance:v, apply:contrast.lumaApplyContrast(luma(luminance:v), value:value))
	}
	
	public func matchContrast(_ linear:Linear.Vector3, to color:Linear.Vector3, by value:Scalar) -> Linear.Vector3 {
		let v = luminance(linear)
		let u = luminance(color)
		
		return applyLuma(linear, luminance:v, apply:contrast.lumaMatchContrast(luma(luminance:v), luma(luminance:u), by:value))
	}
	
	/// Adjust the luminance to create a color that contrasts well against this color, relative to the minimum suggested contrast.
	///
	/// A light and dark color pair with contrasts that add to at least 1.0 satisfies the minimum suggested contrast.
	/// This method will generate the second color of that liminal color pair.
	/// A value of zero will apply the minimum suggested contrast between the colors.
	/// Positive values are the fraction of maximum possible contrast, up to 1.0 which will result in black or white and have the maximum contrast.
	/// Negative values are a fraction of the range below the minimum suggested contrast towards medium luminance.
	///
	/// - contrasting(1) == applyLuminance(-1) == black or white
	/// - contrasting(0) == applyLuminance(contrast() - 1) == minimum suggested contrast
	/// - contrasting(-1)== applyLuminance(0) == medium luminance
	/// - Parameters:
	///   - linear: The color.
	///   - v: The luminance of color.
	///   - value: The contrast adjustment in the range -1 (medium luminance) to 0 (minimum contrast) to 1 (maximum contrast).
	/// - Returns: The adjusted color
	public func contrasting(_ linear:Linear.Vector3, luminance v:Linear, value:Linear) -> Linear.Vector3 {
		return applyLuma(linear, luminance:v, apply:contrast.lumaContrasting(luma(luminance:v), value:value))
	}
	
	//	MARK: Hue
	
	public func hueShift(_ linear:Linear.Vector3, luminance v:Linear, by shift:Linear, apply chroma:Linear) -> Linear.Vector3 {
		return applyChroma(hueShift(linear, luminance:v, by:shift), luminance:v, apply:chroma)
	}
	
	public func huePush(_ linear:Linear.Vector3, from color:Linear.Vector3, minimumShift shift:Linear) -> Linear.Vector3 {
		let v = luminance(linear)
		let w = luminance(color)
		
		guard chroma(color, luminance:w) > 0x1p-6 else { return linear }
		
		let h = hue(linear, luminance:v)
		let g = hue(color, luminance:w)
		let d = h - g
		let e = d.magnitude > 0.5 ? d < 0 ? d + 1 : d - 1 : d
		let s = modf(shift.magnitude).1
		let t = s > 0.5 ? 1 - s : s
		
		guard e.magnitude < t else { return linear }
		
		return hueShift(linear, luminance:v, by:e < 0 ? -e - t : t - e)
	}
	
	public func luminanceRamp(hueStart:Scalar = 0, hueShift:Scalar, chroma:Scalar, luminance from:Scalar, _ to:Scalar, count:Int) -> [Linear.Vector3] {
		return Array<Linear.Vector3>(unsafeUninitializedCapacity:count) { buffer, initialized in
			var hue = hueStart
			
			for index in 0 ..< count {
				let u = from + (to - from) * Scalar(index) / Scalar(count - 1)
				let normalized = pure(hue:hue)
				let luminated = applyLuminance(normalized, luminance:luminance(normalized), apply:u)
				let vector = applyChroma(luminated, luminance:u, apply:chroma)
				
				buffer[index] = vector
				hue += hueShift
			}
			
			initialized = count
		}
	}
	
	public func saturation(_ vector:Linear.Vector3, luminance v:Linear) -> Scalar {
		return simd_length(vector - v)
	}
	
	/// Apply the maximum saturation that preserves the hue of the color.
	public static func saturate(_ vector:Linear.Vector3) -> Linear.Vector3 {
		return illuminate(vector - vector.min())
	}
	
	//	MARK: Chroma
	
	public static func positiveChroma(_ linear:Linear.Vector3, luminance v:Linear) -> Linear {
		let n = 1 - v
		let hueSaturation = linear - v
		let a = n.magnitude > 0 ? (hueSaturation / n).max() : 0
		let b = v.magnitude > 0 ? (hueSaturation / -v).max() : 0
		
		return max(a, b)
	}
	
	public static func negativeChroma(_ linear:Linear.Vector3, luminance v:Linear) -> Linear {
		let n = 1 - v
		let hueSaturation = linear - v
		let a = n.magnitude > 0 ? (hueSaturation / n).min() : 0
		let b = v.magnitude > 0 ? (hueSaturation / -v).min() : 0
		
		return min(a, b)
	}
	
	///	A color with all components equal is desaturated and has a chroma of zero.
	///	A color with a component at 0 or 1 cannot have the saturation increased without denormalizing the color and has a chroma of one.
	///	The chroma of a color is the desaturation scale that would be applied to the maximum color to reach this color.
	/// - Parameter chclt: The color space
	/// - Returns: The croma
	public func chroma(_ linear:Linear.Vector3, luminance v:Linear) -> Scalar {
		return CHCLT.positiveChroma(linear, luminance:v)
	}
	
	/// Scale the chroma of the color.
	/// The color approaches gray as the value approaches zero.
	/// Negative values generate complementary colors.
	/// Values greater than one increase vibrancy and may denormalize the color.
	/// The hue is preserved for positive, inverted for nagative, and lost at zero.
	/// The luminance is preserved.
	public func scaleChroma(_ linear:Linear.Vector3, luminance v:Linear, by scalar:Scalar) -> Linear.Vector3 {
		let t = 1 - scalar
		
		return linear * scalar + v * t
	}
	
	/// Adjust the chroma to create a color with the given relative color intensity.
	/// The color approaches gray as the value approaches zero.
	/// Negative values generate complementary colors.
	/// The hue is preserved for positive, inverted for nagative, and lost at zero.
	/// The luminance is preserved.
	public func applyChroma(_ linear:Linear.Vector3, luminance v:Linear, apply value:Scalar) -> Linear.Vector3 {
		let c = value < 0 ? CHCLT.negativeChroma(linear, luminance:v) : CHCLT.positiveChroma(linear, luminance:v)
		let s = c.magnitude > 0x1p-30 ? value.magnitude / c : 0
		
		return scaleChroma(linear, luminance:v, by:s)
	}
	
	public func matchChroma(_ linear:Linear.Vector3, to color:Linear.Vector3, by value:Scalar) -> Linear.Vector3 {
		let v = luminance(linear)
		let w = luminance(color)
		let c = chroma(linear, luminance:v)
		let d = chroma(color, luminance:w)
		let n = 1 - value
		
		return applyChroma(linear, luminance:v, apply:c * n + d * value)
	}
	
	public func chromaRamp(_ linear:Linear.Vector3, luminance v:Linear, intermediaries:Int = 1, withNegative:Bool = false) -> [Linear.Vector3] {
		let c = CHCLT.positiveChroma(linear, luminance:v)
		
		guard c.magnitude > 0x1p-30 else { return [linear, linear] }
		
		let maximum = 1 / c
		var result = [scaleChroma(linear, luminance:v, by:maximum)]
		
		if intermediaries > 0 {
			for index in 0 ..< intermediaries {
				let value = Linear(intermediaries - index) / Linear(intermediaries + 1)
				
				result.append(scaleChroma(linear, luminance:v, by:maximum * value))
			}
		}
		
		result.append(scaleChroma(linear, luminance:v, by:0))
		
		if withNegative {
			let minimum = 1 / CHCLT.negativeChroma(linear, luminance:v)
			
			if intermediaries > 0 {
				for index in 0 ..< intermediaries {
					let value = Linear(index + 1) / Linear(intermediaries + 1)
					
					result.append(scaleChroma(linear, luminance:v, by:minimum * value))
				}
			}
			
			result.append(scaleChroma(linear, luminance:v, by:minimum))
		}
		
		return result
	}
	
	// MARK: Transform
	
	public func hcl(linear:Linear.Vector3) -> Linear.Vector3 {
		let l = luminance(linear)
		let h = hue(linear, luminance:l)
		let c = chroma(linear, luminance:l)
		
		return Linear.vector3(h, c, luma(luminance:l))
	}
	
	public func transformContrast(_ linear:Linear.Vector3, luminance v:Linear, transform:Transform.Effect) -> Linear.Vector3 {
		switch transform.mode {
		case .relative: return scaleContrast(linear, luminance:v, by:transform.scalar)
		case .absolute: return applyContrast(linear, luminance:v, apply:transform.scalar)
		}
	}
	
	public func transformHue(_ linear:Linear.Vector3, luminance v:Linear, transform:Transform.Effect) -> Linear.Vector3 {
		switch transform.mode {
		case .relative: return hueShift(linear, luminance:v, by:transform.scalar)
		case .absolute: return hueShift(linear, luminance:v, by:transform.scalar - hue(linear, luminance:v))
		}
	}
	
	public func transformChroma(_ linear:Linear.Vector3, luminance v:Linear, transform:Transform.Effect) -> Linear.Vector3 {
		switch transform.mode {
		case .relative: return scaleChroma(linear, luminance:v, by:transform.scalar)
		case .absolute: return applyChroma(linear, luminance:v, apply:transform.scalar)
		}
	}
	
	public func transformLuminance(_ linear:Linear.Vector3, luminance v:Linear, transform:Transform.Effect) -> Linear.Vector3 {
		switch transform.mode {
		case .relative: return linear * transform.scalar
		case .absolute: return applyLuminance(linear, luminance:v, apply:transform.scalar)
		}
	}
	
	public func transform(_ linear:Linear.Vector3, luminance v:Linear, transform:Transform) -> Linear.Vector3 {
		var result = linear
		var v = v
		
		if let effect = transform.contrast {
			result = transformContrast(result, luminance:v, transform:effect)
			v = luminance(result)
		} else if let effect = transform.luminance {
			result = transformLuminance(result, luminance:v, transform:effect)
			v = luminance(result)
		}
		
		if let effect = transform.hue {
			result = transformHue(result, luminance:v, transform:effect)
		}
		
		if let effect = transform.chroma {
			result = transformChroma(result, luminance:v, transform:effect)
		}
		
		return result
	}
}

//	MARK: -

extension CHCLT {
	/// A color in the linear RGB space reached via CHCLT.
	/// # Range
	/// The range of the color components is 0 ... 1 and colors outside this range can be brought within the range using normalize.
	/// # Stability
	/// Shifting the hue will not change the luminance, and will only change the saturation if the colors becomes denormalized, but it will usually change the chroma value.
	/// Changing the chroma will not change the luminance and will not change the hue if chroma remains positive.
	/// Changing the luminance will not change the hue unless color information is lost at the extrema, but it may change the chroma value.
	/// Changing the contrast is equivalent to changing the luminance.
	public struct LinearRGB {
		public static let black = LinearRGB(CHCLT.Vector3.zero)
		public static let white = LinearRGB(CHCLT.Vector3.one)
		
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
			self.init(Linear.vector3(red, green, blue))
		}
		
		public init(gray:Linear) {
			self.init(Linear.vector3(gray, gray, gray))
		}
		
		public init(_ chclt:CHCLT, hue:Scalar) {
			self.init(chclt.pure(hue:hue))
		}
		
		public init(_ chclt:CHCLT, hue:Scalar, luminance u:Linear) {
			self.init(chclt.pure(hue:hue, luminance:u))
		}
		
		public init(_ chclt:CHCLT, hue:Scalar, chroma:Scalar, luminance u:Linear) {
			self.init(chclt.applyChroma(chclt.pure(hue:hue, luminance:u), luminance:u, apply:chroma))
		}
		
		public init(_ chclt:CHCLT, hue:Scalar, chroma:Scalar, luma:Linear) {
			self.init(chclt, hue:hue, chroma:chroma, luminance:chclt.luminance(luma:luma))
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
		public func display(_ chclt:CHCLT, alpha:Scalar = 1) -> CHCLT.Vector4 {
			return Scalar.vector4(chclt.display(vector), alpha)
		}
		
		public func color(_ chclt:CHCLT, alpha:Scalar = 1) -> CHCLT.Color {
			return CHCLT.Color(chclt, linear:vector, alpha:alpha)
		}
		
		/// Interpolate each component towards the component in the target color
		public func interpolated(towards:LinearRGB, by scalar:Scalar) -> LinearRGB {
			let t = 1 - scalar
			let a = vector * t
			let b = towards.vector * scalar
			
			return LinearRGB(a + b)
		}
		
		public func normalized(_ chclt:CHCLT) -> LinearRGB {
			return LinearRGB(CHCLT.normalize(vector, luminance:luminance(chclt), leavePositive:false))
		}
		
		public func isNormal() -> Bool {
			return vector.min() >= 0.0 && vector.max() <= 1.0
		}
		
		//	MARK: Luma
		
		public func luma(_ chclt:CHCLT) -> Scalar {
			return chclt.luma(vector)
		}
		
		public func scaleLuma(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			return LinearRGB(chclt.scaleLuma(vector, luminance:chclt.luminance(vector), by:scalar))
		}
		
		public func applyLuma(_ chclt:CHCLT, value u:Scalar) -> LinearRGB {
			return LinearRGB(chclt.applyLuma(vector, luminance:chclt.luminance(vector), apply:u))
		}
		
		//	MARK: Luminance
		
		public func luminance(_ chclt:CHCLT) -> Linear {
			return chclt.luminance(vector)
		}
		
		public func scaleLuminance(by scalar:Linear) -> LinearRGB {
			return LinearRGB(vector * scalar)
		}
		
		public func applyLuminance(_ chclt:CHCLT, value u:Linear) -> LinearRGB {
			return LinearRGB(chclt.applyLuminance(vector, luminance:chclt.luminance(vector), apply:u))
		}
		
		/// Maximum luminance that may be applied without affecting ratio of components.
		public func maximumLuminancePreservingRatio(_ chclt:CHCLT) -> Linear {
			let d = vector.max()
			
			return d > 0 ? luminance(chclt) / d : 1
		}
		
		public func illuminated() -> LinearRGB {
			return LinearRGB(CHCLT.illuminate(vector))
		}
		
		public func matchLuminance(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			return LinearRGB(chclt.matchLuminance(vector, to:color.vector, by:value))
		}
		
		//	MARK: Contrast
		
		public func isDark(_ chclt:CHCLT) -> Bool {
			return chclt.isDark(vector)
		}
		
		public func contrast(_ chclt:CHCLT) -> Linear {
			return chclt.contrast(luminance:luminance(chclt))
		}
		
		public func scaleContrast(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			return LinearRGB(chclt.scaleContrast(vector, luminance:luminance(chclt), by:scalar))
		}
		
		public func applyContrast(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return LinearRGB(chclt.applyContrast(vector, luminance:luminance(chclt), apply:value))
		}
		
		public func opposing(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return applyContrast(chclt, value:-value)
		}
		
		public func contrasting(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return LinearRGB(chclt.contrasting(vector, luminance:luminance(chclt), value:value))
		}
		
		public func matchContrast(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			return LinearRGB(chclt.matchContrast(vector, to:color.vector, by:value))
		}
		
		//	MARK: Chroma
		
		public func chroma(_ chclt:CHCLT) -> Scalar {
			return chclt.chroma(vector, luminance:chclt.luminance(vector))
		}
		
		public func scaleChroma(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			return LinearRGB(chclt.scaleChroma(vector, luminance:luminance(chclt), by:scalar))
		}
		
		public func applyChroma(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return LinearRGB(chclt.applyChroma(vector, luminance:luminance(chclt), apply:value))
		}
		
		public func matchChroma(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			return LinearRGB(chclt.matchChroma(vector, to:color.vector, by:value))
		}
		
		//	MARK: Saturation
		
		public func saturation(_ chclt:CHCLT) -> Scalar {
			let v = chclt.luminance(vector)
			let hueSaturation = vector - v
			
			return simd_length(hueSaturation)
		}
		
		public func applySaturation(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			let s = saturation(chclt)
			
			return s > 0 ? scaleChroma(chclt, by:value / s) : self
		}
		
		public func matchSaturation(_ chclt:CHCLT, to color:LinearRGB, by value:Scalar) -> LinearRGB {
			let s = saturation(chclt)
			let t = color.saturation(chclt)
			let n = 1 - value
			
			return applySaturation(chclt, value:s * n + t * value)
		}
		
		public func saturated() -> LinearRGB {
			return LinearRGB(CHCLT.saturate(vector))
		}
		
		//	MARK: Hue
		
		public func hue(_ chclt:CHCLT) -> Linear {
			return chclt.hue(vector, luminance:chclt.luminance(vector))
		}
		
		public func hueShifted(_ chclt:CHCLT, by shift:Linear) -> LinearRGB {
			return LinearRGB(chclt.hueShift(vector, luminance:luminance(chclt), by:shift))
		}
		
		public func huePushed(_ chclt:CHCLT, from color:LinearRGB, minimumShift shift:Linear) -> LinearRGB {
			return LinearRGB(chclt.huePush(vector, from:color.vector, minimumShift:shift))
		}
		
		//	MARK: Transform
		
		public func transform(_ chclt:CHCLT, transform:Transform) -> LinearRGB {
			return LinearRGB(chclt.transform(vector, luminance:luminance(chclt), transform:transform))
		}
	}
}

//	MARK: -

extension CHCLT {
	public enum CIEXYZ {
		public static let d50:CHCLT.Vector3 = tristimulus(x:0.34567, y:0.35850)
		public static let d55:CHCLT.Vector3 = tristimulus(x:0.33242, y:0.34743)
		public static let d65:CHCLT.Vector3 = tristimulus(x:0.31271, y:0.32902)
		public static let d75:CHCLT.Vector3 = tristimulus(x:0.29902, y:0.31485)
		public static let d93:CHCLT.Vector3 = tristimulus(x:0.28315, y:0.29711)
		public static let f7_d65:CHCLT.Vector3 = tristimulus(x:0.31292, y:0.32933)
		public static let f8_d50:CHCLT.Vector3 = tristimulus(x:0.34588, y:0.35875)
		public static let ansi65:CHCLT.Vector3 = tristimulus(x:0.313, y:0.337)
		public static let dci:CHCLT.Vector3 = tristimulus(x:0.314, y:0.351)
		public static let aces:CHCLT.Vector3 = tristimulus(x:0.32168, y:0.33767)
		
		public static let rgb_to_xyz = CHCLT.Linear.Matrix3x3([0.49, 0.17697, 0.0] / 0.17697, [0.31, 0.8124, 0.01] / 0.17697, [0.2, 0.01063, 0.99] / 0.17697)
		public static let rgb_to_xyz_romm_d50 = rgb_to_xyz_with_chromaticities(xWhite:0.345704, yWhite:0.35854, xRed:0.734699, yRed:0.265301, xGreen:0.159597, yGreen:0.840403, xBlue:0.036598, yBlue:0.000105)
		public static let rgb_to_xyz_smpte240m_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3291, xRed:0.630, yRed:0.340, xGreen:0.310, yGreen:0.595, xBlue:0.155, yBlue:0.070)
		public static let rgb_to_xyz_bt601_625_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3290, xRed:0.640, yRed:0.330, xGreen:0.290, yGreen:0.600, xBlue:0.150, yBlue:0.060)
		public static let rgb_to_xyz_bt601_525_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3290, xRed:0.630, yRed:0.340, xGreen:0.310, yGreen:0.595, xBlue:0.155, yBlue:0.070)
		public static let rgb_to_xyz_bt709_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3290, xRed:0.640, yRed:0.330, xGreen:0.300, yGreen:0.600, xBlue:0.150, yBlue:0.060)
		public static let rgb_to_xyz_bt2020_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3290, xRed:0.708, yRed:0.292, xGreen:0.170, yGreen:0.797, xBlue:0.131, yBlue:0.046)
		public static let rgb_to_xyz_bt2100_d65 = rgb_to_xyz_bt2020_d65
		public static let rgb_to_xyz_sRGB_d65 = rgb_to_xyz_bt709_d65
		public static let rgb_to_xyz_adobeRGB_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3290, xRed:0.640, yRed:0.330, xGreen:0.210, yGreen:0.710, xBlue:0.150, yBlue:0.060)
		public static let rgb_to_xyz_displayP3_d65 = rgb_to_xyz_with_chromaticities(xWhite:0.3127, yWhite:0.3290, xRed:0.680, yRed:0.320, xGreen:0.265, yGreen:0.690, xBlue:0.150, yBlue:0.060)
		public static let rgb_to_xyz_theaterP3_dci = rgb_to_xyz_with_chromaticities(xWhite:0.314, yWhite:0.351, xRed:0.680, yRed:0.320, xGreen:0.265, yGreen:0.690, xBlue:0.150, yBlue:0.060)
		public static let rgb_to_xyz_aces2065 = rgb_to_xyz_with_chromaticities(xWhite:0.32168, yWhite:0.33767, xRed:0.7347, yRed:0.2653, xGreen:0.0, yGreen:1.0, xBlue:0.0001, yBlue:-0.077)
		public static let rgb_to_xyz_acescg = rgb_to_xyz_with_chromaticities(xWhite:0.32168, yWhite:0.33767, xRed:0.713, yRed:0.293, xGreen:0.165, yGreen:0.830, xBlue:0.128, yBlue:0.044)
		public static let rgb_to_xyz_eci_d50 = rgb_to_xyz_with_chromaticities(xWhite:0.34567, yWhite:0.35850, xRed:0.670, yRed:0.330, xGreen:0.210, yGreen:0.710, xBlue:0.140, yBlue:0.080)
		
		public static func tristimulus(x:CHCLT.Linear, y:CHCLT.Linear) -> CHCLT.Linear.Vector3 {
			return CHCLT.Linear.vector3(x / y, 1, (1 - x - y) / y)
		}
		
		public static func rgb_to_xyz_with_chromaticities(xWhite:CHCLT.Linear, yWhite:CHCLT.Linear, xRed:CHCLT.Linear, yRed:CHCLT.Linear, xGreen:CHCLT.Linear, yGreen:CHCLT.Linear, xBlue:CHCLT.Linear, yBlue:CHCLT.Linear) -> CHCLT.Linear.Matrix3x3 {
			let white = tristimulus(x:xWhite, y:yWhite)
			let red = tristimulus(x:xRed, y:yRed)
			let green = tristimulus(x:xGreen, y:yGreen)
			let blue = tristimulus(x:xBlue, y:yBlue)
			let primaries = CHCLT.Linear.Matrix3x3(red, green, blue)
			let inverse = primaries.inverse
			let s = inverse * white
			
			return CHCLT.Linear.Matrix3x3(red * s.x, green * s.y, blue * s.z)
		}
		
		public static func luminanceCoefficients(_ rgb_to_xyz:CHCLT.Linear.Matrix3x3) -> CHCLT.Linear.Vector3 {
			return CHCLT.Linear.vector3(rgb_to_xyz.columns.0.y, rgb_to_xyz.columns.1.y, rgb_to_xyz.columns.2.y)
		}
		
		public static func fromLinearRGB(rgb:CHCLT.Linear.Vector3, rgb_to_xyz:CHCLT.Linear.Matrix3x3) -> CHCLT.Linear.Vector3 {
			return rgb_to_xyz * rgb
		}
		
		public static func toLinearRGB(xyz:CHCLT.Linear.Vector3, rgb_to_xyz:CHCLT.Linear.Matrix3x3) -> CHCLT.Linear.Vector3 {
			return rgb_to_xyz.inverse * xyz
		}
		
		public static func xyY(xyz:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			let d = xyz.sum()
			
			return CHCLT.Linear.vector3(xyz.x / d, xyz.y / d, xyz.y)
		}
	}
}

//	MARK: -

extension CHCLT {
	public enum YUV {
		public static let rgb_to_yuv_bt601 = YUV.rgb_to_yuv(coefficients:CHCLT.Linear.vector3(0.299, 0.587, 0.114), maximum:CHCLT.Linear.vector2(0.436, 0.615))
		public static let rgb_to_ycc_bt601 = YUV.rgb_to_yuv(coefficients:CHCLT.Linear.vector3(0.299, 0.587, 0.114), maximum:CHCLT.Linear.vector2(0.5, 0.5))
		public static let rgb_to_ydd_bt601 = YUV.rgb_to_yuv(coefficients:CHCLT.Linear.vector3(0.299, 0.587, 0.114), maximum:CHCLT.Linear.vector2(1.333, -1.333))
		public static let rgb_to_yuv_bt709 = YUV.rgb_to_yuv(coefficients:CHCLT.Linear.vector3(0.2126, 0.7152, 0.0722), maximum:CHCLT.Linear.vector2(0.436, 0.615))
		public static let rgb_to_ycc_bt709 = YUV.rgb_to_yuv(coefficients:CHCLT.Linear.vector3(0.2126, 0.7152, 0.0722), maximum:CHCLT.Linear.vector2(0.5, 0.5))
		
		public static func rgb_to_yuv(coefficients:CHCLT.Linear.Vector3, maximum:CHCLT.Linear.Vector2) -> CHCLT.Linear.Matrix3x3 {
			let um = maximum.x / (1.0 - coefficients.z)
			let vm = maximum.y / (1.0 - coefficients.x)
			
			let c0 = CHCLT.Linear.vector3(coefficients.x, -coefficients.x * um, maximum.y)
			let c1 = CHCLT.Linear.vector3(coefficients.y, -coefficients.y * um, -coefficients.y * vm)
			let c2 = CHCLT.Linear.vector3(coefficients.z, maximum.x, -coefficients.z * vm)
			
			return CHCLT.Linear.Matrix3x3(c0, c1, c2)
		}
		
		public static func fromLinearRGB(rgb:CHCLT.Linear.Vector3, rgb_to_yuv:CHCLT.Linear.Matrix3x3) -> CHCLT.Linear.Vector3 {
			return rgb_to_yuv * rgb
		}
		
		public static func toLinearRGB(yuv:CHCLT.Linear.Vector3, rgb_to_yuv:CHCLT.Linear.Matrix3x3) -> CHCLT.Linear.Vector3 {
			return rgb_to_yuv.inverse * yuv
		}
	}
}

//	MARK: -

extension CHCLT {
	public struct CLSH {
		public static let sRGB = CLSH(rgb_to_lms:OKLAB.m1_x_sRGB, lms_to_lab:OKLAB.m2)
		
		public let rgb2lms, lms2rgb, lms2lab, lab2lms:CHCLT.Linear.Matrix3x3
		public let zeroAlignRed:CHCLT.Scalar
		
		public init(rgb_to_lms:CHCLT.Linear.Matrix3x3, lms_to_lab:CHCLT.Linear.Matrix3x3) {
			rgb2lms = rgb_to_lms
			lms2rgb = rgb_to_lms.inverse
			lms2lab = lms_to_lab
			lab2lms = lms_to_lab.inverse
			
			let red = CHCLT.Linear.vector3(1, 0, 0)
			var lms = rgb_to_lms * red
			
			lms.x = cbrt(lms.x)
			lms.y = cbrt(lms.y)
			lms.z = cbrt(lms.z)
			
			let lab = lms_to_lab * lms
			let hue = atan2(lab.z, lab.y)
			
			zeroAlignRed = hue * 0.5 / .pi
		}
		
		public init(rgb_to_xyz_d65:CHCLT.Linear.Matrix3x3) {
			self.init(rgb_to_lms:OKLAB.m1 * rgb_to_xyz_d65, lms_to_lab:OKLAB.m2)
		}
		
		public func lab(rgb:CHCLT.Linear.Vector3) -> CHCLT.Scalar.Vector3 {
			var lms = rgb2lms * rgb
			
			lms.x = cbrt(lms.x)
			lms.y = cbrt(lms.y)
			lms.z = cbrt(lms.z)
			
			return lms2lab * lms
		}
		
		public func rgb(lab:CHCLT.Scalar.Vector3) -> CHCLT.Linear.Vector3 {
			let l = lab2lms * lab
			let lms = l * l * l
			
			return lms2rgb * lms
		}
		
		public func lch(lab:CHCLT.Scalar.Vector3) -> CHCLT.Scalar.Vector3 {
			return CHCLT.Linear.vector3(lab.x, hypot(lab.z, lab.y), atan2(lab.z, lab.y))
		}
		
		public func lab(lch:CHCLT.Scalar.Vector3) -> CHCLT.Scalar.Vector3 {
			let sc = lch.z.sincos()
			
			return CHCLT.Linear.vector3(lch.x, lch.y * sc.__cosval, lch.y * sc.__sinval)
		}
		
		///	k = a(l+xd)³ + b(l+xe)³ + c(l+xf)³
		private static func maximumChromaRoot(a:Linear, b:Linear, c:Linear, d:Linear, e:Linear, f:Linear, l:Linear, k:Linear) -> Linear {
			//	k = a(l+xd)³ + b(l+xe)³ + c(l+xf)³
			//	k = al³ + 3al²xd + 3alx²d² + ax³d³ + bl³ + 3bl²xe + 3blx²e² + bx³e³ + cl³ + 3cl²xf + 3clx²f² + cx³f³
			//	k = (a+b+c)l³ + 3l²(ad + be + cf)x + 3l(ad² + be² + cf²)x² + (ad³ + be³ + cf³)x³
			
			let p0 = (a + b + c) * l * l * l - k
			let p1 = 3 * (a * d + b * e + c * f) * l * l
			let p2 = 3 * (a * d * d + b * e * e + c * f * f) * l
			let p3 = (a * d * d * d + b * e * e * e + c * f * f * f)
			
			guard p0.magnitude > 0 else { return 0 }
			guard p3.magnitude > 0 else { return Polynomial.quadraticRoots(a:p2, b:p1, c:p0).filter { $0 >= 0 }.min() ?? 1 }
			
			let roots = Polynomial.cubicRoots(a:p3, b:p2, c:p1, d:p0)
			
			return roots.filter { $0 >= 0 }.min() ?? 1
		}
		
		public func maximumChroma(l:Scalar, sine:Scalar, cosine:Scalar) -> CHCLT.Scalar {
			let h4 = lab2lms.columns.1.x * cosine + lab2lms.columns.2.x * sine
			let h5 = lab2lms.columns.1.y * cosine + lab2lms.columns.2.y * sine
			let h6 = lab2lms.columns.1.z * cosine + lab2lms.columns.2.z * sine
			
			let r0 = CLSH.maximumChromaRoot(a:lms2rgb.columns.0.x, b:lms2rgb.columns.1.x, c:lms2rgb.columns.2.x, d:h4, e:h5, f:h6, l:l, k:0)
			let r1 = CLSH.maximumChromaRoot(a:lms2rgb.columns.0.x, b:lms2rgb.columns.1.x, c:lms2rgb.columns.2.x, d:h4, e:h5, f:h6, l:l, k:1)
			let g0 = CLSH.maximumChromaRoot(a:lms2rgb.columns.0.y, b:lms2rgb.columns.1.y, c:lms2rgb.columns.2.y, d:h4, e:h5, f:h6, l:l, k:0)
			let g1 = CLSH.maximumChromaRoot(a:lms2rgb.columns.0.y, b:lms2rgb.columns.1.y, c:lms2rgb.columns.2.y, d:h4, e:h5, f:h6, l:l, k:1)
			let b0 = CLSH.maximumChromaRoot(a:lms2rgb.columns.0.z, b:lms2rgb.columns.1.z, c:lms2rgb.columns.2.z, d:h4, e:h5, f:h6, l:l, k:0)
			let b1 = CLSH.maximumChromaRoot(a:lms2rgb.columns.0.z, b:lms2rgb.columns.1.z, c:lms2rgb.columns.2.z, d:h4, e:h5, f:h6, l:l, k:1)
			
			return min(r0, r1, g0, g1, b0, b1)
		}
		
		public func clsh(rgb:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			var clsh = lch(lab:lab(rgb:rgb))
			
			if clsh.y > 0 {
				let sc = clsh.z.sincos()
				let mc = maximumChroma(l:clsh.x, sine:sc.__sinval, cosine:sc.__cosval)
				
				if mc > 0 {
					clsh.y /= mc
					clsh.z = modf(clsh.z * 0.5 / .pi + 1.0 - zeroAlignRed).1
				} else {
					clsh.y = 0
					clsh.z = 0
				}
			} else {
				clsh.z = 0
			}
			
			return clsh
		}
		
		public func rgb(clsh:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			guard clsh.x > 0 else { return CHCLT.Linear.Vector3.zero }
			guard clsh.x < 1 else { return CHCLT.Linear.Vector3.one }
			
			var lab = CHCLT.Linear.vector3(clsh.x, 0, 0)
			
			if clsh.y.magnitude > 0 {
				let turns = clsh.z + zeroAlignRed
				let sc = turns.sincosturns()
				let mc = maximumChroma(l:clsh.x, sine:sc.__sinval, cosine:sc.__cosval)
				let c = mc * clsh.y
				
				lab.y = c * sc.__cosval
				lab.z = c * sc.__sinval
			}
			
			return rgb(lab:lab)
		}
	}
	
	public func clsh(linearRGB:Vector3) -> Vector3 {
		return CLSH.sRGB.clsh(rgb:linearRGB)
	}
	
	public func linearRGB(clsh:Vector3) -> Vector3 {
		let rgb = CLSH.sRGB.rgb(clsh:clsh)
		
		return rgb.clamped(lowerBound:Linear.Vector3.zero, upperBound:Linear.Vector3.one)
	}
}

//	MARK: -

extension CHCLT {
	public enum OKLAB {
		public static let normalizeLCH = CHCLT.Scalar.vector3(1.0, 0.5, 2.0 * .pi)
		public static let m1 = CHCLT.Linear.Matrix3x3([0.8189330101, 0.0329845436, 0.0482003018], [0.3618667424, 0.9293118715, 0.2643662691], [-0.1288597137, 0.0361456387, 0.6338517070])
		public static let m1i = m1.inverse
		public static let m2 = CHCLT.Linear.Matrix3x3([0.2104542553, 1.9779984951, 0.0259040371], [0.7936177850, -2.4285922050, 0.7827717662], [-0.0040720468, 0.4505937099, -0.8086757660])
		public static let m2i = m2.inverse
		public static let m1_x_sRGB = CHCLT.Linear.Matrix3x3([0.4122214708, 0.2119034982, 0.0883024619], [0.5363325363, 0.6806995451, 0.2817188376], [0.0514459929, 0.1073969566, 0.6299787005])
		
		public static func toXYZ(lab:CHCLT.Linear.Vector3, white:CHCLT.Linear.Vector3 = CIEXYZ.d65) -> CHCLT.Linear.Vector3 {
			let linear = OKLAB.m2i * lab
			let lms = linear * linear * linear
			let xyz = OKLAB.m1i * lms
			
			return xyz
		}
		
		public static func fromXYZ(xyz:CHCLT.Linear.Vector3, white:CHCLT.Linear.Vector3 = CIEXYZ.d65) -> CHCLT.Linear.Vector3 {
			var lms = OKLAB.m1 * xyz
			
			lms.x = cbrt(lms.x)
			lms.y = cbrt(lms.y)
			lms.z = cbrt(lms.z)
			
			let lab = OKLAB.m2 * lms
			
			return lab
		}
		
		public static func toLCH(lab:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			return CHCLT.Linear.vector3(lab.x, hypot(lab.z, lab.y), atan2(lab.z, lab.y))
		}
		
		public static func fromLCH(lch:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			let sc = lch.z.sincos()
			
			return CHCLT.Linear.vector3(lch.x, lch.y * sc.__cosval, lch.y * sc.__sinval)
		}
	}
	
	public func oklch(linearRGB:Vector3) -> Vector3 {
		let xyz = ciexyz(linearRGB:linearRGB)
		let lab = OKLAB.fromXYZ(xyz:xyz)
		var lch = OKLAB.toLCH(lab:lab) / OKLAB.normalizeLCH
		
		lch.z = modf(lch.z + 1.0).1
		
		return lch
	}
	
	public func linearRGB(oklch:Vector3) -> Vector3 {
		let lch = oklch * OKLAB.normalizeLCH
		let lab = OKLAB.fromLCH(lch:lch)
		let xyz = OKLAB.toXYZ(lab:lab)
		
		return linearRGB(ciexyz:xyz)
	}
}

//	MARK: -

extension CHCLT {
	public enum CIELAB {
		public static let normalizeLCH = CHCLT.Scalar.vector3(100.0, 200.0, 2.0 * .pi)
		public static let genericWhite = CIEXYZ.d50
		
		public static func toXYZ(_ t:CHCLT.Linear) -> CHCLT.Linear {
			let o:Linear = 6.0 / 29.0
			
			if t > o {
				return t * t * t
			} else {
				let d:Linear = 3.0 * o * o
				let p:Linear = 4.0 / 29.0
				
				return d * (t - p)
			}
		}
		
		public static func toXYZ(lab:CHCLT.Linear.Vector3, white:CHCLT.Linear.Vector3 = CIEXYZ.d65) -> CHCLT.Linear.Vector3 {
			let l = (lab.x + 16.0) / 116.0
			let x = l + lab.y / 500.0
			let z = l - lab.z / 200.0
			
			return white * CHCLT.Linear.vector3(toXYZ(x), toXYZ(l), toXYZ(z))
		}
		
		public static func fromXYZ(_ t:CHCLT.Linear) -> CHCLT.Linear {
			let o:Linear = 6.0 / 29.0
			let o2 = o * o
			let o3 = o2 * o
			
			if t > o3 {
				return cbrt(t)
			} else {
				let d:Linear = 3.0 * o2
				let p:Linear = 4.0 / 29.0
				
				return t / d + p
			}
		}
		
		public static func fromXYZ(xyz:CHCLT.Linear.Vector3, white:CHCLT.Linear.Vector3 = CIEXYZ.d65) -> CHCLT.Linear.Vector3 {
			let xyz = xyz / white
			let x = fromXYZ(xyz.x)
			let y = fromXYZ(xyz.y)
			let z = fromXYZ(xyz.z)
			
			return CHCLT.Linear.vector3(116.0 * y - 16.0, 500.0 * (x - y), 200.0 * (y - z))
		}
		
		public static func toLCH(lab:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			return CHCLT.Linear.vector3(lab.x, hypot(lab.z, lab.y), atan2(lab.z, lab.y))
		}
		
		public static func fromLCH(lch:CHCLT.Linear.Vector3) -> CHCLT.Linear.Vector3 {
			let sc = lch.z.sincos()
			
			return CHCLT.Linear.vector3(lch.x, lch.y * sc.__cosval, lch.y * sc.__sinval)
		}
		
		public static func difference_cie76(_ lab1:CHCLT.Linear.Vector3, _ lab2:CHCLT.Linear.Vector3) -> Scalar {
			return simd_distance(lab1, lab2)
		}
		
		public static func difference_cie94(_ lab1:CHCLT.Linear.Vector3, _ lab2:CHCLT.Linear.Vector3) -> Scalar {
			let dl = lab1.x - lab2.x
			let c1 = hypot(lab1.y, lab1.z)
			let c2 = hypot(lab2.y, lab2.z)
			let dc = c1 - c2
			let da = lab1.y - lab2.y
			let db = lab1.z - lab2.z
			let hh = da * da + db * db - dc * dc
			//let hh = simd_distance_squared(lab1, lab2) - dl * dl - dc * dc
			let dh = hh.squareRoot()
			let sl = 1.0
			let sc = 1.0 + 0.45 * c1
			let sh = 1.0 + 0.15 * c2
			let v = Scalar.vector3(dl / sl, dc / sc, dh / sh)
			
			return simd_length(v)
		}
		
//		public static func difference_cie2000(_ lab1:CHCLT.Linear.Vector3, _ lab2:CHCLT.Linear.Vector3) -> Scalar {
//			return 0.000000
//		}
		
		public static func difference(_ lab1:CHCLT.Linear.Vector3, _ lab2:CHCLT.Linear.Vector3) -> Scalar {
			return difference_cie94(lab1, lab2)
		}
	}
	
	public func cielab(linearRGB:Vector3) -> Vector3 {
		return CIELAB.fromXYZ(xyz:ciexyz(linearRGB:linearRGB), white:whitepoint())
	}
	
	public func linearRGB(cielab:Vector3) -> Vector3 {
		return linearRGB(ciexyz:CIELAB.toXYZ(lab:cielab, white:whitepoint()))
	}
	
	public func lchab(linearRGB:Vector3) -> Vector3 {
		let lab = cielab(linearRGB:linearRGB)
		var lch = CIELAB.toLCH(lab:lab) / CIELAB.normalizeLCH
		
		lch.z = modf(lch.z + 1.0).1
		
		return lch
	}
	
	public func linearRGB(lchab:Vector3) -> Vector3 {
		let lch = lchab * CIELAB.normalizeLCH
		let lab = CIELAB.fromLCH(lch:lch)
		
		return linearRGB(cielab:lab)
	}
}

//	MARK: -

extension CHCLT {
	public static var `default`:CHCLT = CHCLT_sRGB.standard
}

//	MARK: -

public class CHCLT_Linear: CHCLT {
	public static let sRGB = CHCLT_Linear(CHCLT.CIEXYZ.rgb_to_xyz_sRGB_d65, contrast:CHCLT_sRGB.contrast)
	public static let aces = CHCLT_Linear(CHCLT.CIEXYZ.rgb_to_xyz_acescg, contrast:CHCLT.Contrast(0.5))
}

//	MARK: -

public class CHCLT_Pure: CHCLT {
	public static let y240 = CHCLT_Pure(CHCLT.CIEXYZ.rgb_to_xyz_smpte240m_d65, exponent:2)
	public static let y601 = CHCLT_Pure(CHCLT_BT.y601.toCIEXYZ, exponent:19 / 10, coefficients:CHCLT_BT.y601.coefficients)
	public static let y709 = CHCLT_Pure(CHCLT.CIEXYZ.rgb_to_xyz_bt709_d65, exponent:19 / 10)
	public static let y2020 = CHCLT_Pure(CHCLT.CIEXYZ.rgb_to_xyz_bt2020_d65, exponent:19 / 10)
	public static let sRGB = CHCLT_Pure(CHCLT.CIEXYZ.rgb_to_xyz_sRGB_d65, exponent:11 / 5)
	public static let dciP3 = CHCLT_Pure(CHCLT.CIEXYZ.rgb_to_xyz_theaterP3_dci, exponent:13 / 5)
	public static let adobeRGB = CHCLT_Pure(CHCLT.CIEXYZ.rgb_to_xyz_adobeRGB_d65, exponent:563 / 256)
	
	public let exponent:Linear
	
	public init(_ toXYZ:Scalar.Matrix3x3, exponent:Linear, contrast:CHCLT.Contrast, coefficients:Vector3? = nil) {
		self.exponent = exponent
		super.init(toXYZ, contrast:contrast, coefficients:coefficients)
	}
	
	public convenience init(_ toXYZ:Scalar.Matrix3x3, exponent:Linear, coefficients:Vector3? = nil) {
		self.init(toXYZ, exponent:exponent, contrast:CHCLT.Contrast(pow(0.5, exponent)), coefficients:coefficients)
	}
	
	public override func linear(_ value:Scalar) -> Linear {
		return pow(value.magnitude, exponent - 1.0) * value
	}
	
	public override func transfer(_ value:Linear) -> Scalar {
		return pow(value, 1.0 / exponent)
	}
	
	public override func hash(into hasher: inout Hasher) {
		super.hash(into:&hasher)
		hasher.combine(exponent)
	}
	
	public override func isEqual(to chclt:CHCLT) -> Bool {
		return exponent == (chclt as? CHCLT_Pure)?.exponent ?? 1 && super.isEqual(to:chclt)
	}
}

//	MARK: -

public class CHCLT_sRGB: CHCLT {
	public static let displayP3 = CHCLT_sRGB(CHCLT.CIEXYZ.rgb_to_xyz_displayP3_d65)
	public static let standard = CHCLT_sRGB(CHCLT.CIEXYZ.rgb_to_xyz_sRGB_d65)
	public static let g18 = CHCLT_sRGB(CHCLT.CIEXYZ.rgb_to_xyz_sRGB_d65, contrast:CHCLT.Contrast(2 / 11, mediumLuma:CHCLT_sRGB.transfer(2 / 11)))
	
	public static let contrast = CHCLT.Contrast(CHCLT_sRGB.linear(0.5))
	
	public override init(_ toXYZ:Scalar.Matrix3x3, contrast:CHCLT.Contrast = CHCLT_sRGB.contrast, coefficients:Vector3? = nil) {
		super.init(toXYZ, contrast:contrast, coefficients:coefficients)
	}
	
	public static func linear(_ value:Scalar) -> Linear {
		return value > 11.0 / 280.0 ? pow((200.0 * value + 11.0) / 211.0, 12.0 / 5.0) : value / 12.9232102
	}
	
	public static func transfer(_ value:Linear) -> Scalar {
		return value > 11.0 / 280.0 / 12.9232102 ? (211.0 * pow(value, 5.0 / 12.0) - 11.0) / 200.0 : value * 12.9232102
	}
	
	public override func linear(_ value:Scalar) -> Linear {
		return CHCLT_sRGB.linear(value)
	}
	
	public override func transfer(_ value:Linear) -> Scalar {
		return CHCLT_sRGB.transfer(value)
	}
}

//	MARK: -

public class CHCLT_BT: CHCLT {
	public static let y601 = CHCLT_BT(CHCLT.CIEXYZ.rgb_to_xyz_bt601_525_d65, coefficients:CHCLT.Linear.vector3(0.299, 0.587, 0.114))
	public static let y709 = CHCLT_BT(CHCLT.CIEXYZ.rgb_to_xyz_bt709_d65)
	public static let y2020 = CHCLT_BT(CHCLT.CIEXYZ.rgb_to_xyz_bt2020_d65)
	public static let y2100 = y2020
	
	public static let contrast = CHCLT.Contrast(CHCLT_BT.linear(0.5))
	
	public override init(_ toXYZ:Scalar.Matrix3x3, contrast:CHCLT.Contrast = CHCLT_BT.contrast, coefficients:Vector3? = nil) {
		super.init(toXYZ, contrast:contrast, coefficients:coefficients)
	}
	
	public static func linear(_ value:Scalar) -> Linear {
		return value > 0.081 ? pow((value + 0.099) / 1.099, 20.0 / 9.0) : value / 4.5
	}
	
	public static func transfer(_ value:Linear) -> Scalar {
		return value > 0.018 ? 1.099 * pow(value, 9.0 / 20.0) - 0.099 : value * 4.5
	}
	
	public override func linear(_ value:Scalar) -> Linear {
		return CHCLT_BT.linear(value)
	}
	
	public override func transfer(_ value:Linear) -> Scalar {
		return CHCLT_BT.transfer(value)
	}
}

//	MARK: -

public class CHCLT_ROMM: CHCLT {
	public static let standard = CHCLT_ROMM(CHCLT.CIEXYZ.rgb_to_xyz_romm_d50)
	
	public static let contrast = CHCLT.Contrast(CHCLT_ROMM.linear(0.5))
	
	public override init(_ toXYZ:Scalar.Matrix3x3, contrast:CHCLT.Contrast = CHCLT_ROMM.contrast, coefficients:Vector3? = nil) {
		super.init(toXYZ, contrast:contrast, coefficients:coefficients)
	}
	
	public static func linear(_ value:Scalar) -> Linear {
		return value > 0x1p-5 ? pow(value, 9.0 / 5.0) : value / 16.0
	}
	
	public static func transfer(_ value:Linear) -> Scalar {
		return value > 0x1p-9 ? pow(value, 5.0 / 9.0) : value * 16.0
	}
	
	public override func linear(_ value:Scalar) -> Linear {
		return CHCLT_ROMM.linear(value)
	}
	
	public override func transfer(_ value:Linear) -> Scalar {
		return CHCLT_ROMM.transfer(value)
	}
}
