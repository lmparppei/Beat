//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

import Foundation
import XCTest
@testable import yswift

func XCTAssertEqualReference(_ a: Any?, _ b: Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let a = a as AnyObject
    let b = b as AnyObject
    
    XCTAssert(a === b, "(\(a)) is not equal to (\(a)) \(message())")
}

func XCTAssertEqualJSON(_ a: Any?, _ b : Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    func toJSON(_ a: Any?) -> Any {
        if a is NSNull { return "NSNull()" }
        guard let a = a else { return "nil" }
        guard let data = try? JSONSerialization.data(withJSONObject: a, options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]) else {
            return a
        }
        let json = String(data: data, encoding: .utf8)!
        return json
    }
    
    XCTAssert(equalJSON(a, b), "(\(toJSON(a))) is not equal to (\(toJSON(b))) \(message())", file: file, line: line)
}


private func compareItemIDs(_ a: YItem?, _ b: YItem?) -> Bool {
    if a === b { return true }
    return a?.id == b?.id
}

// returns updated docs
@discardableResult
func YAssertEqualDocs(_ docs: [TestDoc]) throws -> [YDocument] {
    try docs.forEach{ try $0.connect() }
    while try docs[0].connector.flushAllMessages() {}

    let mergedDocs = try docs.map{ doc in
        // swift add
        let ydoc = YDocument()
        let update = try YTestEnvironment.currentEnvironment.mergeUpdates(doc.updates.value)
        try YTestEnvironment.currentEnvironment.applyUpdate(ydoc, update, nil)
        return ydoc
    }
    
    var docs = docs as [YDocument]
    
    docs.append(contentsOf: mergedDocs)
    let userArrayValues = try XCTUnwrap(docs.map{ $0.getOpaqueArray("array").toJSON() } as? [[Any]])
    let userMapValues = try XCTUnwrap(docs.map{ $0.getOpaqueMap("map").toJSON() } as? [[String: Any]])
    let userTextValues = try XCTUnwrap(docs.map{ $0.getText("text").toDelta() })
        
    for doc in docs {
        XCTAssertNil(doc.store.pendingDs)
        XCTAssertNil(doc.store.pendingStructs)
    }
    
    // Test Map iterator
    let ymapkeys = docs[0].getOpaqueMap("map").keys().map{ $0 }
    XCTAssertEqual(ymapkeys.count, userMapValues[0].count)
    
    ymapkeys.forEach{ key in
        XCTAssertNotNil(userMapValues[0][key])
    }
    
    var mapRes: [String: Any] = [:]
    for (k, v) in docs[0].getOpaqueMap("map") {
        if v == nil {
            mapRes[k] = NSNull()
        } else {
            mapRes[k] = v is YOpaqueObject ? (v as! YOpaqueObject).toJSON() : v
        }
    }
    
    XCTAssertEqualJSON(userMapValues[0], mapRes)
        
    // Compare all users
    for i in 0..<docs.count-1 {
        XCTAssertEqual(userArrayValues[i].count, docs[i].getOpaqueArray("array").count)
        
        XCTAssertEqualJSON(userArrayValues[i], userArrayValues[i + 1], "comparing client '\(i)' and '\(i+1)'")
        XCTAssertEqualJSON(userMapValues[i], userMapValues[i + 1], "comparing client '\(i)' and '\(i+1)'")
        XCTAssertEqual(
            userTextValues[i].map{ a in
                a.insert is String ? a.insert as! String : " "
            }.joined().count,
            docs[i].getText("text").count
        )
        
        for (a, b) in zip(userTextValues[i], userTextValues[i+1]) {
            XCTAssertEqual(a, b)
        }
        
        try XCTAssertEqual(docs[i].encodeStateVector(), docs[i+1].encodeStateVector())
        try YAssertEqualDeleteSet(
            YDeleteSet.createFromStructStore(docs[i].store),
            YDeleteSet.createFromStructStore(docs[i+1].store)
        )
        try YAssertEqualStructStore(docs[i].store, docs[i+1].store)
    }
    
    docs.forEach{ $0.destroy() }
    
    return docs
}

func YAssertEqualStructStore(_ ss1: YStructStore, _ ss2: YStructStore) throws {
    XCTAssertEqual(ss1.clients.count, ss2.clients.count)
    
    for (client, structs1) in ss1.clients {
        let structs2 = try XCTUnwrap(ss2.clients[client]?.value)
        
        XCTAssertEqual(structs2.count, structs1.count)
        
        for i in 0..<structs1.count {
            let s1 = structs1[i]
            let s2 = structs2[i]
            if (
                type(of: s1) != type(of: s2)
                || s1.id != s2.id
                || s1.deleted != s2.deleted
                || s1.length != s2.length
            ) {
                XCTFail("Structs dont match")
            }
            if let s1 = s1 as? YItem {
                guard let s2 = s2 as? YItem else {
                    return XCTFail("Items dont match")
                }
                if (
                    !((s1.left == nil && s2.left == nil) || (s1.left != nil && s2.left != nil && (s1.left as! YItem).lastID == (s2.left as! YItem).lastID))
                    || !compareItemIDs((s1.right as? YItem), (s2.right as? YItem))
                    || s1.origin != s2.origin
                    || s1.rightOrigin != s2.rightOrigin
                    || s1.parentKey != s2.parentKey
                ) {
                    return XCTFail("Items dont match")
                }
                // make sure that items are connected correctly
                XCTAssert(s1.left == nil || (s1.left as? YItem)?.right === s1)
                XCTAssert(s1.right == nil || (s1.right as? YItem)?.left === s1)
                XCTAssert(s2.left == nil || (s2.left as? YItem)?.right === s2)
                XCTAssert(s2.right == nil || (s2.right as? YItem)?.left === s2)
            }
        }
    }
}

func YAssertEqualDeleteSet(_ ds1: YDeleteSet, _ ds2: YDeleteSet) throws {
    XCTAssertEqual(ds1.clients.count, ds2.clients.count)
    
    for (client, deleteItems1) in ds1.clients {
        let deleteItems2 = try XCTUnwrap(ds2.clients[client])
        
        XCTAssertEqual(deleteItems1.count, deleteItems2.count)
        
        for i in 0..<deleteItems1.count {
            let di1 = deleteItems1[i]
            let di2 = deleteItems2[i]
            if di1.clock != di2.clock || di1.len != di2.len {
                XCTFail("DeleteSets dont match")
            }
        }
    }
}

