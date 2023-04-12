//
//  iOSDocument.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

@objc protocol iOSDocumentDelegate {
	var parser:ContinuousFountainParser? { get }
	func text() -> String!
	func contentForSaving() -> String!
}

class iOSDocument: UIDocument {
    
	@objc var rawText:String! = ""
	@objc var settings:BeatDocumentSettings = BeatDocumentSettings()
	@objc var delegate:iOSDocumentDelegate?
	@objc var parser:ContinuousFountainParser {
		return self.delegate?.parser ?? ContinuousFountainParser()
	}
	
	override var description: String {
		return fileURL.deletingPathExtension().lastPathComponent
	}
	
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
		let text = delegate?.text() ?? ""
		return text.data(using: .utf8) as Any
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
		rawText = String(data: contents as! Data, encoding: .utf8)
		
		// Read settings and replace range
		let range = settings.readAndReturnRange(rawText)
		if (range.length > 0) {
			rawText = rawText.stringByReplacing(range: range, withString: "")
		}
    }


}

