//
//  Palette.swift
//  Chocolate
//
//  Created by Eric Cole on 2/25/21.
//

import CoreGraphics
import Foundation

class Palette {
	let chclt:CHCLT
	let primary:CHCL.LinearRGB
	let primaryAdjustment:CHCL.Adjustment
	let contrasting:CHCL.LinearRGB
	let contrastingAdjustment:CHCL.Adjustment
	
	var primaryForeground:CGColor! { return primary.color() }
	var secondaryForeground:CGColor! { return foreground(0.5).color() }
	var tertiaryForeground:CGColor! { return foreground(1.0).color() }
	
	var primaryBackground:CGColor! { return contrasting.color() }
	var secondaryBackground:CGColor! { return background(0.5).color() }
	var tertiaryBackground:CGColor! { return background(1.0).color() }
	
	var placeholder:CGColor! { return background(2.0).color() }
	var divider:CGColor! { return background(1.5).color() }
	
	init(chclt:CHCLT, primary:CHCL.LinearRGB, contrasting:CHCL.LinearRGB, primaryAdjustment:CHCL.Adjustment, contrastingAdjustment:CHCL.Adjustment) {
		self.chclt = chclt
		self.primary = primary
		self.primaryAdjustment = primaryAdjustment
		self.contrasting = contrasting
		self.contrastingAdjustment = contrastingAdjustment
	}
	
	convenience init(chclt:CHCLT, primary:CHCL.LinearRGB, contrasting:CHCL.Adjustment, primaryAdjustment:CHCL.Adjustment, contrastingAdjustment:CHCL.Adjustment) {
		let color = primary.contrasting(chclt, value:contrasting.contrast).applyChroma(chclt, value:contrasting.chroma)
		
		self.init(chclt:chclt, primary:primary, contrasting:color, primaryAdjustment:primaryAdjustment, contrastingAdjustment:contrastingAdjustment)
	}
	
	func disabled(_ color:CHCL.LinearRGB) -> CHCL.LinearRGB {
		return color.scaleContrast(chclt, by:0.5)
	}
	
	func inverted(_ color:CHCL.LinearRGB) -> CHCL.LinearRGB {
		return color.scaleContrast(chclt, by:-1)
	}
	
	func adapt(_ color:CHCL.LinearRGB, similar:CHCL.LinearRGB) -> CHCL.LinearRGB {
		let contrast = similar.contrast(chclt)
		
		let c = color
			.matchLuminance(chclt, to:similar, by:0.625 - 0.125 * contrast)
			.matchChroma(chclt, to:similar, by:0.75 - 0.5 * contrast)
			.huePushed(chclt, from:similar, minimumShift:0.05)
		
		return c
	}
	
	func foreground(_ value:CHCL.Scalar) -> CHCL.LinearRGB {
		let n = 1 - value
		
		return primary
			.scaleContrast(chclt, by:value * primaryAdjustment.contrast + n)
			.scaleChroma(chclt, by:value * primaryAdjustment.chroma + n)
	}
	
	func background(_ value:CHCL.Scalar) -> CHCL.LinearRGB {
		let n = 1 - value
		
		return contrasting
			.scaleContrast(chclt, by:value * contrastingAdjustment.contrast + n)
			.scaleChroma(chclt, by:value * contrastingAdjustment.chroma + n)
	}
}
