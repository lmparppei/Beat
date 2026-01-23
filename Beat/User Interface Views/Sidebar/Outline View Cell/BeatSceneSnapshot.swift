//
//  BeatSnapshotView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.1.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore
import AppKit

class BeatSceneSnapshot:NSObject {
	/// Creates an image of the given scene in text view
	class func create(scene:OutlineScene, delegate:BeatEditorDelegate, maxHeight:CGFloat = 400.0) -> NSImage? {
		guard let textView = delegate.getTextView(),
			  let layoutManager = delegate.getTextView().layoutManager else {
			return nil
		}
		
		var range = scene.range()
		if NSMaxRange(range) == textView.text.count && textView.text.count > 0 {
			// For some mysterious reason, NSLayoutManager gives us a wrong rect if the range reaches the last symbol in text view.
			// Let's subtract a single characer from length to avoid that, even if this might cause weirdness in some cases.
			range.length -= 1
		}
		
		let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
		var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
		rect.origin.x += textView.textContainerInset.width
		rect.origin.y += textView.textContainerInset.height
		
		if rect.size.height > maxHeight { rect.size.height = maxHeight }
		
		if let bitmap = textView.bitmapImageRepForCachingDisplay(in: rect) {
			bitmap.size = rect.size
			textView.cacheDisplay(in: rect, to: bitmap)
			
			let image = NSImage(size: rect.size)
			image.addRepresentation(bitmap)
			return image
		} else {
			return nil
		}
	}
}
