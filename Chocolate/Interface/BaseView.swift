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

protocol ViewControllerAttachable: AnyObject {
	func attachViewController(_ viewController:PlatformViewController)
}

extension PlatformView {
	var stableBounds:CGRect { return CGRect(origin:.zero, size:bounds.size) }
	
	var safeBounds:CGRect {
#if os(macOS)
		if #available(macOS 11.0, *) {
			let insets = safeAreaInsets
			let size = bounds.size
			
			return CGRect(x:insets.left, y:insets.top, width:size.width - insets.left - insets.right, height:size.height - insets.top - insets.bottom)
		}
		
		return stableBounds
#else
		return stableBounds.inset(by:safeAreaInsets)
#endif
	}
}

class BaseView: PlatformView, PlatformSizeChangeView, ViewControllerAttachable {
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
	
	override init(frame:CGRect) {
		super.init(frame:frame)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	func prepare() {
		translatesAutoresizingMaskIntoConstraints = false
		
#if os(macOS)
		wantsLayer = true
#endif
	}
	
	func attachViewController(_ viewController:PlatformViewController) {
		autoresizingMask = .flexibleSize
	}
	
#if os(macOS)
//	override func resizeSubviews(withOldSize oldSize: NSSize) {
//		super.resizeSubviews(withOldSize:oldSize)
//		sizeMayHaveChanged(newSize:bounds.size)
//	}
	
	override func layout() {
		super.layout()
		sizeMayHaveChanged(newSize:bounds.size)
	}
	
	override func makeBackingLayer() -> CALayer {
		return Self.layerClass.init()
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		sizeMayHaveChanged(newSize:bounds.size)
	}
#endif
	
	func invalidateLayout() { priorSize = .zero }
	func sizeChanged() {}
}

class BaseViewController: PlatformViewController {
	override init(nibName nibNameOrNil:String?, bundle nibBundleOrNil:Bundle?) {
		super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		(view as? ViewControllerAttachable)?.attachViewController(self)
	}
	
	func prepare() {}
	
#if os(iOS)
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
#endif
}

class BaseTabController: PlatformTabController {
	override init(nibName nibNameOrNil:String?, bundle nibBundleOrNil:Bundle?) {
		super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.translatesAutoresizingMaskIntoConstraints = false
		view.backgroundColor = .white
	}
	
	func prepare() {}
}

class BaseControl: PlatformControl {
	override init(frame:CGRect) {
		super.init(frame:frame)
		
		prepare()
	}
	
	required init?(coder:NSCoder) {
		super.init(coder:coder)
		
		prepare()
	}
	
	func prepare() {}
}
