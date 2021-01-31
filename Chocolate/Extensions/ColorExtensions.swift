//
//  ColorExtensions.swift
//  CHCLT
//
//  Created by Eric Cole on 1/26/21.
//

import Foundation


#if os(macOS)
import Cocoa

typealias SystemColor = NSColor

extension NSColor {
	var rgba:RGBA? {
		return RGBA(color:cgColor)
	}
}
#else
import UIKit

typealias SystemColor = UIColor

extension UIColor {
	var rgba:RGBA? {
		return RGBA(color:cgColor)
	}
}
#endif

extension CGColor {
	var rgba:RGBA? {
		return RGBA(color:self)
	}
	
	static func from(rgba:RGBA?, colorSpace:CGColorSpace?) -> CGColor? {
		return rgba?.cgColor(colorSpace:colorSpace)
	}
}

extension CGColor {
	static var chocolate = CHCLTPower.y709
	
	var chocolateHue:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.vectorHue(color.vector) }
	var chocolateSaturation:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.saturation(color.vector) }
	var chocolateLuma:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.luma(color.vector) }
	var chocolateContrast:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.contrast(color.vector) }
	
	func chocolateTransform(transform:(CHCLT.Vector4) -> CHCLT.Vector4) -> CGColor? { guard let color = rgba else { return nil }; return RGBA(vector:transform(color.vector)).cgColor(colorSpace:colorSpace) }
	func chocolateHue(_ hue:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.color(hue:hue, saturation:CGColor.chocolate.saturation($0), luma:CGColor.chocolate.luma($0), alpha:$0.w) } ?? self }
	func chocolateShiftHue(_ hue:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.shiftVectorHue($0, by:hue) } ?? self }
	func chocolateSaturation(_ saturation:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.applySaturation($0, saturation:saturation) } ?? self }
	func chocolateScaleSaturation(_ scalar:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.scaleSaturation($0, by:scalar) } ?? self }
	func chocolateLuma(_ luma:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.applyLuma($0, luma:luma) } ?? self }
	func chocolateScaleLuma(_ scalar:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.scaleLuma($0, by:scalar) } ?? self }
	func chocolateContrasting(_ contrast:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.contrasting($0, contrast:contrast) } ?? self }
	func chocolateScaleContrast(_ scalar:Double) -> CGColor { return chocolateTransform { CGColor.chocolate.scaleContrast($0, by:scalar) } ?? self }
}

extension SystemColor {
	convenience init?(chocolateHue hue:Double, saturation:Double, luma:Double, alpha:Double) {
		let vector = CGColor.chocolate.color(hue:hue, saturation:saturation, luma:luma, alpha:alpha)
		
		self.init(red:CGFloat(vector.x), green:CGFloat(vector.y), blue:CGFloat(vector.z), alpha:CGFloat(vector.w))
	}
}
