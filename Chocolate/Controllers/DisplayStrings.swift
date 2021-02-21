//
//  DisplayStrings.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import Foundation

enum DisplayStrings {
	enum Chocolate {
		static let title = "Chocolate"
		static let primary = "Color"
		static let derived = "Derived Colors"
		static let foreground = "Derive Foreground Colors"
		static let contrast = "Contrast"
		static let saturation = "Saturation"
		
		static func example(foreground:Int, background:Int) -> String { return "Foreground \(foreground), Background \(background)" }
		static func example(foreground:Int, fc:String, background:Int, bc:String, contrast:String) -> String { return "Fore \(foreground) \(fc)◑, Back \(background) \(bc)◑, g18◑ \(contrast)" }
	}
}
