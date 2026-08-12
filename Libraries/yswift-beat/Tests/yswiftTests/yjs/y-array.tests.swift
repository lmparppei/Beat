import XCTest
import Promise
@testable import yswift

final class YArrayTests: XCTestCase {
    func testBasicUpdate() throws {
        let doc1 = YDocument()
        let doc2 = YDocument()
        doc1.getOpaqueArray("array").insert("hi", at: 0)
        let update = try doc1.encodeStateAsUpdate()
        try doc2.applyUpdate(update)
        XCTAssertEqualJSON(doc2.getOpaqueArray("array").toArray(), ["hi"])
    }
    
    func testSlice() throws {
        let doc1 = YDocument()
        let arr = doc1.getOpaqueArray("array")
        arr.insert(contentsOf: [1, 2, 3], at: 0)
        XCTAssertEqualJSON(arr[0...].map{ $0 }, [1, 2, 3])
        XCTAssertEqualJSON(arr[1...].map{ $0 }, [2, 3])
        XCTAssertEqualJSON(arr[0..<arr.count-1].map{ $0 }, [1, 2])
        arr.insert(0, at: 0)
        XCTAssertEqualJSON(arr[0...].map{ $0 }, [0, 1, 2, 3])
        XCTAssertEqualJSON(arr[0..<2].map{ $0 }, [0, 1])
    }

    func testArrayFrom() throws {
        let doc1 = YDocument()
        let db1 = doc1.getOpaqueMap("root")
        let nestedArray1 = Array([0, 1, 2])
        db1.set("array", value: nestedArray1)
        // ?
        XCTAssertEqual(nestedArray1, [0, 1, 2])
    }
    
    /**
     * Debugging yjs#297 - a critical bug connected to the search-marker approach
     *
     * @param {t.TestCase} tc
     */
    func testLengthIssue() throws {
        let doc1 = YDocument()
        let arr = doc1.getOpaqueArray("array")
        arr.append(contentsOf: [0, 1, 2, 3])
        arr.delete(at: 0)
        arr.insert(0, at: 0)
        XCTAssert(arr.count == arr.toArray().count)
        doc1.transact{ _ in
            arr.delete(at: 1)
            XCTAssert(arr.count == arr.toArray().count)
            arr.insert(1, at: 1)
            XCTAssert(arr.count == arr.toArray().count)
            arr.delete(at: 2)
            XCTAssert(arr.count == arr.toArray().count)
            arr.insert(2, at: 2)
            XCTAssert(arr.count == arr.toArray().count)
        }
        XCTAssert(arr.count == arr.toArray().count)
        arr.delete(at: 1)
        XCTAssert(arr.count == arr.toArray().count)
        arr.insert(1, at: 1)
        XCTAssert(arr.count == arr.toArray().count)
    }

    // in swift remove empty array must be fatalError

    func testLengthIssue2() throws {
        let doc = YDocument()
        let next = doc.getOpaqueArray()
        doc.transact({ _ in
            next.insert("group2", at: 0)
        })
        doc.transact({ _ in
            next.insert("rectangle3", at: 1)
        })
        doc.transact({ _ in
            next.delete(at: 0)
            next.insert("rectangle3", at: 0)
        })
        next.delete(at: 1)
        doc.transact({ _ in
            next.insert("ellipse4", at: 1)
        })
        doc.transact({ _ in
            next.insert("ellipse3", at: 2)
        })
        doc.transact({ _ in
            next.insert("ellipse2", at: 3)
        })
        
        
//        doc.transact({ _ in
//            doc.transact({ _ in
//                XCTAssertThrowsError(next.insert("rectangle2", at: 5))
//                next.insert("rectangle2", at: 4)
//            })
//            doc.transact({ _ in
//                // self should not throw an error message
//                next.remove(4)
//            })
//        })
        print(next.toArray())
    }

    // in swift remove empty array must be fatalError

