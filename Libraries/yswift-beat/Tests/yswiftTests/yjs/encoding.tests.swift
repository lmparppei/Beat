import XCTest
import Promise
@testable import yswift

final class EncodingTests: XCTestCase {
    
    func testStructReferences() {
        // Swift (intentionally) has no functions equality check.
    }

    func testPermanentUserData() async throws {
        let ydoc1 = YDocument()
        let ydoc2 = YDocument()
        let pd1 = try YPermanentUserData(doc: ydoc1, storeType: nil)
        let pd2 = try YPermanentUserData(doc: ydoc2, storeType: nil)
        try pd1.setUserMapping(doc: ydoc1, clientid: ydoc1.clientID, userDescription: "user a")
        try pd2.setUserMapping(doc: ydoc2, clientid: ydoc2.clientID, userDescription: "user b")
        ydoc1.getText().insert(0, text: "xhi")
        ydoc1.getText().delete(0, length: 1)
        ydoc2.getText().insert(0, text: "hxxi")
        ydoc2.getText().delete(1, length: 2)
        
        await Promise.wait(for: 1).value()
        
        try ydoc2.applyUpdate(ydoc1.encodeStateAsUpdate())
        try ydoc1.applyUpdate(ydoc2.encodeStateAsUpdate())

        // now sync a third doc with same name as doc1 and then create PermanentUserData
        let ydoc3 = YDocument()
        try ydoc3.applyUpdate(ydoc1.encodeStateAsUpdate())
        let pd3 = try YPermanentUserData(doc: ydoc3, storeType: nil)
        try pd3.setUserMapping(doc: ydoc3, clientid: ydoc3.clientID, userDescription: "user a")
    }
    
    
    func testDiffStateVectorOfUpdateIsEmpty() throws {
        let ydoc = YDocument()
        var sv: Data? = nil
        ydoc.getText().insert(0, text: "a")
        ydoc.on(YDocument.On.update) { update, _, _ in
            do {
                sv = try update.encodeStateVectorFromUpdate()
            } catch {
                XCTFail("\(error)")
            }
        }
        
        ydoc.getText().insert(0, text: "a")
        try XCTAssertEqual(XCTUnwrap(sv).map{ $0 }, [0])
    }

    func testDiffStateVectorOfUpdateIgnoresSkips() throws {
        let ydoc = YDocument()
        var updates: [YUpdate] = []
        ydoc.on(YDocument.On.update) { update, _, _ in
            updates.append(update)
        }
        ydoc.getText().insert(0, text: "a")
        ydoc.getText().insert(0, text: "b")
        ydoc.getText().insert(0, text: "c")
                
        let update13 = try YUpdate.merged([updates[0], updates[2]])
                
        let sv = try update13.encodeStateVectorFromUpdate()
        let state = try YDeleteSetDecoderV1(sv).readStateVector()
        XCTAssertEqual(state[ydoc.clientID], 1)
        XCTAssertEqual(state.count, 1)
    }
    
}

