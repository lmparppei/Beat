//
//  BeatRenderLayoutManager.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 8.8.2025.
//

import UXKit

// MARK: - Custom layout manager for text views in rendered page view

public class BeatRenderLayoutManager:NSLayoutManager {
	weak var pageView:BeatPaginationPageView?
    
	override public func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
		
		let container = self.textContainers.first!
        let revisions = pageView?.settings.revisions as? IndexSet ?? []
		
		if ((pageView?.isTitlePage ?? false)) {
			return
		}
		
        #if os(macOS)
		NSGraphicsContext.saveGraphicsState()
        #endif
		
		self.enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, textContainer, originalRange, stop in
			let markerRect = CGRectMake(container.size.width - 10 - (self.pageView?.pageStyle.marginRight ?? 0.0), usedRect.origin.y - 3.0, 15, usedRect.size.height)
			
			var highestRevision = -1
			var range = originalRange
			
			// This is a fix for some specific languages. Sometimes you might have more characters in range than what are stored in text storage.
			if (NSMaxRange(range) > self.textStorage!.string.count) {
				let len = max(self.textStorage!.string.count - NSMaxRange(range), 0)
				range = NSMakeRange(range.location, len)
				
				if (range.length == 0) {
					return
				}
			}
			
            // In rendered text, the revision attribute is a A NUMBER VALUE
			self.textStorage?.enumerateAttribute(NSAttributedString.Key(BeatRevisions.attributeKey()), in: range, using: { obj, attrRange, stop in
                guard obj != nil, let revisionValue = obj as? NSNumber else { return }
                
                let level = revisionValue.intValue

				// If the revision is not included in settings, just skip it.
                if !revisions.contains(level) { return }
				                
                if highestRevision < level {
					highestRevision = level
				}
			})
			
			if highestRevision == -1 { return }
			
            let generation = BeatRevisions.revisionGenerations()[highestRevision]
            
            let marker:NSString = generation.marker as NSString
            let font = BeatFontManager.shared.defaultFonts.regular
			marker.draw(at: markerRect.origin, withAttributes: [
				NSAttributedString.Key.font: font,
				NSAttributedString.Key.foregroundColor: UXColor.black
			])
		}
		
        #if os(macOS)
		NSGraphicsContext.restoreGraphicsState()
        #endif
	}
	
	override public func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
	}
}
