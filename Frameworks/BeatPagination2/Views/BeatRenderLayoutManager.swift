//
//  BeatRenderLayoutManager.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 8.8.2025.
//

import UXKit

// MARK: - Custom layout manager for text views in rendered page view

public class BeatRenderLayoutManager:NSLayoutManager, NSLayoutManagerDelegate {
	weak var pageView:BeatPaginationPageView?
    
    public override init() {
        super.init()
        self.delegate = self
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
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
        
        //var previousLine:Line?
                
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
            /*
            var newLine = false
            
            self.textStorage?.enumerateAttribute(NSAttributedString.Key(BeatRepresentedLineKey), in: range) { obj, attrRange, stop in
                if let line = obj as? Line {
                    if line.type == .heading {
                        stop.pointee = true
                    } else if line != previousLine {
                        newLine = true
                    }
                    
                    previousLine = line
                    stop.pointee = true
                }
            }
            
            if newLine {
                // Draw line number here
            }
             */
            
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
        drawHighlight(forGlyphRange: glyphsToShow)
	}
    
    /// Draws background highlights (for `Highlight` attribute) for given glyph range. Called in `drawBackground`.
    func drawHighlight(forGlyphRange glyphRange:NSRange) {
        let range = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        self.textStorage?.enumerateAttribute(NSAttributedString.Key("Highlight"), in: range) { val, highlightRange, stop in
            guard val != nil else { return }
            
            let gr = self.glyphRange(forCharacterRange: highlightRange, actualCharacterRange: nil)
            let rects = self.rectsForGlyphRange(gr)
            
            let c = UXColor.yellow.withAlphaComponent(0.9)
            c.setFill()
            
            for rectValue in rects {
                #if os(iOS)
                    let rect = rectValue.cgRectValue
                    UIRectFill(rect)
                #else
                    let rect = rectValue.rectValue
                    rect.fill()
                #endif
            }
        }
    }
    
    @objc func lineFragmentRanges() -> [NSRange] {
        guard let textStorage else { return [] }
        
        var ranges:[NSRange] = []
        
        let glyphRange = self.glyphRange(forCharacterRange: NSMakeRange(0, textStorage.length), actualCharacterRange: nil)
        enumerateLineFragments(forGlyphRange: glyphRange) { rect, bounds, container, range, stop in
            let charRange = self.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            if charRange.length > 0 {
                ranges.append(charRange)
            }
        }
        
        return ranges
    }
    
    @objc func stringInRange(_ range:NSRange) -> String? {
        guard let textStorage, NSMaxRange(range) <= textStorage.length else { return nil }
        
        return textStorage.string.substring(range: range)
    }
    
    func representedLineUUIDs(inRange:NSRange) -> [NSRange:String?] {
        guard let textStorage else { return [:] }
        
        var uuids:[NSRange:String] = [:]
        //let ranges: [NSRange] = self.lineFragmentRanges()
        
        textStorage.enumerateAttribute(NSAttributedString.Key(BeatRepresentedLineKey), in: textStorage.range) { value, range, stop in
            if let line = value as? Line {
                uuids[range] = line.uuidString()
            }
        }
        
        return uuids
    }
    
    
    /// This is a delegate trick to hold some Japanese and Chinese fonts constrained to the actual size that was paginated. For some reason, internal pagination code handles the Japanese sizing just well, but once it is rendered out, the slightly higher fonts start to drift. We'll forcibly set the line fragment rect when that happens.
    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<CGRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        let chrRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        guard let textStorage,
              let paragraphStyle = textStorage.attribute(.paragraphStyle, at: chrRange.location, effectiveRange: nil) as? NSParagraphStyle
        else { return false }
        
        let allowedHeight = paragraphStyle.maximumLineHeight + paragraphStyle.paragraphSpacingBefore + paragraphStyle.paragraphSpacing
        let proposedHeight = lineFragmentRect.pointee.height
        
        // If the proposed height is higher than what we are expecting from styles, let's not allow that. Baseline stays the same.
        if proposedHeight > allowedHeight {
            lineFragmentRect.pointee = CGRectMake(lineFragmentRect.pointee.origin.x, lineFragmentRect.pointee.origin.y, lineFragmentRect.pointee.width, allowedHeight)
            return true
        } else {
            return false
        }
    }
}
