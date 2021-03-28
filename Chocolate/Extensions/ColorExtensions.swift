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
	static var chocolate:CHCLT = CHCLT_sRGB.standard
	
	func chocolateColor(chclt:CHCLT? = nil) -> CHCLT.Color? { return CHCLT.Color(chclt ?? colorSpace?.chclt ?? CGColor.chocolate, self, useSpaceFromColorWhenAvailable:chclt == nil) }
	
	func chocolateTransform(_ transform:CHCLT.Transform, chclt:CHCLT? = nil) -> CGColor? {
		chocolateColor(chclt:chclt)?.transform(transform).color()
	}
}

extension PlatformColor {
	func chocolateColor(chclt:CHCLT? = nil) -> CHCLT.Color? { return cgColor.chocolateColor(chclt:chclt) }
	
	convenience init?(chocolateHue hue:CHCLT.Scalar, chroma:CHCLT.Scalar, luma:CHCLT.Scalar, alpha:CHCLT.Scalar) {
		let color = CHCLT.Color(CGColor.chocolate, hue:hue, chroma:chroma, luma:luma, alpha:alpha)
		let vector = color.display
		
		self.init(red:CGFloat(vector.x), green:CGFloat(vector.y), blue:CGFloat(vector.z), alpha:CGFloat(vector.w))
	}
	
	func chocolateTransform(_ transform:CHCLT.Transform, chclt:CHCLT? = nil) -> PlatformColor? {
		return cgColor.chocolateTransform(transform, chclt:chclt)?.platformColor
	}
}
