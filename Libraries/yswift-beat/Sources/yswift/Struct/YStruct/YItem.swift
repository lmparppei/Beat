//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

extension YItem {
    enum Parent {
        case string(String)
        case id(YIdentifier)
        case object(YOpaqueObject)
        
        var string: String? { if case .string(let parent) = self { return parent }; return nil }
        var id: YIdentifier? { if case .id(let parent) = self { return parent }; return nil }
        var object: YOpaqueObject? { if case .object(let parent) = self { return parent }; return nil }
    }
}

/// Abstract class that represents any content.
final class YItem: YStructure, JSHashable {
    
    // =========================================================================== //
    // MARK: - Properties -

    /// The item that was originally to the left of this item.
    var origin: YIdentifier?

    /// The item that is currently to the left of this item.
    var left: YStructure?

    /// The item that is currently to the right of this item.
    var right: YStructure?

    /// The item that was originally to the right of this item. */
    var rightOrigin: YIdentifier?
    
    var parent: Parent?
    
    var parentKey: String?
    
    var redone: YIdentifier?
    
    var content: any YContent

    var info: UInt8

    var marker: Bool {
        get { self.info & 0b0000_1000 > 0 }
        set { if self.marker != newValue { self.info ^= 0b0000_1000 } }
    }

    var keep: Bool {
        get { self.info & 0b0000_0001 > 0 }
        set { if self.keep != newValue { self.info ^= 0b0000_0001 } }
    }
    
    override var deleted: Bool {
        get { return self.info & 0b0000_0100 > 0 }
        set { if self.deleted != newValue { self.info ^= 0b0000_0100 } }
    }
    
    var countable: Bool { self.info & 0b0000_0010 > 0 }
    
    var next: YItem? {
        var item = self.right
        while let uitem = item as? YItem, uitem.deleted { item = uitem.right }
        return item as? YItem
    }

    var prev: YItem? {
        var item = self.left
        while let uitem = item as? YItem, uitem.deleted { item = uitem.left }
        return item as? YItem
    }

    /// Computes the last content address of this Item.
    var lastID: YIdentifier {
        if self.length == 1 { return self.id }
        return YIdentifier(client: self.id.client, clock: self.id.clock + self.length - 1)
    }

    init(id: YIdentifier, left: YStructure?, origin: YIdentifier?, right: YStructure?, rightOrigin: YIdentifier?, parent: Parent?, parentSub: String?, content: any YContent) {
        self.origin = origin
        self.left = left
        self.right = right
        self.rightOrigin = rightOrigin
        self.parent = parent
        self.parentKey = parentSub
        self.redone = nil
        self.content = content
        self.info = self.content.isCountable ? 0b0000_0010 : 0
        
        super.init(id: id, length: content.count)
    }
    
    // =========================================================================== //
    // MARK: - Methods -
    
    override func getMissing(_ transaction: YTransaction, store: YStructStore) -> Int? {
        if let origin = self.origin, origin.client != self.id.client, origin.clock >= store.getState(origin.client) {
            return origin.client
        }
        if let rightOrigin = self.rightOrigin, rightOrigin.client != self.id.client, rightOrigin.clock >= store.getState(rightOrigin.client) {
            return rightOrigin.client
        }
        if let parent = self.parent?.id, self.id.client != parent.client, parent.clock >= store.getState(parent.client) {
            return parent.client
        }

        // We have all missing ids, now find the items
        if let origin = self.origin {
            self.left = store.getItemCleanEnd(transaction, id: origin)
            self.origin = (self.left as? YItem)?.lastID
        }
        if let rightOrigin = self.rightOrigin {
            self.right = YStructStore.getItemCleanStart(transaction, id: rightOrigin)
            self.rightOrigin = self.right!.id
        }
        if self.left is YGC || self.right is YGC {
            self.parent = nil
        }
        // only set parent if this shouldn't be garbage collected
        if self.parent == nil {
            if let leftItem = self.left as? YItem {
                self.parent = leftItem.parent
                self.parentKey = leftItem.parentKey
            }
            if let rightItem = self.right as? YItem {
                self.parent = rightItem.parent
                self.parentKey = rightItem.parentKey
            }
        } else if let parent = self.parent?.id {
            let parentItem = store.find(parent)
            if let content = (parentItem as? YItem)?.content as? YObjectContent {
                self.parent = .object(content.object)
            } else {
                self.parent = nil
            }
        }
        return nil
    }

