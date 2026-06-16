//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

// list extensions
extension YOpaqueObject {
    func listSlice(start: Int, end: Int) -> [Any?] {
        var start = start, end = end
        
        if start < 0 { start = self._length + start }
        if end < 0 { end = self._length + end }
        var len = end - start
        var result: [Any?] = []
        var item = self._start
        
        while let uitem = item, len > 0 {
            if uitem.countable && !uitem.deleted {
                let values = uitem.content.values
                if values.count <= start {
                    start -= values.count
                } else {
                    var i = start; while i < values.count && len > 0 {
                        result.append(values[i])
                        len -= 1; i += 1
                    }
                    start = 0
                }
            }
            item = uitem.right as? YItem
        }
        
        return result
    }

    func listToArray(snapshot: YSnapshot) -> [Any?] {
        var cs: [Any?] = []
        var n = self._start
        while (n != nil) {
            if n!.countable && n!.isVisible(snapshot) {
                let c = n!.content.values
                for i in 0..<c.count {
                    cs.append(c[i])
                }
            }
            n = n!.right as? YItem
        }
        return cs
    }

    func listCreateIterator() -> AnyIterator<Any?> {
        var item = self._start
        var currentContent: [Any?]? = nil
        var currentContentIndex = 0
        
        return AnyIterator<Any?>{ () -> Any?? in
            // find some content
            if currentContent == nil {
                while (item != nil && item!.deleted) { item = item!.right as? YItem }
                if item == nil { return nil }
                currentContent = item!.content.values
                currentContentIndex = 0
                item = item!.right as? YItem
            }
            let value = currentContent![currentContentIndex] // ! ok
            currentContentIndex += 1
            if currentContent!.count <= currentContentIndex { currentContent = nil }
            return value
        }
    }

    func listForEach(snapshot: YSnapshot, _ body: (Any?) -> Void) {
        var item = self._start
        while (item != nil) {
            if item!.countable && item!.isVisible(snapshot) {
                let c = item!.content.values
                for i in 0..<c.count {
                    body(c[i])
                }
            }
            item = item!.right as? YItem
        }
    }

    func listGet(_ index: Int) -> Any? {
        var index = index
        let marker = YArraySearchMarker.find(self, index: index)
        var item = self._start
        if let marker = marker {
            item = marker.item
            index -= marker.index
        }
        while let uitem = item {
            if !uitem.deleted && uitem.countable {
                if index < uitem.length { return uitem.content.values[index] }
                index -= uitem.length
            }
            item = uitem.right as? YItem
        }
        
        fatalError("Index out of Bounds")
        
//        return nil
    }

    func listInsert(_ contents: [Any?], after referenceItem: YItem?, _ transaction: YTransaction) {
        var left = referenceItem
        let doc = transaction.doc
        let ownClientId = doc.clientID
        let store = doc.store
        let right = referenceItem == nil ? self._start : referenceItem!.right

        var jsonContent: [Any?] = []

        func packJsonContent() {
            if (jsonContent.count <= 0) { return }
            let id = YIdentifier(client: ownClientId, clock: store.getState(ownClientId))
            let content = YAnyContent(jsonContent)
            left = YItem(
                id: id,
                left: left, origin: left?.lastID,
                right: right, rightOrigin: right?.id,
                parent: .object(self), parentSub: nil,
                content: content
            )
            left!.integrate(transaction: transaction, offset: 0)
            jsonContent = []
        }

        for content in contents {
            guard let content = content else {
                jsonContent.append(content)
                continue
            }
            
            if content is NSNumber || content is String || content is NSDictionary || content is NSArray {
                jsonContent.append(content)
            } else {
                packJsonContent()
                if (content is Data) {
                    let id = YIdentifier(client: ownClientId, clock: store.getState(ownClientId))
                    let icontent = YBinaryContent(content as! Data)
                    left = YItem(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: .object(self), parentSub: nil, content: icontent)
                    left!.integrate(transaction: transaction, offset: 0)
                } else if content is YDocument {
                    let id = YIdentifier(client: ownClientId, clock: store.getState(ownClientId))
                    let icontent = YDocumentContent(content as! YDocument)
                    left = YItem(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: .object(self), parentSub: nil, content: icontent)
                    
                    left!.integrate(transaction: transaction, offset: 0)
                    
                } else if content is YOpaqueObject {
                    let id = YIdentifier(client: ownClientId, clock: store.getState(ownClientId))
                    let icontent = YObjectContent(content as! YOpaqueObject)
                    left = YItem(id: id, left: left, origin: left?.lastID, right: right, rightOrigin: right?.id, parent: .object(self), parentSub: nil, content: icontent)
                    left!.integrate(transaction: transaction, offset: 0)
                } else {
                    fatalError("Unexpected content type")
                }
            }
        }
        
        packJsonContent()
    }
    
