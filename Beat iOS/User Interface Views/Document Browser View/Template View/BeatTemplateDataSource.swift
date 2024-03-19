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
	
	var templates:[[BeatTemplateFile]] = []
	var templateNames = [
		NSLocalizedString("templates.heading.newDocument", comment: "Start a new project"),
		NSLocalizedString("templates.heading.tutorials", comment: "Tutorials"),
		NSLocalizedString("templates.heading.templates", comment: "Templates")
	]
	
	override init() {
		super.init()
		
		let tutorials = BeatTemplates.shared().forFamily("Tutorials")
		let templates = BeatTemplates.shared().forFamily("Templates")
		
		// Insert a new, blank document
		var newDoc = BeatTemplateFile(filename: "New Document.fountain", title: "templates.newDocument.title", description: "templates.newDocument.description", product: nil)
		newDoc.url = Bundle(for: BeatTemplates.self).url(forResource: newDoc.filename, withExtension: "")
		//tutorials.insert(newDoc, at: 0)

		self.templates = [[newDoc], tutorials, templates]
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return templates[section].count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let template = self.templates[indexPath.first ?? 0][indexPath.last ?? 0]
		
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
		return self.templates.count
	}
	
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		if let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath) as? BeatTemplateHeading {
			sectionHeader.title?.text = self.templateNames[indexPath.first ?? 0]
			return sectionHeader
		}
		return UICollectionReusableView()
	}
	
}