    override func integrate(transaction: YTransaction, offset: Int) {
        if offset > 0 {
            self.id.clock += offset
            self.left = transaction.doc.store.getItemCleanEnd(
                transaction,
                id: YIdentifier(client: self.id.client, clock: self.id.clock - 1)
            )
            self.origin = (self.left as? YItem)?.lastID
            self.content = self.content.splice(offset)
            self.length -= offset
        }

        guard let parent = self.parent?.object else {
            let gc = YGC(id: self.id, length: self.length)
            gc.integrate(transaction: transaction, offset: 0)
            return
        }
        
        let hasLeft = self.left == nil && (self.right == nil || (self.right as? YItem)?.left != nil)
        let hasRight = (self.left != nil && (self.left as? YItem)?.right !== self.right)

        if hasLeft || hasRight {
            var left = self.left as? YItem

            var item: YItem?

            if let rightItem = left?.right as? YItem {
                item = rightItem
            } else {
                if let parentKey = self.parentKey {
                    item = parent.storage[parentKey]
                    while let left = item?.left as? YItem { item = left }
                } else {
                    item = parent._start
                }
            }
            
            var conflictingItems = Set<YItem>()
            var itemsBeforeOrigin = Set<YItem>()
            
            while let uitem = item, uitem !== self.right {
                itemsBeforeOrigin.insert(uitem)
                conflictingItems.insert(uitem)
                if self.origin == uitem.origin {
                    // case 1
                    if uitem.id.client < self.id.client {
                        left = uitem
                        conflictingItems.removeAll()
                    } else if self.rightOrigin == uitem.rightOrigin {
                        break
                    }
                } else if let origin = uitem.origin, itemsBeforeOrigin.contains(transaction.doc.store.getItem(origin)) {
                    // case 2
                    if !conflictingItems.contains(transaction.doc.store.getItem(origin)) {
                        left = uitem
                        conflictingItems.removeAll()
                    }
                } else {
                    break
                }
                item = uitem.right as? YItem
            }
            self.left = left
        }
        
        if let left = self.left as? YItem {
            let right = left.right
            self.right = right
            left.right = self
        } else {
            var right: YItem?
            
            if let parentKey = self.parentKey {
                right = parent.storage[parentKey]
                while let left = right?.left as? YItem { right = left }
            } else {
                right = parent._start
                parent._start = self
            }
            
            self.right = right
        }
        
        if let right = self.right as? YItem {
            right.left = self
        } else if let parentKey = self.parentKey {
        
            // set as current parent value if right == nil and this is parentSub
            parent.storage[parentKey] = self
            
            if let left = self.left as? YItem {
                // this is the current attribute value of parent. delete right
                left.delete(transaction)
            }
        }
        // adjust length of parent
        if self.parentKey == nil && self.countable && !self.deleted {
            parent._length += self.length
        }
        
        transaction.doc.store.addStruct(self)
        
        self.content.integrate(with: self, transaction)
        
        // add parent to transaction.changed
        transaction.addChangedType(parent, parentSub: self.parentKey)
        
        // delete if parent is deleted or if this is not the current attribute value of parent
        if let parentItem = parent._objectItem, parentItem.deleted { self.delete(transaction) }
        if self.parentKey != nil, self.right != nil { self.delete(transaction) }
    }
    
    override func merge(with right: YStructure) -> Bool {
        guard let right = right as? YItem else { return false }
        guard right.origin == self.lastID,
              self.right === right,
              self.rightOrigin == right.rightOrigin,
              self.id.client == right.id.client,
              self.id.clock + self.length == right.id.clock,
              self.deleted == right.deleted,
              self.redone == nil,
              right.redone == nil,
              type(of: self.content) == type(of: right.content),
              self.content.merge(with: right.content),
              let parent = self.parent?.object
        else { return false }
    
        for marker in parent.serchMarkers ?? [] where marker.item === right {
            marker.item = self
            if !self.deleted && self.countable {
                marker.index -= self.length
            }
        }
        
        if right.keep { self.keep = true }
        self.right = right.right
        
        if let right = self.right as? YItem { right.left = self }
        self.length += right.length
        
        return true
    }

