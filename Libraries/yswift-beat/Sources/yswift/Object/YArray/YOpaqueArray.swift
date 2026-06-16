//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class YOpaqueArray: YOpaqueObject {
    public var count: Int { self.document == nil ? self._prelimContent.count : self._length }
    
    public var isEmpty: Bool { count == 0 }
    
    private var _prelimContent: [Any?] = []

    public override init() {
        super.init()
        self.serchMarkers = []
    }
    
    public convenience init(_ contents: [Any?]) {
        self.init()
        self.append(contentsOf: contents.map{ $0 })
    }
    

    public subscript(index: Int) -> Any? {
        if document != nil { return self.listGet(index) }
        return _prelimContent[index]
    }
    
    public subscript<R: _RangeExpression>(range: R) -> [Any?] {
        let range = range.relative(to: self.count)
        return self._slice(range.lowerBound, end: range.upperBound)
    }
    
    
    public func append(_ content: Any?) {
        assert(!(content is [Any]), "You puts array into array. Use self.append(contentsOf:) instead.")
        
        self.append(contentsOf: [content])
    }
    public func append(contentsOf contents: [Any?]) {
        assert(!contents.contains(where: { $0 is any YWrapperObject }), "You should not put wrapper directory to opaque object.")
        
        if let doc = self.document {
            doc.transact{ self.listPush(contents, $0) }
        } else {
            self._prelimContent.append(contentsOf: contents)
        }
    }
    
    
    public func insert(_ content: Any?, at index: Int) {
        assert(!(content is [Any]), "You puts array into array. Use self.append(contentsOf:) instead.")

        self.insert(contentsOf: [content], at: index)
    }
    public func insert(contentsOf contents: [Any?], at index: Int) {
        assert(!contents.contains(where: { $0 is any YWrapperObject }), "You should not put wrapper directory to opaque object.")
        
        if let doc = self.document {
            doc.transact{ self.listInsert(contents, at: index, $0) }
        } else {
            self._prelimContent.insert(contentsOf: contents, at: index)
        }
    }
    
    public func delete(at index: Int) {
        self._delete(at: index)
    }
    
    public func delete<R: _RangeExpression>(in range: R) {
        let range = range.relative(to: self.count)
        if range.isEmpty { return }
        self._delete(at: range.lowerBound, count: range.count)
    }
    
    public func deleteAll() {
        self.delete(in: 0..<count)
    }
    
    public func remove(at index: Int) -> Any? {
        let element = (self[index] as? YOpaqueObject).map{ $0.copy() } ?? self[index]
        self._delete(at: index)
        return element
    }
    
    public func assign(_ other: [Any?]) {
        self.deleteAll()
        self.append(contentsOf: other)
    }
    
    public override func copy() -> YOpaqueArray {
        let array = YOpaqueArray()
        array.insert(contentsOf: self.map{ ($0 as? YOpaqueObject).map{ $0.copy() } ?? $0 }, at: 0)
        return array
    }
    
    public func toArray() -> [Any?] { Array(self) }
    
    public override func toJSON() -> Any {
        self.map{ ($0 as? YOpaqueObject).map{ $0.toJSON() } ?? $0 } as [Any?]
    }

    // ============================================================================== //
    // MARK: - Private -
    
    private func _delete(at index: Int, count: Int = 1) {
        if let doc = self.document {
            doc.transact{ transaction in
                self.listDelete(at: index, count: count, transaction)
            }
        } else {
            self._prelimContent.removeSubrange(index..<index+count)
        }
    }
        
    private func _slice(_ start: Int = 0, end: Int? = nil) -> [Any?] {
        let end = end ?? self.count
        
        if self.document != nil { return self.listSlice(start: start, end: end) }
        return self._prelimContent[start..<end].map{ $0 }
    }

    override func _integrate(_ y: YDocument, item: YItem?) {
        super._integrate(y, item: item)
        self.insert(contentsOf: self._prelimContent, at: 0)
        self._prelimContent.removeAll()
    }

    override func _copy() -> YOpaqueArray { return YOpaqueArray() }

    override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        super._callObserver(transaction, _parentSubs: _parentSubs)
        self.callObservers(transaction: transaction, event: YOpaqueArrayEvent(self, transaction: transaction))
    }

    override func _write(_ encoder: YUpdateEncoder) {
        encoder.writeTypeRef(YArrayRefID)
    }
}

extension YOpaqueArray: Sequence {
    public typealias Element = Any?
    
    public func makeIterator() -> AnyIterator<Element> {
        if document != nil { return self.listCreateIterator() }
        return AnyIterator(self._prelimContent.makeIterator())
    }
}

extension YOpaqueArray: CustomStringConvertible {
    public var description: String {
        self.map{ $0 ?? "nil" }.description
    }
}

func readYArray(_decoder: YUpdateDecoder) -> YOpaqueArray {
    return YOpaqueArray()
}
