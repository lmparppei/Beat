//
//  BeatQuickLookDelegate.swift
//  BeatQuickLook
//
//  Created by Lauri-Matti Parppei on 29.5.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatParsing

@objc protocol BeatQuickLookDelegate {
	var pageSize:BeatPaperSize { get }
}
