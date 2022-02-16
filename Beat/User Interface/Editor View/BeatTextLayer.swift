//
//  BeatTextLayer.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatTextLayer: CATextLayer {
	
	@objc public var attrString = NSAttributedString(string: "")
	@objc public var fontName = ""
	
	@objc func setLineHeight(_ height: CGFloat) {
		
		let paragraph = NSMutableParagraphStyle()
		paragraph.lineSpacing = height
		let attrs = [
			NSAttributedString.Key.font: NSFont (name: fontName, size: self.fontSize),
			NSAttributedString.Key.paragraphStyle: paragraph
		]
		
		let str = NSMutableAttributedString.init(string: self.string as! String)
		str.addAttributes(attrs as [NSAttributedString.Key : Any], range: NSMakeRange(0, str.length))
		self.attrString = str

	}

	override func draw(in ctx: CGContext) {
		
		// Flip the coordinate system
		ctx.textMatrix = .identity
		ctx.translateBy(x: 0, y: bounds.size.height)
		ctx.scaleBy(x: 1.0, y: -1.0)
		
		let path = CGMutablePath()
		path.addRect(bounds)
		
		let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
		let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), path, nil)
		CTFrameDraw(frame, ctx)
	}

}
