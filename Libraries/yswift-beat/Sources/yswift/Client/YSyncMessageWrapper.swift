//
//  YSyncMessageWrapper.swift
//  CRDTImplementation
//
//  Created by Lauri-Matti Parppei on 12.6.2026.
//

import Foundation

public struct YSyncMessageWrapper: Codable {
    public let type:MessageType
    public let data:Data
    
    public enum MessageType:Int, Codable {
        public typealias RawValue = Int
        case sync = 0
        case update = 1
        case awareness = 2
    }
    
    public func asData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
}
