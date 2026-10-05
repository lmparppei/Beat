//
//  BeatDocumentViewController Extensions.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore
import BeatFileExport

@objc public extension BeatDocumentViewController {
	
	@IBAction func nextScene(_ sender:Any!) {
		if let line = self.parser.nextOutlineItem(of: .heading, from: self.selectedRange().location) {
			self.scroll(to: line)
		}
	}
	
	@IBAction func previousScene(_ sender:Any!) {
		if let line = self.parser.previousOutlineItem(of: .heading, from: self.selectedRange().location) {
			self.scroll(to: line)
		}
	}
	
	@IBAction func showCharacterList(_ sender:Any?) {
		let vc = BeatCharacterListViewController(editorDelegate: self)
		self.present(vc, animated: true)
	}
}

/// An extension to trick conformance to `BeatBackupViewControlDelegate` and to show backups
@objc extension BeatDocumentViewController:BeatBackupViewControllerDelegate {
	@IBAction func showBackups() {
		let vc = BeatBackupViewController(delegate: self)
		present(vc, animated: true)
	}
}

extension BeatDocumentViewController {
	open override func pageBreaksUpdated() {
		guard let textView = self.textView as? BeatUITextView,
			  let layoutManager = textView.layoutManager as? BeatLayoutManager,
			  let pageBreaksMap = layoutManager.pageBreaksMap
		else { return }
		
		textView.pageNumberOverlay?.reloadPageMap(pageBreaksMap)
	}
}
