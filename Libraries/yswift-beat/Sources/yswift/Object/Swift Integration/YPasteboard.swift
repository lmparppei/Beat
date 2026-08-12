//
//  File.swift
//  
//
//  Created by yuki on 2023/04/08.
//

public protocol YPasteboardCopy {
    func toPropertyList() -> Any?
    static func fromPropertyList(_ content: Any?) -> Self?
}

public protocol YPasteboardReferenceCopy: YPasteboardCopy {
    func toReferencePropertyList() -> Any?
}

#if canImport(Cocoa)
import Cocoa

extension NSPasteboard {
    public struct ObjectType<T: YPasteboardCopy>: ExpressibleByStringLiteral {
        public let type: NSPasteboard.PasteboardType
        
        public init(type: NSPasteboard.PasteboardType) {
            self.type = type
        }
        public init(rawValue: String) {
            self.type = .init(rawValue)
        }
        public init(stringLiteral value: StringLiteralType) {
            self.type = .init(value)
        }
    }
}

extension YPasteboardCopy {
    public func pasteBoardDataStorage(forType type: NSPasteboard.ObjectType<Self>) -> NSPasteboardWriting {
        let item = NSPasteboardItem()
        item.setObject(self, forType: type)
        return item
    }
}

extension YPasteboardReferenceCopy {
    public func pasteBoardRefStorage(forType type: NSPasteboard.ObjectType<Self>) -> NSPasteboardWriting {
        let item = NSPasteboardItem()
        item.setObjectRef(self, forType: type)
        return item
    }
}

extension NSPasteboardItem {
    public func object<T: YPasteboardCopy>(forType type: NSPasteboard.ObjectType<T>) -> NSDictionary? {
        self.propertyList(forType: type.type).flatMap{ $0 as? NSDictionary }
    }
    
    public func setObject<T: YPasteboardCopy>(_ node: T, forType type: NSPasteboard.ObjectType<T>) {
        guard let propertyList = node.toPropertyList() else { return }
        self.setPropertyList(propertyList, forType: type.type)
    }
    public func setObjectRef<T: YPasteboardReferenceCopy>(_ node: T, forType type: NSPasteboard.ObjectType<T>) {
        guard let propertyList = node.toReferencePropertyList() else { return }
        self.setPropertyList(propertyList, forType: type.type)
    }
}

extension NSPasteboard {
    @discardableResult public func declareType<T: YPasteboardCopy>(_ type: NSPasteboard.ObjectType<T>, owner: Any?) -> Int {
        self.declareTypes([type.type], owner: owner)
    }
    @discardableResult public func addTypes<T: YPasteboardCopy>(_ type: NSPasteboard.ObjectType<T>, owner: Any?) -> Int {
        self.addTypes([type.type], owner: owner)
    }
    
    public func canReadType(_ type: NSPasteboard.PasteboardType) -> Bool {
        self.canReadItem(withDataConformingToTypes: [type.rawValue])
    }
    public func canReadType<T: YPasteboardCopy>(_ type: NSPasteboard.ObjectType<T>) -> Bool {
        self.canReadItem(withDataConformingToTypes: [type.type.rawValue])
    }
    public func objects<T: YPasteboardCopy>(type: NSPasteboard.ObjectType<T>) -> [T]? {
        self.pasteboardItems?.compactMap{ $0.object(forType: type) }.compactMap{ T.fromPropertyList($0) }
    }
    
    public func setObjects<T: YPasteboardCopy>(_ nodes: [T], forType type: NSPasteboard.ObjectType<T>) {
        self.writeObjects(nodes.map{ $0.pasteBoardDataStorage(forType: type) })
    }
    
    public func setObjectsRef<T: YPasteboardReferenceCopy>(_ nodes: [T], forType type: NSPasteboard.ObjectType<T>) {
        self.writeObjects(nodes.map{ $0.pasteBoardRefStorage(forType: type) })
    }
}

extension NSView {
    public func registerForDraggedType<T: YPasteboardCopy>(_ type: NSPasteboard.ObjectType<T>) {
        self.registerForDraggedTypes([type.type])
    }
}

#endif

#if canImport(UIKit)
import UIKit
// TODO: Implementation for UIKit
#endif
