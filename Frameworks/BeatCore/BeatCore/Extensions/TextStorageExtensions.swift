//
//  TextStorageExtensions.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.4.2024.
//

import Foundation

fileprivate var _isEditing = false

extension NSTextStorage {
    open override func beginEditing() {
        _isEditing = true
        super.beginEditing()
    }
    
    open override func endEditing() {
        _isEditing = false
        super.endEditing()
    }
    
    @objc public var isEditing:Bool {
        return _isEditing
    }

}
