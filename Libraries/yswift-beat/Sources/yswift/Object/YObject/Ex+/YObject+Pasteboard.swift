//
//  File.swift
//
//
//  Created by yuki on 2023/04/07.
//

import Foundation

private let encoder = DictionaryEncoder()
private let decoder = DictionaryDecoder()

private struct YCopyContext: Codable {
    enum CopyType: String, Codable {
        case reference = "ref"
        case copy = "copy"
    }
    
    let type: CopyType
    let objectID: YObjectID
}

extension YObject: YPasteboardReferenceCopy {
    public func toPropertyList() -> Any? {
        assert(objectID != nil, "You cannot encode object without objectID.")
        let context = YCopyContext(type: .copy, objectID: self.objectID)
        return try! encoder.encode(context) as! NSDictionary
    }
    
    public func toReferencePropertyList() -> Any? {
        assert(objectID != nil, "You cannot encode object without objectID.")
        let context = YCopyContext(type: .reference, objectID: self.objectID)
        return try! encoder.encode(context) as! NSDictionary
    }
    
    public static func fromPropertyList(_ content: Any?) -> Self? {
        guard let content = content else { return nil }
        guard let context = try? decoder.decode(YCopyContext.self, from: content) else { return nil }
        guard let object = YObjectStore.shared.object(for: context.objectID) as? Self else { return nil }
        
        switch context.type {
        case .copy: return object.smartCopy()
        case .reference: return object
        }
    }
}

