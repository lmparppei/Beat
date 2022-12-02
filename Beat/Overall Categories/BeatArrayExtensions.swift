//
//  BeatArrayExtensions.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension RangeReplaceableCollection where Iterator.Element : Equatable {
	// Remove first collection element that is equal to the given `object`:
	mutating func removeObject(object : Iterator.Element) {
		if let index = self.firstIndex(of: object) {
			self.remove(at: index)
		}
	}
}

extension NSArray {
	func swiftArray<T>() -> [T] {
		return self.compactMap({ $0 as? T })
	}
}
