import XCTest
import Promise
@testable import yswift

final class DocTests: XCTestCase {
    
    func testAfterTransactionRecursion() throws { // xml -> array
        let ydoc = YDocument()
        let ymap = ydoc.getOpaqueArray("")
        ydoc.on(YDocument.On.afterTransaction) { tr in
            if tr.origin as! String == "test" {
                _ = ymap.toJSON()
            }
        }
        ydoc.transact(origin: "test") { _ in
            for _ in 0..<1500  { // as Swift slow in DEBUG mode
                ymap.append(contentsOf: [YText("a")])
            }
        }
    }

    func testOriginInTransaction() throws {
        let doc = YDocument()
        let ytext = doc.getText("")
        var origins = [String]()
        
        doc.on(YDocument.On.afterTransaction) { tr in
            guard let origin = tr.origin as? String else { return XCTFail("No a string.") }
            
            origins.append(origin)
            
            if origins.count <= 1 {
                _ = ytext.toDelta(YSnapshot(doc: doc))
                doc.transact(origin: "nested") { _ in
                    ytext.insert(0, text: "a")
                }
            }
        }
        
        doc.transact(origin: "first") { _ in
            ytext.insert(0, text: "0")
        }
        
        XCTAssertEqual(origins, ["first", "cleanup", "nested"])
    }

    func testClientIdDuplicateChange() throws {
        let doc1 = YDocument()
        doc1.clientID = 0
        let doc2 = YDocument()
        doc2.clientID = 0
        XCTAssertEqual(doc2.clientID, doc1.clientID)
        doc1.getOpaqueArray("a").insert(contentsOf: [1, 2], at: 0)
        try doc2.applyUpdate(doc1.encodeStateAsUpdate())
        XCTAssertNotEqual(doc2.clientID, doc1.clientID)
    }

    func testGetTypeEmptyId() throws {
        let doc1 = YDocument(.init(cliendID: 100))
        doc1.getText("").insert(0, text: "h")
        doc1.getText("").insert(1, text: "i")
                
        let doc2 = YDocument(.init(cliendID: 101))
        
        let update = try doc1.encodeStateAsUpdate()
                
        try doc2.applyUpdate(update)
        
        XCTAssertEqual(doc2.getText("").toString(), "hi")
        XCTAssertEqual(doc2.getText("").toString(), "hi")
    }

    func testToJSON() throws {
        let doc = YDocument()
        XCTAssertTrue(doc.toJSON().isEmpty, "doc.toJSON yields empty object")

        let arr = doc.getOpaqueArray("array")
        arr.append(contentsOf: ["test1"])

        let map = doc.getOpaqueMap("map")
        map.set("k1", value: "v1")
        let map2 = YOpaqueMap()
        map.set("k2", value: map2)
        map2.set("m2k1", value: "m2v1")

        XCTAssertEqual(doc.toJSON() as NSDictionary, [
            "array": [ "test1" ],
            "map": [
                "k1": "v1",
                "k2": [ "m2k1": "m2v1" ]
            ] as NSDictionary
        ], "doc.toJSON has array and recursive map")
    }

        
    func testSubdoc() throws {
        let doc = YDocument()
        doc.load() // doesn"t do Anything
        
        do {
            var event: [Set<String>]? = nil
            
            doc.on(YDocument.On.subdocs) { subdocs, _ in
                event = [
                    Set(subdocs.added.map{ $0.guid }),
                    Set(subdocs.removed.map{ $0.guid }),
                    Set(subdocs.loaded.map{ $0.guid })
                ]
            }
            
            let subdocs = doc.getOpaqueMap("mysubdocs")
            let docA = YDocument(.init(guid: "a"))
            docA.load()
            subdocs.set("a", value: docA)
            
            XCTAssertEqual(event, [["a"], [], ["a"]])

            event = nil
            (subdocs["a"] as! YDocument).load()
            XCTAssertNil(event)

            event = nil
            (subdocs["a"] as! YDocument).destroy()
            XCTAssertEqual(event, [["a"], ["a"], []])
            (subdocs["a"] as! YDocument).load()
            XCTAssertEqual(event, [[], [], ["a"]])

            subdocs.set("b", value: YDocument(.init(guid: "a", shouldLoad: false)))
            XCTAssertEqual(event, [["a"], [], []])
            (subdocs["b"] as! YDocument).load()
            XCTAssertEqual(event, [[], [], ["a"]])

            let docC = YDocument(.init(guid: "c"))
            docC.load()
            subdocs.set("c", value: docC)
            XCTAssertEqual(event, [["c"], [], ["c"]])

            XCTAssertEqual(doc._subdocGuids, ["a", "c"])
        }

        let doc2 = YDocument()
        do {
            XCTAssertTrue(doc2.subdocs.isEmpty)
            var event: [Set<String>]? = nil
            
            doc2.on(YDocument.On.subdocs) { subdocs, _ in
                event = [
                    Set(subdocs.added.map{ $0.guid }),
                    Set(subdocs.removed.map{ $0.guid }),
                    Set(subdocs.loaded.map{ $0.guid })
                ]
            }
            
            try doc2.applyUpdate(doc.encodeStateAsUpdate())
            XCTAssertEqual(event, [["a", "a", "c"], [], []])

            (doc2.getOpaqueMap("mysubdocs")["a"] as! YDocument).load()
            XCTAssertEqual(event, [[], [], ["a"]])

            XCTAssertEqual(doc2._subdocGuids, ["a", "c"])

            doc2.getOpaqueMap("mysubdocs").deleteValue(forKey: "a")
            XCTAssertEqual(event, [[], ["a"], []])
            XCTAssertEqual(doc2._subdocGuids, ["a", "c"])
        }
    }

