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
			let (start, end) = direction.points()
			let e = points[index]
			let s = points[(index + 4) % 8]
			
			XCTAssertEqual(start, s, "start direction \(index)/8")
			XCTAssertEqual(end, e, "end direction \(index)/8")
		}
	}
	
	func testColorModelCoordinates() {
		let v = CHCLT.Scalar.vector3(0.3125, 0.625, 0.9)
		let n = 144
		
		for axis in 0 ..< n {
			let c = ColorModel.components(coordinates:v, axis:axis)
			let d = ColorModel.coordinates(components:c, axis:axis)
			
			XCTAssertEqual(v, d, "axis \(axis)")
		}
		
		for axis in 0 ..< n {
			let c = ColorModel.coordinates(components:v, axis:axis)
			let d = ColorModel.components(coordinates:c, axis:axis)
			
			XCTAssertEqual(v, d, "axis \(axis)")
		}
	}
	
	func testOKLAB() {
		let xyz_lab:[(CHCLT.Vector3, CHCLT.Vector3)] = [
			(CHCLT.Scalar.vector3(0.95, 1.0, 1.09), CHCLT.Scalar.vector3(1, 0, 0)),
			(CHCLT.Scalar.vector3(1.0, 0.0, 0.0), CHCLT.Scalar.vector3(0.450, 1.236, -0.019)),
			(CHCLT.Scalar.vector3(0.0, 1.0, 0.0), CHCLT.Scalar.vector3(0.922, -0.671, 0.263)),
			(CHCLT.Scalar.vector3(0.0, 0.0, 1.0), CHCLT.Scalar.vector3(0.153, -1.415, -0.449))
		]
		
		for (xyz, lab) in xyz_lab {
			var converted_xyz = CHCLT.OKLAB.toXYZ(lab:lab)
			var converted_lab = CHCLT.OKLAB.fromXYZ(xyz:xyz)
			
			converted_xyz *= 100.0
			converted_lab *= 1000.0
			converted_xyz.round(.toNearestOrAwayFromZero)
			converted_lab.round(.toNearestOrAwayFromZero)
			converted_xyz /= 100.0
			converted_lab /= 1000.0
			
			XCTAssertEqual(xyz, converted_xyz)
			XCTAssertEqual(lab, converted_lab)
		}
	}
}
