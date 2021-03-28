//
//	ChocolateDrawing.swift
//	Chocolate
//
//	Created by Eric Cole on 3/13/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation

enum ChocolateDrawing {
	static func drawPlaneFromPolarCubeHCL(_ chclt:CHCLT, axis:Int, value:CHCLT.Scalar, pixels:UnsafeMutablePointer<UInt32>, width:Int, height:Int, rowLength:Int) {
		for x in 0 ..< width {
			let a = CHCLT.Scalar(x) / CHCLT.Scalar(width - 1)
			
			for y in 0 ..< height {
				let b = CHCLT.Scalar(y) / CHCLT.Scalar(height - 1)
				let r = min(hypot(b * 2 - 1, a * 2 - 1), 1)
				let t = atan2(b * 2 - 1, a * 2 - 1) / .pi
				let h, c, l:CHCLT.Scalar
				
				switch axis % 6 {
				case 0: h = value; c = 1 - t.magnitude * 2; l = 1 - r
				case 1: h = t * -0.5; c = value; l = 1 - r
				case 2: h = t * -0.5; c = r; l = value
				case 3: h = value; c = copysign(r, -t); l = t.magnitude
				case 4: h = r; c = value; l = t.magnitude
				default: h = r; c = 1 - t.magnitude * 2; l = value
				}
				
				let color = CHCLT.LinearRGB(chclt, hue:h, chroma:c, luma:l)
				
				pixels[y * rowLength + x] = color.pixel()
			}
		}
	}
	
	static func drawPlaneFromCubeHCL(_ chclt:CHCLT, axis:Int, value:CHCLT.Scalar, pixels:UnsafeMutablePointer<UInt32>, width:Int, height:Int, rowLength:Int) {
		let isFlipped = (axis / 3) & 1 != 0
		let count = isFlipped ? height : width
		let hues = axis % 3 == 0 ? [chclt.pure(hue:value)] : chclt.hueRange(start:0, shift:1 / CHCLT.Scalar(count), count:count)
		
		for x in 0 ..< width {
			let a = CHCLT.Scalar(x) / CHCLT.Scalar(width - 1)
			
			for y in 0 ..< height {
				let b = CHCLT.Scalar(y) / CHCLT.Scalar(height - 1)
				let h:Int, c, l:CHCLT.Scalar
				
				switch axis % 6 {
				case 0: h = 0; c = 1 - b; l = a
				case 1: h = x; c = value; l = 1 - b
				case 2: h = x; c = 1 - b; l = value
				case 3: h = 0; c = a; l = 1 - b
				case 4: h = y; c = value; l = a
				default: h = y; c = a; l = value
				}
				
				let color = CHCLT.LinearRGB(hues[h]).applyLuma(chclt, value:l).applyChroma(chclt, value:c)
				
				pixels[y * rowLength + x] = color.pixel()
			}
		}
	}
	
	static func drawPlaneFromCubeHCL(_ chclt:CHCLT, axis:Int, value:CHCLT.Scalar, image:MutableImage) {
		guard image.image.bitsPerPixel == 32 && image.image.colorSpace?.model == .rgb else { return }
		
		let width = image.image.width
		let height = image.image.height
		let data = image.data as NSMutableData
		let pixels = data.mutableBytes.assumingMemoryBound(to:UInt32.self)
		let rowLength = image.image.bytesPerRow / MemoryLayout<UInt32>.stride
		
		if axis < 0 {
			drawPlaneFromPolarCubeHCL(chclt, axis:-axis, value:value, pixels:pixels, width:width, height:height, rowLength:rowLength)
		} else {
			drawPlaneFromCubeHCL(chclt, axis:axis, value:value, pixels:pixels, width:width, height:height, rowLength:rowLength)
		}
	}
	
