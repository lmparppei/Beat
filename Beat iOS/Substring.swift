//
//  Substring.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 16.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation


extension String {
	func substring(range:NSRange) -> String {
		if (range.length == 0) { return "" }
		
		let start = index(startIndex, offsetBy: range.location)
		let end = index(startIndex, offsetBy: NSMaxRange(range))
		let strRange = start..<end
		
		return String(self[strRange])
	}
	
	func stringByReplacing(range:NSRange, withString string:String) -> String {
		let range = Range(range, in: self)
		let result = self.replacingCharacters(in: range!, with: string)
		return result
	}
}
