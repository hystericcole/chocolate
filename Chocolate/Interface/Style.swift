//
//  Style.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
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
		case title, body
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
				return displayFont(descriptor:PlatformFontDescriptor(fontAttributes:[.family: family.rawValue]), traits:traits, size:size)
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
}
