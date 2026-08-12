import Foundation

final class DictionaryEncoder {
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    enum DataEncoding {
        case nsdata
        case base64
    }

    final class Options {
        var userInfo: [CodingUserInfoKey : Any] = [:]
        var dataEncoding: DataEncoding = .nsdata
    }

    let options = Options()

    init() {}
    
    convenience init(dataEncoding: DataEncoding) {
        self.init()
        self.options.dataEncoding = dataEncoding
    }

    func encode<T : Encodable>(_ value: T) throws -> Any? {
        let encoder = _DictionaryEncoder(options: self.options)
        return try encoder.box_(value)
    }
}

private class _DictionaryEncoder : Encoder {
    
    var codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey : Any] { self.options.userInfo }
    
    fileprivate var storage: _DictionaryEncodingStorage

    fileprivate let options: DictionaryEncoder.Options
    
    fileprivate var canEncodeNewValue: Bool { self.storage.count == self.codingPath.count }

    fileprivate init(options: DictionaryEncoder.Options, codingPath: [CodingKey] = []) {
        self.options = options
        self.storage = _DictionaryEncodingStorage()
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        let topContainer: NSMutableDictionary
        if self.canEncodeNewValue {
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }

        let container = DictionaryCodingKeyedEncodingContainer<Key>(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let topContainer: NSMutableArray
        if self.canEncodeNewValue {
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }

        return _DictionaryUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    }

    func singleValueContainer() -> SingleValueEncodingContainer { self }
}

fileprivate struct _DictionaryEncodingStorage {
    private(set) fileprivate var containers: [Any?] = []

    fileprivate init() {}

    fileprivate var count: Int { self.containers.count }

    fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        self.containers.append(array)
        return array
    }

    fileprivate mutating func push(container: Any?) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() -> Any? {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}

fileprivate struct DictionaryCodingKeyedEncodingContainer<K: CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    private let encoder: _DictionaryEncoder

    private let container: NSMutableDictionary

    private(set) var codingPath: [CodingKey]

    init(referencing encoder: _DictionaryEncoder, codingPath: [CodingKey], wrapping container: NSMutableDictionary) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }
    
    mutating func encodeNil(forKey key: Key) throws {
        self.container[key.stringValue] = NSNull()
    }
    mutating func encode(_ value: Bool, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Int, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Int8, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Int16, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Int32, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Int64, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: UInt, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: String, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Float, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode(_ value: Double, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try self.encoder.box(value)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let dictionary = NSMutableDictionary()
        self.container[key.stringValue] = dictionary

        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }

        let container = DictionaryCodingKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let array = NSMutableArray()
        self.container[key.stringValue] = array

        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }
        return _DictionaryUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }

    mutating func superEncoder() -> Encoder {
        return _DictionaryReferencingEncoder(referencing: self.encoder, key: DictionaryCodingKey.super, convertedKey: DictionaryCodingKey.super, wrapping: self.container)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return _DictionaryReferencingEncoder(referencing: self.encoder, key: key, convertedKey: key, wrapping: self.container)
    }
}

private struct _DictionaryUnkeyedEncodingContainer : UnkeyedEncodingContainer {
    var count: Int { self.container.count }
    
    private(set) var codingPath: [CodingKey]
    
    private let encoder: _DictionaryEncoder

    private let container: NSMutableArray

    init(referencing encoder: _DictionaryEncoder, codingPath: [CodingKey], wrapping container: NSMutableArray) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    // MARK: - UnkeyedEncodingContainer Methods
    mutating func encodeNil()             throws { self.container.add(NSNull()) }
    mutating func encode(_ value: Bool)   throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Int)    throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Int8)   throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Int16)  throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Int32)  throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Int64)  throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: UInt)   throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: UInt8)  throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: UInt16) throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: UInt32) throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: UInt64) throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: String) throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Float)  throws { self.container.add(self.encoder.box(value)) }
    mutating func encode(_ value: Double) throws { self.container.add(self.encoder.box(value)) }

    mutating func encode<T : Encodable>(_ value: T) throws {
        self.encoder.codingPath.append(DictionaryCodingKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }
        self.container.add(try self.encoder.box(value) ?? NSNull())
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        self.codingPath.append(DictionaryCodingKey(index: self.count))
        defer { self.codingPath.removeLast() }

        let dictionary = NSMutableDictionary()
        self.container.add(dictionary)

        let container = DictionaryCodingKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self.codingPath.append(DictionaryCodingKey(index: self.count))
        defer { self.codingPath.removeLast() }

        let array = NSMutableArray()
        self.container.add(array)
        return _DictionaryUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }

    mutating func superEncoder() -> Encoder {
        return _DictionaryReferencingEncoder(referencing: self.encoder, at: self.container.count, wrapping: self.container)
    }
}

