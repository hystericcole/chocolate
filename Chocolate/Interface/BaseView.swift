//
//  BaseView.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

class BaseView: CommonView, ViewControllerAttachable {
#if os(macOS)
	class var layerClass:CALayer.Type { return CALayer.self }
	
	override var isFlipped:Bool { return true }
	override var acceptsFirstResponder: Bool { return true }
#endif
	
	var priorSize:CGSize = .zero
	
	var viewController:PlatformViewController? {
#if os(macOS)
		return nextResponder as? PlatformViewController
#else
		return next as? PlatformViewController
#endif
	}
	
	override func prepare() {
		translatesAutoresizingMaskIntoConstraints = false
		
#if os(macOS)
		wantsLayer = true
#endif
	}
	
	func attachViewController(_ viewController:PlatformViewController) {
		autoresizingMask = .flexibleSize
	}
	
#if os(macOS)
	override func layout() {
		super.layout()
		arrangeContents()
	}
	
	override func makeBackingLayer() -> CALayer {
		return Self.layerClass.init()
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		arrangeContents()
	}
#endif
	
	func arrangeContents() {}
}

//	MARK: -

class BaseViewController: CommonViewController {
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		(view as? ViewControllerAttachable)?.attachViewController(self)
	}
	
#if os(macOS)
	func replaceChild(with child:PlatformViewController, duration:TimeInterval = 0.5, options:NSViewController.TransitionOptions = .crossfade) {
		if let old = children.last {
			addChild(child)
			transition(
				from:old,
				to:child,
				options: options,
				completionHandler: {
					old.removeFromParent()
				}
			)
		} else {
			addChild(child)
			child.view.frame = view.stableBounds
			view.addSubview(child.view)
		}
	}
#else
	func replaceChild(with child:PlatformViewController, duration:TimeInterval = 0.5, options:PlatformView.AnimationOptions = .transitionCrossDissolve) {
		if let old = children.last {
			transition(
				from:old,
				to:child,
				duration:duration,
				options:options,
				animations: {
					old.willMove(toParent:nil)
					self.addChild(child)
				},
				completion: { finished in
					old.removeFromParent()
					child.didMove(toParent:self)
				}
			)
		} else {
			addChild(child)
			child.view.frame = view.stableBounds
			view.addSubview(child.view)
			child.didMove(toParent:self)
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.viewWillAppear()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.viewDidAppear()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.viewWillDisappear()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		self.viewDidDisappear()
	}
	
	func viewWillAppear() {}
	func viewDidAppear() {}
	func viewWillDisappear() {}
	func viewDidDisappear() {}
#endif
}

//	MARK: -

class BaseTabController: CommonTabController {
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.translatesAutoresizingMaskIntoConstraints = false
		view.backgroundColor = .white
	}
	
#if os(macOS)
	override func tabView(_ tabView:NSTabView, didSelect tabViewItem:NSTabViewItem?) {
		super.tabView(tabView, didSelect:tabViewItem)
		
		guard let controller = tabViewItem?.viewController else { return }
		
		tabView.window?.makeFirstResponder(controller.view)
	}
#endif
}
