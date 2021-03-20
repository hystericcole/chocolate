//
//  Palette.swift
//  Chocolate
//
//  Created by Eric Cole on 2/25/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation

class Palette {
	let chclt:CHCLT
	let primary:CHCLT.LinearRGB
	let primaryChroma:CHCLT.Linear
	let primaryAdjustment:CHCLT.Adjustment
	let contrasting:CHCLT.LinearRGB
	let contrastingChroma:CHCLT.Linear
	let contrastingAdjustment:CHCLT.Adjustment
	
	var primaryForeground:CGColor! { return primary.color() }
	var secondaryForeground:CGColor! { return foreground(0.5).color() }
	var tertiaryForeground:CGColor! { return foreground(1.0).color() }
	
	var primaryBackground:CGColor! { return contrasting.color() }
	var secondaryBackground:CGColor! { return background(0.5).color() }
	var tertiaryBackground:CGColor! { return background(1.0).color() }
	
	var placeholder:CGColor! { return background(2.0).color() }
	var divider:CGColor! { return background(1.5).color() }
	
	init(
		chclt:CHCLT = .default,
		primary:CHCLT.LinearRGB,
		contrasting:CHCLT.LinearRGB,
		primaryAdjustment:CHCLT.Adjustment = .half,
		contrastingAdjustment:CHCLT.Adjustment = .half
	) {
		self.chclt = chclt
		self.primary = primary
		self.primaryChroma = primary.chroma(chclt)
		self.primaryAdjustment = primaryAdjustment
		self.contrasting = contrasting
		self.contrastingChroma = contrasting.chroma(chclt)
		self.contrastingAdjustment = contrastingAdjustment
	}
	
	init(
		chclt:CHCLT = .default,
		primary:CHCLT.LinearRGB,
		contrasting:CHCLT.Adjustment = CHCLT.Adjustment(contrast:0.0, chroma:0.5),
		primaryAdjustment:CHCLT.Adjustment = .half,
		contrastingAdjustment:CHCLT.Adjustment = .half
	) {
		let primaryChroma = primary.chroma(chclt)
		let contrastingChroma = primaryChroma * contrasting.chroma
		
		self.chclt = chclt
		self.primary = primary
		self.primaryChroma = primaryChroma
		self.primaryAdjustment = primaryAdjustment
		self.contrasting = primary.contrasting(chclt, value:contrasting.contrast).applyChroma(chclt, value:contrastingChroma)
		self.contrastingChroma = contrastingChroma
		self.contrastingAdjustment = contrastingAdjustment
	}
	
	func disabled(_ color:CHCLT.LinearRGB) -> CHCLT.LinearRGB {
		return color.scaleContrast(chclt, by:0.5)
	}
	
	func inverted(_ color:CHCLT.LinearRGB) -> CHCLT.LinearRGB {
		return color.scaleContrast(chclt, by:-1)
	}
	
	func adapt(_ color:CHCLT.LinearRGB, similar:CHCLT.LinearRGB, minimumShift:CHCLT.Linear = 0.05) -> CHCLT.LinearRGB {
		let contrast = similar.contrast(chclt)
		
		let c = color
			.matchLuminance(chclt, to:similar, by:0.625 - 0.125 * contrast)
			.matchChroma(chclt, to:similar, by:0.75 - 0.5 * contrast)
			.huePushed(chclt, from:similar, minimumShift:minimumShift)
		
		return c
	}
	
	func adjust(color:CHCLT.LinearRGB, by value:CHCLT.Scalar, using adjustment:CHCLT.Adjustment, chroma:CHCLT.Linear = 1.0) -> CHCLT.LinearRGB {
		let n = 1 - value
		let c = value * adjustment.contrast + n
		let s = value * adjustment.chroma + n
		
		return color.scaleContrast(chclt, by:c).applyChroma(chclt, value:chroma * s)
	}
	
	func foreground(_ value:CHCLT.Scalar) -> CHCLT.LinearRGB {
		return adjust(color:primary, by:value, using:primaryAdjustment, chroma:primaryChroma)
	}
	
	func background(_ value:CHCLT.Scalar) -> CHCLT.LinearRGB {
		return adjust(color:contrasting, by:value, using:contrastingAdjustment, chroma:contrastingChroma.magnitude)
	}
}
