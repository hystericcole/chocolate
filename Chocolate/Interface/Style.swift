//
//  Style.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

struct Style {
	typealias Attributes = [NSAttributedString.Key:Any]
	
	enum Font {
		enum FamilyName: String {
			case arial = "Arial"
			case avenir = "Avenir"
			case avenirNext = "Avenir Next"
			case baskerville = "Baskerville"
			case copperplate = "Copperplate"
			case courier = "Courier"
			case courierNew = "Courier New"
			case damascus = "Damascus"
			case didot = "Didot"
			case futura = "Futura"
			case gill = "Gill Sans"
			case gothicNeo = "Apple SD Gothic Neo"
			case georgia = "Georgia"
			case helvetica = "Helvetica"
			case helveticaNeue = "Helvetica Neue"
			case kailasa = "Kailasa"
			case menlo = "Menlo"
			case noteworthy = "Noteworthy"
			case optima = "Optima"
			case palatino = "Palatino"
			case papyrus = "Papyrus"
			case rockwell = "Rockwell"
			case savoye = "Savoye Let"
			case snell = "Snell Roundhand"
			case typewriter = "American Typewriter"
			case times = "Times New Roman"
			case trebuchet = "Trebuchet MS"
			case verdana = "Verdana"
		}
		
		case system, bold
		case title, body, monospaceDigits
		case name(String)
		case descriptor(PlatformFontDescriptor)
		case attributes([PlatformFontDescriptor.AttributeName:Any])
		case family(FamilyName, PlatformFontDescriptor.SymbolicTraits?)
		
		static var commonSize:CGFloat { return PlatformFont.systemFontSize }
		static func commonFont(_ size:CGFloat? = nil) -> PlatformFont { return PlatformFont.systemFont(ofSize:size ?? commonSize) }
		
		func displayFont(descriptor:PlatformFontDescriptor, traits:PlatformFontDescriptor.SymbolicTraits? = nil, size:CGFloat? = nil) -> PlatformFont {
			var descriptor = descriptor
			
#if os(macOS)
			if let traits = traits {
				descriptor = descriptor.withSymbolicTraits(traits)
			}
			
			return PlatformFont(descriptor:descriptor, size:size ?? descriptor.pointSize) ?? Font.commonFont(size)
#else
			if let traits = traits {
				descriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
			}
			
			return PlatformFont(descriptor:descriptor, size:size ?? descriptor.pointSize)
#endif
		}
		
