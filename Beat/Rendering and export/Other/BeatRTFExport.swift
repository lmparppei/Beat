//
//  BeatRTFExport.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.1.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore

public class BeatRTFExport:NSObject {
	public class func register(_ manager:BeatFileExportManager) {
		manager.registerHandler(for: "RTF", fileTypes: ["rtf"], supportedStyles: ["Novel"]) { delegate in
			return rtf(delegate)
		}
	}
	
	class func rtf(_ delegate:BeatEditorDelegate) -> NSData? {
		let attrStr = NSMutableAttributedString()
		let settings = delegate.exportSettings

		var types:IndexSet = IndexSet()
		for element in delegate.styles.document._visibleElements {
			types.insert(Int(element.rawValue))
		}
		print("types", types)
		
		settings.additionalTypes = types
		
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
					pStyle.textBlocks = []
					
					// Remove left margin
					pStyle.firstLineHeadIndent = style.marginLeft + style.firstLineIndent
					pStyle.headIndent = style.marginLeft
					
					str.addAttribute(.paragraphStyle, value: pStyle, range: str.range)
				}
				
				attrStr.append(str)
			}
		}
		
		do {
			let data = try attrStr.data(from: attrStr.range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) as NSData
			print("Data", data)
			return data
		} catch {
			print("Error",error)
			return nil
		}
	}
}
