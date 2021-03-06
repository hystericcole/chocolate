//
//  MutableImage.swift
//  Chocolate
//
//  Created by Eric Cole on 1/14/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import CoreGraphics
import Foundation

struct MutableImage {
	struct Parameters {
		let space:CGColorSpace?
		let size:CGSize
		let scale:CGFloat
		let opaque:Bool
		let intent:CGColorRenderingIntent
		
		init(space:CGColorSpace?, size:CGSize, scale:CGFloat = 1, opaque:Bool = false, intent:CGColorRenderingIntent = .defaultIntent) {
			self.size = size
			self.space = space
			self.scale = scale
			self.opaque = opaque
			self.intent = intent
		}
		
		init(grayscale:Bool, size:CGSize, scale:CGFloat = 1, opaque:Bool = false) {
			self.init(space:CGImage.colorSpace(grayscale:grayscale), size:size, scale:scale, opaque:opaque)
		}
	}
	
	let image:CGImage
	let context:CGContext
	let data:CFMutableData
	let size:CGSize
	
	var scale:CGFloat { return CGFloat(image.width) / size.width }
	var space:CGColorSpace? { return image.colorSpace }
	var intent:CGColorRenderingIntent { return image.renderingIntent }
	var parameters:Parameters { return Parameters(space:space, size:size, scale:scale, opaque:opaque, intent:intent) }
	
	var opaque:Bool {
		switch image.alphaInfo {
		case .none, .noneSkipLast, .noneSkipFirst: return true
		case .alphaOnly: return true
		default: return false
		}
	}
	
	init(image:CGImage, context:CGContext, data:CFMutableData, size:CGSize) {
		self.image = image
		self.context = context
		self.data = data
		self.size = size
	}
	
	init?(size:CGSize, colorSpace space:CGColorSpace?, scale:CGFloat = 1, opaque:Bool = false, intent:CGColorRenderingIntent = .defaultIntent) {
		guard let (i, c, d) = CGImage.mutableImage(size:size, colorSpace:space, scale:scale, opaque:opaque, intent:intent) else { return nil }
		
		self.init(image:i, context:c, data:d, size:size)
	}
	
	init?(size:CGSize, grayscale:Bool = false, scale:CGFloat = 1, opaque:Bool = false, intent:CGColorRenderingIntent = .defaultIntent) {
		self.init(size:size, colorSpace:CGImage.colorSpace(grayscale:grayscale), scale:scale, opaque:opaque, intent:intent)
	}
	
	init?(parameters:Parameters) {
		self.init(size:parameters.size, colorSpace:parameters.space, scale:parameters.scale, opaque:parameters.opaque, intent:parameters.intent)
	}
	
	func isEquivalent(parameters:Parameters) -> Bool {
		guard opaque == parameters.opaque else { return false }
		guard space?.model == parameters.space?.model else { return false }
		guard intent == parameters.intent || parameters.intent == .defaultIntent else { return false }
		
		if parameters.scale == 0 {
			guard size == parameters.size else { return false }
		} else {
			let width = ceil(parameters.size.width * parameters.scale)
			let height = ceil(parameters.size.height * parameters.scale)
			
			guard Int(width) == image.width && Int(height) == image.height else { return false }
		}
		
		return true
	}
	
	func fill<T>(_ value:T) {
		let mutableData = data as NSMutableData
		
		mutableData.mutableBytes.assumingMemoryBound(to:T.self).assign(repeating:value, count:mutableData.length / MemoryLayout<T>.stride)
	}
	
	static func manage(image:inout MutableImage?, parameters:Parameters) {
		guard let existing = image, existing.isEquivalent(parameters:parameters) else {
			image = MutableImage(parameters:parameters)
			return
		}
		
		if parameters.scale > 0 && existing.size != parameters.size {
			let ratio = parameters.scale / existing.scale
			
			existing.context.scaleBy(x:ratio, y:ratio)
			
			image = MutableImage(image:existing.image, context:existing.context, data:existing.data, size:parameters.size)
		}
	}
}

