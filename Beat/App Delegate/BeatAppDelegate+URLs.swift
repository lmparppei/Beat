//
//  BeatAppDelegate+URLs.swift
//  Beat Ad Hoc
//
//  Created by Lauri-Matti Parppei on 28.6.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

/// Custom URL handling delegate
extension BeatAppDelegate {
	@objc func handleURLs(_ urls:[URL]) {
		for url in urls {
			guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false) else { continue }
			
			let command = components.host
			let params = components.queryItems
			
			if command == "join", let roomId = params?.first?.name as? String {
				BeatCollaborationManager.openJoinModal(roomId)
			}
		}
	}
}
