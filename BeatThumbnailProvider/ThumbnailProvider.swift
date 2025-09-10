//
//  ThumbnailProvider.swift
//  BeatThumbnailProvider
//
//  Created by Lauri-Matti Parppei on 17.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 A very minimal quick look extension for Beat iOS.
 
 */

import UIKit
import QuickLookThumbnailing
import BeatParsing
import BeatCore

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
		do {
			let string = try String(contentsOf: request.fileURL)
			
			let parser = ContinuousFountainParser(string: string)!
			let titlePage = BeatTitlePage(parser.parseTitlePage() ?? [])

			let size = CGSizeMake(request.maximumSize.height * 0.694, request.maximumSize.height)
			
			let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: { () -> Bool in
				guard let font = UIFont(name: "Courier", size: size.height / 28) else {
					return false
				}
				
				var title = titlePage.stringFor("title")
				if (title.count == 0) { title = "Untitled" }
				title = title.uppercased()
				
				let credit = titlePage.stringFor("credit")
				if (credit.count > 0) { title += "\n\n" + credit }
				
				let authors = titlePage.stringFor("authors")
				if (authors.count > 0) { title += "\n\n" + authors }
				
				let pStyle = NSMutableParagraphStyle()
				pStyle.alignment = .center
				
				let attrs:[NSAttributedString.Key : Any] = [
					NSAttributedString.Key.font: font,
					NSAttributedString.Key.foregroundColor: UIColor.black,
					NSAttributedString.Key.paragraphStyle: pStyle
				]
				
				let titleStr = NSAttributedString(string: title, attributes: attrs)
				titleStr.draw(in: CGRectMake(size.width * 0.2, size.height * 0.25, size.width * 0.6, 150.0))
								
				// Draw icon at the bottom
				if let image = UIImage(named: "icon") {
					let rect = CGRect(x: size.width * 0.025, y: size.height - 40 - size.height * 0.025, width: 40, height: 40)
					image.draw(in: rect)
				} else {
					print("No image found")
				}
				
				return true
			})
			
			handler(reply, nil)
		} catch {
			handler(nil, nil)
		}
    }
}
