//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import XCTest
import Promise
@testable import yswift

private struct IntentionalError: Error {}

final class YMapTests: XCTestCase {
    
    func testSpecialForSwift_NilInInitialValues() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.map[0], map1 = test.map[1]
        
        map0.set("map", value: YOpaqueMap(["nil": nil]))
        
        try test.sync()
        
        XCTAssertEqualJSON(
            try XCTUnwrap(map0["map"] as? YOpaqueMap).toJSON(),
            ["nil": nil] as [String : Any?]
        )
        XCTAssertEqualJSON(
            try XCTUnwrap(map1["map"] as? YOpaqueMap).toJSON(),
            ["nil": nil] as [String : Any?]
        )
    }
    
    func testSpecialForSwift_AssignNilToMap() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        
        map0.set("nil", value: nil)
        
        try test.sync()

        XCTAssertEqual(map0.count, 1)
        XCTAssertNil(map0["nil"])
        
        XCTAssertEqual(map1.count, 1)
        XCTAssertNil(map1["nil"])
        
        try YAssertEqualDocs(docs)
    }
    
    func testMapHavingIterableAsConstructorParamTests() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.map[0]
        
        let m1 = YOpaqueMap([ "int": 1, "string": "hello" ])
        map0.set("m1", value: m1)
        XCTAssertEqual(try XCTUnwrap(m1["int"] as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(m1["string"] as? String), "hello")
        
        let m2 = YOpaqueMap([
            "object": ["x": 1],
            "boolean": true
        ])
        
        map0.set("m2", value: m2)
        XCTAssertEqual(try XCTUnwrap(m2["object"] as? [String: Int])["x"], 1)
        XCTAssertEqual(try XCTUnwrap(m2["boolean"] as? Bool), true)
        
        let dict = Dictionary(uniqueKeysWithValues: m1.map{ $0 } + m2)
        let m3 = YOpaqueMap(dict)
        map0.set("m3", value: m3)
        XCTAssertEqual(try XCTUnwrap(m3["int"] as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(m3["string"] as? String), "hello")
        XCTAssertEqual(try XCTUnwrap(m3["object"] as? [String: Int]), ["x": 1])
        XCTAssertEqual(try XCTUnwrap(m3["boolean"] as? Bool), true)
    }
    
    func testBasicMapTests() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2]
        docs[2].disconnect()
        
        map0.set("nil", value: nil)
        map0.set("number", value: 1)
        map0.set("string", value: "hello Y")
        map0.set("object", value: ["key": [ "key2": "value" ]])
        map0.set("y-map", value: YOpaqueMap())
        map0.set("boolean1", value: true)
        map0.set("boolean0", value: false)
        let map = try XCTUnwrap(map0["y-map"] as? YOpaqueMap)
        map.set("y-array", value: YOpaqueArray())
        let array = try XCTUnwrap(map["y-array"] as? YOpaqueArray)
        array.insert(0, at: 0)
        array.insert(-1, at: 0)
        
        XCTAssertEqualJSON(map0["nil"], nil, "client 0 computed the change (nil)")
        XCTAssertEqualJSON(map0["number"], 1, "client 0 computed the change (number)")
        XCTAssertEqualJSON(map0["string"], "hello Y", "client 0 computed the change (string)")
        XCTAssertEqualJSON(map0["boolean0"], false, "client 0 computed the change (boolean)")
        XCTAssertEqualJSON(map0["boolean1"], true, "client 0 computed the change (boolean)")
        XCTAssertEqualJSON(map0["object"], ["key": ["key2": "value"]], "client 0 computed the change (object)")
        XCTAssertEqualJSON(((map0["y-map"] as? YOpaqueMap)?["y-array"] as? YOpaqueArray)?[0], -1, "client 0 computed the change (type)")
        XCTAssertEqualJSON(map0.count, 7, "client 0 map has correct size")
        
        try docs[2].connect()
        try connector.flushAllMessages()

        XCTAssertEqualJSON(map1["nil"], nil, "client 1 received the update (nil)")
        XCTAssertEqualJSON(map1["number"], 1, "client 1 received the update (number)")
        XCTAssertEqualJSON(map1["string"], "hello Y", "client 1 received the update (string)")
        XCTAssertEqualJSON(map1["boolean0"], false, "client 1 computed the change (boolean)")
        XCTAssertEqualJSON(map1["boolean1"], true, "client 1 computed the change (boolean)")
        XCTAssertEqualJSON(map1["object"], ["key": ["key2": "value"]], "client 1 received the update (object)")
        XCTAssertEqualJSON(((map1["y-map"] as? YOpaqueMap)?["y-array"] as? YOpaqueArray)?[0], -1, "client 1 computed the change (type)")
        XCTAssertEqualJSON(map1.count, 7, "client 1 map has correct size")

        // compare disconnected user
        XCTAssertEqualJSON(map2["nil"], nil, "client 2 received the update (nil) - was disconnected")
        XCTAssertEqualJSON(map2["number"], 1, "client 2 received the update (number) - was disconnected")
        XCTAssertEqualJSON(map2["string"], "hello Y", "client 2 received the update (string) - was disconnected")
        XCTAssertEqualJSON(map2["boolean0"], false, "client 2 computed the change (boolean)")
        XCTAssertEqualJSON(map2["boolean1"], true, "client 2 computed the change (boolean)")
        XCTAssertEqualJSON(map2["object"], ["key": ["key2": "value"]], "client 2 received the update (object) - was disconnected")
        XCTAssertEqualJSON(((map2["y-map"] as? YOpaqueMap)?["y-array"] as? YOpaqueArray)?[0], -1, "client 2 received the update (type) - was disconnected")
        XCTAssertEqualJSON(map2.count, 7, "client 2 map has correct size")
        
        try YAssertEqualDocs(docs)
    }
    
    func testGetAndSetOfMapProperty() throws {
        let test = try YTest<Any>(docs: 2)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        
        map0.set("stuff", value: "stuffy")
//        map0.set("undefined", value: undefined) // No undefined in Swift
        map0.set("nil", value: nil)
        
        XCTAssertEqualJSON(map0["stuff"], "stuffy")

        try connector.flushAllMessages()

        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertEqualJSON(u["stuff"], "stuffy")
//            XCTAssertEqualJSON(u.get("undefined") == undefined, "undefined")
            XCTAssertEqualJSON(u["nil"], nil, "nil")
        }
        
        try YAssertEqualDocs(docs)
    }
    
    func testYmapSetsYmap() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, map0 = test.map[0]
        let map = YOpaqueMap()
        map0.set("map", value: map)
        
        XCTAssert(map0["map"] as? AnyObject === map)
        map.set("one", value: 1)
        XCTAssertEqualJSON(map["one"], 1)
        
        try YAssertEqualDocs(docs)
    }

    func testYmapSetsYarray() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, map0 = test.map[0]
        let array = YOpaqueArray()
        
        map0.set("array", value: array)
        XCTAssert(map0["array"] as? AnyObject === array)
        
        array.insert(contentsOf: [1, 2, 3], at: 0)
        
        XCTAssertEqualJSON(map0.toJSON(), ["array": [1, 2, 3]])
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertySyncs() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        
        map0.set("stuff", value: "stuffy")
        XCTAssertEqualJSON(map0["stuff"], "stuffy")
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertEqualJSON(u["stuff"], "stuffy")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertyWithConflict() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        map0.set("stuff", value: "c0")
        map1.set("stuff", value: "c1")
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertEqualJSON(u["stuff"], "c1")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSizeAndDeleteOfMapProperty() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.map[0]
        
        map0.set("stuff", value: "c0")
        map0.set("otherstuff", value: "c1")
        XCTAssertEqual(map0.count, 2, "map size is \(map0.count) expected 2")
        
        map0.deleteValue(forKey: "stuff")
        XCTAssertEqual(map0.count, 1, "map size after delete is \(map0.count), expected 1")
        
        map0.deleteValue(forKey: "otherstuff")
        XCTAssertEqual(map0.count, 0, "map size after delete is \(map0.count), expected 0")
    }

    func testGetAndSetAndDeleteOfMapProperty() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1]
        map0.set("stuff", value: "c0")
        map1.set("stuff", value: "c1")
        map1.deleteValue(forKey: "stuff")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertNil(u["stuff"])
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSetAndClearOfMapProperties() throws {
        let test = try YTest<Any>(docs: 1)
        
        let connector = test.connector, docs = test.docs, map0 = test.map[0]
        map0.set("stuff", value: "c0")
        map0.set("otherstuff", value: "c1")
        map0.removeAll()
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertNil(u["stuff"])
            XCTAssertNil(u["otherstuff"])
            XCTAssert(u.count == 0, "map size after clear is \(u.count), expected 0")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testSetAndClearOfMapPropertiesWithConflicts() throws {
        let test = try YTest<Any>(docs: 4)
        
        let connector = test.connector, docs = test.docs,
        map0 = test.map[0], map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        map0.set("stuff", value: "c0")
        map1.set("stuff", value: "c1")
        map1.set("stuff", value: "c2")
        map2.set("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        map0.set("otherstuff", value: "c0")
        map1.set("otherstuff", value: "c1")
        map2.set("otherstuff", value: "c2")
        map3.set("otherstuff", value: "c3")
        map3.removeAll()
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertNil(u["stuff"])
            XCTAssertNil(u["otherstuff"])
            XCTAssert(u.count == 0, "map size after clear is \(u.count), expected 0")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetOfMapPropertyWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2]
        
        map0.set("stuff", value: "c0")
        map1.set("stuff", value: "c1")
        map1.set("stuff", value: "c2")
        map2.set("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertEqualJSON(u["stuff"], "c3")
        }
        
        try YAssertEqualDocs(docs)
    }

    func testGetAndSetAndDeleteOfMapPropertyWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 4)
        let connector = test.connector, docs = test.docs, map0 = test.map[0], map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        map0.set("stuff", value: "c0")
        map1.set("stuff", value: "c1")
        map1.set("stuff", value: "c2")
        map2.set("stuff", value: "c3")
        
        try connector.flushAllMessages()
        
        map0.set("stuff", value: "deleteme")
        map1.set("stuff", value: "c1")
        map2.set("stuff", value: "c2")
        map3.set("stuff", value: "c3")
        map3.deleteValue(forKey: "stuff")
        
        try connector.flushAllMessages()
        
        for doc in docs {
            let u = doc.getOpaqueMap("map")
            XCTAssertNil(u["stuff"])
        }
        
        try YAssertEqualDocs(docs)
    }
    
    func testObserveDeepProperties() throws {
        let test = try YTest<Any>(docs: 4)
        let connector = test.connector, docs = test.docs, map1 = test.map[1], map2 = test.map[2], map3 = test.map[3]
        
        let _map1 = YOpaqueMap()
        map1.set("map", value: _map1)
        
        var calls = 0
        var dmapid: YIdentifier?
        map1.observeDeep({ events, _ in
            do {
                try events.forEach({ event in
                    let mevent = try XCTUnwrap(event as? YOpaqueMapEvent)
                    calls += 1
                    
                    XCTAssert(mevent.keysChanged.contains("deepmap"))
                    XCTAssertEqual(mevent.path.count, 1)
                    XCTAssertEqual(mevent.path[0], .key("map"))
                    let emap = try XCTUnwrap(event.target as? YOpaqueMap)
                    dmapid = try XCTUnwrap(emap["deepmap"] as? YOpaqueMap)._objectItem?.id
                })
            } catch {
                XCTFail("\(error)")
            }
        })
        
        try connector.flushAllMessages()
        
        let _map3 = try XCTUnwrap(map3["map"] as? YOpaqueMap)
        _map3.set("deepmap", value: YOpaqueMap())
        try connector.flushAllMessages()
        
        let _map2 = try XCTUnwrap(map2["map"] as? YOpaqueMap)
        _map2.set("deepmap", value: YOpaqueMap())
        try connector.flushAllMessages()
        
        let dmap1 = try XCTUnwrap(_map1["deepmap"] as? YOpaqueMap)
        let dmap2 = try XCTUnwrap(_map2["deepmap"] as? YOpaqueMap)
        let dmap3 = try XCTUnwrap(_map3["deepmap"] as? YOpaqueMap)
        
        XCTAssertGreaterThan(calls, 0)
        XCTAssertEqual(dmap1._objectItem?.id, dmap2._objectItem?.id)
        XCTAssertEqual(dmap1._objectItem?.id, dmap3._objectItem?.id)
        XCTAssertEqual(dmap1._objectItem?.id, dmapid)
        
        try YAssertEqualDocs(docs)
    }

    func testObserversUsingObservedeep() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var pathes: [[YEvent.PathElement]] = []
        var calls = 0
        
        map0.observeDeep{ events, _ in
            events.forEach{ event in
                pathes.append(event.path)
            }
            calls += 1
        }
        
        map0.set("map", value: YOpaqueMap())
        let _map = try XCTUnwrap(map0["map"] as? YOpaqueMap)
        _map.set("array", value: YOpaqueArray())
        try XCTUnwrap(_map["array"] as? YOpaqueArray).insert("content", at: 0)
        
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(pathes, [[], [.key("map")], [.key("map"), .key("array")]])
        
        try YAssertEqualDocs(docs)
    }

    // TODO: Test events in Map
    private func compareEvent(_ event: YEvent?, keysChanged: Set<String?>, target: AnyObject) {
        guard let event = event as? YOpaqueMapEvent else {
            return XCTFail()
        }
        XCTAssertEqual(event.keysChanged, keysChanged)
        XCTAssert(event.target === target)
        // TODO: compare more values
    }

    func testThrowsAddAndUpdateAndDeleteEvents() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var event: YEvent?
        map0.observe{ e, _ in event = e }
        
        map0.set("stuff", value: 4)
        compareEvent(event, keysChanged: Set(["stuff"]), target: map0)
        
        // update, oldValue is in contents
        map0.set("stuff", value: YOpaqueArray())
        compareEvent(event, keysChanged: Set(["stuff"]), target: map0)
        
        // update, oldValue is in opContents
        map0.set("stuff", value: 5)
        // delete
        map0.deleteValue(forKey: "stuff")
        compareEvent(event, keysChanged: Set(["stuff"]), target: map0)
        
        try YAssertEqualDocs(docs)
    }

    func testThrowsDeleteEventsOnClear() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var event: YEvent?
        map0.observe{ e, _ in event = e }
        
        // set values
        map0.set("stuff", value: 4)
        map0.set("otherstuff", value: YOpaqueArray())
        // clear
        map0.removeAll()
        
        compareEvent(event, keysChanged: Set(["stuff", "otherstuff"]), target: map0)
        
        try YAssertEqualDocs(docs)
    }

    func testChangeEvent() throws {
        let test = try YTest<Any>(docs: 2)
        let docs = test.docs, map0 = test.map[0]

        var changes: YEvent.Change? = nil
        var keyChange: YEvent.Key? = nil
        
        map0.observe{ e, _ in changes = e.changes() }
        
        map0.set("a", value: 1)
        keyChange = changes?.keys["a"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .add)
        XCTAssertNil(keyChange?.oldValue)
        
        map0.set("a", value: 2)
        keyChange = changes?.keys["a"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .update)
        XCTAssertEqualJSON(keyChange?.oldValue, 1)
        
        docs[0].transact{ _ in
            map0.set("a", value: 3)
            map0.set("a", value: 4)
        }
        
        keyChange = changes?.keys["a"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .update)
        XCTAssertEqualJSON(keyChange?.oldValue, 2)
        
        docs[0].transact{ _ in
            map0.set("b", value: 1)
            map0.set("b", value: 2)
        }
        
        keyChange = changes?.keys["b"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .add)
        XCTAssertNil(keyChange?.oldValue)
        
        docs[0].transact{ _ in
            map0.set("c", value: 1)
            map0.deleteValue(forKey: "c")
        }
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.keys.count, 0)
        
        docs[0].transact{ _ in
            map0.set("d", value: 1)
            map0.set("d", value: 2)
        }
        
        keyChange = changes?.keys["d"]
        XCTAssertNotNil(changes)
        XCTAssertEqual(keyChange?.action, .add)
        XCTAssertNil(keyChange?.oldValue)
        
        try YAssertEqualDocs(docs)
    }

    // In swift observer should not throw error
    
