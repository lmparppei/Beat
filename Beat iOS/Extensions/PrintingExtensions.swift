//
//  PrintingExtensions.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 24.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension UIPrintPageRenderer {
	@objc func printToPDF() -> NSData {
		let pdfData = NSMutableData()
		
		UIGraphicsBeginPDFContextToData(pdfData, self.paperRect, nil)
		
		self.prepare(forDrawingPages: NSMakeRange(0, self.numberOfPages))
		let bounds = UIGraphicsGetPDFContextBounds()
		
		for i in 0 ..< self.numberOfPages {
			UIGraphicsBeginPDFPage();
			self.drawPage(at: i, in: bounds)
		}
		
		UIGraphicsEndPDFContext();
		
		return pdfData;
	}
}
