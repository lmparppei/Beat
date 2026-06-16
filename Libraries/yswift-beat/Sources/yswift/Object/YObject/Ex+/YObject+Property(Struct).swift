//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation
import Combine

extension YObject {
    public func register<T: YWrapperObject>(_ property: WProperty<T>, for key: String) {
        if T.isWrappingReference {
            self._register(property, for: "&\(key)")
        } else {
            self._register(property, for: key)
        }
    }
        
    private func _register<T: YElement>(_ property: WProperty<T>, for key: String) {
        property.storage.getter = {[unowned self] in T.fromOpaque(self._getValue(for: key)) }
        if case .decode = YObject.initContext {} else {
            self._setValue(property.initialValue().toOpaque(), for: key)
        }
    }
}

extension YObject {
    @propertyWrapper
    public struct WProperty<Value: YWrapperObject> {
        final class Storage {
            var _wrappedValue: Value?
            var getter: (() -> Value)!
        }
        
        public var wrappedValue: Value { storage.getter() }
        
        public var projectedValue: some Publisher<Value, Never> { storage.getter().publisher }
        
        let storage = Storage()
        let initialValue: () -> Value
        
        public init(wrappedValue: @autoclosure @escaping () -> Value) {
            self.initialValue = wrappedValue
        }
    }
}
