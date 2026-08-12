//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YEvent {
    public enum Action: String {
        case add, update, delete
    }

    public struct Key {
        public let action: Action
        public let oldValue: Any?
        public let newValue: Any?
        
        init(action: YEvent.Action, oldValue: Any? = nil, newValue: Any? = nil) {
            self.action = action
            self.oldValue = oldValue
            self.newValue = newValue
        }
    }
    
    public struct Change {
        var added: Set<YItem>
        var deleted: Set<YItem>
        var keys: [String: Key]
        var delta: [YEvent.Delta]
        
        init(added: Set<YItem>, deleted: Set<YItem>, keys: [String : Key], delta: [YEvent.Delta]) {
            self.added = added
            self.deleted = deleted
            self.keys = keys
            self.delta = delta
        }
    }

}

