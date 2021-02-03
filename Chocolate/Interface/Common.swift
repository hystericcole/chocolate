//
//  Common.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import Foundation

#if os(macOS)
import Cocoa

typealias PlatformFont = NSFont
typealias PlatformFontDescriptor = NSFontDescriptor
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
typealias PlatformResponder = NSResponder
typealias PlatformViewController = NSViewController
typealias PlatformView = NSView
typealias PlatformControl = NSControl
typealias PlatformSlider = NSSlider
typealias PlatformLabel = NSTextField
typealias PlatformImageView = NSImageView
typealias PlatformScroller = NSScroller
typealias PlatformScrollingView = NSScrollView
typealias PlatformSpinner = NSProgressIndicator
typealias PlatformVisualEffectView = NSVisualEffectView

@available(macOS 10.15, *)
typealias PlatformSwitch = NSSwitch
#else
import UIKit

typealias PlatformFont = UIFont
typealias PlatformFontDescriptor = UIFontDescriptor
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformResponder = UIResponder
typealias PlatformViewController = UIViewController
typealias PlatformView = UIView
typealias PlatformControl = UIControl
typealias PlatformSlider = UISlider
typealias PlatformSwitch = UISwitch
typealias PlatformLabel = UILabel
typealias PlatformImageView = UIImageView
typealias PlatformScrollingView = UIScrollView
typealias PlatformScrollingDelegate = UIScrollViewDelegate
typealias PlatformSpinner = UIActivityIndicatorView
typealias PlatformVisualEffectView = UIVisualEffectView
#endif

extension CGColor {
	var platformColor:PlatformColor? { return PlatformColor(cgColor:self) }
}

extension CTFont {
	var platformFont:PlatformFont { return self as PlatformFont }
}

#if os(macOS)
extension PlatformView {
	var alpha:CGFloat {
		get { return alphaValue }
		set { alphaValue = newValue }
	}
	
	var backgroundColor:PlatformColor? {
		get { return layer?.backgroundColor?.platformColor }
		set { layer?.backgroundColor = newValue?.cgColor }
	}
}

extension PlatformLabel {
	var attributedText:NSAttributedString? {
		get { return attributedStringValue }
		set { attributedStringValue = newValue ?? NSAttributedString() }
	}
}

extension PlatformSlider {
	var value:Float {
		get { return floatValue }
		set { floatValue = newValue }
	}
}
#endif