    // this -> parent
    func listInsert(_ contents: [Any?], at index: Int, _ transaction: YTransaction) {
        var index = index
        if index > self._length {
            fatalError("Out of range")
//            throw YSwiftError.lengthExceeded
        }

        if index == 0 {
            if self.serchMarkers != nil {
                YArraySearchMarker.updateChanges(self.serchMarkers!, index: index, len: contents.count)
            }
            
            self.listInsert(contents, after: nil, transaction)
            return
        }
        
        let startIndex = index
        let marker = YArraySearchMarker.find(self, index: index)
        var n = self._start
        if marker != nil {
            n = marker!.item
            index -= marker!.index
            // we need to iterate one to the left so that the algorithm works
            if index == 0 {
                n = n!.prev
                index += (n != nil && n!.countable && !n!.deleted) ? n!.length : 0
            }
        }
        
        while n != nil {
            if !n!.deleted && n!.countable {
                if index <= n!.length {
                    if index < n!.length {
                        let id = YIdentifier(client: n!.id.client, clock: n!.id.clock + index)
                        YStructStore.getItemCleanStart(transaction, id: id)
                    }
                    break
                }
                index -= n!.length
            }
            n = n!.right as? YItem
        }
        if (self.serchMarkers != nil) {
            YArraySearchMarker.updateChanges(self.serchMarkers!, index: startIndex, len: contents.count)
        }
        
        return self.listInsert(contents, after: n, transaction)
    }
    
    func listPush(_ contents: [Any?], _ transaction: YTransaction) {
        let marker = (self.serchMarkers ?? [])
            .reduce(YArraySearchMarker(item: self._start, index: 0)) { maxMarker, currMarker in
                return currMarker.index > maxMarker.index ? currMarker : maxMarker
            }
    
        var item = marker.item
        while (item?.right != nil) { item = item!.right as? YItem }
        return self.listInsert(contents, after: item, transaction)
    }


    func listDelete(at index: Int, count: Int, _ transaction: YTransaction) {
        var index = index, length = count
        
        if length == 0 { return }
        let startIndex = index
        let startLength = length
        let marker = YArraySearchMarker.find(self, index: index)
        var item = self._start
        if marker != nil {
            item = marker!.item
            index -= marker!.index
        }
        // compute the first item to be deleted
        while item != nil && index > 0 {
            if !item!.deleted && item!.countable {
                if index < item!.length {
                    let id = YIdentifier(client: item!.id.client, clock: item!.id.clock + index)
                    _ = YStructStore.getItemCleanStart(transaction, id: id)
                }
                index -= item!.length
            }
            
            item = item!.right as? YItem
        }
        
        while (length > 0 && item != nil) {
            if !item!.deleted {
                if length < item!.length {
                    let id = YIdentifier(client: item!.id.client, clock: item!.id.clock + length)
                    _ = YStructStore.getItemCleanStart(transaction, id: id)
                }
                item!.delete(transaction)
                length -= item!.length
            }
            item = item!.right as? YItem
        }
        if length > 0 {
            fatalError("Index out of range.")
        }
        if (self.serchMarkers != nil) {
            YArraySearchMarker.updateChanges(self.serchMarkers!, index: startIndex, len: length - startLength)
        }
    }
}
