//
//	ChocolateGradientSlider.swift
//	Chocolate
//
//	Created by Eric Cole on 3/12/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import Foundation
import QuartzCore

class ChocolateGradientSlider: Viewable.Group {
	var layout:Layout.ThumbTrackHorizontal
	var thumb = Viewable.Color(color:PlatformColor(white:1, alpha:0.0))
	var track = Viewable.Gradient(colors:[], direction:.right)
	var action:Selector
	var radius:CGFloat
	weak var target:AnyObject?
	
	enum Constant {
		static let trackBorderWidth:CGFloat = 1.0
		static let thumbBorderWidth:CGFloat = 3.0
		static let trackInset = thumbBorderWidth - trackBorderWidth
	}
	
	struct InsetGradient: PositionableWithTarget {
		let target:Positionable
		let inset:CGFloat
		
		func applyPositionableFrame(_ frame: CGRect, context: Layout.Context) {
			target.applyPositionableFrame(frame, context:context)
			
			let gradients = target.orderablePositionables(environment:context.environment, order:.existing)
				.compactMap { $0 as? PlatformView }
				.compactMap { $0.layer as? CAGradientLayer }
			
			for layer in gradients {
				layer.applyDirection(.right, inset:inset / layer.bounds.size.width)
			}
		}
	}
	
	var value:Double {
		get { return layout.thumbPosition }
		set { layout.thumbPosition = newValue; view?.ordered = layout }
	}
	
	init(value:Double = 0.0, target:AnyObject? = nil, action:Selector, radius:CGFloat = 22) {
		let diameter = radius.native * 2
		let gradient = InsetGradient(target:track, inset:radius - Constant.trackInset)
		
		self.radius = radius
		self.action = action
		self.target = target
		
		self.layout = Layout.ThumbTrackHorizontal(
			thumb:thumb.fixed(width:diameter, height:diameter),
			trackBelow:Layout.empty,
			trackAbove:Layout.empty,
			trackWhole:gradient.rounded(),
			thumbPosition:value,
			trackInset:Layout.EdgeInsets(uniform:Constant.trackInset.native)
		)
		
		super.init(content:layout)
	}
	
	override func attachToView(_ view: ViewableGroupView) {
		super.attachToView(view)
		
		let thumbBorderColor = PlatformColor.black
		let trackBorderColor = PlatformColor.lightGray
		
		track.border(CALayer.Border(width:Constant.trackBorderWidth, radius:radius, color:trackBorderColor.cgColor))
		thumb.border(CALayer.Border(width:Constant.thumbBorderWidth, radius:radius, color:thumbBorderColor.cgColor))
		
		Common.Recognizer.attachRecognizers([
			Common.Recognizer(.pan(false), target:self, action:#selector(recognizerPanned)),
			Common.Recognizer(.tap(false, 1), target:self, action:#selector(recognizerPanned))
		], to:view)
	}
	
	func applyModel(model:ColorModel, axis:Int, chclt:CHCLT, hue:CHCLT.Scalar, count:Int = 360) {
		let linear = model.linearColors(axis:axis, chclt:chclt, hue:hue, count:count)
		let colors = linear.compactMap { $0.color() }
		
		track.colors = colors
	}
	
	@objc
	func recognizerPanned(_ recognizer:PlatformPanGestureRecognizer) {
		guard let view = view else { return }
		
		switch recognizer.state {
		case .recognized, .began, .changed: break
		default: return
		}
		
		let box = CGRect(origin:.zero, size:view.bounds.size)
		let groove = box.insetBy(dx:radius, dy:0)
		let location = recognizer.location(in:view)
		let offset = location.x.native - groove.origin.x.native
		let fraction = min(max(0, offset / groove.width.native), 1)
		
		guard value != fraction else { return }
		
		value = fraction
		
		PlatformApplication.shared.sendAction(action, to:target, from:view)
	}
}