//    func testYmapEventExceptionsShouldCompleteTransaction() throws {
//        let doc = YDocument()
//        let map = try doc.getOpaqueMap("map")
//
//        var updateCalled = false
//        var throwingObserverCalled = false
//        var throwingDeepObserverCalled = false
//        doc.on(YDocument.On.update) { _ in updateCalled = true }
//
//        func throwingObserver() throws {
//            throwingObserverCalled = true
//            throw IntentionalError()
//        }
//
//        func throwingDeepObserver() throws {
//            throwingDeepObserverCalled = true
//            throw IntentionalError()
//        }
//
//        map.observe{ _, _ in try throwingObserver() }
//        map.observeDeep{ _, _ in try throwingDeepObserver() }
//
//        XCTAssertThrowsError(try map.setThrowingError("y", value: "2"))
//
//        XCTAssert(updateCalled)
//        XCTAssert(throwingObserverCalled)
//        XCTAssert(throwingDeepObserverCalled)
//
//        // check if it works again
//        updateCalled = false
//        throwingObserverCalled = false
//        throwingDeepObserverCalled = false
//        XCTAssertThrowsError(map.setThrowingError("z", value: "3"))
//
//        XCTAssert(updateCalled)
//        XCTAssert(throwingObserverCalled)
//        XCTAssert(throwingDeepObserverCalled)
//
//        XCTAssertEqualJSON(map["z"], "3")
//    }
    

    private let mapTransactions: [(YDocument, YTest<Any>, Any?) -> Void] = [
        { doc, test, _ in // set
            let key = test.gen.oneOf(["one", "two"])
            let value = test.gen.string()
            doc.getOpaqueMap("map").set(key, value: value)
        },
        { doc, test, _ in // setType
            let key = test.gen.oneOf(["one", "two"])
            let type = test.gen.oneOf([YOpaqueArray(), YOpaqueMap()])
            doc.getOpaqueMap("map").set(key, value: type)
            if let type = type as? YOpaqueArray {
                type.insert(contentsOf: [1, 2, 3, 4], at: 0)
            } else if let type = type as? YOpaqueMap {
                type.set("deepkey", value: "deepvalue")
            }
        },
        { doc, test, _ in // delete
            let key = test.gen.oneOf(["one", "two"])
            doc.getOpaqueMap("map").deleteValue(forKey: key)
        }
    ]

    func testRepeatGeneratingYmapTests10() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 6)
    }
    
    func testRepeatGeneratingYmapTests40() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 40)
    }

    func testRepeatGeneratingYmapTests42() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 42)
    }

    func testRepeatGeneratingYmapTests43() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 43)
    }

    func testRepeatGeneratingYmapTests44() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 44)
    }

    func testRepeatGeneratingYmapTests45() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 45)
    }

    func testRepeatGeneratingYmapTests46() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 46)
    }

    func testRepeatGeneratingYmapTests300() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 300)
    }

    func testRepeatGeneratingYmapTests400() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 400)
    }

    func testRepeatGeneratingYmapTests500() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 500)
    }

    func testRepeatGeneratingYmapTests600() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 600)
    }

    func testRepeatGeneratingYmapTests1000() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 1000)
    }

    func testRepeatGeneratingYmapTests1800() throws {
        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 1800)
    }

