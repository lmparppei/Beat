//
//  BeatiOSPreviewController.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 15.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatPagination2
import BeatCore.BeatEditorDelegate
import WebKit

class BeatPreviewController:BeatPreviewManager {
	override func reload(with pagination: BeatPagination) {
		guard let previewView = self.previewView as? BeatPageViewController else { return }
		
		previewView.reload()
	}
	
	override func scrollToRange(_ range: NSRange) {
		// First find the corresponding page
		guard let pagination = self.pagination,
			  let pages = self.pagination?.pages
		else {
			return
		}
		
		var pageIndex = NSNotFound
		
		for i in 0 ..< pages.count {
			let page = pages[i]
			
			if NSLocationInRange(range.location, page.representedRange()) {
				pageIndex = i
				break
			}
		}
		
		
		if pageIndex != NSNotFound {
			// Fix page index if there's a title page
			if pagination.hasTitlePage { pageIndex += 1 }
			
			self.previewView?.scrollToPage(pageIndex)
		}
	}
}
