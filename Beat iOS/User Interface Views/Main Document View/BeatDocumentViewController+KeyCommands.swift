//
//  BeatDocumentViewController+KeyCommands.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 12.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

extension BeatDocumentViewController {
	
	open override var keyCommands: [UIKeyCommand]? {
		return [
			UIKeyCommand(title: "Show Preview", action: #selector(togglePreview), input: "e", modifierFlags: [.command]),
		]
	}

}