//    func testRepeatGeneratingYmapTests5000() throws {
//        try XCTSkipIf(!isProductionTest)
//        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 5000)
//    }
//
//    func testRepeatGeneratingYmapTests10000() throws {
//        try XCTSkipIf(!isProductionTest)
//        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 10000)
//    }
//
//    func testRepeatGeneratingYmapTests100000() throws {
//        try XCTSkipIf(!isProductionTest)
//        try YTest<Any>(docs: 5).randomTests(self.mapTransactions, iterations: 100000)
//    }
}


// MARK: I don't understand why these two tests exist. (event.value and event.name must be undefined)

//    func testYmapEventHasCorrectValueWhenSettingAPrimitive() throws {
//        let test = try YTest<Any>(docs: 3)
//        let docs = test.docs, map0 = test.map[0]
//
//        var event: YMapEvent? = nil
//        map0.observe{ e, _ in event = try XCTUnwrap(e as? YMapEvent) }
//        try map0.set("stuff", value: 2)
//
//        XCTAssertEqual(event.value, event.target.get(event.name))
//
//        compare(users)
//    }
//    func testYmapEventHasCorrectValueWhenSettingAPrimitiveFromOtherUser() throws {
//        let { users, map0, map1, testConnector } = init(tc, { users: 3 })
//
//        var event: { [s: string]: Any } = {}
//        map0.observe(e -> {
//            event = e
//        })
//        map1.set("stuff", 2)
//        testConnector.flushAllMessages()
//        XCTAssertEqual(event.value, event.target.get(event.name))
//        compare(users)
//    }
