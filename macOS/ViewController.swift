//
//  ViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Cocoa

class ViewController: BaseViewController {
	override var representedObject: Any? {
		didSet {
		}
	}
	
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Chocolate.title
		//preferredContentSize = CGSize(width:400, height:800)
	}
	
	override func loadView() {
		view = PlatformView()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		view.window?.title = DisplayStrings.Chocolate.title
		
		let viewController =
			NSEvent.modifierFlags.contains(.option) ? ChocolateLumaRampViewController() :
			NSEvent.modifierFlags.contains(.control) ? ChocolateLayerViewController() :
			ChocolateViewController()
		
		replaceChild(with:viewController)
		applyMinimumSizeToWindow(from:viewController)
	}
	
	func applyMinimumSizeToWindow(from viewController:BaseViewController) {
		guard let window = view.window else { return }
		
		let screen = window.screen ?? NSScreen.main
		let limit = screen?.visibleFrame.size ?? CGSize(square:640)
		let size = viewController.view.positionableSize(fitting:Layout.Limit(size:limit))
		var minimum = size.minimum
		
		if #available(macOS 11.0, *) {
			let insets = view.safeAreaInsets
			
			minimum.width += insets.left + insets.right
			minimum.height += insets.top + insets.bottom
		}
		
		minimum.width = min(max(240, ceil(minimum.width)), limit.width)
		minimum.height = min(max(360, ceil(minimum.height)), limit.height)
		
		window.contentMinSize = minimum
	}
}
