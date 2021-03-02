//
//	ColorTransformable.swift
//	Chocolate
//
//	Created by Eric Cole on 3/2/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation

protocol ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT)
}

extension Viewable.Color: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		view?.backgroundColor = model.color?.chocolateTransform(transform, chclt:chclt)
	}
}

extension Viewable.Shape: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		view?.shapeLayer?.fillColor = model.style.fill?.chocolateTransform(transform, chclt:chclt)
		view?.shapeLayer?.strokeColor = model.style.stroke?.chocolateTransform(transform, chclt:chclt)
	}
}

extension Viewable.Gradient: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		view?.gradientLayer?.colors = model.gradient.colors.compactMap { $0.chocolateTransform(transform, chclt:chclt) }
	}
}

extension Viewable.Label: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		if let string = model.string {
			let mutable = NSMutableAttributedString(attributedString:string)
			let wholeString = NSRange(location:0, length:mutable.length)
			
			mutable.enumerateAttributes(in:wholeString, options:.longestEffectiveRangeNotRequired) { attributes, range, stop in
				for (key, value) in attributes {
					guard let color = value as? PlatformColor, let transformed = color.chocolateTransform(transform, chclt:chclt) else { continue }
					
					mutable.addAttribute(key, value:transformed, range:range)
				}
			}
			
			view?.attributedText = mutable
		}
	}
}

extension Viewable.Group: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		model.content.transformColors(transform, chclt:chclt)
	}
}

extension Viewable.Button: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		model.content.transformColors(transform, chclt:chclt)
	}
}

extension Viewable.Scroll: ColorTransformable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		model.content.transformColors(transform, chclt:chclt)
	}
}

extension Positionable {
	func transformColors(_ transform:CHCLT.Transform, chclt:CHCLT) {
		if let tintable = self as? ColorTransformable {
			tintable.transformColors(transform, chclt:chclt)
		} else if let node = self as? PositionableNode {
			for positionable in node.positionables {
				positionable.transformColors(transform, chclt:chclt)
			}
		}
	}
}
