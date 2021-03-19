//
//  ColorExtensions.swift
//  Chocolate
//
//  Created by Eric Cole on 1/26/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation

extension CGColor {
	static var chocolate = CHCLT_sRGB.standard
	
	var displayRGB:DisplayRGB? { return DisplayRGB(self) }
	var linearRGB:CHCLT.LinearRGB? { return CHCLT.LinearRGB(self) }
	
	var chocolate:CHCLT { return colorSpace?.chclt ?? CGColor.chocolate }
	var chocolateHue:Double { return displayRGB?.vectorHue(CGColor.chocolate) ?? 0 }
	var chocolateChroma:Double { return displayRGB?.chroma(CGColor.chocolate) ?? 0 }
	var chocolateLuma:Double { return displayRGB?.luma(CGColor.chocolate) ?? 0 }
	var chocolateContrast:Double { return displayRGB?.contrast(CGColor.chocolate) ?? 0 }
	
	func chocolateTransform(transform:(CHCLT.LinearRGB?) -> CHCLT.LinearRGB?) -> CGColor? { return transform(linearRGB)?.color(colorSpace:colorSpace) }
	func chocolateHueShifted(_ value:Double) -> CGColor { return chocolateTransform { $0?.hueShifted(chocolate, by:value) } ?? self }
	func chocolateHue(_ value:Double) -> CGColor { return chocolateTransform { $0?.hueShifted(chocolate, by:($0?.hue(chocolate) ?? 0) - value) } ?? self }
	func chocolateScaleChroma(_ value:Double) -> CGColor { return chocolateTransform { $0?.scaleChroma(chocolate, by:value) } ?? self }
	func chocolateChroma(_ value:Double) -> CGColor { return chocolateTransform { $0?.applyChroma(chocolate, value:value) } ?? self }
	func chocolateScaleLuma(_ value:Double) -> CGColor { return chocolateTransform { $0?.scaleLuma(chocolate, by:value) } ?? self }
	func chocolateLuma(_ value:Double) -> CGColor { return chocolateTransform { $0?.applyLuma(chocolate, value:value) } ?? self }
	func chocolateScaleContrast(_ value:Double) -> CGColor { return chocolateTransform { $0?.scaleContrast(chocolate, by:value) } ?? self }
	func chocolateContrasting(_ value:Double) -> CGColor { return chocolateTransform { $0?.contrasting(chocolate, value:value) } ?? self }
	
	func chocolateTransform(_ transform:CHCLT.Transform, chclt:CHCLT? = nil) -> CGColor? { return linearRGB?.transform(chclt ?? chocolate, transform:transform).color(colorSpace:colorSpace, alpha:alpha) }
}

extension PlatformColor {
	var displayRGB:DisplayRGB? { return cgColor.displayRGB }
	var linearRGB:CHCLT.LinearRGB? { return cgColor.linearRGB }
	
	convenience init?(chocolateHue hue:Double, chroma:Double, luma:Double, alpha:Double) {
		let color = DisplayRGB(CGColor.chocolate, hue:hue, chroma:chroma, luma:luma, alpha:alpha)
		let vector = color.vector
		
		self.init(red:CGFloat(vector.x), green:CGFloat(vector.y), blue:CGFloat(vector.z), alpha:CGFloat(vector.w))
	}
	
	func chocolateTransform(_ transform:CHCLT.Transform, chclt:CHCLT? = nil) -> PlatformColor? {
		return cgColor.chocolateTransform(transform, chclt:chclt)?.platformColor
	}
}
