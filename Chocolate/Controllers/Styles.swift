//
//  Styles.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation

extension Style {
	static let example = Style(font:Font.family(.avenirNext, nil), size:18, color:nil)
	static let caption = Style(font:Font.family(.helveticaNeue, nil), size:18, color:nil)
	static let small = Style(font:Font.family(.helveticaNeue, nil), size:12, color:nil)
	static let medium = Style(font:Font.family(.helveticaNeue, nil), size:15, color:nil)
	static let webColor = Style(font:Font.family(.courierNew, nil), size:12, color:nil)
	static let monospace = Style(font:Font.family(.menlo, nil), size:18, color:nil)
	static let numberRight = Style.small.align(.right)
}
