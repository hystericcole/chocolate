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
	
	var layout:Layout.ThumbTrackHorizontal
	var track = Viewable.Gradient(colors:[], direction:.right)
	var thumb = Viewable.Shape(
		path:ChocolateGradientSlider.thumbIndicatorPath(radius:10.0, thickness:1.0),
		box:CGRect(origin:.zero, size:CGSize(square:20.0)),
		style:Viewable.Shape.Style(fill:PlatformColor.black.cgColor)
	)
	var action:Selector
	var radius:CGFloat
	var isTracking:Bool
	weak var target:AnyObject?
	
	var value:Double {
		get { return layout.thumbPosition }
		set { layout.thumbPosition = newValue; view?.ordered = layout }
	}
	
	var thumbColor:CGColor? {
		get { return thumb.style.fill }
		set { thumb.style.fill = newValue }
	}
	
	var borderColor:CGColor? = PlatformColor.lightGray.cgColor {
		didSet { track.gradientLayer?.borderColor = borderColor }
	}
	
	init(value:Double = 0.0, target:AnyObject? = nil, action:Selector, radius:CGFloat = 22) {
		let diameter = radius.native * 2
		let gradient = InsetGradient(target:track, inset:radius - Constant.trackInset)
		
		self.radius = radius
		self.action = action
		self.target = target
		self.isTracking = false
		
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
	
	static func thumbIndicatorPath(radius:CGFloat = 8.0, thickness:CGFloat = 1.0) -> CGPath {
		let path = CGMutablePath()
		
		let two:CGFloat = 2.0
		let c:CGFloat = radius
		let r:CGFloat = radius - thickness
		let d:CGFloat = 1.0 + two.squareRoot()
		let s:CGFloat = r / d
		let c0 = CGPoint(x:c, y:c)
		let c1 = CGPoint(x:c + s, y:c + s)
		let c2 = CGPoint(x:c + s, y:c - s)
		let c3 = CGPoint(x:c - s, y:c - s)
		let c4 = CGPoint(x:c - s, y:c + s)
		
		path.addEllipse(in:CGRect(x:0, y:0, width:radius * 2, height:radius * 2))
		path.move(to:CGPoint(x:c, y:c + s))
		path.addArc(center:c1, radius:s, startAngle:1.00 * .pi, endAngle:0.25 * .pi, clockwise:true)
		path.addArc(center:c0, radius:r, startAngle:0.25 * .pi, endAngle:1.75 * .pi, clockwise:true)
		path.addArc(center:c2, radius:s, startAngle:1.75 * .pi, endAngle:1.00 * .pi, clockwise:true)
		path.addArc(center:c3, radius:s, startAngle:0.00 * .pi, endAngle:1.25 * .pi, clockwise:true)
		path.addArc(center:c0, radius:r, startAngle:1.25 * .pi, endAngle:0.75 * .pi, clockwise:true)
		path.addArc(center:c4, radius:s, startAngle:0.75 * .pi, endAngle:0.00 * .pi, clockwise:true)
		path.closeSubpath()
		
		return path
	}
	
	override func attachToView(_ view: ViewableGroupView) {
		super.attachToView(view)
		
		if let borderColor = borderColor {
			track.border(CALayer.Border(width:Constant.trackBorderWidth, radius:radius, color:borderColor))
		}
		
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
	func recognizerPanned(_ recognizer:PlatformGestureRecognizer) {
		guard let view = view else { return }
		
		switch recognizer.state {
		case .recognized, .began, .changed: break
		default: isTracking = false; return
		}
		
		let box = CGRect(origin:.zero, size:view.bounds.size)
		let groove = box.insetBy(dx:radius, dy:0)
		let location = recognizer.location(in:view)
		let offset = location.x.native - groove.origin.x.native
		let fraction = min(max(0, offset / groove.width.native), 1)
		
		guard value != fraction else { return }
		
		isTracking = recognizer is PlatformPanGestureRecognizer
		value = fraction
		
		if !isTracking {
			Common.animate(duration:0.25, animations:{ view.arrangeContents() }, completion:nil)
		}
		
		PlatformApplication.shared.sendAction(action, to:target, from:view)
	}
}