    func testSubdocLoadEdgeCases() throws {
        let ydoc = YDocument()
        let yarray = ydoc.getOpaqueArray("") // [Doc]
        let subdoc1 = YDocument()
        var lastEvent: YDocument.On.SubDocEvent? = nil
        
        ydoc.on(YDocument.On.subdocs) { event, _ in
            lastEvent = event
        }
        yarray.insert(subdoc1, at: 0)
        XCTAssert(subdoc1.shouldLoad)
        XCTAssert(subdoc1.autoLoad == false)
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc1))
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc1))
        
        // destroy and check whether lastEvent adds it again to added (it shouldn"t)
        subdoc1.destroy()
        let subdoc2 = try XCTUnwrap(yarray[0] as? YDocument)
        XCTAssert(subdoc1 != subdoc2)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(!XCTUnwrap(lastEvent).loaded.contains(subdoc2))
        // load
        subdoc2.load()
        try XCTAssert(!XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc2))
        // apply from remote
        let ydoc2 = YDocument()
        ydoc2.on(YDocument.On.subdocs) { event, _ in
            lastEvent = event
        }
        try ydoc2.applyUpdate(ydoc.encodeStateAsUpdate())
        let subdoc3 = try XCTUnwrap(ydoc2.getOpaqueArray("")[0] as? YDocument)
        XCTAssert(subdoc3.shouldLoad == false)
        XCTAssert(subdoc3.autoLoad == false)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc3))
        try XCTAssert(!XCTUnwrap(lastEvent).loaded.contains(subdoc3))
        // load
        subdoc3.load()
        XCTAssert(subdoc3.shouldLoad)
        try XCTAssert(!XCTUnwrap(lastEvent).added.contains(subdoc3))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc3))
    }

    func testSubdocLoadEdgeCasesAutoload() throws {
        let ydoc = YDocument()
        let yarray = ydoc.getOpaqueArray("") // [Doc]
        let subdoc1 = YDocument(.init(autoLoad: true))
        
        var lastEvent: YDocument.On.SubDocEvent? = nil
        ydoc.on(YDocument.On.subdocs) { event, _ in
            lastEvent = event
        }
        
        yarray.insert(subdoc1, at: 0)
        
        
        XCTAssertTrue(subdoc1.shouldLoad)
        XCTAssertTrue(subdoc1.autoLoad)
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc1))
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc1))
        
        // destroy and check whether lastEvent adds it again to added (it shouldn"t)
        subdoc1.destroy()
        let subdoc2 = try XCTUnwrap(yarray[0] as? YDocument)
        XCTAssertNotIdentical(subdoc1, subdoc2)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(!XCTUnwrap(lastEvent).loaded.contains(subdoc2))
                
        // load
        subdoc2.load()
        try XCTAssert(!XCTUnwrap(lastEvent).added.contains(subdoc2))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc2))
        
        // apply from remote
        let ydoc2 = YDocument()
        ydoc2.on(YDocument.On.subdocs) { event, _ in
            lastEvent = event
        }
        let update = try ydoc.encodeStateAsUpdate()
        try ydoc2.applyUpdate(update)
        let subdoc3 = try XCTUnwrap(ydoc2.getOpaqueArray("")[0] as? YDocument)
        XCTAssert(subdoc1.shouldLoad)
        XCTAssert(subdoc1.autoLoad)
        try XCTAssert(XCTUnwrap(lastEvent).added.contains(subdoc3))
        try XCTAssert(XCTUnwrap(lastEvent).loaded.contains(subdoc3))
    }

    func testSubdocsUndo() throws {
        let ydoc = YDocument()
        let elems = ydoc.getOpaqueArray()
        let undoManager = YUndoManager(elems)
        let subdoc = YDocument()
        elems.insert(subdoc, at: 0)
        undoManager.undo()
        undoManager.redo()
        XCTAssert(elems.count == 1)
    }

    func testLoadDocsEvent() async throws {
        let ydoc = YDocument()
        XCTAssert(ydoc.isLoaded == false)
        var loadedEvent = false
        ydoc.on(YDocument.On.load) {
            loadedEvent = true
        }
        ydoc.emit(YDocument.On.load, ())
        await ydoc.whenLoaded.value()
        
        XCTAssert(loadedEvent)
        XCTAssert(ydoc.isLoaded)
    }

    func testSyncDocsEvent() async throws {
        let ydoc = YDocument()
        XCTAssertFalse(ydoc.isLoaded)
        XCTAssertFalse(ydoc.isSynced)
        var loadedEvent = false
        ydoc.once(YDocument.On.load) {
            loadedEvent = true
        }
        var syncedEvent = false
        ydoc.once(YDocument.On.sync) { isSynced in
            syncedEvent = true
            XCTAssertTrue(isSynced)
        }
        ydoc.emit(YDocument.On.sync, true)
        
        await ydoc.whenLoaded.value()
        
        let oldWhenSynced = ydoc.whenSynced
        
        await ydoc.whenSynced.value()
        
        XCTAssert(loadedEvent)
        XCTAssert(syncedEvent)
        XCTAssert(ydoc.isLoaded)
        XCTAssert(ydoc.isSynced)
        var loadedEvent2 = false
        ydoc.on(YDocument.On.load) {
            loadedEvent2 = true
        }
        var syncedEvent2 = false
        ydoc.on(YDocument.On.sync) { isSynced in
            syncedEvent2 = true
            XCTAssertFalse(isSynced)
        }
        ydoc.emit(YDocument.On.sync, false)
        XCTAssert(!loadedEvent2)
        XCTAssert(syncedEvent2)
        XCTAssert(ydoc.isLoaded)
        XCTAssert(!ydoc.isSynced)
        XCTAssert(ydoc.whenSynced.state.isSettled != oldWhenSynced?.state.isSettled)
    }
}
