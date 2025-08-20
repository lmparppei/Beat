//
//  BeatiOSRendererComponents.swift
//  BeatiOSRendererPrototype
//
//  Created by Lauri-Matti Parppei on 22.1.2024.
//
/**
 
 This is a collection of small extensions and classes for iOS to support certain TextKit 1-like things and to ensure real PDF creation.
 For some incomprehensible reason printing a tet view in iOS won't create a real PDF, but instead rasterizes it, save for *some* elements.
 It doesn't make any sense, but these extensions take some pain out of it.
 
 Most of these "fixes" are essentially hacks to avoid some (undocumented) weirdness and bugs in TextKit 2. There are many inconsistencies
 and things that seem just blatantly broken, and it's unclear if those are intended behaviors or not.
 
 If Apple fixes any of them, my fixes and hacks might get broken. 
 
 */

import BeatCore
import BeatParsing

#if os(iOS)

/// `UILabel` subclass which acts as a "table cell" in text attachments
@objc public class BeatTextTableCell:UILabel {
    var width = 0.0
    var link:URL?
    
    @objc public init(content:NSAttributedString, width: Double = 0.0) {
        self.width = width
        
        let rect = CGRect(x: 0.0, y: 0.0, width: width, height: 12.0)
        super.init(frame: rect)
                
        self.attributedText = content
        
        self.tintColor = UIColor.black
        self.lineBreakMode = .byWordWrapping
        self.numberOfLines = 50
        
        self.layer.shouldRasterize = false
        
        // Get and remove link
        if content.length > 0, let linkAttr = content.attribute(.link, at: 0, effectiveRange: nil) {
            link = linkAttr as? URL
            
            let attrStr = NSMutableAttributedString(attributedString: content)
            attrStr.removeAttribute(.link, range: attrStr.range)
    
            self.attributedText = attrStr
        }
    }
    
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        // Thank you, @marcprux on stackoverflow
        let isPDF = !UIGraphicsGetPDFContextBounds().isEmpty
        
