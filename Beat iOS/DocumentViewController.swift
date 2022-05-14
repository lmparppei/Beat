//
//  DocumentViewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class DocumentViewController: UIViewController, ContinuousFountainParserDelegate {
	var documentSettings: BeatDocumentSettings?
	var printSceneNumbers: Bool = true
	var characterInputForLine: Line?
	
	var document: UIDocument?
	
	@IBOutlet weak var textView: BeatUITextView?
    @IBOutlet weak var documentNameLabel: UILabel!
    
	var parser: ContinuousFountainParser?
	
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Access the document
        document?.open(completionHandler: { (success) in
            if success {
                // Display the content of the document, e.g.:
                self.documentNameLabel.text = self.document?.fileURL.lastPathComponent
				self.setupDocument()
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
	func setupDocument () {
		if (self.document == nil) { return; }
		
		var text = ""
		do {
			text = try String(contentsOf: self.document!.fileURL)
		} catch {}
		
		parser = ContinuousFountainParser(string: text, delegate: self)
		self.textView?.text = text
	}
	
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.document?.close(completionHandler: nil)
        }
    }
	
	// Delegation
	func sceneNumberingStartsFrom() -> Int {
		return 1
	}
	
	func selectedRange() -> NSRange {
		return self.textView!.selectedRange
	}
	
	func reformatLines(at indices: NSMutableIndexSet!) {
		// Do nothing
	}
	
	func applyFormatChanges() {
		// Do nothing for now
	}
}
