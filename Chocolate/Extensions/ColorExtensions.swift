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
	var rgba:DisplayRGB? {
		return DisplayRGB(cgColor)
	}
}
#else
import UIKit

typealias SystemColor = UIColor

extension UIColor {
	var rgba:DisplayRGB? {
		return DisplayRGB(cgColor)
	}
}
#endif

extension CGColor {
	var rgba:DisplayRGB? {
		return DisplayRGB(self)
	}
	
	static func from(rgba:DisplayRGB?, colorSpace:CGColorSpace?) -> CGColor? {
		return rgba?.color(colorSpace:colorSpace)
	}
}

extension CGColor {
	static var chocolate = CHCLTPower.y709
	
	var displayRGB:DisplayRGB? { return DisplayRGB(self) }
	
	var chocolateHue:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.vectorHue(color.vector) }
	var chocolateSaturation:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.saturation(color.vector) }
	var chocolateLuma:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.luma(color.vector) }
	var chocolateContrast:Double { guard let color = rgba else { return 0 }; return CGColor.chocolate.contrast(color.vector) }
	
	func chocolateTransform(transform:(DisplayRGB?) -> DisplayRGB?) -> CGColor? { return transform(displayRGB)?.color(colorSpace:colorSpace) }
	func chocolateHueShifted(_ value:Double) -> CGColor { return chocolateTransform { $0?.hueShifted(CGColor.chocolate, by:value) } ?? self }
	func chocolateHue(_ value:Double) -> CGColor { return chocolateTransform { $0?.hueShifted(CGColor.chocolate, by:($0?.vectorHue(CGColor.chocolate) ?? 0) - value) } ?? self }
	func chocolateScaleChroma(_ value:Double) -> CGColor { return chocolateTransform { $0?.scaleChroma(CGColor.chocolate, by:value) } ?? self }
	func chocolateChroma(_ value:Double) -> CGColor { return chocolateTransform { $0?.applyChroma(CGColor.chocolate, value:value) } ?? self }
	func chocolateScaleLuma(_ value:Double) -> CGColor { return chocolateTransform { $0?.scaleLuma(CGColor.chocolate, by:value) } ?? self }
	func chocolateLuma(_ value:Double) -> CGColor { return chocolateTransform { $0?.applyLuma(CGColor.chocolate, value:value) } ?? self }
	func chocolateScaleContrast(_ value:Double) -> CGColor { return chocolateTransform { $0?.scaleContrast(CGColor.chocolate, by:value) } ?? self }
	func chocolateContrasting(_ value:Double) -> CGColor { return chocolateTransform { $0?.contrasting(CGColor.chocolate, value:value) } ?? self }
}

extension SystemColor {
	convenience init?(chocolateHue hue:Double, saturation:Double, luma:Double, alpha:Double) {
		let vector = CGColor.chocolate.color(hue:hue, saturation:saturation, luma:luma, alpha:alpha)
		
		self.init(red:CGFloat(vector.x), green:CGFloat(vector.y), blue:CGFloat(vector.z), alpha:CGFloat(vector.w))
	}
}
