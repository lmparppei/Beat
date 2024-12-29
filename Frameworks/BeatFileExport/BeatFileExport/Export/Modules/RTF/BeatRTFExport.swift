//
//  BeatRTFExport.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore
import BeatPagination2

public class BeatRTFExport:NSObject {
	public class func register(_ manager:BeatFileExportManager) {
		manager.registerHandler(for: "RTF", fileTypes: ["rtf"], supportedStyles: ["Novel", "Screenplay"]) { delegate in
			return export(delegate)
		}
	}
	
    class func export(_ delegate:BeatEditorDelegate, documentType:NSAttributedString.DocumentType = .rtf) -> NSData? {
		let attrStr = NSMutableAttributedString()
		let settings = delegate.exportSettings

        var types:IndexSet = IndexSet(IndexPath(indexes: settings.additionalTypes))
		for element in delegate.styles.document._visibleElements {
			types.insert(Int(element.rawValue))
		}
		
		settings.additionalTypes = types
        settings.simpleSceneHeadings = true
		
		if let screenplay = BeatScreenplay.from(delegate.parser, settings: settings) {
			
			let renderer = BeatRenderer(settings: settings)
			
			for line in screenplay.lines {
				// Check forced page breaks
				let style = delegate.styles.forLine(line)
				if (style.beginsPage) {
					attrStr.append(NSAttributedString(string: "\u{0c}"))
				}
				
				let str = NSMutableAttributedString(attributedString: renderer.renderLine(line))
                
				if str.length > 0, let pStyle = str.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSMutableParagraphStyle {
                    #if os(macOS)
                    pStyle.textBlocks = [] // RTF/DOC export doesn't take kindly to text blocks
                    
                    // macOS DOC export doesn't always respect line breaks for some reason
                    // if documentType == .officeOpenXML, line.type == .action { str.appendString("\n") }
                    #endif
                    
					// Remove left margin
					pStyle.firstLineHeadIndent = style.marginLeft + style.firstLineIndent
					pStyle.headIndent = style.marginLeft
					
					str.addAttribute(.paragraphStyle, value: pStyle, range: str.range)
				}
				
				attrStr.append(str)
			}
		}
		
		do {
            let data = try attrStr.data(from: attrStr.range, documentAttributes: [.documentType: documentType]) as NSData
			return data
		} catch {
			print("RTF export error:",error)
			return nil
		}
	}
}

class BeatDocxExport:NSObject {
    #if os(macOS)
    public class func register(_ manager:BeatFileExportManager) {
        manager.registerHandler(for: "Microsoft Word", fileTypes: ["docx"], supportedStyles: ["Screenplay", "Novel"]) { delegate in
            BeatRTFExport.export(delegate, documentType: .officeOpenXML)
        }
    }
    #endif
}
