//
//  BeatTemplateDataSource.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore

@objc class BeatTemplateDataSource:NSObject, UICollectionViewDataSource {
	
	var templateData = BeatTemplates.shared()
	
	var templates:[BeatTemplateFile] = []
	
	override init() {
		super.init()
		
		templates = BeatTemplates.shared().forFamily("Tutorials")
		templates.append(contentsOf: BeatTemplates.shared().forFamily("Templates"))
		
		// Insert a new, blank document
		var newDoc = BeatTemplateFile(filename: "New Document.fountain", title: "templates.newDocument.title", description: "templates.newDocument.description", product: nil)
		newDoc.url = Bundle(for: BeatTemplates.self).url(forResource: newDoc.filename, withExtension: "")
		templates.insert(newDoc, at: 0)
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return templates.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let template = self.templates[indexPath.last ?? 0]
		
		let title = NSLocalizedString(template.title, comment: "Template title")
		let description = NSLocalizedString(template.description, comment: "Template description")

		let icon = template.icon ?? ""

		let image = UIImage(systemName: icon)
				
		// Create cell
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? BeatTemplateCell
		
		cell?.title?.text = title
		cell?.templateDescription?.text = description
		
		// If no image is defined, use the default image in cell prototype (blank doc)
		if (image != nil) { cell?.icon?.image = image }

		// Get URL for resource
		cell?.url = template.url
		cell?.product = template.product
		
		// A smaller image for phones
		if UIDevice.current.userInterfaceIdiom == .phone {
			cell?.icon?.frame.size.width *= 0.7
			cell?.labelView?.frame.origin.x -= 0.3 * cell!.labelView!.frame.origin.x
		}

		return cell!
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}
	
}
