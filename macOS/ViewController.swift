//
//  ViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
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
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		view.window?.title = DisplayStrings.Chocolate.title
		
		let viewController = ChocolateViewController()
		//let viewController = ChocolateLayerViewController()
		
		replaceChild(with:viewController)
		applyMinimumSize(from:viewController)
	}
	
	override func viewDidLayout() {
		super.viewDidLayout()
		
		let box = view.stableBounds
		
		for child in view.subviews {
			child.frame = box
		}
	}
	
	func applyMinimumSize(from viewController:BaseViewController) {
		if let window = view.window, let layout = (viewController.view as? BaseView)?.makeLayout() {
			let size = layout.positionableSize(fitting:Layout.Limit(width:nil, height:nil))
			var minimum = size.minimum
			
			if #available(OSX 11.0, *) {
				let insets = view.safeAreaInsets
				
				minimum.width += insets.left + insets.right
				minimum.height += insets.top + insets.bottom
			}
			
			window.contentMinSize = minimum
		}
	}
}
