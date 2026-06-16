//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject {
    public func makeDescription<S: Sequence>(from proprties: S) -> String where S.Element == (String, Any?) {
        var components = [String]()
                
        for var (key, value) in proprties {
            if key == YObject.objectIDKey {
                key = "id"
            }
            if let _value = value, !(_value is NSNull) {
                if let _value = _value as? any YWrapperObject {
                    value = String(reflecting: _value.opaque)
                } else {
                    value = String(reflecting: value!)
                }
            } else {
                value = "nil"
            }
            
            components.append("\(key): \(value!)")
        }
        
        return "\(Self.self)(\(components.joined(separator: ", ")))"
    }
    
    public func makeDescription(in keys: Set<String>) -> String {
        self.makeDescription(from: self.elementSequence().filter{ keys.contains($0.0) }.sorted(by: { $0.0 < $1.0 }))
    }
}

protocol YObjectAutoDescription: YObject, CustomStringConvertible {}
extension YObjectAutoDescription {
    public var description: String {
        self.makeDescription(from: self.elementSequence().sorted(by: { $0.0 < $1.0 }))
    }
}