	static func drawHueGraphs(_ chclt:CHCLT, count:Int, context:CGContext, box:CGRect, polar:Bool) {
		let hues:[CHCLT.Vector3] = chclt.hueRange(start:0.0, shift:1.0 / CHCLT.Scalar(count), count:count)
		let domain:[CHCLT.Scalar] = (0 ..< count).map { CHCLT.Scalar($0) / CHCLT.Scalar(count - 1) }
		let mode:CGPathDrawingMode = polar ? .fillStroke : .stroke
		let opacity:CGFloat = 0.25
		
		let red:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:hues[$0].x) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(hues[$0].x)) }
		context.setStrokeColor(red:1.0, green:0.0, blue:0.0, alpha:1.0)
		context.setFillColor(red:1.0, green:0.0, blue:0.0, alpha:opacity)
		context.addLines(between:red)
		context.drawPath(using:mode)
		
		let green:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:hues[$0].y) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(hues[$0].y)) }
		context.setStrokeColor(red:0.0, green:1.0, blue:0.0, alpha:1.0)
		context.setFillColor(red:0.0, green:1.0, blue:0.0, alpha:opacity)
		context.addLines(between:green)
		context.drawPath(using:mode)
		
		let blue:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:hues[$0].z) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(hues[$0].z)) }
		context.setStrokeColor(red:0.0, green:0.0, blue:1.0, alpha:1.0)
		context.setFillColor(red:0.0, green:0.0, blue:1.0, alpha:opacity)
		context.addLines(between:blue)
		context.drawPath(using:mode)
		
		let luminances:[CHCLT.Scalar] = hues.map { chclt.luminance($0) }
		let luminance:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:luminances[$0]) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(luminances[$0])) }
		context.setStrokeColor(red:0.0, green:0.0, blue:0.0, alpha:1.0)
		context.setFillColor(red:0.0, green:0.0, blue:0.0, alpha:opacity)
		context.addLines(between:luminance)
		context.drawPath(using:mode)
		
		let chromas:[CHCLT.Scalar] = hues.map { chclt.chroma($0, luminance:chclt.luminance($0)) }
		let chroma:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:chromas[$0]) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(chromas[$0])) }
		context.setStrokeColor(red:0.5, green:0.0, blue:0.5, alpha:1)
		context.setFillColor(red:0.5, green:0.0, blue:0.5, alpha:opacity)
		context.addLines(between:chroma)
		context.drawPath(using:.stroke)
		
		let saturations:[CHCLT.Scalar] = hues.map { chclt.saturation($0, luminance:chclt.luminance($0)) }
		let saturation:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:saturations[$0]) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(saturations[$0])) }
		context.setStrokeColor(red:0.0, green:0.5, blue:0.5, alpha:1)
		context.setFillColor(red:0.0, green:0.5, blue:0.5, alpha:opacity)
		context.addLines(between:saturation)
		context.drawPath(using:.stroke)
		
		let minimums:[CHCLT.Scalar] = hues.map { chclt.applyLuminance($0, luminance:chclt.luminance($0), apply:0.5).min() }
		let minimum:[CGPoint] = polar
			? (0 ..< count).map { box.polar(turns:domain[$0], radius:minimums[$0]) }
			: (0 ..< count).map { box.unit(x:CGFloat(domain[$0]), y:CGFloat(minimums[$0])) }
		context.setStrokeColor(red:0.5, green:0.0, blue:0.5, alpha:1)
		context.setFillColor(red:0.5, green:0.0, blue:0.5, alpha:opacity)
		context.addLines(between:minimum)
		context.drawPath(using:.stroke)
	}
	
	//	MARK: -
	
	static func generateGraph(chclt:CHCLT, box:CGRect) -> CGImage? {
		guard let colorSpace = CGColorSpace(name:CGColorSpace.sRGB) else { return nil }
		guard let mutable = MutableImage(size:box.size, colorSpace:colorSpace, scale:1, opaque:true) else { return nil }
		
		let inner = box.insetBy(dx:2, dy:2)
		let polar = false
		
		mutable.context.setFillColor(gray:1, alpha:1)
		mutable.context.fill(box)
		
		if !polar {
			mutable.context.setStrokeColor(gray:0, alpha:1)
			mutable.context.stroke(inner)
		}
		
		drawHueGraphs(chclt, count:Int(inner.size.width), context:mutable.context, box:inner, polar:polar)
		
		return mutable.image
	}
	
	static func generateGraphs() {
		DispatchQueue.userInitiated.async {
			let box = CGRect(origin:.zero, size:CGSize(square:512))
			let chclt = CHCLT.default
			
			guard let image = generateGraph(chclt:chclt, box:box), let data = image.pngData() else { return }
			
			PlatformPasteboard.general.setPNG(data)
		}
	}
	
	static func generateIcon(chclt:CHCLT, dimension:CGFloat, axis:Int, value:CHCLT.Scalar) -> CGImage? {
		guard let colorSpace = CGColorSpace(name:CGColorSpace.genericRGBLinear) else { return nil }
		
		let outerSize = CGSize(square:dimension)
		let innerSize = CGSize(square:min(dimension * 0.875, dimension - 4))
		let innerBox = CGRect(origin:.zero, size:outerSize).relative(x:0.5, y:0.5, size:innerSize)
		let lineWidth = min(max(1, dimension / 128.0), 4)
		let isRadiusLuminance = axis < 0 && -axis % 6 < 2
		
		guard let outerMutable = MutableImage(size:outerSize, colorSpace:colorSpace, scale:1, opaque:false, intent:.absoluteColorimetric) else { return nil }
		guard let innerMutable = MutableImage(size:innerSize, colorSpace:colorSpace, scale:1, opaque:true, intent:.absoluteColorimetric) else { return nil }
		
		drawPlaneFromCubeHCL(chclt, axis:axis, value:value, image:innerMutable)
		outerMutable.context.setLineWidth(lineWidth)
		
		if !isRadiusLuminance {
			outerMutable.context.strokeEllipse(in:innerBox.insetBy(dx:-1.5 * lineWidth, dy:-1.5 * lineWidth))
		}
		
		outerMutable.context.setStrokeColor(gray:1, alpha:1)
		outerMutable.context.strokeEllipse(in:innerBox.insetBy(dx:-0.5 * lineWidth, dy:-0.5 * lineWidth))
		outerMutable.context.addEllipse(in:innerBox)
		outerMutable.context.clip()
		outerMutable.context.draw(innerMutable.image, in:innerBox)
		
		return outerMutable.image
	}
	
	static func generateIconPNG(chclt:CHCLT, dimension:CGFloat, axis:Int, value:CHCLT.Scalar, file:URL) {
		guard let image = generateIcon(chclt:chclt, dimension:dimension, axis:axis, value:value) else { return }
		guard let data = image.pngData() else { return }
		
		do { try data.write(to:file) } catch { print(error) }
	}
	
	static func generateIcons() {
		let sizes:[CGFloat] = [120, 180, 76, 152, 167, 16, 32, 64, 128, 256, 512, 1024]
		let axisValue:[(Int, CHCLT.Scalar)] = [(1, 0.75)]
		let spaceName:[(CHCLT, String)] = [(CHCLT_Pure.y709, "y709n")]
		let path = ("~/Desktop/Chocolate" as NSString).expandingTildeInPath
		let folder = URL(fileURLWithPath:path)
		let manager = FileManager.default
		var isDirectory:ObjCBool = false
		
		if !manager.fileExists(atPath:path, isDirectory:&isDirectory) {
			do {
				try manager.createDirectory(at:folder, withIntermediateDirectories:false, attributes:nil)
			} catch {
				print(error)
				return
			}
		} else if !isDirectory.boolValue {
			print("File exists at " + path)
			return
		}
		
		for dimension in sizes {
			let dimensionName = sizes.count > 1 ? "_" + String(Int(dimension)) : ""
			
			for (axis, value) in axisValue {
				let axisName = axisValue.count > 1 ? "_" + (axis < 0 ? "p" : "c") + String(axis.magnitude) : ""
				
				for (chclt, name) in spaceName {
					let spaceName = spaceName.count > 1 ? "_" + name : ""
					let fileName = "icon" + axisName + spaceName + dimensionName + ".png"
					
					DispatchQueue.userInitiated.async {
						let file = folder.appendingPathComponent(fileName)
						
						generateIconPNG(chclt:chclt, dimension:dimension, axis:axis, value:value, file:file)
					}
				}
			}
		}
	}
}

