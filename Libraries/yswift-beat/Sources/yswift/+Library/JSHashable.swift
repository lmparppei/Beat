//
//  File.swift
//  
//
//  Created by yuki on 2023/04/02.
//

import Foundation

protocol JSHashable: AnyObject, Hashable, Equatable {}

extension JSHashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

