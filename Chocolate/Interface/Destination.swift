//
//	Destination.swift
//	Chocolate
//
//	Created by Eric Cole on 3/1/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import SwiftUI

protocol Destination {
	var title:String { get }
	var path:String { get }
	
	func icon() -> CGImage?
	func display() -> Positionable
	
	func flow() -> Flow
}

struct Flow {
	enum Mode {
		case navigate
		case modal
	}
	
	let controller:PlatformViewController
	let mode:Mode
}