extension _DictionaryEncoder : SingleValueEncodingContainer {
    func encodeNil() throws { self.storage.push(container: NSNull()) }
    func encode(_ value: Bool)      throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Int)       throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Int8)      throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Int16)     throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Int32)     throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Int64)     throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: UInt)      throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: UInt8)     throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: UInt16)    throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: UInt32)    throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: UInt64)    throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: String)    throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Float)     throws { self.storage.push(container: self.box(value)) }
    func encode(_ value: Double)    throws { self.storage.push(container: self.box(value)) }
    func encode<T : Encodable>(_ value: T) throws { try self.storage.push(container: self.box(value)) }
}

extension _DictionaryEncoder {
    fileprivate func box(_ value: Bool)    -> Any { value }
    fileprivate func box(_ value: Int)     -> Any { value }
    fileprivate func box(_ value: Int8)    -> Any { value }
    fileprivate func box(_ value: Int16)   -> Any { value }
    fileprivate func box(_ value: Int32)   -> Any { value }
    fileprivate func box(_ value: Int64)   -> Any { value }
    fileprivate func box(_ value: UInt)    -> Any { value }
    fileprivate func box(_ value: UInt8)   -> Any { value }
    fileprivate func box(_ value: UInt16)  -> Any { value }
    fileprivate func box(_ value: UInt32)  -> Any { value }
    fileprivate func box(_ value: UInt64)  -> Any { value }
    fileprivate func box(_ value: Float)   -> Any { value }
    fileprivate func box(_ value: Double)  -> Any { value }
    fileprivate func box(_ value: String)  -> Any { value }
    fileprivate func box(_ value: Date)    -> Any { value }
    fileprivate func box(_ value: Data)    -> Any { value }
    
    fileprivate func box<T : Encodable>(_ value: T) throws -> Any? {
        return try self.box_(value)
    }

    fileprivate func box_<T : Encodable>(_ value: T) throws -> Any? {
        if T.self == Data.self || T.self == NSData.self {
            switch self.options.dataEncoding {
            case .nsdata: return value
            case .base64: return (value as! Data).base64EncodedString()
            }
        } else if T.self == URL.self || T.self == NSURL.self {
            return (value as! URL).absoluteString
        } else if T.self == CGFloat.self {
            return value as! CGFloat
        }

        let depth = self.storage.count
        do {
            try value.encode(to: self)
        } catch {
            if self.storage.count > depth { _ = self.storage.popContainer() }
            throw error
        }

        guard self.storage.count > depth else { return nil }
        return self.storage.popContainer()
    }
}

private class _DictionaryReferencingEncoder : _DictionaryEncoder {
    private enum Reference {
        case array(NSMutableArray, Int)
        case dictionary(NSMutableDictionary, String)
    }

    fileprivate let encoder: _DictionaryEncoder

    private let reference: Reference

    init(referencing encoder: _DictionaryEncoder, at index: Int, wrapping array: NSMutableArray) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(DictionaryCodingKey(index: index))
    }

    init(referencing encoder: _DictionaryEncoder, key: CodingKey, convertedKey: CodingKey, wrapping dictionary: NSMutableDictionary) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, convertedKey.stringValue)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(key)
    }

    fileprivate override var canEncodeNewValue: Bool {
        self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }

    deinit {
        let value: Any
        switch self.storage.count {
        case 0: value = NSDictionary()
        case 1: value = self.storage.popContainer() ?? NSNull()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case .array(let array, let index): array.insert(value, at: index)
        case .dictionary(let dictionary, let key): dictionary[NSString(string: key)] = value
        }
    }
}