extension CGImage {
	/// Create a paired `CGImage` and `CGContext` backed by a shared data buffer so that any drawing to the context or changes to the buffer will be reflected in the image the next time it is drawn.  Do not reduce the length of the data buffer.
	/// # Color Space
	/// When creating an image with a color space, the color space determines the number of channels in the image.  Grayscale color spaces only support opaque images.
	/// # Mask
	/// When no color space is provided, an image mask is created.  When the mask is opaque, clearing adds to the mask and drawing removes from the mask.  When the mask is not opaque, drawing in the context adds to the mask and clearing removes from the mask.
	/// # View
	/// When using the image with views or layers, create and assign a copy of the image every time the content changes or else the system may ignore the changes.
	/// - Parameters:
	///   - size: desired size of the image
	///   - space: color space of the image and context or nil for a mask image
	///   - scale: scale at which image will be rendrered or 0 for screen scale
	///   - opaque: with a color space, false creates an alpha channel and clears the image. with no color space, false inverts the decode array
	///   - intent: rendering intent for the image
	/// - Returns: paired `CGImage` and `CGContext` with the `CFData` that backs the pixels of both
	public static func mutableImage(
		size:CGSize, colorSpace space:CGColorSpace?, scale:CGFloat = 1, opaque:Bool = false,
		intent:CGColorRenderingIntent = .defaultIntent) -> (CGImage, CGContext, CFMutableData)? {
		
		let alpha:CGImageAlphaInfo
		let components:Int
		let order:CGBitmapInfo
		
		if let space = space {
			switch space.numberOfComponents {
			case 4 where opaque:
				components = 4
				alpha = .none
			case 3:
				components = 4
				alpha = opaque ? .noneSkipFirst : .premultipliedFirst
			case 1:
				components = 1//opaque ? 1 : 2
				alpha = .none//opaque ? .none : .premultipliedLast
			default:
				return nil
			}
		} else {
			components = 1
			alpha = .alphaOnly
		}
		
		switch components {
		case 4: order = BYTE_ORDER == BIG_ENDIAN ? .byteOrder32Big : .byteOrder32Little
		case 2: order = BYTE_ORDER == BIG_ENDIAN ? .byteOrder16Big : .byteOrder16Little
		default: order = []
		}
		
		let scale = scale > 0 ? scale : Common.Interface.scale
		let width = Int(ceil(size.width * scale))
		let height = Int(ceil(size.height * scale))
		let bytesPerRow = components * width
		let capacity = bytesPerRow * height
		
		guard width > 0 && height > 0 else { return nil }
		guard let data = CFDataCreateMutable(nil, capacity) else { return nil }
		
		CFDataSetLength(data, capacity)
		
		guard let context = CGContext(
			data:CFDataGetMutableBytePtr(data), width:width, height:height,
			bitsPerComponent:8, bytesPerRow:bytesPerRow, space:space ?? CGColorSpaceCreateDeviceGray(),
			bitmapInfo:UInt32(alpha.rawValue | order.rawValue)) else { return nil }
		
		if !opaque { context.clear(CGRect(x:0, y:0, width:width, height:height)) }
		if scale > 0 { context.scaleBy(x:scale, y:scale) }
		
		guard let provider = CGDataProvider(data:data) else { return nil }
		var image:CGImage?
		
		if let space = space {
			image = CGImage(width:width, height:height, bitsPerComponent:8,
				bitsPerPixel:8 * components, bytesPerRow:bytesPerRow, space:space,
				bitmapInfo:order.union(CGBitmapInfo(rawValue:alpha.rawValue)),
				provider:provider, decode:nil, shouldInterpolate:true, intent:intent
			)
		} else {
			let clearIsTransparent:[CGFloat] = [1, 0]
			
			image = CGImage(maskWidth:width, height:height, bitsPerComponent:8,
				bitsPerPixel:8 * components, bytesPerRow:bytesPerRow,
				provider:provider, decode:opaque ? nil : clearIsTransparent, shouldInterpolate:true
			)
		}
		
		guard let mutableImage = image else { return nil }
		
		return (mutableImage, context, data)
	}
	
	public static func colorSpace(grayscale:Bool) -> CGColorSpace {
		if grayscale {
			return CGColorSpace(name:CGColorSpace.genericGrayGamma2_2) ?? CGColorSpaceCreateDeviceGray()
		} else {
			if #available(macOS 10.11.2, iOS 9.3, *), let display = CGColorSpace(name:CGColorSpace.displayP3) { return display }
			
			return CGColorSpace(name:CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
		}
	}
	
	public static func render(
		size:CGSize, colorSpace space:CGColorSpace, scale:CGFloat = 1,
		opaque:Bool = false, intent:CGColorRenderingIntent = .defaultIntent,
		render:(CGContext, CGRect) -> Void) -> CGImage?
	{
		guard let (image, context, _) = mutableImage(size:size, colorSpace:space, scale:scale, opaque:opaque, intent:intent) else { return nil }
		
		render(context, CGRect(origin:.zero, size:size))
		
		return image
	}
	
	public static func render(
		size:CGSize, scale:CGFloat = 1, opaque:Bool = false,
		grayscale:Bool = false, intent:CGColorRenderingIntent = .defaultIntent,
		render:(CGContext, CGRect) -> Void) -> CGImage?
	{
		return CGImage.render(size:size, colorSpace:colorSpace(grayscale:grayscale),
			scale:scale, opaque:opaque, intent:intent, render:render)
	}
	
	public static func renderMask(
		size:CGSize, scale:CGFloat = 1,
		render:(CGContext, CGRect) -> Void) -> CGImage?
	{
		guard let (image, context, _) = mutableImage(size:size, colorSpace:nil, scale:scale, opaque:true) else { return nil }
		
		render(context, CGRect(origin:.zero, size:size))
		
		return image
	}
	
	public static func generateMask(width:Int, height:Int, generate:(UnsafeMutablePointer<UInt8>, Int, Int) -> Void) -> CGImage? {
		guard width > 0 && height > 0 else { return nil }
		
		let components:Int = 1
		let bytesPerRow = components * width
		let capacity = bytesPerRow * height
		
		guard let data = CFDataCreateMutable(nil, capacity) else { return nil }
		
		CFDataSetLength(data, capacity)
		
		generate(CFDataGetMutableBytePtr(data), width, height)
		
		guard let provider = CGDataProvider(data:data) else { return nil }
		
		return CGImage(
			maskWidth:width, height:height,
			bitsPerComponent:8, bitsPerPixel:8, bytesPerRow:bytesPerRow,
			provider:provider, decode:nil, shouldInterpolate:true
		)
	}
	
	public static func renderLines(size:CGSize, points:[CGPoint], scale:CGFloat = 1) -> CGImage? {
		return render(size:size, scale:scale, opaque:true, grayscale:true) { context, box in
			context.fill(box)
			context.addLines(between:points)
			context.strokePath()
		}
	}
}
