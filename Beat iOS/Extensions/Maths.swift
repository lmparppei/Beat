//
//  Maths.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 5.7.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation


// Specify the decimal place to round to using an enum
public enum RoundingPrecision {
	case ones
	case tenths
	case hundredths
}

// Round to the specific decimal place
public func preciseRound(
	_ value: Double,
	precision: RoundingPrecision = .ones) -> Double
{
	switch precision {
	case .ones:
		return round(value)
	case .tenths:
		return round(value * 10) / 10.0
	case .hundredths:
		return round(value * 100) / 100.0
	}
}
