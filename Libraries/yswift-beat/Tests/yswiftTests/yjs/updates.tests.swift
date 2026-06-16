import XCTest
import Promise
import lib0
@testable import yswift

final class UpdatesTests: XCTestCase {
    func testMergeUpdates() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, array0 = test.array[0], array1 = test.array[1]

        array0.insert(1, at: 0)
        array1.insert(2, at: 0)

        let ndocs = try YAssertEqualDocs(docs)

        for env in YUpdateEnvironment.encoders {
            let merged = try env.docFromUpdates(ndocs.map{ $0 })
        
            XCTAssertEqualJSON(
                array0.map{ $0 }, merged.getOpaqueArray("array").map{ $0 }
            )
        }
    }
    
    func testKeyEncoding() throws {
        let test = try YTest<Any>(docs: 2)
        
        let docs = test.docs, text0 = test.text[0], text1 = test.text[1]

        text0.insert(0, text: "a", attributes: ["i": true])
        text0.insert(0, text: "b")
        text0.insert(0, text: "c", attributes: ["i": true])
        
        let update = try docs[0].encodeStateAsUpdateV2()
        
        try docs[1].applyUpdateV2(update)

        XCTAssertEqual(text1.toDelta(), [
            YEvent.Delta(insert: "c", attributes: ["i": true]),
            YEvent.Delta(insert: "b"),
            YEvent.Delta(insert: "a", attributes: ["i": true]),
        ])

        try YAssertEqualDocs(docs)
    }
    
    func testMergeUpdates1() throws {
        for env in YUpdateEnvironment.encoders {
            print("== Using encoder: \(env.description) ==")
            let ydoc = YDocument(YDocument.Options(gc: false))
            
            var updates = [YUpdate]()
            ydoc.on(env.updateEventName) { update, _, _ in updates.append(update) }

            let array = ydoc.getOpaqueArray()
            array.insert(1, at: 0)
            array.insert(2, at: 0)
            array.insert(3, at: 0)
            array.insert(4, at: 0)

            try checkUpdateCases(ydoc: ydoc, updates: updates, enc: env, hasDeletes: false)
        }
    }

    func testMergeUpdates2() throws {
        for env in [YUpdateEnvironment.v2] {
            print("== Using encoder: \(env.description) ==")
            let ydoc = YDocument(YDocument.Options(gc: false))
            
            var updates: [YUpdate] = []
            ydoc.on(env.updateEventName) {
                update, _, _ in updates.append(update)
            }

            let array = ydoc.getOpaqueArray()
            array.insert(contentsOf: [1, 2], at: 0)
            array.delete(at: 1)
            array.insert(contentsOf: [3, 4], at: 0)
            array.delete(in: 1..<2)
            
            try checkUpdateCases(ydoc: ydoc, updates: updates, enc: env, hasDeletes: true)
        }
    }

    func testMergePendingUpdates() throws {
        let yDoc = YDocument()
        var serverUpdates: [YUpdate] = []
        yDoc.on(YDocument.On.update) { update, _, _ in
            serverUpdates.insert(update, at: serverUpdates.count)
        }
        let yText = yDoc.getText("textBlock")
        yText.applyDelta([ YEvent.Delta(insert: "r") ])
        yText.applyDelta([ YEvent.Delta(insert: "o") ])
        yText.applyDelta([ YEvent.Delta(insert: "n") ])
        yText.applyDelta([ YEvent.Delta(insert: "e") ])
        yText.applyDelta([ YEvent.Delta(insert: "n") ])

        let yDoc1 = YDocument()
        try yDoc1.applyUpdate(serverUpdates[0])
        let update1 = try yDoc1.encodeStateAsUpdate()

        let yDoc2 = YDocument()
        try yDoc2.applyUpdate(update1)
        try yDoc2.applyUpdate(serverUpdates[1])
        let update2 = try yDoc2.encodeStateAsUpdate()

        let yDoc3 = YDocument()
        try yDoc3.applyUpdate(update2)
        try yDoc3.applyUpdate(serverUpdates[3])
        let update3 = try yDoc3.encodeStateAsUpdate()

        let yDoc4 = YDocument()
        try yDoc4.applyUpdate(update3)
        try yDoc4.applyUpdate(serverUpdates[2])
        let update4 = try yDoc4.encodeStateAsUpdate()

        let yDoc5 = YDocument()
        try yDoc5.applyUpdate(update4)
        try yDoc5.applyUpdate(serverUpdates[4])
        _ = try yDoc5.encodeStateAsUpdate()

        let yText5 = yDoc5.getText("textBlock")
        XCTAssertEqual(yText5.toString(), "nenor")
    }
    
    private func checkUpdateCases(ydoc: YDocument, updates: [YUpdate], enc: YUpdateEnvironment, hasDeletes: Bool) throws {
        var cases: [YUpdate] = []

        // Case 1: Simple case, simply merge everything
        try cases.append(enc.mergeUpdates(updates))

        // Case 2: Overlapping updates
        try cases.append(enc.mergeUpdates([
            enc.mergeUpdates(updates[2...].map{ $0 }),
            enc.mergeUpdates(updates[..<2].map{ $0 })
        ]))

        // Case 3: Overlapping updates
        try cases.append(enc.mergeUpdates([
            enc.mergeUpdates(updates[2...].map{ $0 }),
            enc.mergeUpdates(updates[1..<3].map{ $0 }),
            updates[0]
        ]))

        // Case 4: Separated updates (containing skips)
        try cases.append(enc.mergeUpdates([
            enc.mergeUpdates([updates[0], updates[2]]),
            enc.mergeUpdates([updates[1], updates[3]]),
            enc.mergeUpdates(updates[4...].map{ $0 })
        ]))

        // Case 5: overlapping with mAny duplicates
        try cases.append(enc.mergeUpdates(cases))


        for mergedUpdates in cases {
            let merged = YDocument(YDocument.Options(gc: false))
            try enc.applyUpdate(merged, mergedUpdates, nil)
            XCTAssertEqualJSON(merged.getOpaqueArray().map{ $0 }, ydoc.getOpaqueArray().map{ $0 })
            
            try XCTAssertEqual(
                enc.encodeStateVector_Doc(merged).map{ $0 },
                enc.encodeStateVectorFromUpdate(mergedUpdates).map{ $0 }
            )

            if enc.updateEventName.name != "update" {
                for j in 1..<updates.count {
                    let partMerged = try enc.mergeUpdates(updates[j...].map{ $0 })
                    let partMeta = try enc.parseUpdateMeta(partMerged)
                    
                    let targetSV = try YUpdate.mergedV2(updates[..<j].map{ $0 })
                        .encodeStateVectorFromUpdateV2()
                    let diffed = try enc.diffUpdate(mergedUpdates, targetSV)
                    let diffedMeta = try enc.parseUpdateMeta(diffed)
                    XCTAssertEqual(partMeta, diffedMeta)
                    do {
                        let decoder = LZDecoder(diffed.data)
                        let updateDecoder = try YUpdateDecoderV2(decoder)
                        _ = try updateDecoder.readClientsStructRefs(doc: YDocument())
                        let ds = try YDeleteSet.decode(decoder: updateDecoder)
                        let updateEncoder = YUpdateEncoderV2()
                        updateEncoder.restEncoder.writeUInt(0) // 0 structs
                        ds.encode(into: updateEncoder)
                        let deletesUpdate = updateEncoder.toUpdate()
                        let mergedDeletes = try YUpdate.mergedV2([deletesUpdate, partMerged])
                        if !hasDeletes || enc !== YUpdateEnvironment.doc {
                            // deletes will almost definitely lead to different encoders because of the mergeStruct feature that is present in encDoc
                            XCTAssertEqual(diffed, mergedDeletes)
                        }
                    }
                }
            }

            let meta = try enc.parseUpdateMeta(mergedUpdates)
            meta.from.forEach{ client, clock in
                XCTAssert(clock == 0)
            }
            meta.to.forEach{ client, clock in
                let structs = merged.store.clients[client]?.value as! [YItem]
                let lastStruct = structs[structs.count - 1]
                XCTAssert(lastStruct.id.clock + lastStruct.length == clock)
            }
        }
    }
}
