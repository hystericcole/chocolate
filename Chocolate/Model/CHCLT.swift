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
	/// Luminance that is considered medium.  Color pairs with luminances straddling this value are suitable as foreground and background colors.  Used to identify contrasting colors.  Values in the range 0.1 ... 0.5 are valid.
	/// 
	/// Contrast is computed as a ratio or difference of luminance between two colors.  CHCLT uses a ratio.  To compute the ratio, take the luminances of two colors, add the offset to each, then divide the larger sum by the smaller sum.
	/// 
	/// CHCLT chooses the ratio and offset so that the medium luminance is a value, not a range.  The medium luminance (m), ratio (r) and offset (1/d) are related as follows:
	/// ```
	/// m = (√(d+1)-1) / d = 1/(r + 1)
	/// d = (1 - 2m) / m² = r² - 1
	/// r = √(d+1) = 1/m - 1
	/// ```
	/// 
	/// The standard medium luminance for CHCLT is 1/4, which corresponds to a ratio of 3 and 1/8 offset.  Compute the ratio of 2 colors with luminance a and b as follows:
	/// ```
	/// ratio = (max(a, b) + 1/8) / (min(a, b) + 1/8)
	/// ```
	/// When the ratio is > 3, the colors are considered to have sufficient contrast.  The contrast of a single color is computed such that two opposing colors with contrasts that add to 1 will have this ratio.
	/// 
	/// # G18
	/// The G18 contrast standard calls for a ratio of 4.5 and offset of 0.05, which puts medium luminance in the range 21/120 ... 22/120.
	/// 
	/// - Use a medium luminance of 2/11 (0.182) to conform to the 4.5 ratio of G18.
	/// 
	/// The standard CHCLT contrast ratio is 2/3 that of G18, but the visible contrast of the colors is similar.
	func mediumLuminance() -> CHCLT.Scalar
	
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
	
	/// A color in the linear RGB space reached via the CHCLT.
	/// # Range
	/// The range of the color components is 0 ... 1 and colors outside this range can be brought within the range using normalize
	/// # Stability
	/// Shifting the hue will not change the luminance, but it will usually change the chroma.  Changing the chroma will not change the luminance and will not change the hue if chroma remains positive.  Changing the luminance will not change the hue unless color information is lost at the extrema, but it may change the saturation.  Changing the contrast is equivalent to changing the luminance.
	public struct LinearRGB {
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
		
		public init(_ chclt:CHCLT, hue:Scalar, luminance u:Linear) {
			guard u > 0 else { self.init(.zero); return }
			guard u < 1 else { self.init(.one); return }
			
			self.init(LinearRGB(chclt.inverseLuminance(Linear.vector3(u, 0, 0))).hueShifted(chclt, by:hue, luminance:u).vector)
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
		
		/// Bring each component with the 0 ... 1 range by desaturating
		/// - Parameters:
		///   - v: The luminance of the color
		///   - leavePositive: Normalize negative values but allow values above one
		/// - Returns: The adjusted color
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
		
		/// Create a new color with the same hue and given luminance.  Increasing the luminance to the point where it would be denormalized will instead desaturate the color, in which case decreasing the luminance to the original value will not produce the original color.  The chroma value may change while the perceptual chroma is preserved.
		/// - Parameters:
		///   - chclt: The color space
		///   - u: Value from 0 ... 1 to apply.  Zero is black, one is white.
		/// - Returns: The adjusted color
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
		
		/// The maximum luminance value that can be applied without canging the ratio of the components and desaturating the color.
		public func maximumLuminancePreservingRatio(_ chclt:CHCLT) -> Linear {
			let d = vector.max()
			
			return d > 0 ? luminance(chclt) / d : 1
		}
		
		//	MARK: - Contrast
		
		/// True if the luminance is below the medium luminance of the color space.
		public func isDark(_ chclt:CHCLT) -> Bool {
			return luminance(chclt) < chclt.mediumLuminance()
		}
		
		/// The contrast of a color is a measure of the distance from medium luminance.  Both black and white have a contrast of 1.  The contrast is computed so that light and dark color pairs with contrasts that add to at least 0.5 will be legible, and a sum of at least 1.0 is recommended.
		/// - Parameter chclt: The color space
		/// - Returns: The contrast
		public func contrast(_ chclt:CHCLT) -> Linear {
			let m = chclt.mediumLuminance()
			let v = luminance(chclt)
			let c = v > m ? (v - m) / (1 - m) : 1 - v / m
			
			return c.magnitude
		}
		
		/// Scale the luminance of the color so that the resulting contrast will be scaled by the given amount.  For example, scale by 0.5 to produce a color that contrasts half as much against the same background.  Scaling to 0 will result in a color with medium luminance.  Scaling to negative will result in contrasting colors.
		public func scaleContrast(_ chclt:CHCLT, by scalar:Scalar) -> LinearRGB {
			let m = chclt.mediumLuminance()
			let v = luminance(chclt)
			let t = scalar < 0 ? v < m ? (1 - m) / m : m / (1 - m) : 1
			let u = m - scalar.magnitude * (m - v) * t
			
			return applyLuminance(chclt, value:u)
		}
		
		/// Adjust the luminance to create a color that contrasts against the same colors as this color.
		/// - Parameters:
		///   - chclt: The color space
		///   - value: The contrast of the adjusted color.  Negative values create contrasting colors.  Values near zero contrast poorly.  Values near one contrast well.
		/// - Returns: The adjusted color
		public func applyContrast(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			let m = chclt.mediumLuminance()
			let v = luminance(chclt)
			let u = (v < m) == (value < 0) ? (1 - m) * value.magnitude + m : m * (1 - value.magnitude) 
			
			return applyLuminance(chclt, value:u)
		}
		
		/// Adjust the luminance to create a color that contrasts well against this color.  Use a value of at least `1 - contrast(chclt)` for a color with the suggested minimum contrast.
		/// - Parameters:
		///   - chclt: The color space
		///   - value: The contrast of the adjusted color.  Negative values create colors that do not contrast with this color.  Values near zero contrast poorly.  Values near one contrast well.
		/// - Returns: The adjusted color
		public func contrasting(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			return applyContrast(chclt, value:-value)
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
		
		///	A color with all components equal is desaturated and has a chroma of zero.  A color with a component at 0 or 1 cannot have the saturation increased without denormalizing the color and has a chroma of one.  The chroma of a color is the desaturation scale that would be applied to the maximum color to reach this color.
		/// - Parameter chclt: The color space
		/// - Returns: The croma
		public func chroma(_ chclt:CHCLT) -> Scalar {
			let v = chclt.luminance(vector)
			let m = maximumChroma(luminance:v)
			let c = m.isFinite ? 1 / m : 0
			
			return c
		}
		
		/// Scale the chroma of the color.  The color approaches gray as the value approaches zero.  Values greater than one increase vibrancy and may denormalize the color.  The hue is preserved for positive, inverted for nagative, and lost at zero.  The luminance is preserved.
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
		
		public func saturation(_ chclt:CHCLT) -> Scalar {
			let v = chclt.luminance(vector)
			let hueSaturation = vector - v
			
			return simd_length(hueSaturation)
		}
		
		public func applySaturation(_ chclt:CHCLT, value:Scalar) -> LinearRGB {
			let s = saturation(chclt)
			
			return s > 0 ? scaleChroma(chclt, by: value / s) : self
		}
		
		//	MARK: - Hue
		
		/// Hue is the angle between the color and red, normalized to the 0 ... 1 range.  Reds are near 0 or 1, greens are near ⅓, and blues are near ⅔ but the actual angles vary by color space.
		/// - Parameter chclt: The color space
		/// - Returns: The hue
		public func hue(_ chclt:CHCLT) -> Linear {
			let v = chclt.luminance(vector)
			
			let hueSaturation = vector - v
			let hueSaturationLengthSquared = simd_length_squared(hueSaturation)
			
			guard hueSaturationLengthSquared > 0.0 else { return 0.0 }
			
			let hueSaturationUnit = hueSaturation / hueSaturationLengthSquared.squareRoot()
			let red = Linear.vector3(1, 0, 0)
			let referenceRed = chclt.inverseLuminance(red) - 1
			let referenceUnit = simd_normalize(referenceRed)
			
			let dot = min(max(-1.0, simd_dot(hueSaturationUnit, referenceUnit)), 1.0)
			let turns = acos(dot) * 0.5 / .pi
			
			return vector.y < vector.z ? 1.0 - turns : turns
		}
		
		/// Rotate the deluminated color vector around the normal.
		public func hueShifted(_ chclt:CHCLT, by shift:Scalar, luminance v:Linear) -> LinearRGB {
			let hueSaturation = vector - v
			
			guard simd_length_squared(hueSaturation) > 0 else { return self }
			
			let inverse = chclt.inverseLuminance(.one)
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
		
		/// Rotate the color around the normal axis, changing the ratio of the components.  Shifting the hue will preserve the luminance, and changes the chroma value.  The perceptual chroma is preserved unless the color needs to be normalized after rotation.
		/// - Parameters:
		///   - chclt: The color space.
		///   - shift: The amount to shift.  Shifting by zero or one has no effect.  Shifting by half gives the same hue as negating chroma.
		/// - Returns: The adjusted color.
		public func hueShifted(_ chclt:CHCLT, by shift:Linear) -> LinearRGB {
			return hueShifted(chclt, by:shift, luminance:luminance(chclt))
		}
	}
}

//	MARK: -

extension CHCLT {
	public func mediumLuminance() -> CHCLT.Scalar {
		return 0.25
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
	
	public static let y240 = CHCLTPower(CHCLT.Linear.vector3(0.212, 0.701, 0.087), exponent:0.5)					//	39:129:16
	public static let y601 = CHCLTPower(CHCLT.Linear.vector3(0.299, 0.587, 0.114), exponent:0.45)					//	34:67:13	SDTV
	public static let y709 = CHCLTPower(CHCLT.Linear.vector3(0.2126, 0.7152, 0.0722), exponent:0.45)				//	53:178:18	HDTV
	public static let y2020 = CHCLTPower(CHCLT.Linear.vector3(0.2627, 0.6780, 0.0593), exponent:0.45)				//	31:80:7		UHDTV
	public static let sRGB = CHCLTPower(CHCLT_sRGB.coefficients, exponent:5 / 12)									//	53:178:18	HDTV
}

//	MARK: -

public struct CHCLT_sRGB: CHCLT {
	public static let coefficients:CHCLT.Vector3 = CHCLT.Linear.vector3(0.21263901, 0.71516867, 0.07219232)
	
	public func linear(_ value:CHCLT.Scalar) -> CHCLT.Linear {
		return value > 11.0 / 280.0 ? pow((200.0 * value + 11.0) / 211.0, 12.0 / 5.0) : value / 12.9232102
	}
	
	public func transfer(_ value:CHCLT.Linear) -> CHCLT.Scalar {
		return value > 11.0 / 280.0 / 12.9232102 ? (211.0 * pow(value, 5.0 / 12.0) - 11.0) / 200.0 : value * 12.9232102
	}
	
	public func linear(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return CHCLT.Linear.vector3(linear(vector.x), linear(vector.y), linear(vector.z))
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
	public let coefficients:CHCLT.Vector3
	
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
		return simd_dot(vector, CHCLT_sRGB.coefficients)
	}
	
	public func inverseLuminance(_ vector:CHCLT.Vector3) -> CHCLT.Vector3 {
		return vector / CHCLT_sRGB.coefficients
	}
}
