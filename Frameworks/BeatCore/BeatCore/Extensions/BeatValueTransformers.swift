//
//  BeatValueTransformers.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatBoolTransformer:ValueTransformer {
	override func transformedValue(_ value: Any?) -> Any? {
		guard let a = value as? Bool else { return false }
		return a == true
	}
	class override func allowsReverseTransformation() -> Bool {
		return true
	}
	override func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let a = value as? Bool else { return false}
		return a ? false : true
	}
}