//	MARK: -

public struct CHCLTShading {
	public struct ColorLocation {
		public let color:CHCLT.LinearRGB
		public let alpha:CHCLT.Scalar
		public let location:CHCLT.Scalar
		
		func display(_ model:CHCLT) -> CHCLT.Color { CHCLT.Color(model, color, alpha:alpha) }
		func vector() -> CHCLT.Scalar.Vector4 { return CHCLT.Scalar.vector4(color.vector, alpha) }
	}

	public let model:CHCLT
	public let colors:[ColorLocation]
	var previousAbove = 0
	
	public init(model:CHCLT, colors:[ColorLocation]) {
		self.model = model
		self.colors = colors
	}
	
	public init(model:CHCLT, colors:[CHCLT.Color]) {
		let scalar = CHCLT.Scalar(colors.count - 1)
		
		self.init(model:model, colors:colors.indices.map { ColorLocation(color:colors[$0].linearRGB, alpha:colors[$0].alpha, location:CHCLT.Scalar($0) / scalar) })
	}
	
	public init(model:CHCLT, colors:[CHCLT.Color], locations:[CHCLT.Scalar]) {
		let indices = 0 ..< min(colors.count, locations.count)
		
		self.init(model:model, colors:indices.map { ColorLocation(color:colors[$0].linearRGB, alpha:colors[$0].alpha, location:locations[$0]) })
	}
	
