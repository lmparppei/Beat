//
//  NSLayoutManager+RectsForRange.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 30.1.2026.
//

public extension NSLayoutManager {
    
    /// - warning: This method is also implemented in Objective C for the editor layout manager. We can't use this extension there because of performance hit.
    func rectsForGlyphRange(_ glyphsToShow: NSRange) -> [NSValue] {
        var rects: [NSValue] = []
        
        guard let textContainer = textContainers.first else {
            return rects
        }
        
        enumerateLineFragments(forGlyphRange: glyphsToShow) {
            rect, usedRect, _, glyphRange, _ in
            
            let intersection = NSIntersectionRange(glyphsToShow, glyphRange)
            guard intersection.length > 0 else { return }
            
            let lineFragmentRect = self.boundingRect(
                forGlyphRange: intersection,
                in: textContainer
            )
            
#if os(iOS)
            rects.append(NSValue(cgRect: lineFragmentRect))
#else
            rects.append(NSValue(rect: lineFragmentRect))
#endif
        }
        
        return rects
    }
    
}
