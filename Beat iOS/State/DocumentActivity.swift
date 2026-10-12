//
//  DocumentActivity.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

enum DocumentActivity {
	static let openDocumentType = "fi.KAPITAN.Beat.openDocument"
	
	static func make(for url: URL) -> NSUserActivity {
		let activity = NSUserActivity(activityType: openDocumentType)
		activity.title = url.lastPathComponent
		activity.userInfo = ["documentURL": url.absoluteString]
		activity.targetContentIdentifier = url.absoluteString
		
		return activity
	}
	
	static func documentURL(from activity: NSUserActivity) -> URL? {
		guard activity.activityType == openDocumentType,
			  let urlString = activity.userInfo?["documentURL"] as? String else { return nil }
		return URL(string: urlString)
	}
}
