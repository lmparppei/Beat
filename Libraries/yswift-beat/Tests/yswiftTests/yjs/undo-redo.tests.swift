import XCTest
import Promise
@testable import yswift

final class UndoRedoTests: XCTestCase {
    
    func testInfiniteCaptureTimeout() throws {
        let test = try YTest<Any>(docs: 3)
        let array0 = test.swiftyArray(Int.self, 0)
        
        let undoManager = YUndoManager(array0, options: .make(captureTimeout: .infinity))
        
        array0.append(contentsOf: [1, 2, 3])
        undoManager.stopCapturing()
        array0.append(contentsOf: [4, 5, 6])
        undoManager.undo()
        XCTAssertEqual(array0.toArray(), [1, 2, 3])
        
        try YAssertEqualDocs(test.docs)
    }
    
    func testUndoText() throws {
        let test = try YTest<Any>(docs: 3)
        let text0 = test.text[0], text1 = test.text[1], connector = test.connector
        
        let undoManager = YUndoManager(text0)
        
        // items that are added & deleted in the same transaction won"t be undo
        text0.insert(0, text: "test")
        text0.delete(0, length: 4)
        undoManager.undo()
        XCTAssert(text0.toString() == "")
        
        // follow redone items
        text0.insert(0, text: "a")
        undoManager.stopCapturing()
        text0.delete(0, length: 1)
        undoManager.stopCapturing()
        undoManager.undo()
        XCTAssert(text0.toString() == "a")
        undoManager.undo()
        XCTAssert(text0.toString() == "")
        
        text0.insert(0, text: "abc")
        text1.insert(0, text: "xyz")
        
        try connector.syncAll()
        
        undoManager.undo()
        
        XCTAssert(text0.toString() == "xyz")
        undoManager.redo()
        XCTAssert(text0.toString() == "abcxyz")
        
        try connector.syncAll()
        
        text1.delete(0, length: 1)
        
        try connector.syncAll()
        
        undoManager.undo()
        XCTAssert(text0.toString() == "xyz")
        undoManager.redo()
        XCTAssert(text0.toString() == "bcxyz")
        // test marks
        
        text0.format(1, length: 3, attributes: ["bold": true])
        XCTAssertEqual(text0.toDelta(), [
            YEvent.Delta(insert: "b"),
            YEvent.Delta(insert: "cxy", attributes: ["bold": true]),
            YEvent.Delta(insert: "z")
        ])
        undoManager.undo()
        XCTAssertEqual(text0.toDelta(), [
            YEvent.Delta(insert: "bcxyz")
        ])
        undoManager.redo()
        XCTAssertEqual(text0.toDelta(), [
            YEvent.Delta(insert: "b"),
            YEvent.Delta(insert: "cxy", attributes: ["bold": true]),
            YEvent.Delta(insert: "z")
        ])
    }
    
    /**
     * Test case to fix #241
     * @param {t.TestCase} tc
     */
    func testEmptyTypeScope() throws {
        let ydoc = YDocument()
        let um = YUndoManager([], options: .make(document: ydoc))
        let yarray = ydoc.getArray(Int.self)
        um.addToScope(yarray)
        yarray.insert(1, at: 0)
        um.undo()
        XCTAssert(yarray.count == 0)
    }
    
    func testDoubleUndo() throws {
        let doc = YDocument()
        let text = doc.getText()
        text.insert(0, text: "1221")
        
        let manager = YUndoManager(text)
        
        text.insert(2, text: "3")
        text.insert(3, text: "3")
        
        manager.undo()
        manager.undo()
        
        text.insert(2, text: "3")
        
        XCTAssertEqual(text.toString(), "12321")
    }
    
    func testUndoMap() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, map0 = test.map[0], map1 = test.map[1]
        
        map0["a"] = 0
        let undoManager = YUndoManager(map0)
        
        map0["a"] = 1
        undoManager.undo()
        XCTAssertEqualJSON(map0["a"], 0)
        
        undoManager.redo()
        XCTAssertEqualJSON(map0["a"], 1)
        
        let subType = YOpaqueMap()
        map0["a"] = subType
        subType["x"] = 42
        XCTAssertEqualJSON(map0.toJSON(), ["a": ["x": 42]])
        
