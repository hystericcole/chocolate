//
//  ChocolateTests.swift
//  ChocolateTests
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import XCTest
@testable import Chocolate

class ChocolateTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
	
	func testGradientDirection() {
		let points:[CGPoint] = [CGPoint(x:1, y:0.5), CGPoint(x:1, y:1), CGPoint(x:0.5, y:1), CGPoint(x:0, y:1), CGPoint(x:0, y:0.5), CGPoint(x:0, y:0), CGPoint(x:0.5, y:0), CGPoint(x:1, y:0)]
		let directions:[CAGradientLayer.Direction] = (0 ..< 8).map { .turn(CGFloat($0) / 8) }
		
		for index in 0 ..< 8 {
			let direction = directions[index]
			let (start, end) = direction.points
			let e = points[index]
			let s = points[(index + 4) % 8]
			
			XCTAssertEqual(start, s, "start direction \(index)/8")
			XCTAssertEqual(end, e, "end direction \(index)/8")
		}
	}
}
