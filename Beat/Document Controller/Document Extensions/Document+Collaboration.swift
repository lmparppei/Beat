//
//  Document+YDocument.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 17.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatCore
import yswift

extension Document {

	@objc @IBAction func startCollaboration(_ sender:Any?) {
		BeatCollaborationManager.beginCollaboration(document: self)
	}
		
	override open func endCollaboration(documentClosing:Bool) {
		super.endCollaboration(documentClosing: documentClosing)
		
		Task {
			await MainActor.run {
				self.collaborationButton?.isHidden = true
				self.collaborationButton?.reset()
			}
		}
	}
	
	override open func setupCollaboration(string:String, joining:Bool = false) {
		super.setupCollaboration(string: string, joining: joining)
		
		if let yClient {
			self.collaborationButton?.setup(with: yClient)
			self.collaborationButton?.isHidden = false
		}
	}
	
	
	// MARK: - Awareness
	
	override open func updateRemoteCarets() {
		self.textView?.updateCarets()
	}
	

}