    func testDeleteInsert() throws {
//        let test = try YTest<Any>(docs: 2)
//        let docs = test.docs, array0 = test.array[0]
//
//        array0.remove(0, count: 0)
        
        
//        print("Does not throw when deleting zero elements with position 0")
//        XCTAssertThrowsError(array0.remove(1, count: 1))
//        array0.insert("A", at: 0)
//        array0.remove(1, count: 0)
//
//        print("Does not throw when deleting zero elements with valid position 1")
//        YAssertEqualDocs(docs)
    }
    
    func testInsertThreeElementsTryRegetProperty() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        array0.insert(contentsOf: [1, true, false] as [Any?], at: 0)
        XCTAssertEqualJSON(array0.toJSON(), [1, true, false] as [Any?], ".toJSON() works")
        
        try connector.flushAllMessages()
        XCTAssertEqualJSON(array1.toJSON(), [1, true, false] as [Any?], ".toJSON() works after sync")
        
        try YAssertEqualDocs(docs)
    }

    func testConcurrentInsertWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 3)
        let docs = test.docs, array0 = test.array[0], array1 = test.array[1], array2 = test.array[2]
        
        array0.insert(0, at: 0)
        array1.insert(1, at: 0)
        array2.insert(2, at: 0)
        
        try YAssertEqualDocs(docs)
    }

    func testConcurrentInsertDeleteWithThreeConflicts() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1], array2 = test.array[2]
        
        array0.insert(contentsOf: ["x", "y", "z"], at: 0)
        try connector.flushAllMessages()
        array0.insert(0, at: 1)
        array1.delete(at: 0)
        array1.delete(in: 1..<2)
        array2.insert(2, at: 1)
        try YAssertEqualDocs(docs)
    }

    func testInsertionsInLateSync() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1], array2 = test.array[2]
        
        array0.insert(contentsOf: ["x", "y"], at: 0)
        try connector.flushAllMessages()
        
        docs[1].disconnect()
        docs[2].disconnect()
        
        array0.insert("user0", at: 1)
        array1.insert("user1", at: 1)
        array2.insert("user2", at: 1)
        
        try docs[1].connect()
        try docs[2].connect()
        try connector.flushAllMessages()
        
        try YAssertEqualDocs(docs)
    }

    func testDisconnectReallyPreventsSendingMessages() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        array0.insert(contentsOf: ["x", "y"], at: 0)
        try connector.flushAllMessages()
        
        docs[1].disconnect()
        docs[2].disconnect()
        
        array0.insert("user0", at: 1)
        array1.insert("user1", at: 1)
        
        XCTAssertEqualJSON(array0.toJSON(), ["x", "user0", "y"])
        XCTAssertEqualJSON(array1.toJSON(), ["x", "user1", "y"])
        
        try docs[1].connect()
        try docs[2].connect()
        
        try YAssertEqualDocs(docs)
    }

    
    func testDeletionsInLateSync() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, users = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        array0.insert(contentsOf: ["x", "y"], at: 0)
        try connector.flushAllMessages()
        
        users[1].disconnect()
        
        array1.delete(at: 1)
        array0.delete(in: 0..<2)
        
        try users[1].connect()
        
        try YAssertEqualDocs(users)
    }

    func testInsertThenMergeDeleteOnSync() throws {
        let test = try YTest<Any>(docs: 2)
        let connector = test.connector, docs = test.docs, array0 = test.array[0], array1 = test.array[1]
        
        array0.insert(contentsOf: ["x", "y", "z"], at: 0)
        try connector.flushAllMessages()
        
        docs[0].disconnect()
        
        array1.delete(in: 0..<3)
        
        try docs[0].connect()
        
        try YAssertEqualDocs(docs)
    }

    func testInsertAndDeleteEvents() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var event: YEvent?
        
        array0.observe{ e, _ in event = e }
        array0.insert(contentsOf: [0, 1, 2], at: 0)
        XCTAssert(event != nil)
        
        event = nil
        array0.delete(at: 0)
        XCTAssert(event != nil)
        
        event = nil
        array0.delete(in: 0..<2)
        XCTAssert(event != nil)
        
        event = nil
        try YAssertEqualDocs(docs)
    }

    func testNestedObserverEvents() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var vals: [Int] = []
        
        array0.observe{ e, _ in
            if array0.count == 1 {
                array0.insert(1, at: 1)
                vals.append(0)
            } else {
                vals.append(1)
            }
        }
        array0.insert(0, at: 0)
        XCTAssertEqual(vals, [0, 1])
        XCTAssertEqualJSON(array0.toArray(), [0, 1])
        
        try YAssertEqualDocs(docs)
    }

    func testInsertAndDeleteEventsForTypes() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var event: YEvent?
        
        array0.observe{ e, _ in event = e }
        
        array0.insert(YOpaqueArray(), at: 0)
        XCTAssert(event != nil)
        
        event = nil
        array0.delete(at: 0)
        XCTAssert(event != nil)
        
        event = nil
        try YAssertEqualDocs(docs)
    }

    /**
     * This issue has been reported in https://discuss.yjs.dev/t/order-in-which-events-yielded-by-observedeep-should-be-applied/261/2
     *
     * Deep observers generate multiple events. When an array added at item at, say, position 0,
     * and item 1 changed then the array-add event should fire first so that the change event
     * path is correct. A array binding might lead to an inconsistent state otherwise.
     *
     * @param {t.TestCase} tc
     */
    func testObserveDeepEventOrder() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs

        var events: [YEvent] = []
        array0.observeDeep{ e, _ in events = e }
        
        array0.insert(YOpaqueMap(), at: 0)
        
        try docs[0].transact{ _ in
            try XCTUnwrap(array0[0] as? YOpaqueMap).set("a", value: "a")
            array0.insert(0, at: 0)
        }
        
        for i in 1..<events.count {
            XCTAssert(
                events[i-1].path.count <= events[i].path.count,
                "path size increases, fire top-level events first"
            )
        }
    }

    func testChangeEvent() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs

        var changes: YEvent.Change? = nil
        array0.observe{ e, _ in changes = e.changes() }
        
        let newArr = YOpaqueArray()
        array0.insert(contentsOf: [newArr, 4, "dtrn"], at: 0)
        
        var wchanges = try XCTUnwrap(changes)
        XCTAssertEqual(wchanges.added.count, 2)
        XCTAssertEqual(wchanges.deleted.count, 0)
        XCTAssertEqual(wchanges.delta, [YEvent.Delta(insert: [newArr, 4, "dtrn"] as [Any?])])


        changes = nil
        array0.delete(in: 0..<2)

        wchanges = try XCTUnwrap(changes)
        XCTAssertEqual(wchanges.added.count, 0)
        XCTAssertEqual(wchanges.deleted.count, 2)
        XCTAssertEqual(wchanges.delta, [YEvent.Delta(delete: 2)])

        changes = nil
        array0.insert(0.1, at: 1)

        wchanges = try XCTUnwrap(changes)
        XCTAssertEqual(wchanges.added.count, 1)
        XCTAssertEqual(wchanges.deleted.count, 0)
        XCTAssertEqual(wchanges.delta, [YEvent.Delta(retain: 1), YEvent.Delta(insert: [0.1])])

        try YAssertEqualDocs(docs)
    }
    

    func testInsertAndDeleteEventsForTypes2() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs

        var events: [YEvent] = []
        array0.observe{ e, _ in events.append(e) }
        
        array0.insert(contentsOf: ["hi", YOpaqueMap()] as [Any?], at: 0)
        XCTAssert(events.count == 1, "Event is triggered exactly once for insertion of two elements")
        
        array0.delete(at: 1)
        XCTAssert(events.count == 2, "Event is triggered exactly once for deletion")
        
        try YAssertEqualDocs(docs)
    }

    /**
     * This issue has been reported here https://github.com/yjs/yjs/issues/155
     * @param {t.TestCase} tc
     */
    func testNewChildDoesNotEmitEventInTransaction() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.array[0], docs = test.docs
        var fired = false
        docs[0].transact{ _ in
            let newMap = YOpaqueMap()
            newMap.observe{ _, _ in fired = true }
            array0.insert(newMap, at: 0)
            newMap.set("tst", value: 42)
        }
        
        XCTAssertFalse(fired, "Event does not trigger")
    }

    func testGarbageCollector() throws {
        let test = try YTest<Any>(docs: 3)
        
        let connector = test.connector, docs = test.docs, array0 = test.array[0]
        
        array0.insert(contentsOf: ["x", "y", "z"], at: 0)
        try connector.flushAllMessages()
        docs[0].disconnect()
        
        array0.delete(in: 0..<3)
        try docs[0].connect()
        try connector.flushAllMessages()
        
        try YAssertEqualDocs(docs)
    }

    func testEventTargetIsSetCorrectlyOnLocal() throws {
        let test = try YTest<Any>(docs: 3)
        let array0 = test.array[0], docs = test.docs

        var event: YEvent?
        array0.observe{ e, _ in event = e }
        
        array0.insert("stuff", at: 0)
        XCTAssert(
            try XCTUnwrap(event).target === array0,
            "\"target\" property is set correctly"
        )
        
        try YAssertEqualDocs(docs)
    }

    func testEventTargetIsSetCorrectlyOnRemote() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, array0 = test.array[0], array1 = test.array[1], docs = test.docs

        var event: YEvent?
        array0.observe{ e, _ in event = e }
        
        array1.insert("stuff", at: 0)
        try connector.flushAllMessages()
        
        XCTAssert(
            try XCTUnwrap(event).target === array0,
            "\"target\" property is set correctly"
        )
        
        try YAssertEqualDocs(docs)
    }

    func testIteratingArrayContainingTypes() throws {
        let y = YDocument()
        let arr = y.getOpaqueArray("arr") // YArray<YMap<Int>>
        let numItems = 10
        for i in 0..<numItems {
            let map = YOpaqueMap()
            map.set("value", value: i)
            arr.append(contentsOf: [map])
        }
        var cnt = 0
        for item in arr.toArray() {
            let map = try XCTUnwrap(item as? YOpaqueMap)
            let value = try XCTUnwrap(map["value"] as? Int)
            XCTAssertEqual(value, cnt, "value is correct")
            cnt += 1
        }
        y.destroy()
    }
    
    private func getUniqueNumber() -> Int {
        enum __ { static var _uniqueNumber = 0 }
        defer { __._uniqueNumber += 1 }
        return __._uniqueNumber
    }

    private lazy var arrayTransactions: [(YDocument, YTest<Any>, Any?) throws -> Void] = [
        { doc, test, _ in // insert
            let yarray = doc.getOpaqueArray("array")
            let uniqueNumber = self.getUniqueNumber()
            var content: [Int] = []
            let len = test.gen.int(in: 1...4)
            for _ in 0..<len {
                content.append(uniqueNumber)
            }
            let pos = test.gen.int(in: 0...yarray.count)
            var oldContent = yarray.toArray()
            test.log("insert \(content) at '\(pos)'")
            
            yarray.insert(contentsOf: content, at: pos)
            oldContent.insert(contentsOf: content, at: pos)
            XCTAssertEqualJSON(yarray.toArray(), oldContent)
        },
        { doc, test, _ in // insertTypeArray
            let yarray = doc.getOpaqueArray("array")
            let pos = test.gen.int(in: 0...yarray.count)
            yarray.insert(YOpaqueArray(), at: pos)
            
            test.log("insert YArray at '\(pos)'")
            
            let array2 = try XCTUnwrap(yarray[pos] as? YOpaqueArray)
            array2.insert(contentsOf: [1, 2, 3, 4], at: 0)
        },
        { doc, test, _ in // insertTypeMap
            let yarray = doc.getOpaqueArray("array")
            let pos = test.gen.int(in: 0...yarray.count)
            
            test.log("insert YMap at '\(pos)'")
            
            yarray.insert(YOpaqueMap(), at: pos)
            let map = try XCTUnwrap(yarray[pos] as? YOpaqueMap)
            map.set("someprop", value: 42)
            map.set("someprop", value: 43)
            map.set("someprop", value: 44)
        },
        { doc, test, _ in // insertTypeNull
            let yarray = doc.getOpaqueArray("array")
            let pos = test.gen.int(in: 0...yarray.count)
            test.log("insert 'nil' at '\(pos)'")
            yarray.insert(nil, at: pos)
        },
        { doc, test, _ in // delete
            let yarray = doc.getOpaqueArray("array")
            let length = yarray.count
            guard length > 0 else {
                test.log("no delete")
                return
            }
                        
            var somePos = test.gen.int(in: 0...length-1)
            var delLength = test.gen.int(in: 1...min(2, length-somePos))
            
            if test.gen.bool() {
                let type = yarray[somePos]
                if let type = type as? YOpaqueArray, type.count > 0 {
                    somePos = test.gen.int(in: 0...type.count-1)
                    delLength = test.gen.int(in: 0...min(2, type.count - somePos))
                    
                    test.log("delete nested YArray at '\(somePos)..<\(somePos+delLength)'")
                    type.delete(in: somePos..<somePos+delLength)
                }
            } else {
                var oldContent = yarray.toArray()
                test.log("delete at '\(somePos)..<\(somePos+delLength)'")
                yarray.delete(in: somePos..<somePos+delLength)
                oldContent.removeSubrange(somePos..<somePos+delLength)
                XCTAssertEqualJSON(yarray.toArray(), oldContent)
            }
        }
    ]
    
    func testRepeatGeneratingYarrayTests_FailSeedTest() throws {
        try YTest<Any>(docs: 5, seed: 243939758)
            .randomTests(self.arrayTransactions, iterations: 100)
    }

    func testRepeatGeneratingYarrayTests6() throws {
        try YTest<Any>(docs: 5).randomTests(self.arrayTransactions, iterations: 6)
    }

    func testRepeatGeneratingYarrayTests40() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 40)
    }

    func testRepeatGeneratingYarrayTests42() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 42)
    }

    func testRepeatGeneratingYarrayTests43() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 43)
    }

    func testRepeatGeneratingYarrayTests44() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 44)
    }

    func testRepeatGeneratingYarrayTests45() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 45)
    }

    func testRepeatGeneratingYarrayTests46() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 46)
    }

    func testRepeatGeneratingYarrayTests300() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 300)
    }

    func testRepeatGeneratingYarrayTests400() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 400)
    }

    func testRepeatGeneratingYarrayTests500() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 500)
    }

    func testRepeatGeneratingYarrayTests600() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 600)
    }

    func testRepeatGeneratingYarrayTests1000() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 1000)
    }

    func testRepeatGeneratingYarrayTests1800() throws {
        try YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 1800)
    }

//    func testRepeatGeneratingYarrayTests3000() throws {
//        XCTSkipIf(!isProductionTest)
//        YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 3000)
//    }
//
//    func testRepeatGeneratingYarrayTests5000() throws {
//        XCTSkipIf(!isProductionTest)
//        YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 5000)
//    }
//
//    func testRepeatGeneratingYarrayTests30000() throws {
//        XCTSkipIf(!isProductionTest)
//        YTest<Any>(docs: 6).randomTests(self.arrayTransactions, iterations: 30000)
//    }
}
