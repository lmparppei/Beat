//
//  BeatValueTransformers.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

public class BeatBoolTransformer:ValueTransformer {
	public override func transformedValue(_ value: Any?) -> Any? {
		guard let a = value as? Bool else { return false }
		return a == true
	}
    public class override func allowsReverseTransformation() -> Bool {
		return true
	}
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let a = value as? Bool else { return false}
		return a ? false : true
	}
}
