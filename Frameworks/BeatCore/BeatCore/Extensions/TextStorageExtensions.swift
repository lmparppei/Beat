//
//  TextStorageExtensions.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.4.2024.
//


import Foundation

#if os(macOS)
fileprivate var _isEditing = false
#endif

/**
 For some reason the text view and text storage interaction behaves very differently on iOS and macOS, so we need different ways of telling if the text storage is editing changes. The macOS solution causes text range and selection issues on iOS and vice-versa.
 
 macOS stores the editing state to a fileprivate boolean, while iOS uses edited mask, which is *not* viable on macOS, for some reason or another.

 */
extension NSTextStorage {
    
    #if os(macOS)
    open override func beginEditing() {
        _isEditing = true
        super.beginEditing()
    }
    
    open override func endEditing() {
        _isEditing = false
        super.endEditing()
    }
    #endif
    
    
    @objc public var isEditing:Bool {
        #if os(macOS)
            return _isEditing
        #else
            return self.editedMask != []
        #endif
    }
    
}
