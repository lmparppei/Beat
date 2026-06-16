//
//  File.swift
//  
//
//  Created by yuki on 2023/04/01.
//

protocol _YObjectRefrence: YObject {}
extension YObject: _YObjectRefrence {}

extension _YObjectRefrence {
    public func reference() -> YReference<Self> { .init(self) }
}

final public class YReference<T: YObject> {
    
    public var value: T { YObjectStore.shared.object(for: objectID) as! T }
    
    let objectID: YObjectID
    
    init(objectID: YObjectID) { self.objectID = objectID }
    
    public init(_ object: T) { self.objectID = object.objectID }
    
    public static func reference(_ object: T) -> YReference<T> { .init(object) }
}

extension YReference: YValue {
    public static var isReference: Bool { true }
    
    public func toOpaque() -> Any? { self.objectID.value }
    
    public static func fromOpaque(_ opaque: Any?) -> YReference<T> {
        YReference(objectID: YObjectID(opaque as! Int))
    }
    
    public func toPropertyList() -> Any? { self.objectID.value }
    
    public static func fromPropertyList(_ content: Any?) -> YReference<T>? {
        guard let content = content as? Int else { return nil }
        return YReference(objectID: YObjectID(content))
    }
}

extension YReference: Equatable {
    public static func == (lhs: YReference<T>, rhs: YReference<T>) -> Bool {
        lhs.objectID == rhs.objectID
    }
}

extension YReference: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectID)
    }
}

extension YReference: RawRepresentable {
    public typealias RawValue = String
    
    public var rawValue: RawValue { objectID.compressedString() }
    
    public convenience init(rawValue: String) {
        self.init(objectID: YObjectID(compressedString: rawValue))
    }
}

extension YReference: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension YReference: Decodable {
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
}
