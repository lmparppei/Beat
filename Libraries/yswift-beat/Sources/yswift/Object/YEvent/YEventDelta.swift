//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YEvent {
    final public class Delta {
        public var insert: Any?
        public var retain: Int?
        public var delete: Int?
        var attributes: YTextAttributes?
        
        init(insert: Any? = nil, retain: Int? = nil, delete: Int? = nil, attributes: YTextAttributes? = nil) {
            self.insert = insert
            self.retain = retain
            self.delete = delete
            self.attributes = attributes
        }
        
        public func getAttributes() -> [String:(any YTextAttributeValue)] {
            var attrs:[String:(any YTextAttributeValue)] = [:]
            
            self.attributes?.forEach { key, value in
                attrs[key] = value
            }
            
            return attrs
        }
    }
}


extension YEvent.Delta: CustomStringConvertible {
    public var description: String {
        var dict = [String: Any]()
        dict["insert"] = insert
        dict["retain"] = retain
        dict["delete"] = delete
        dict["attributes"] = attributes
        return dict.description
    }
}

extension YEvent.Delta: Equatable {
    public static func == (lhs: YEvent.Delta, rhs: YEvent.Delta) -> Bool {
        return optionalEqual(lhs.insert, rhs.insert, compare: { equalJSON($0, $1) })
        && lhs.retain == rhs.retain
        && lhs.delete == rhs.delete
        && optionalEqual(lhs.attributes, rhs.attributes, compare: { $0.isEqual(to: $1) })
    }
}


