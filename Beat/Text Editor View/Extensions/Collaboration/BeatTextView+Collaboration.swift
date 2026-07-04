//
//  BeatTextView+Collaboration.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 22.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import yswift

/// Collaboration methods for the base text view
extension BeatTextView {
	
	func updateCarets() {
		guard let document = self.editorDelegate as? Document, let lm = self.layoutManager as? BeatLayoutManager
		else {
			return
		}
				
		let users = document.yClient?.activeUsers() ?? []
				
		CATransaction.begin()
		CATransaction.setDisableActions(true)
				
		if self.userCarets == nil {
			self.userCarets = NSMutableDictionary()
		}
				
		if let client = document.yClient {
			for user in users {
				if user.userId == client.userId { continue }
				let color = client.userColor(for: user.userId)
				
				// Update layout manager with the current user selection
				lm.updateRemoteUserSelection(user.userId, range: NSMakeRange(user.location, user.length))
				
				// Update caret map
				if userCarets[user.userId] == nil {
					let layer = CALayer()
					
					layer.anchorPoint = .zero
					layer.cornerRadius = 1
					layer.backgroundColor = (BeatColors.color(color) ?? NSColor.red).cgColor
					
					self.userCarets[user.userId] = layer
					self.layer?.addSublayer(layer)
				}
				
				if let layer = userCarets[user.userId] as? CALayer {
					let range = NSMakeRange(user.location + user.length, 0)
					if let boundingRect = self.boundingRect(for: range) {
						layer.frame = CGRect(x: boundingRect.origin.x - 1.0, y: boundingRect.origin.y, width: 2, height: boundingRect.height)
					}
				}
			}}
		
		// Remove inactive users
		let activeIds = users.map { $0.userId }
		for userId in self.userCarets.allKeys {
			guard let userId = userId as? String, !activeIds.contains(userId) else { continue }
			
			if let layer = self.userCarets[userId] as? CALayer {
				layer.removeFromSuperlayer()
			}
			
			self.userCarets.removeObject(forKey: userId)
			lm.userSelections?.removeObject(forKey: userId)
		}
		
		CATransaction.commit()
	}
	
}