        if !self.layer.shouldRasterize && isPDF {
            self.draw(self.bounds)
        } else {
            super.draw(layer, in: ctx)
        }
    }
    
    var height:CGFloat {
        guard var attributedText = self.attributedText  else { return 0.0 }
        
        if attributedText.length > 0{
            attributedText = attributedText.trimWhiteSpace(includeLineBreaks: true)
        }
        if attributedText.length == 0 {
            // Nothing was left, return default line height
            return 12.0
        }
        
        // Calculate frame size
        let rect = attributedText.boundingRect(with: CGSize(width: self.frame.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        self.frame.size.height = rect.size.height
        self.frame.origin.y = 0
        
        return self.frame.height
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Text attachment which mimics a table (or rather a column) view
@objc public class BeatTableAttachment:NSTextAttachment {
    var cells:[BeatTextTableCell]?
    var spacing = 0.0
    var margin = 0.0
    
    @objc public init(cells:[BeatTextTableCell], spacing:CGFloat = 0.0, margin:CGFloat = 0.0) {
        NSTextAttachment.registerViewProviderClass(BeatTextTableProvider.self, forFileType: "public.data")
        
        self.cells = cells
        self.spacing = spacing
        self.margin = margin
        
        super.init(data: nil, ofType: "public.data")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// Text attachment provider for column view
@objc public class BeatTextTableProvider : NSTextAttachmentViewProvider {
    var cells:[BeatTextTableCell] = []
    var spacing = 0.0
    var margin = 0.0
    
    override init(textAttachment: NSTextAttachment, parentView: UIView?, textLayoutManager: NSTextLayoutManager?, location: NSTextLocation) {
        
        if let attachment = textAttachment as? BeatTableAttachment {
            self.cells = attachment.cells ?? []
            self.spacing = attachment.spacing
            self.margin = attachment.margin
        }
        
        super.init(textAttachment: textAttachment, parentView: parentView, textLayoutManager: textLayoutManager, location: location)
        tracksTextAttachmentViewBounds = true
    }
    
    @objc public override func loadView() {
        super.loadView()
        
        view = UIView()
        
        var x = self.margin
        for column in self.cells {
            column.frame.origin.x = x
            view?.addSubview(column)
            
            x = spacing + CGRectGetMaxX(column.frame)
        }
    }

    /// Returns height of the tallest column in this view
    @objc public override func attachmentBounds(
        for attributes: [NSAttributedString.Key : Any],
        location: NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        var height = 0.0
        for column in self.cells {
            let colHeight = column.height // Ask this only once to avoid resizing frames too much
            if colHeight > height { height = colHeight }
        }

        return CGRect(x: 0, y: 0, width: proposedLineFragment.width - 15.0, height: height)
    }
}


extension BeatPaginationPageView:NSTextLayoutManagerDelegate {
    public func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        return BeatRenderingTextFragment(textElement: textElement, range: textElement.elementRange)
    }
}

/// Text fragment which draws revision markers and ensures that we're drawing in the correct position in a true PDF.
/// This is essentially a hack and is cooked up using trial and error, and might be bound to break if Apple fixes some bugs in TextKit 2.
public class BeatRenderingTextFragment:NSTextLayoutFragment {
    public func draw(at point: CGPoint, origin:CGPoint, in context: CGContext) {
        var actualPoint = point
        actualPoint.x += origin.x
        actualPoint.y += origin.y
        
        super.draw(at: actualPoint, in: context)
        
        let pageView = self.textLayoutManager?.delegate as? BeatPaginationPageView
        //let visibleRevisions = BeatRevisions.everyRevisionIndex()
        let visibleRevisions = pageView?.settings.revisions ?? BeatRevisions.everyRevisionIndex()
        
        guard let container = self.textLayoutManager?.textContainer,
              let contentManager = textLayoutManager?.textContentManager
        else { return }
        
        let layoutFrame = self.layoutFragmentFrame
        
//            (textContentManager as? NSTextContentStorage)?.textStorage?.setAttributes(attrs, range: NSRange(range, in: textContentManager))
        
        // NSRange from UITextRange
        let offset = contentManager.offset(from: textLayoutManager!.documentRange.location, to: rangeInElement.location)
        let length = contentManager.offset(from: rangeInElement.location, to: rangeInElement.endLocation)
        let range = NSRange(location: offset, length: length)
        
        // Get attributed string, don't go out of range
        if let attrStr = pageView?.attributedString,
           NSIntersectionRange(range, attrStr.range).length == range.length {
            
            var highestRevisions:[NSValue:Int] = [:]
            
            // TODO: Flip these somehow (rects vs. attrs) or something
            // Or better yet, maybe create a dictinoary with line rect as key and the highest revision there
            attrStr.enumerateAttribute(NSAttributedString.Key(rawValue: BeatRevisions.attributeKey()), in: range, using: { value, attrRange, stop in
                guard let revisionValue = value as? NSNumber else { return }
                let generation = revisionValue.intValue
                
                // If the revision is not included in settings, just skip it.
                if (!visibleRevisions.contains(where: { $0 == generation })) {
                    return
                }
                
                // Size of the revision marker
                let width = 25.0
                let x = container.size.width - layoutFrame.origin.x - width
                
                context.saveGState()
                if origin != CGPointZero {
                    // We'll only translate if we're in PDF mode
                    context.translateBy(x: origin.x + layoutFrame.origin.x, y: origin.y + layoutFrame.origin.y)
                }
                
                // Get line fragment rects from text view
                let rects = self.textLayoutManager?.lineRects(in: attrRange) ?? []
                for rect in rects {
                    let rectValue = NSValue(cgRect: rect)
                    if highestRevisions[rectValue] == nil {
                        highestRevisions[rectValue] = generation
                    } else {
                        // Don't draw a revision marker because there already was a higher one
                        let highest = highestRevisions[rectValue] ?? 0

                        if generation < highest { continue }
                    }
                    
                    let localY = rect.origin.y - layoutFrame.origin.y
                    let revisionRect = CGRect(x: x, y: localY, width: width, height: rect.height)
                    
                    let marker = BeatRevisions.revisionGenerations()[generation].marker as NSString
                    marker.draw(at: revisionRect.origin, withAttributes: [
                        NSAttributedString.Key.font: BeatFontManager.shared.defaultFonts.regular,
                        NSAttributedString.Key.foregroundColor: UIColor.black,
                        NSAttributedString.Key.backgroundColor: UIColor.white
                    ])
                }
                
                context.restoreGState()

            })
        }
    }
    
    /// For some reason we need to draw fragments using _zero_ origin to make the show up in the correct position on page.
    override public func draw(at point: CGPoint, in context: CGContext) {
        draw(at: point, origin:CGPointZero, in: context)
    }
    
    /// We need to have line fragments that are as wide as the container, so we can draw on the edges
    /// Thank you, Shadowfacts – https://shadowfacts.net/2022/textkit-2/
    override public var layoutFragmentFrame: CGRect {
        var rect = super.layoutFragmentFrame
        
        if let container = self.textLayoutManager?.textContainer {
            rect.size.width = container.size.width - rect.origin.x
        }
        
        return rect
    }
}

extension NSTextLayoutManager {
    func lineRects(in range:NSRange) -> [CGRect] {
        guard let contentManager = self.textContentManager,
              let startLoc = contentManager.location(contentManager.documentRange.location, offsetBy: range.location),
              let endLoc = contentManager.location(startLoc, offsetBy: range.length),
              let textRange = NSTextRange(location: startLoc, end: endLoc) else {
            return []
        }
        
        var textLineRects:[CGRect] = []
        
        enumerateTextSegments(in: textRange, type: .standard, options: .rangeNotRequired) { _, rect, _, _ in
            textLineRects.append(rect)
            return true
        }
        
        return textLineRects
    }
}

#endif
