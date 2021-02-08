//
//  StringExtensions.swift
//  Chocolate
//
//  Created by Eric Cole on 2/5/21.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension NSAttributedString {
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
