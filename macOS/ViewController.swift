//
//  ViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Cocoa

class ViewController: BaseTabController {
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Chocolate.title
		viewControllers = [ChocolateViewController(), ChocolatePlaneViewController(), ChocolateLumaRampViewController()]
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		applyMinimumSizeToWindow()
		view.window?.title = DisplayStrings.Chocolate.title
	}
	
	func transformIntoWindowTabs() {
		guard #available(OSX 10.12, *), let window = view.window else { return }
		
		let controllers = viewControllers
		
		for controller in controllers.dropFirst().reversed() {
			window.addTabbedWindow(NSWindow(contentViewController:controller), ordered:.above)
		}
		
		window.contentViewController = controllers[0]
	}
	
	func applyMinimumSizeToWindow() {
		guard let window = view.window else { return }
		
		let screen = window.screen ?? NSScreen.main
		let limit = screen?.visibleFrame.size ?? CGSize(square:640)
		var minimum = CGSize(width:240, height:360)
		
		for controller in viewControllers {
			let size = controller.view.positionableSize(fitting:Layout.Limit(size:limit))
			let require = size.minimum
			
			minimum.width = min(max(minimum.width, ceil(require.width)), limit.width)
			minimum.height = min(max(minimum.height, ceil(require.height)), limit.height)
		}
		
		//minimum = CGSize(square:320)
		
		window.contentMinSize = minimum
	}
}