    override func encode(into encoder: YUpdateEncoder, offset: Int) {
        let origin = offset > 0 ? YIdentifier(client: self.id.client, clock: self.id.clock + offset - 1) : self.origin
        let rightOrigin = self.rightOrigin
        let parentSub = self.parentKey
        
        let info: UInt8 =
            (self.content.typeid    & 0b0001_1111) |
            (origin == nil      ? 0 : 0b1000_0000) | // origin is defined
            (rightOrigin == nil ? 0 : 0b0100_0000) | // right origin is defined
            (parentSub == nil   ? 0 : 0b0010_0000)   // parentSub is non-nil
        
        encoder.writeInfo(info)
        
        if let origin = origin { encoder.writeLeftID(origin) }
        if let rightOrigin = rightOrigin { encoder.writeRightID(rightOrigin) }
        
        if origin == nil && rightOrigin == nil {
            switch self.parent {
            case .object(let parent):
                let parentItem = parent._objectItem
                if parentItem == nil {
                    let ykey = parent.findRootTypeKey()
                    encoder.writeParentInfo(true)
                    encoder.writeString(ykey)
                } else {
                    encoder.writeParentInfo(false)
                    encoder.writeLeftID(parentItem!.id)
                }
            case .id(let parent):
                encoder.writeParentInfo(false)
                encoder.writeLeftID(parent)
            case .string(let parent): // write parentYKey
                encoder.writeParentInfo(true)
                encoder.writeString(parent)
            case .none:
                fatalError("Unexpected case")
//                throw YSwiftError.unexpectedCase
            }
            
            if parentSub != nil { encoder.writeString(parentSub!) }
        }
        
        self.content.encode(into: encoder, offset: offset)
    }
}

// =========================================================================== //
// MARK: - Item Methods -

extension YItem {
    /** Mark this Item as deleted. */
    func delete(_ transaction: YTransaction) {
        guard !self.deleted, let parent = self.parent?.object else { return }
        
        // adjust the length of parent
        if self.countable && self.parentKey == nil {
            parent._length -= self.length
        }
        
        self.deleted = true
        transaction.deleteSet.add(client: self.id.client, clock: self.id.clock, length: self.length)
        transaction.addChangedType(parent, parentSub: self.parentKey)
        
        self.content.delete(transaction)
    }

    func gc(_ store: YStructStore, parentGC: Bool) {
        if !self.deleted {
            fatalError("Unexpected case")
        }
        
        self.content.gc(store)
        
        if parentGC {
            store.replaceStruct(self, newStruct: YGC(id: self.id, length: self.length))
        } else {
            self.content = YDeletedContent(self.length)
        }
    }
    
    func keepRecursive(keep: Bool) {
        var item: YItem? = self
        while let uitem = item, uitem.keep != keep {
            item!.keep = keep
            item = uitem.parent?.object?._objectItem
        }
    }

    func isVisible(_ snapshot: YSnapshot?) -> Bool {
        guard let snapshot = snapshot else {
            return !self.deleted
        }
        guard let sclock = snapshot.stateVectors[self.id.client], sclock > self.id.clock, !snapshot.deleteSet.isDeleted(self.id) else {
            return false
        }
        return true
    }

    /// Split leftItem into two items; this -> leftItem
    func split(_ transaction: YTransaction, diff: Int) -> YItem {
        let client = self.id.client, clock = self.id.clock
        
        let rightItem = YItem(
            id: YIdentifier(client: client, clock: clock + diff),
            left: self,
            origin: YIdentifier(client: client, clock: clock + diff - 1),
            right: self.right,
            rightOrigin: self.rightOrigin,
            parent: self.parent,
            parentSub: self.parentKey,
            content: self.content.splice(diff)
        )
        if self.deleted { rightItem.deleted = true }
        if self.keep { rightItem.keep = true }
        
        if let redone = self.redone { rightItem.redone = YIdentifier(client: redone.client, clock: redone.clock + diff) }
        
        self.right = rightItem
        if let rightRightItem = rightItem.right as? YItem { rightRightItem.left = rightItem }
        
        transaction._mergeStructs.value.append(rightItem)
        
        if let parentSub = rightItem.parentKey, rightItem.right == nil {
            rightItem.parent?.object?.storage[parentSub] = rightItem
        }
        self.length = diff
        return rightItem
    }
}

extension YItem {
    // TODO: Fix
    struct RightSequence: Sequence {
        let start: YItem?
        
        func makeIterator() -> some IteratorProtocol<YItem> {
            struct Iterator: IteratorProtocol {
                var item: YItem?
                mutating func next() -> YItem? { defer{ item = item?.right as? YItem }; return item }
            }
            return Iterator(item: start)
        }
    }
    
    struct LeftSequence: Sequence {
        let start: YItem?
                
        func makeIterator() -> some IteratorProtocol<YItem> {
            struct Iterator: IteratorProtocol {
                var item: YItem?
                mutating func next() -> YItem? { defer{ item = item?.left as? YItem }; return item }
            }
            return Iterator(item: start)
        }
    }
    
    func rightSequence() -> some Sequence<YItem> { RightSequence(start: self) }
    func leftSequence() -> some Sequence<YItem> { LeftSequence(start: self) }
}
