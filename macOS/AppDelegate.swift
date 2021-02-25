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
		positionWindow(NSApplication.shared.mainWindow)
		//AppDelegate.generateIcons()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	func positionWindow(_ window:NSWindow?) {
		guard let window = window, let screen = NSScreen.main else { return }
		
		let screenHeight = screen.frame.size.height
		
		window.setContentSize(CGSize(width:400, height:min(800, screenHeight * 0.75)))
		window.center()
	}
	
	@objc
	func newDocument(_ sender:NSObject) {
		let controller = ViewController()
		let window = NSWindow(contentViewController: controller)
		
		positionWindow(window)
		
		window.makeKeyAndOrderFront(sender)
	}
}

extension AppDelegate {
	static func generateIcon(chclt:CHCLT, dimension:CGFloat, axis:Int, value:CHCL.Scalar) -> CGImage? {
		guard let colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear) else { return nil }
		
		let outerSize = CGSize(square:dimension)
		let innerSize = CGSize(square:min(dimension * 0.875, dimension - 4))
		let innerBox = CGRect(origin:.zero, size:outerSize).relative(x:0.5, y:0.5, size:innerSize)
		let lineWidth = min(max(1, dimension / 128.0), 4)
		let isRadiusLuminance = axis < 0 && -axis % 6 < 2
		
		guard let outerMutable = MutableImage(size:outerSize, colorSpace:colorSpace, scale:1, opaque:false, intent:.absoluteColorimetric) else { return nil }
		guard let innerMutable = MutableImage(size:innerSize, colorSpace:colorSpace, scale:1, opaque:true, intent:.absoluteColorimetric) else { return nil }
		
		CHCL.LinearRGB.drawPlaneFromCubeHCL(chclt, axis:axis, value:value, image:innerMutable)
		outerMutable.context.setLineWidth(lineWidth)
		
		if !isRadiusLuminance {
			outerMutable.context.strokeEllipse(in:innerBox.insetBy(dx:-1.5 * lineWidth, dy:-1.5 * lineWidth))
		}
		
		outerMutable.context.setStrokeColor(gray:1, alpha:1)
		outerMutable.context.strokeEllipse(in:innerBox.insetBy(dx:-0.5 * lineWidth, dy:-0.5 * lineWidth))
		outerMutable.context.addEllipse(in:innerBox)
		outerMutable.context.clip()
		outerMutable.context.draw(innerMutable.image, in:innerBox)
		
		return outerMutable.image
	}
	
	static func generateIcons() {
		let sizes:[CGFloat] = [120, 180, 76, 152, 167, 16, 32, 64, 128, 256, 512, 1024]
		let axisValue:[(Int, Double)] = [(1, 0.75)]
		let spaceName:[(CHCLT, String)] = [(CHCLTPower.y709, "y709n")]
		let path = ("~/Desktop/Chocolate" as NSString).expandingTildeInPath
		let folder = URL(fileURLWithPath:path)
		let manager = FileManager.default
		var isDirectory:ObjCBool = false
		let prefix = "icon"
		
		if !manager.fileExists(atPath:path, isDirectory:&isDirectory) {
			do {
				try manager.createDirectory(at:folder, withIntermediateDirectories:false, attributes:nil)
			} catch {
				print("Remove App Sandbox capability from macOS target")
				print(error)
				return
			}
		} else if !isDirectory.boolValue {
			return
		}
		
		for dimension in sizes {
			DispatchQueue.global(qos:.userInitiated).async {
				for (axis, value) in axisValue {
					for (chclt, name) in spaceName {
						guard let image = generateIcon(chclt:chclt, dimension:dimension, axis:axis, value:value) else { return }
						guard let data = NSBitmapImageRep(cgImage:image).representation(using:.png, properties:[:]) else { return }
						
						var suffix = ""
						
						if axisValue.count > 1 { suffix += "_" + (axis < 0 ? "p" : "c") + String(axis.magnitude)  }
						if spaceName.count > 1 { suffix += "_" + name }
						if sizes.count > 1 { suffix += "_\(Int(dimension))" }
						
						let file = folder.appendingPathComponent(prefix + suffix + ".png")
						
						do { try data.write(to:file) } catch { print(error) }
					}
				}
			}
		}
	}
}
