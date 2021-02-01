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

protocol ViewControllerAttachable: AnyObject {
	func attachViewController(_ viewController:PlatformViewController)
}

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

class BaseView: PlatformView, ViewControllerAttachable {
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
	
	func prepareHierarchy() {
		guard let layout = makeLayout() else { return }
		
		PlatformView.orderPositionables([layout], environment:positionableEnvironment, addingToHierarchy:true, hierarchyRoot:self)
	}
	
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
	
	func invalidateLayout() { priorSize = .zero }
	func makeLayout() -> Positionable? { return nil }
	func applyLayout(_ layout:Positionable) { positionableContext.performLayout(layout) }
	func sizeChanged() { if let layout = makeLayout() { applyLayout(layout) } }
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		guard let layout = makeLayout() else { return super.positionableSizeFitting(size) }
		
		return layout.positionableSize(fitting:Layout.Limit(size:size)).data
	}
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

class BaseScrollingLayoutView: PlatformScroller, ViewControllerAttachable {
#if os(macOS)
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
		
		prepareView()
		prepareContent()
		prepareHierarchy()
		prepareLayout()
	}
	
	func prepareView() {
#if os(macOS)
		scrollerStyle = .overlay
		borderType = .noBorder
		autohidesScrollers = true
		hasVerticalScroller = true
		hasHorizontalScroller = true
#else
		contentInsetAdjustmentBehavior = .always
#endif
	}
	
	func prepareContent() {}
	
	func prepareHierarchy() {
		guard let layout = makeLayout() else { return }
		
#if os(macOS)
		let hierarchyRoot:PlatformView
		
		if let view = documentView {
			hierarchyRoot = view
		} else {
			hierarchyRoot = PlatformView()
			
			documentView = hierarchyRoot
		}
#else
		let hierarchyRoot = self
#endif
		
		PlatformView.orderPositionables([layout], environment:positionableEnvironment, addingToHierarchy:true, hierarchyRoot:hierarchyRoot)
	}
	
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
			sizeChanged(old:oldSize)
			priorSize = size
		}
	}
#else
	override func layoutSubviews() {
		super.layoutSubviews()
		
		let size = bounds.size
		
		if size != priorSize {
			sizeChanged(old:priorSize)
			priorSize = size
		}
	}
#endif
	
	func invalidateLayout() { priorSize = .zero }
	func makeLayout() -> Positionable? { return nil }
	
	func applyLayout(_ layout:Positionable) {
#if os(macOS)
		documentView?.positionableContext.performLayout(layout)
#else
		let content, bounds:CGRect
		let size = contentSize
		
		if contentInsetAdjustmentBehavior == .always {
			let insets = adjustedContentInset
			let padded = CGSize(width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
			
			content = CGRect(origin:.zero, size:contentSize)
			bounds = CGRect(origin:CGPoint(x:-insets.left, y:-insets.top), size:padded)
		} else {
			let insets = safeAreaInsets
			let padded = CGSize(width:size.width + insets.left + insets.right, height:size.height + insets.top + insets.bottom)
			
			content = CGRect(origin:CGPoint(x:insets.left, y:insets.top), size:contentSize)
			bounds = CGRect(origin:.zero, size:padded)
		}
		
		let context = Layout.Context(bounds:bounds, safeBounds:content, isDownPositive:false, environment:positionableEnvironment)
		
		context.performLayout(layout)
#endif
	}
	
	func sizeChanged(old:CGSize) {
		guard let layout = makeLayout() else { return }
		
#if os(macOS)
		let limit = bounds.size
		let inset = PlatformScroller.frameSize(forContentSize:.zero, horizontalScrollerClass:NSScroller.self, verticalScrollerClass:NSScroller.self, borderType:.noBorder, controlSize:verticalScroller?.controlSize ?? .regular, scrollerStyle:scrollerStyle)
		let intrinsicSize = layout.positionableSize(fitting:Layout.Limit(size:limit))
		let minimum = intrinsicSize.minimum
		let available = CGSize(
			width:minimum.height > limit.height ? limit.width - inset.width : limit.width,
			height:minimum.width > limit.width ? limit.height - inset.height : limit.height
		)
		let size = intrinsicSize.resolve(available)
		let content = CGSize(width:ceil(max(size.width, available.width)), height:ceil(max(size.height, available.height)))
		
		if let view = documentView {
			view.setFrameSize(content)
		} else {
			let view = PlatformView(frame:NSRect(origin:.zero, size:content))
			
			documentView = view
			PlatformView.orderPositionables([layout], environment:positionableEnvironment, addingToHierarchy:true, hierarchyRoot:view)
		}
#else
		let available = bounds.size
		let insets = contentInsetAdjustmentBehavior == .always ? adjustedContentInset : safeAreaInsets
		let limit = CGRect(origin:.zero, size:available).inset(by:insets).size
		let intrinsicSize = layout.positionableSize(fitting:Layout.Limit(size:limit))
		let size = intrinsicSize.resolve(limit)
		let content = CGSize(width:ceil(max(size.width, limit.width)), height:ceil(max(size.height, limit.height)))
		
		contentSize = content
#endif
		
		applyLayout(layout)
	}
	
	override func positionableSizeFitting(_ size:CGSize) -> Data {
		guard let layout = makeLayout() else { return super.positionableSizeFitting(size) }
		
		return layout.positionableSize(fitting:Layout.Limit(size:size)).data
	}
}
