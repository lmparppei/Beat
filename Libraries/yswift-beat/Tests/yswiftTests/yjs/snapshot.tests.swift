import XCTest
import Promise
@testable import yswift

final class SnapshotTests: XCTestCase {
    
    func testBasicRestoreSnapshot() throws {
        let doc = YDocument(YDocument.Options(gc: false))
        doc.getArray(String.self, "array").insert("hello", at: 0)
        
        let snap = doc.snapshot()
        
        doc.getArray(String.self, "array").insert("world", at: 1)
        
        let docRestored = try doc.restored(from: snap)
        
        XCTAssertEqual(
            docRestored.getArray(String.self, "array").toArray(), ["hello"]
        )
        XCTAssertEqual(
            doc.getArray(String.self, "array").toArray(), ["hello", "world"]
        )
    }
    
    func testEmptyRestoreSnapshot() throws {
        let doc = YDocument(.init(gc: false))
        let snap = doc.snapshot()
        snap.stateVectors[9999] = 0
        doc.getArray(String.self).insert("world", at: 0)

        let docRestored = try doc.restored(from: snap)

        XCTAssertEqual(docRestored.getArray(String.self).toArray(), [])
        XCTAssertEqual(doc.getArray(String.self).toArray(), ["world"])

        // now self snapshot reflects the latest state. It shoult still work.
        let snap2 = doc.snapshot()
        let docRestored2 = try doc.restored(from: snap2)
        XCTAssertEqual(docRestored2.getArray(String.self).toArray(), ["world"])
    }
    
    func testRestoreSnapshotWithSubType() throws {
        let doc = YDocument(.init(gc: false))
        doc.getArray(YMap<String>.self, "array").insert(YMap<String>(), at: 0)
        let subMap = doc.getArray(YMap<String>.self, "array")[0]
        subMap["key1"] = "value1"

        let snap = doc.snapshot()
        subMap["key2"] = "value2"

        let docRestored = try doc.restored(from: snap)

        XCTAssertEqualJSON(
            docRestored.getArray(YMap<String>.self, "array").toJSON(), [[ "key1": "value1" ]]
        )
        XCTAssertEqualJSON(
            doc.getArray(YMap<String>.self, "array").toJSON(),
            [[ "key1": "value1", "key2": "value2" ]]
        )
    }

    func testRestoreDeletedItem1() throws {
        let doc = YDocument(.init(gc: false))
        doc.getArray(String.self, "array")
            .insert(contentsOf: ["item1", "item2"], at: 0)

        let snap = doc.snapshot()
        doc.getArray(String.self, "array")
            .delete(at: 0)

        let docRestored = try doc.restored(from: snap)

        XCTAssertEqual(
            docRestored.getArray(String.self, "array").toArray(),
            ["item1", "item2"]
        )
        XCTAssertEqual(
            doc.getArray(String.self, "array").toArray(),
            ["item2"]
        )
    }

    func testRestoreLeftItem() throws {
        let doc = YDocument(.init(gc: false))
        doc.getArray(String.self, "array").insert("item1", at: 0)
        doc.getMap(Int.self, "map")["test"] = 1
        doc.getArray(String.self, "array").insert("item0", at: 0)

        let snap = doc.snapshot()
        doc.getArray(String.self, "array").delete(at: 1)

        let docRestored = try doc.restored(from: snap)

        XCTAssertEqual(docRestored.getArray(String.self, "array").toArray(), ["item0", "item1"])
        XCTAssertEqual(doc.getArray(String.self, "array").toArray(), ["item0"])
    }

    
    func testDeletedItemsBase() throws {
        let doc = YDocument(.init(gc: false))
        doc.getArray(String.self, "array").insert("item1", at: 0)
        doc.getArray(String.self, "array").delete(at: 0)
        let snap = doc.snapshot()
        doc.getArray(String.self, "array").insert("item0", at: 0)

        let docRestored = try snap.toDoc(doc)

        XCTAssertEqual(docRestored.getArray(String.self, "array").toArray(), [])
        XCTAssertEqual(doc.getArray(String.self, "array").toArray(), ["item0"])
    }

    func testDeletedItems2() throws {
        let doc = YDocument(.init(gc: false))
        doc.getArray(String.self, "array").insert(contentsOf: ["item1", "item2", "item3"], at: 0)
        doc.getArray(String.self, "array").delete(at: 1)
        let snap = doc.snapshot()
        doc.getArray(String.self, "array").insert("item0", at: 0)

        let docRestored = try snap.toDoc(doc)

        XCTAssertEqual(docRestored.getArray(String.self, "array").toArray(), ["item1", "item3"])
        XCTAssertEqual(doc.getArray(String.self, "array").toArray(), ["item0", "item1", "item3"])
    }

    func testDependentChanges() throws {
        let test = try YTest<Any>(docs: 2, gc: false)
        let array0 = test.array[0], array1 = test.array[1], connector = test.connector

        let doc0 = try XCTUnwrap(array0.document)
        let doc1 = try XCTUnwrap(array1.document)

        array0.insert("user1item1", at: 0)
        try connector.syncAll()
        array1.insert("user2item1", at: 1)
        try connector.syncAll()

        let snap = doc0.snapshot()

        array0.insert("user1item2", at: 2)
        try connector.syncAll()
        array1.insert("user2item2", at: 3)
        try connector.syncAll()

        let docRestored0 = try snap.toDoc(doc0)
        XCTAssertEqual(docRestored0.getArray(String.self, "array").toArray(), ["user1item1", "user2item1"])

        let docRestored1 = try snap.toDoc(doc1)
        XCTAssertEqual(docRestored1.getArray(String.self, "array").toArray(), ["user1item1", "user2item1"])
    }
    
}
