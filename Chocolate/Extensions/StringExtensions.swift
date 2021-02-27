//
//  StringExtensions.swift
//  Chocolate
//
//  Created by Eric Cole on 2/5/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension NSAttributedString {
	static func attributes(
		font:PlatformFont? = nil,
		paragraph:NSParagraphStyle? = nil,
		color:PlatformColor? = nil,
		background:PlatformColor? = nil,
		strokeColor:PlatformColor? = nil,
		strokeWidth:Double = 0,
		baselineOffset:Double = 0,
		kern:Double = 0,
		expansion:Double = 0,
		obliqueness:Double = 0,
		underline:NSUnderlineStyle = [],
		ligatures:Bool = true,
		letterpress:Bool = false,
		link:NSURL? = nil,
		shadow:NSShadow? = nil
	) -> [NSAttributedString.Key:Any] {
		var result:[NSAttributedString.Key:Any] = [:]
		
		if let value = font { result[.font] = value }
		if let value = paragraph { result[.paragraphStyle] = value }
		if let value = color { result[.foregroundColor] = value }
		if let value = background { result[.backgroundColor] = value }
		if let value = strokeColor { result[.strokeColor] = value }
		if strokeWidth != 0 { result[.strokeWidth] = NSNumber(value:strokeWidth) }
		if kern != 0 { result[.kern] = NSNumber(value:kern) }
		if expansion != 0 { result[.expansion] = NSNumber(value:expansion) }
		if obliqueness != 0 { result[.obliqueness] = NSNumber(value:obliqueness) }
		if baselineOffset != 0 { result[.baselineOffset] = NSNumber(value:baselineOffset) }
		if underline.rawValue != 0 { result[.underlineStyle] = NSNumber(value:underline.rawValue) }
		if letterpress { result[.textEffect] = NSAttributedString.TextEffectStyle.letterpressStyle.rawValue }
		if !ligatures { result[.ligature] = NSNumber(value:ligatures ? 1 : 0) }
		if let value = shadow { result[.shadow] = value }
		if let value = link { result[.link] = value }
		
		return result
	}
	
	func withLineBreakMode(_ mode:NSLineBreakMode = .byWordWrapping) -> NSAttributedString {
		var range = NSRange()
		let wholeSting = NSRange(location:0, length:length)
		let paragraphStyle = attribute(.paragraphStyle, at:0, effectiveRange:&range) as? NSParagraphStyle
		
		if range == wholeSting && paragraphStyle?.lineBreakMode == mode {
			return self
		}
		
		let mutableString = NSMutableAttributedString(attributedString:self)
		
		enumerateAttribute(.paragraphStyle, in:wholeSting, options:.longestEffectiveRangeNotRequired) { value, range, stop in
			let mutableStyle:NSMutableParagraphStyle
			
			if let style = value as? NSParagraphStyle {
				if style.lineBreakMode == mode {
					return
				}
				
				mutableStyle = style.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
			} else {
				mutableStyle = NSMutableParagraphStyle()
			}
			
			mutableStyle.lineBreakMode = mode
			mutableString.addAttribute(.paragraphStyle, value:mutableStyle, range:range)
		}
		
		return mutableString
	}
	
	func withText(_ text:String) -> NSMutableAttributedString {
		let range = NSRange(location:0, length:length)
		let mutable = NSMutableAttributedString(attributedString:self)
		
		mutable.replaceCharacters(in:range, with:text)
		
		return mutable
	}
	
#if os(macOS)
	func boundsWrappingWithSize(_ size:CGSize) -> CGRect {
		return withLineBreakMode().boundingRect(with:size, options:.usesLineFragmentOrigin)
	}
#else
	func boundsWrappingWithSize(_ size:CGSize) -> CGRect {
		return withLineBreakMode().boundingRect(with:size, options:.usesLineFragmentOrigin, context: nil)
	}
#endif
}

//	MARK: -

extension NSMutableParagraphStyle {
	convenience init(alignment:NSTextAlignment = .natural, lineBreakMode:NSLineBreakMode = .byWordWrapping, lineHeightMultiple:CGFloat = 0, allowsDefaultTighteningForTruncation:Bool = false) {
		self.init()
		
		self.alignment = alignment
		self.lineBreakMode = lineBreakMode
		self.lineHeightMultiple = lineHeightMultiple
		
		if #available(macOS 10.11, iOS 9.0, *) {
			self.allowsDefaultTighteningForTruncation = allowsDefaultTighteningForTruncation
		}
	}
}

//	MARK: -

extension NSShadow {
	convenience init?(offset:CGSize = .zero, radius:CGFloat = 0, color:PlatformColor? = nil) {
		guard radius != 0 || offset.width != 0 || offset.height != 0 else { return nil }
		guard color == nil || color?.cgColor.alpha ?? 0 > 0 else { return nil }
		
		self.init()
		
		shadowBlurRadius = radius
		shadowOffset = offset
		
		if let color = color {
			shadowColor = color
		}
	}
}
