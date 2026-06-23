//
//  Document+SplitViewDelegate.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

@objc extension Document:TKSplitHandleDelegate {
	@objc public func leftViewDidShow() {
		updateOutlineButton()
	}
	
	@objc public func leftViewDidHide() {
		updateOutlineButton()
	}
			
	@objc public func splitViewDidResize() {
		guard let splitHandle else { return }
		let width:Int = Int(splitHandle.bottomOrLeftView.frame.size.width)
		self.documentSettings.setInt(DocSettingSidebarWidth, as: width)
		
		self.updateLayout()
	}
	
	fileprivate func updateOutlineButton() {
		self.outlineButton?.state = self.sidebarVisible ? .on : .off
	}

}

func setSplitHandleMinSize(_ size:Float) {
	guard let splitHandle else { return }
	splitHandle.topOrRightMinSize = size;
}

/**
 
 I held you through the night
 while you cried
   inconsolably
   in their bed
   with her scent still on the pillow
 "not yet
 not yet
 mom, not yet"
 
 I'm here
 I'm your family now
 I'm still here
 I'll be here
 until
   it finds
   us too.
 
 
 */
