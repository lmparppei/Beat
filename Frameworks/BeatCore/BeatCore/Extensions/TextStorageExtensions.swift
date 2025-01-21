//
//  TextStorageExtensions.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.4.2024.
//

import Foundation

fileprivate var _isEditing = false

extension NSTextStorage {

    @objc public var isEditing:Bool {
        return self.editedMask != []
    }
    
}
