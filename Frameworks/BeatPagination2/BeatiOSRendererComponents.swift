//
//  BeatiOSRendererComponents.swift
//  BeatiOSRendererPrototype
//
//  Created by Lauri-Matti Parppei on 22.1.2024.
//

import BeatCore
import BeatParsing

@objc public class BeatTextTableCell:UILabel {
    var width = 0.0
    
    @objc public init(content:NSAttributedString, width: Double = 0.0) {
        self.width = width
        
        let rect = CGRect(x: 0.0, y: 0.0, width: width, height: 12.0)
        super.init(frame: rect)
                
        self.attributedText = content
        
        self.tintColor = UIColor.black
        //self.lineBreakMode = .byWordWrapping
        self.numberOfLines = 50
    }
    
    var height:CGFloat {
        guard let attributedText = self.attributedText else { return 0.0 }
        
        // Calculate frame size
        var rect = attributedText.boundingRect(with: CGSize(width: self.frame.width, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        if let pStyle = attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
            rect.size.height -= pStyle.paragraphSpacingBefore;
            rect.size.height -= pStyle.paragraphSpacing;
        }
        
        self.frame.size.height = rect.size.height
        
        return self.frame.height
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

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
            
            x += spacing + CGRectGetMaxX(column.frame)
        }
    }

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


        return CGRect(x: 0, y: 0, width: proposedLineFragment.width, height: height)
    }
}
