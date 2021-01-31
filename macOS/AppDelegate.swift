//
//  AppDelegate.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		positionMainWindow()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	func positionMainWindow() {
		guard let window = NSApplication.shared.mainWindow, let screen = NSScreen.main else { return }
		
		let screenHeight = screen.frame.size.height
		
		window.setContentSize(CGSize(width:400, height:min(800, screenHeight * 0.75)))
		window.center()
	}
}
