//
//  AppDelegate.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ aNotification:Notification) {
		if let mainWindow = NSApplication.shared.mainWindow {
			positionWindow(mainWindow)
		} else {
			newDocument(self)
		}
		
		//ChocolateDrawing.generateIcons()
		//ChocolateDrawing.generateGraphs()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	func positionWindow(_ window:NSWindow) {
		let screenHeight = NSScreen.main?.frame.size.height ?? 960
		
		window.setContentSize(CGSize(width:400, height:min(800, screenHeight * 0.75)))
		window.center()
	}
	
	@objc
	func newDocument(_ sender:NSObject) {
		let controller = ViewController()
		let window = NSWindow(contentViewController:controller)
		
		controller.applyMinimumSizeToWindow()
		positionWindow(window)
		controller.transformIntoWindowTabs()
		
		window.makeKeyAndOrderFront(sender)
	}
}
