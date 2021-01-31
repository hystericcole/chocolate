//
//  BaseView.swift
//  Chocolate
//
//  Created by Eric Cole on 1/28/21.
//

import Foundation

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension PlatformView {
	var stableBounds:CGRect { return CGRect(origin:.zero, size:bounds.size) }
	
	var safeBounds:CGRect {
#if os(macOS)
		if #available(OSX 11.0, *) {
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

class BaseView: PlatformView {
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
		
		prepareView()
		prepareContent()
		prepareHierarchy()
		prepareLayout()
	}
	
	func prepareView() {}
	func prepareContent() {}
	func prepareHierarchy() {}
	func prepareLayout() {}
	
	func attachViewController(_ viewController:PlatformViewController) {
#if os(macOS)
		autoresizingMask = [.width, .height]
#else
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
#endif
		
	}
	
#if os(macOS)
	override func resizeSubviews(withOldSize oldSize: NSSize) {
		super.resizeSubviews(withOldSize:oldSize)
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged()
			priorSize = size
		}
	}
	
	override func makeBackingLayer() -> CALayer {
		return Self.layerClass.init()
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged()
			priorSize = size
		}
	}
#endif
	
	
	func makeLayout() -> Positionable? { return nil }
	func applyLayout(_ layout:Positionable) { positionableContext.performLayout(layout) }
	func sizeChanged() { if let layout = makeLayout() { applyLayout(layout) } }
	
	func invalidateLayout() { priorSize = .zero }
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
		
		(view as? BaseView)?.attachViewController(self)
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