		func displayFont(size:CGFloat? = nil) -> PlatformFont {
			switch self {
			case .system:
				return PlatformFont.systemFont(ofSize:size ?? Font.commonSize)
			case .bold:
				return PlatformFont.boldSystemFont(ofSize:size ?? Font.commonSize)
			case .name(let name):
				return PlatformFont(name:name, size:size ?? Font.commonSize) ?? Font.commonFont(size)
			case .descriptor(let descriptor):
				return displayFont(descriptor:descriptor, size:size)
			case .attributes(let attributes):
				return displayFont(descriptor:PlatformFontDescriptor(fontAttributes:attributes), size:size)
			case .family(let family, let traits):
				return displayFont(descriptor:PlatformFontDescriptor(fontAttributes:[.family:family.rawValue]), traits:traits, size:size)
			case .monospaceDigits:
				if #available(macOS 10.11, iOS 9.0, *) {
					return PlatformFont.monospacedDigitSystemFont(ofSize:size ?? 0, weight:.regular)
				} else {
					return displayFont(descriptor:PlatformFontDescriptor(fontAttributes:[.family:FamilyName.courierNew.rawValue]), traits:nil, size:size)
				}
			case .title:
#if os(macOS)
				return PlatformFont.menuFont(ofSize:size ?? 0)
#else
				return displayFont(descriptor:.preferredFontDescriptor(withTextStyle:.largeTitle), size:size)
#endif
			case .body:
#if os(macOS)
				return PlatformFont.labelFont(ofSize:size ?? Font.commonSize)
#else
				return displayFont(descriptor:.preferredFontDescriptor(withTextStyle:.body), size:size)
#endif
			}
		}
	}
	
	let font:Font
	let size:CGFloat?
	let color:PlatformColor?
	let alignment:NSTextAlignment
	
	var attributes:Attributes {
		var attributes:Attributes = [.font:font.displayFont(size:size)]
		
		if let color = color {
			attributes[.foregroundColor] = color
		}
		
		let paragraph = NSMutableParagraphStyle()
		
		paragraph.alignment = alignment
		
		attributes[.paragraphStyle] = paragraph
		
		return attributes
	}
	
	var centered:Style { return with(alignment:.center) }
	var natural:Style { return with(alignment:.natural) }
	
	init(font:Font, size:CGFloat?, color:PlatformColor?, alignment:NSTextAlignment = .natural) {
		self.font = font
		self.size = size
		self.color = color
		self.alignment = alignment
	}
	
	func with(font:Font? = nil, size:CGFloat? = nil, color:PlatformColor? = nil, alignment:NSTextAlignment? = nil) -> Style {
		return Style(
			font:font ?? self.font,
			size:size ?? self.size,
			color:color ?? self.color,
			alignment:alignment ?? self.alignment
		)
	}
	
	func size(_ size:CGFloat) -> Style { return with(size:size) }
	func color(_ color:PlatformColor) -> Style { return with(color:color) }
	
	func string(_ text:String) -> NSAttributedString {
		return NSAttributedString(string:text, attributes:attributes)
	}
	
	func label(_ text:String, maximumLines:Int = 0, intrinsicWidth:CGFloat = 0) -> Style.Label {
		return Style.Label(text:text, style:self, maximumLines:maximumLines, intrinsicWidth:intrinsicWidth)
	}
}

extension Style {
	class Label: ViewablePositionable {
		typealias ViewType = PlatformLabel
		
		struct Model {
			let tag:Int
			var text:String?
			var style:Style
			var maximumLines:Int
			var intrinsicWidth:CGFloat
			var string:NSAttributedString? { guard let text = text else { return nil }; return style.string(text) }
			
			func positionableSize(fitting limit:Layout.Limit) -> Layout.Size {
				guard let string = string else { return .zero }
				
				var sizeLimit = limit.size
				
				if intrinsicWidth > 0 && intrinsicWidth < sizeLimit.width {
					sizeLimit.width = intrinsicWidth
				}
				
				return Layout.Size(
					stringSize:string.boundsWrappingWithSize(sizeLimit).size,
					stringLength:string.length,
					maximumHeight:limit.height,
					maximumLines:maximumLines
				)
			}
		}
		
		weak var view:ViewType?
		var model:Model
		var tag:Int { get { return view?.tag ?? model.tag } }
		var text:String? { get { return view?.text ?? model.text } set { model.text = newValue; view?.attributedText = model.string } }
		var style:Style { get { return model.style } set { model.style = newValue; view?.attributedText = model.string } }
		var intrinsicWidth:CGFloat { get { return view?.preferredMaxLayoutWidth ?? model.intrinsicWidth } set { model.intrinsicWidth = newValue; view?.preferredMaxLayoutWidth = newValue } }
		var textColor:PlatformColor? { get { return view?.textColor } set { view?.textColor = newValue } }
		
		init(tag:Int = 0, text:String?, style:Style, maximumLines:Int = 0, intrinsicWidth:CGFloat = 0) {
			self.model = Model(tag:tag, text:text, style:style, maximumLines:maximumLines, intrinsicWidth:intrinsicWidth)
		}
		
		func applyToView(_ view:PlatformLabel) {
			view.tag = model.tag
			view.attributedText = model.string
			view.prepareViewableLabel(intrinsicWidth:model.intrinsicWidth, maximumLines:model.maximumLines)
		}
		
		func positionableSize(fitting limit:Layout.Limit, context:Layout.Context) -> Layout.Size {
			return view?.positionableSize(fitting:limit, context:context) ?? model.positionableSize(fitting:limit)
		}
		
		func text(_ string:String) -> Self { text = string; return self }
		func color(_ color:PlatformColor?) -> Self { textColor = color; return self }
	}
}
