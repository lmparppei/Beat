//
//  BeatDocumentViewController Extensions.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 7.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
extension BeatDocumentViewController {
	@objc func setupTitleMenu() {
		/*
		navigationItem.titleMenuProvider = { suggestedActions in
			var children = suggestedActions
			children += [
				UIAction(title: "Comments", image: UIImage(systemName: "text.bubble")) { _ in }
			]
			return UIMenu(children: children)
		}
		*/
		
		let documentProperties = UIDocumentProperties(url: document.fileURL)
		if let itemProvider = NSItemProvider(contentsOf: document.fileURL) {
			documentProperties.dragItemsProvider = { _ in
				[UIDragItem(itemProvider: itemProvider)]
			}
			documentProperties.activityViewControllerProvider = {
				UIActivityViewController(activityItems: [itemProvider], applicationActivities: nil)
			}
		}
		
		navigationItem.documentProperties = documentProperties
	}
}
