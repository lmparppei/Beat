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
}
