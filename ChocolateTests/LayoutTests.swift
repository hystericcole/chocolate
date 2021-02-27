//
//  LayoutTests.swift
//  ChocolateTests
//
//  Created by Eric Cole on 1/31/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import XCTest
@testable import Chocolate

class TestablePositionable: Positionable, CustomStringConvertible {
	var tag:Int
	var intrinsicContentSize:CGSize
	var compressionResistance:CGPoint
	var frame:CGRect
	
	var isRTL:Bool
	var isDownPositive:Bool
	var safeAreaInsets:CGSize
	
	var description:String { return "P.\(tag) \(intrinsicContentSize) -> \(frame)" }
	
	var positionableEnvironment:Layout.Environment {
		return Layout.Environment(isRTL:isRTL)
	}
	
	var positionableContext:Layout.Context {
		let bounds = CGRect(origin:.zero, size:frame.size)
		let safeBounds = bounds.insetBy(dx:safeAreaInsets.width, dy:safeAreaInsets.height)
		
		return Layout.Context(bounds:bounds, safeBounds:safeBounds, isDownPositive:isDownPositive, scale:1, environment:positionableEnvironment)
	}
	
	init(tag:Int = 0, size:CGSize = CGSize(width: -1, height: -1), frame:CGRect = .zero) {
		self.tag = tag
		self.frame = frame
		self.intrinsicContentSize = size
		
		self.isRTL = false
		self.isDownPositive = true
		self.safeAreaInsets = .zero
		self.compressionResistance = .zero
	}
	
	func positionableSize(fitting limit: Layout.Limit) -> Layout.Size {
		return Layout.Size(intrinsic:intrinsicContentSize)
	}
	
	func applyPositionableFrame(_ frame: CGRect, context: Layout.Context) {
		self.frame = frame
	}
	
	func orderablePositionables(environment:Layout.Environment, order:Layout.Order) -> [Positionable] {
		return [self]
	}
}

class LayoutTestCase: XCTestCase {
	func testColumns() {
		let size = CGSize(width:90, height:70)
		let targets = (0 ..< 13).map { TestablePositionable(tag:$0 + 1, size:size) }
		let rowTemplate = Layout.Horizontal(targets:[], spacing:4, alignment:.center, position:.center, primary:-1, direction:.natural)
		let columns = Layout.Columns(targets:targets, columnCount:3, spacing:7, template:rowTemplate, position:.center, primary:-1, direction:.natural)
		let container = TestablePositionable(frame:CGRect(x:10, y:10, width:1000, height:1000))
		let context = container.positionableContext
		let box = CGRect(x:100, y:100, width:800, height:800)
		let positionableSize = columns.positionableSize(fitting:Layout.Limit(size:box.size))
		
		columns.applyPositionableFrame(box, context:context)
		
		XCTAssertEqual(positionableSize.resolve(box.size), CGSize(width:278, height:378))
		XCTAssertEqual(targets[0].frame, CGRect(x:361, y:311, width:size.width, height:size.height))
		XCTAssertEqual(targets[2].frame, CGRect(x:549, y:311, width:size.width, height:size.height))
		XCTAssertEqual(targets[11].frame, CGRect(x:549, y:542, width:size.width, height:size.height))
		XCTAssertEqual(targets[12].frame, CGRect(x:361, y:619, width:size.width, height:size.height))
	}
}