        undoManager.undo()
        XCTAssertEqualJSON(map0["a"], 1)
        
        undoManager.redo()
        XCTAssertEqualJSON(map0.toJSON(), ["a": ["x": 42]])
        
        try connector.syncAll()
        map1["a"] = 44
        
        try connector.syncAll()
        
        undoManager.undo()
        XCTAssertEqualJSON(map0["a"], 44)
        
        undoManager.redo()
        XCTAssertEqualJSON(map0["a"], 44)
        
        map0["b"] = "initial"
        undoManager.stopCapturing()
        map0["b"] = "val1"
        map0["b"] = "val2"
        undoManager.stopCapturing()
        undoManager.undo()
        XCTAssertEqualJSON(map0["b"], "initial")
    }
    
    
    func testUndoArray() throws {
        let test = try YTest<Any>(docs: 3)
        let connector = test.connector, array0 = test.array[0], array1 = test.array[1]
        
        let undoManager = YUndoManager(array0)
        array0.insert(contentsOf: [1, 2, 3], at: 0)
        array1.insert(contentsOf: [4, 5, 6], at: 0)
        try connector.syncAll()
        XCTAssertEqualJSON(array0.toArray(), [1, 2, 3, 4, 5, 6])
        
        undoManager.undo()
        XCTAssertEqualJSON(array0.toArray(), [4, 5, 6])
        
        undoManager.redo()
        XCTAssertEqualJSON(array0.toArray(), [1, 2, 3, 4, 5, 6])
        
        try connector.syncAll()
        array1.delete(at: 0)
        try connector.syncAll()
        undoManager.undo()
        XCTAssertEqualJSON(array0.toArray(), [4, 5, 6])
        
        undoManager.redo()
        XCTAssertEqualJSON(array0.toArray(), [2, 3, 4, 5, 6])
        
        array0.delete(in: 0..<5)
        // test nested structure
        let ymap = YOpaqueMap()
        array0.insert(ymap, at: 0)
        XCTAssertEqualJSON(array0.toJSON(), [[:] as NSDictionary])
        
        undoManager.stopCapturing()
        ymap["a"] = 1
        XCTAssertEqualJSON(array0.toJSON(), [[ "a": 1 ]])
        
        undoManager.undo()
        XCTAssertEqualJSON(array0.toJSON(), [[:] as NSDictionary])
        
        undoManager.undo()
        XCTAssertEqualJSON(array0.toJSON(), [2, 3, 4, 5, 6])
        
        undoManager.redo()
        XCTAssertEqualJSON(array0.toJSON(), [[:] as NSDictionary])
        
        undoManager.redo()
        XCTAssertEqualJSON(array0.toJSON(), [["a": 1]])
        
        try connector.syncAll()
        try XCTUnwrap(array1[0] as? YOpaqueMap)["b"] = 2
        try connector.syncAll()
        XCTAssertEqualJSON(array0.toJSON(), [["a": 1, "b": 2]])
        
        undoManager.undo()
        XCTAssertEqualJSON(array0.toJSON(), [["b": 2]])
        
        undoManager.undo()
        XCTAssertEqualJSON(array0.toJSON(), [2, 3, 4, 5, 6])
        
        undoManager.redo()
        XCTAssertEqualJSON(array0.toJSON(), [["b": 2]])
        
        undoManager.redo()
        XCTAssertEqualJSON(array0.toJSON(), [["a": 1, "b": 2]])
    }
    
    // No XML in swift
    
    func testUndoEvents() throws {
        let test = try YTest<Any>(docs: 3)
        let text0 = test.text[0]
        
        let undoManager = YUndoManager(text0)
        var counter = 0
        var receivedMetadata: Any? = nil
        
        undoManager.stackItemAdded.sink{ event in
            XCTAssert(event.changedParentTypes[text0] != nil)
            event.stackItem.meta["test"] = counter
            counter += 1
        }
        .store(in: &objectBag)
        
        undoManager.stackItemPopped.sink{ event in
            XCTAssert(event.changedParentTypes[text0] != nil)
            receivedMetadata = event.stackItem.meta["test"]
        }
        .store(in: &objectBag)
        
        text0.insert(0, text: "abc")
        undoManager.undo()
        XCTAssertEqualJSON(receivedMetadata, 0)
        
        undoManager.redo()
        XCTAssertEqualJSON(receivedMetadata, 1)
    }
    
    func testTrackClass() throws {
        let test = try YTest<Any>(docs: 3)
        let docs = test.docs, text0 = test.text[0]
        
        // only track origins that are Ints
        let undoManager = YUndoManager(
            text0,
            options: .make(trackedOrigins: [Int.self])
        )
        docs[0].transact(origin: 42) { _ in
            text0.insert(0, text: "abc")
        }
        XCTAssertEqual(text0.toString(), "abc")
        
        undoManager.undo()
        XCTAssertEqual(text0.toString(), "")
    }
    
    func testTypeScope() throws {
        let test = try YTest<Any>(docs: 3)
        
        let array0 = test.array[0]
        
        // only track origins that are Ints
        let text0 = YText()
        let text1 = YText()
        array0.insert(contentsOf: [text0, text1], at: 0)
        
        let undoManager = YUndoManager(text0)
        let undoManagerBoth = YUndoManager([text0, text1])
        text1.insert(0, text: "abc")
        XCTAssertEqual(undoManager.undoStack.count, 0)
        XCTAssertEqual(undoManagerBoth.undoStack.count, 1)
        XCTAssertEqual(text1.toString(), "abc")
        
        undoManager.undo()
        XCTAssertEqual(text1.toString(), "abc")
        
        undoManagerBoth.undo()
        XCTAssertEqual(text1.toString(), "")
    }
    
    func testUndoInEmbed() throws {
        let test = try YTest<Any>(docs: 3)
        let text0 = test.text[0]
        
        let undoManager = YUndoManager(text0)
        let nestedText = YText("initial text")
        undoManager.stopCapturing()
        text0.insertEmbed(0, embed: nestedText, attributes: ["bold": true])
        XCTAssert(nestedText.toString() == "initial text")
        
        undoManager.stopCapturing()
        nestedText.delete(0, length: nestedText.count)
        nestedText.insert(0, text: "other text")
        XCTAssert(nestedText.toString() == "other text")
        
        undoManager.undo()
        XCTAssert(nestedText.toString() == "initial text")
        
        undoManager.undo()
        XCTAssert(text0.count == 0)
    }
    
    // In swift we don't provide Item related API.
    
    func testUndoTransaction() throws {
        let test = try YTest<Any>(docs: 3)
        let array0 = test.swiftyArray(Int.self, 0), array1 = test.swiftyArray(Int.self, 1)
        let undoManager = YUndoManager(array0)
        
        test.docs[0].transact{_ in
            array0.append(1)
            array0.append(1)
            array0.append(1)
        }
        
        XCTAssertEqual(array0.toArray(), [1, 1, 1])
        
        try test.connector.syncAll()
        XCTAssertEqual(array1.toArray(), [1, 1, 1])
        
        undoManager.undo()
        XCTAssertEqual(array0.toArray(), [])
        
        try test.connector.syncAll()
        XCTAssertEqual(array1.toArray(), [])
    }

    func testUndoUntilChangePerformed() throws {
        let doc = YDocument()
        let doc2 = YDocument()
        doc.updatePublisher.sink{ try! doc2.applyUpdate($0) }.store(in: &objectBag)
        doc2.updatePublisher.sink{ try! doc.applyUpdate($0) }.store(in: &objectBag)

        
        
        let yArray = doc.getArray(YMap<String>.self, "array")
        let yArray2 = doc2.getArray(YMap<String>.self, "array")
        
        let yMap = YMap<String>()
        yMap["hello"] = "world"
        yArray.append(yMap)
        let yMap2 = YMap<String>()
        yMap2["key"] = "value"
        yArray.append(yMap2)

        let undoManager = YUndoManager(yArray, options: .make(trackedOrigins: [doc.clientID]))
        let undoManager2 = YUndoManager(doc2.getArray(YMap<String>.self, "array"), options: .make(trackedOrigins: [doc2.clientID]))

        doc.transact(origin: doc.clientID) { _ in
            yMap2["key"] = "value modified"
        }
        undoManager.stopCapturing()
        doc.transact(origin: doc.clientID) { _ in
            yMap["hello"] = "world modified"
        }
        doc2.transact(origin: doc2.clientID) { _ in
            yArray2.delete(at: 0)
        }
        undoManager2.undo()
        undoManager.undo()
        
        XCTAssertEqual(yMap2["key"], "value")
    }
        
    func testUndoNestedUndoIssue() throws {
        let doc = YDocument(.init(gc: false))
        let design = doc.getMap(YMap<YMap<String>>.self)
        let undoManager = YUndoManager(design, options: .make(captureTimeout: 0))

        let text = YMap<YMap<String>>()

        let blocks1 = YArray<YMap<String>>()
        let blocks1block = YMap<String>()
        doc.transact{
            blocks1block["text"] = "Type Something"
            blocks1.append(blocks1block)
            text["blocks"] = blocks1block
            design["text"] = text
        }

        let blocks2 = YArray<YMap<String>>()
        let blocks2block = YMap<String>()
        doc.transact{
            blocks2block["text"] = "Something"
            blocks2.append(blocks2block)
            text["blocks"] = blocks2block
        }

        let blocks3 = YArray<YMap<String>>()
        let blocks3block = YMap<String>()
        doc.transact{
            blocks3block["text"] = "Something Else"
            blocks3.append(blocks3block)
            text["blocks"] = blocks3block
        }

        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "Something Else"]]])
        
        undoManager.undo()
        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "Something"]]])
        
        undoManager.undo()
        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "Type Something"]]])
        
        undoManager.undo()
        XCTAssertEqualJSON(design.toJSON(), [:] as NSDictionary)
        undoManager.redo()
        
        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "Type Something"]]])
        
        undoManager.redo()
        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "Something"]]])
        
        undoManager.redo()
        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "Something Else"]]])
    }

    /**
     * This issue has been reported in https://github.com/yjs/yjs/issues/355
     *
     * @param {t.TestCase} tc
     */
    func testConsecutiveRedoBug() throws {
        let doc = YDocument()
        let yRoot = doc.getMap(YMap<Int>.self)
        let undoMgr = YUndoManager(yRoot)

        var yPoint = YMap<Int>()
        yPoint["x"] = 0
        yPoint["y"] = 0
        yRoot["a"] = yPoint
        undoMgr.stopCapturing()

        yPoint["x"] = 100
        yPoint["y"] = 100
        undoMgr.stopCapturing()

        yPoint["x"] = 200
        yPoint["y"] = 200
        undoMgr.stopCapturing()

        yPoint["x"] = 300
        yPoint["y"] = 300
        undoMgr.stopCapturing()

        XCTAssertEqual(yPoint.toDictionary(), ["x": 300, "y": 300])

        undoMgr.undo() // x=200, y=200
        XCTAssertEqual(yPoint.toDictionary(), ["x": 200, "y": 200])
        undoMgr.undo() // x=100, y=100
        XCTAssertEqual(yPoint.toDictionary(), ["x": 100, "y": 100])
        undoMgr.undo() // x=0, y=0
        XCTAssertEqual(yPoint.toDictionary(), ["x": 0, "y": 0])
        undoMgr.undo() // nil
        XCTAssertEqual(yRoot["a"], nil)

        undoMgr.redo() // x=0, y=0
        yPoint = yRoot["a"]!

        XCTAssertEqual(yPoint.toDictionary(), ["x": 0, "y": 0])
        undoMgr.redo() // x=100, y=100
        XCTAssertEqual(yPoint.toDictionary(), ["x": 100, "y": 100])
        undoMgr.redo() // x=200, y=200
        XCTAssertEqual(yPoint.toDictionary(), ["x": 200, "y": 200])
        undoMgr.redo() // expected x=300, y=300, actually nil
        XCTAssertEqual(yPoint.toDictionary(), ["x": 300, "y": 300])
    }

    // No XML in swift

    /**
     * This issue has been reported in https://github.com/yjs/yjs/issues/343
     *
     * @param {t.TestCase} tc
     */
    func testUndoBlockBug() throws {
        let doc = YDocument(.init(gc: false))
        let design = doc.getMap(YMap<YMap<String>>.self)

        let undoManager = YUndoManager(design, options: .make(captureTimeout: 0))

        let text = YMap<YMap<String>>()

        let blocks1 = YArray<YMap<String>>()
        let blocks1block = YMap<String>()
        doc.transact{
            blocks1block["text"] = "1"
            blocks1.append(blocks1block)

            text["blocks"] = blocks1block
            design["text"] = text
        }

        let blocks2 = YArray<YMap<String>>()
        let blocks2block = YMap<String>()
        doc.transact{
            blocks2block["text"] = "2"
            blocks2.append(blocks2block)
            text["blocks"] = blocks2block
        }

        let blocks3 = YArray<YMap<String>>()
        let blocks3block = YMap<String>()
        doc.transact({
            blocks3block["text"] = "3"
            blocks3.append(blocks3block)
            text["blocks"] = blocks3block
        })

        let blocks4 = YArray<YMap<String>>()
        let blocks4block = YMap<String>()
        doc.transact({
            blocks4block["text"] = "4"
            blocks4.append(blocks4block)
            text["blocks"] = blocks4block
        })

        // {"text":{"blocks":{"text":"4"}}}
        undoManager.undo() // {"text":{"blocks":{"3"}}}
        undoManager.undo() // {"text":{"blocks":{"text":"2"}}}
        undoManager.undo() // {"text":{"blocks":{"text":"1"}}}
        undoManager.undo() // {}
        undoManager.redo() // {"text":{"blocks":{"text":"1"}}}
        undoManager.redo() // {"text":{"blocks":{"text":"2"}}}
        undoManager.redo() // {"text":{"blocks":{"text":"3"}}}
        undoManager.redo() // {"text":{}}
        
        XCTAssertEqualJSON(design.toJSON(), ["text": ["blocks": ["text": "4"]]])
    }

    /**
     * Undo text formatting delete should not corrupt peer state.
     *
     * @see https://github.com/yjs/yjs/issues/392
     * @param {t.TestCase} tc
     */
    func testUndoDeleteTextFormat() throws {
        let doc = YDocument()
        let text = doc.getText()
        text.insert(0, text: "Attack ships on fire off the shoulder of Orion.")
        let doc2 = YDocument()
        let text2 = doc2.getText()
        try doc2.applyUpdate(doc.encodeStateAsUpdate())
        let undoManager = YUndoManager(text)

        text.format(13, length: 7, attributes: ["bold": true])
        undoManager.stopCapturing()
        try doc2.applyUpdate(doc.encodeStateAsUpdate())

        text.format(16, length: 4, attributes: ["bold": nil])
        undoManager.stopCapturing()
        try doc2.applyUpdate(doc.encodeStateAsUpdate())

        undoManager.undo()
        try doc2.applyUpdate(doc.encodeStateAsUpdate())

        let expect = [
            YEvent.Delta(insert: "Attack ships "),
            YEvent.Delta(insert: "on fire", attributes: ["bold": true ]),
            YEvent.Delta(insert: " off the shoulder of Orion.")
        ]
        XCTAssertEqual(text.toDelta(), expect)
        XCTAssertEqual(text2.toDelta(), expect)
    }

    /**
     * Undo text formatting delete should not corrupt peer state.
     *
     * @see https://github.com/yjs/yjs/issues/392
     * @param {t.TestCase} tc
     */
    func testBehaviorOfIgnoreremotemapchangesProperty() throws {
        let doc = YDocument()
        let doc2 = YDocument()
        doc.updatePublisher.sink{ try! doc2.applyUpdate($0, origin: doc) }.store(in: &objectBag)
        doc2.updatePublisher.sink{ try! doc.applyUpdate($0, origin: doc2) }.store(in: &objectBag)
        
        let map1 = doc.getMap(Int.self)
        let map2 = doc2.getMap(Int.self)
        
        let um1 = YUndoManager(map1, options: .make(ignoreRemoteMapChanges: true))
        
        map1["x"] = 1
        map2["x"] = 2
        map1["x"] = 3
        map2["x"] = 4
        um1.undo()
        XCTAssertEqual(map1["x"], 2)
        XCTAssertEqual(map2["x"], 2)
    }
}