	public mutating func interpolate(by scalar:CHCLT.Scalar) -> CHCLT.Scalar.Vector4 {
		let count = colors.count
		
		guard count > 1 else { return colors.first?.vector() ?? .zero }
		
		let above, below:Int
		let location = scalar
		
		if previousAbove > 0 && previousAbove < count && colors[previousAbove].location > location && colors[previousAbove - 1].location < location {
			above = previousAbove
			below = above - 1
		} else {
			above = colors.binarySearch(location) { $0.location < $1 }
			below = above - 1
			
			previousAbove = above
		}
		
		guard above < count else { return colors[below].vector() }
		guard above > 0 else { return colors[0].vector() }
		
		let colorAbove = colors[above]
		let colorBelow = colors[below]
		let fraction = (location - colorBelow.location) / (colorAbove.location - colorBelow.location)
		let alpha = colorBelow.alpha * (1 - fraction) + colorAbove.alpha * fraction
		let color = colorBelow.color.interpolated(towards:colorAbove.color, by:fraction)
		
		return CHCLT.Scalar.vector4(color.vector, alpha)
	}
	
	public func shadingFunction() -> CGFunction? {
		let context = UnsafeMutablePointer<CHCLTShading>.allocate(capacity:1)
		
		context.initialize(to:self)
		
		let evaluate:CGFunctionEvaluateCallback = { pointer, input, output in
			guard let shadingPointer = pointer?.assumingMemoryBound(to:CHCLTShading.self) else { return }
			
			let rgba = shadingPointer.pointee.interpolate(by:CHCLT.Scalar(input.pointee))
			
			output[0] = CGFloat(rgba.x)
			output[1] = CGFloat(rgba.y)
			output[2] = CGFloat(rgba.z)
			output[3] = CGFloat(rgba.w)
		}
		
		let release:CGFunctionReleaseInfoCallback = { pointer in
			guard let context = pointer?.assumingMemoryBound(to:CHCLTShading.self) else { return }
			
			context.deinitialize(count:1)
			context.deallocate()
		}
		
		var callbacks = CGFunctionCallbacks(version:0, evaluate:evaluate, releaseInfo:release)
		
		return CGFunction(info:context, domainDimension:1, domain:nil, rangeDimension:4, range:nil, callbacks:&callbacks)
	}
	
	public func shading(linearColorSpace:CGColorSpace, start:CGPoint, end:CGPoint, extendStart:Bool = true, extendEnd:Bool = true) -> CGShading? {
		guard linearColorSpace.model == .rgb, let function = shadingFunction() else { return nil }
		
		return CGShading(
			axialSpace:linearColorSpace,
			start:start,
			end:end,
			function:function,
			extendStart:extendStart,
			extendEnd:extendEnd
		)
	}
	
	public func shading(linearColorSpace:CGColorSpace, start:CGPoint, startRadius:CGFloat = 0, end:CGPoint, endRadius:CGFloat, extendStart:Bool = true, extendEnd:Bool = true) -> CGShading? {
		guard linearColorSpace.model == .rgb, let function = shadingFunction() else { return nil }
		
		return CGShading(
			radialSpace:linearColorSpace,
			start:start,
			startRadius:startRadius,
			end:end, endRadius:endRadius,
			function:function,
			extendStart:extendStart,
			extendEnd:extendEnd
		)
	}
}
