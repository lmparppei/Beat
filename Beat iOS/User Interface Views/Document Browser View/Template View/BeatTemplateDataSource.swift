//
//  BeatTemplateDataSource.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

@objc class BeatTemplateDataSource:NSObject, UICollectionViewDataSource {
	var templates:[[String:String]] = [
		["title": "New Screenplay", "description": "Create a new, blank document", "filename": "New Document"],
		["title": "Tutorial", "description": "Start here if you are new to Beat!", "icon": "map.fill", "filename": "Tutorial"]
	]
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return templates.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {		
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? BeatTemplateCell
		
		let template = self.templates[indexPath.last ?? 0]
		
		let filename = template["filename"] ?? ""
		let title = template["title"] ?? "(none)"
		let description = template["description"] ?? "(none)"
		
		let icon = template["icon"] ?? ""
		let image = UIImage(systemName: icon)
				
		cell?.title?.text = title
		cell?.templateDescription?.text = description
		if (image != nil) { cell?.icon?.image = image }

		// Get URL for resource
		let url = Bundle.main.url(forResource: filename, withExtension: "fountain")
		cell?.url = url
		
		return cell!
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}
	
}
