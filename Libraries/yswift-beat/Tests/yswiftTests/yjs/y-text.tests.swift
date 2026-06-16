import XCTest
import Promise
@testable import yswift

final class YTextTests: XCTestCase {
    
    func testDeltaBug() throws {
        let initialDelta = [
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-28eea923-9cbb-4b6f-a950-cf7fd82bc087"
            ]),
            YEvent.Delta(insert: "\n\n\n", attributes: [
                "table-col": [
                    "width": "150"
                ]
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-9144be72-e528-4f91-b0b2-82d20408e9ea",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-apba4k"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-apba4k",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-639adacb-1516-43ed-b272-937c55669a1c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-a8qf0r"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-a8qf0r",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-6302ca4a-73a3-4c25-8c1e-b542f048f1c6",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-oi9ikb"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-oi9ikb",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-ceeddd05-330e-4f86-8017-4a3a060c4627",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-dt6ks2"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-dt6ks2",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-37b19322-cb57-4e6f-8fad-0d1401cae53f",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-qah2ay"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-qah2ay",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-468a69b5-9332-450b-9107-381d593de249",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-fpcz5a"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-fpcz5a",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-26b1d252-9b2e-4808-9b29-04e76696aa3c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-zrhylp"
                ],
                "row": "row-pflz90",
                "cell": "cell-zrhylp",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-6af97ba7-8cf9-497a-9365-7075b938837b",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-s1q9nt"
                ],
                "row": "row-pflz90",
                "cell": "cell-s1q9nt",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-107e273e-86bc-44fd-b0d7-41ab55aca484",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-20b0j9"
                ],
                "row": "row-pflz90",
                "cell": "cell-20b0j9",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-38161f9c-6f6d-44c5-b086-54cc6490f1e3"
            ]),
            YEvent.Delta(insert: "Content after table"),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-15630542-ef45-412d-9415-88f0052238ce"
            ])
        ]
        let ydoc1 = YDocument()
        let ytext = ydoc1.getText()
        ytext.applyDelta(initialDelta)
        let addingDash = [
            YEvent.Delta(retain: 12),
            YEvent.Delta(insert: "-")
        ]
        ytext.applyDelta(addingDash)
        let addingSpace = [
            YEvent.Delta(retain: 13),
            YEvent.Delta(insert: " ")
        ]
        ytext.applyDelta(addingSpace)
        
        let addingList = [
            YEvent.Delta(retain: 12),
            YEvent.Delta(delete: 2),
            YEvent.Delta(retain: 1, attributes: [
                "table-cell-line": nil,
                "list": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-20b0j9",
                    "list": "bullet"
                ]
            ])
        ]
        ytext.applyDelta(addingList)
        let result = ytext.toDelta()
        let expectedResult = [
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-28eea923-9cbb-4b6f-a950-cf7fd82bc087"
            ]),
            YEvent.Delta(insert: "\n\n\n", attributes: [
                "table-col": [
                    "width": "150"
                ]
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-9144be72-e528-4f91-b0b2-82d20408e9ea",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-apba4k"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-apba4k",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-639adacb-1516-43ed-b272-937c55669a1c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-a8qf0r"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-a8qf0r",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-6302ca4a-73a3-4c25-8c1e-b542f048f1c6",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-oi9ikb"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-oi9ikb",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-ceeddd05-330e-4f86-8017-4a3a060c4627",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-dt6ks2"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-dt6ks2",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-37b19322-cb57-4e6f-8fad-0d1401cae53f",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-qah2ay"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-qah2ay",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-468a69b5-9332-450b-9107-381d593de249",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-fpcz5a"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-fpcz5a",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-26b1d252-9b2e-4808-9b29-04e76696aa3c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-zrhylp"
                ],
                "row": "row-pflz90",
                "cell": "cell-zrhylp",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-6af97ba7-8cf9-497a-9365-7075b938837b",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-s1q9nt"
                ],
                "row": "row-pflz90",
                "cell": "cell-s1q9nt",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "list": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-20b0j9",
                    "list": "bullet"
                ],
                "block-id": "block-107e273e-86bc-44fd-b0d7-41ab55aca484",
                "row": "row-pflz90",
                "cell": "cell-20b0j9",
                "rowspan": "1",
                "colspan": "1"
            ]),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-38161f9c-6f6d-44c5-b086-54cc6490f1e3"
            ]),
            YEvent.Delta(insert: "Content after table"),
            YEvent.Delta(insert: "\n", attributes: [
                "block-id": "block-15630542-ef45-412d-9415-88f0052238ce"
            ])
        ]
        XCTAssertEqual(result, expectedResult)
    }
    
    func testDeltaAfterConcurrentFormatting() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], text1 = test.text[1], connector = test.connector
        
        text0.insert(0, text: "abcde")
        
        try connector.flushAllMessages()
        
        text0.format(0, length: 3, attributes: ["bold": true])
        text1.format(2, length: 2, attributes: ["bold": true])
        
        var deltas: [[YEvent.Delta]] = []
        
        text1.observe{ event, _ in
            if (event.delta().count > 0) {
                deltas.append(event.delta())
            }
        }
        
        try connector.flushAllMessages()
        
        XCTAssertEqual(deltas, [[
            YEvent.Delta(retain: 3, attributes: ["bold": true]),
            YEvent.Delta(retain: 2, attributes: ["bold": nil])
        ]])
    }
    
    func testBasicInsertAndDelete() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], docs = test.docs
        
        var delta: [YEvent.Delta]?
        text0.observe{ event, _ in delta = event.delta() }
        
        text0.delete(0, length: 0)
        
        XCTAssert(true, "Does not throw when deleting zero elements with position 0")
        
        text0.insert(0, text: "abc")
        
        XCTAssert(text0.toString() == "abc", "Basic insert works")
        XCTAssertEqual(delta, [YEvent.Delta(insert: "abc")])
        
        text0.delete(0, length: 1)
        
        XCTAssert(text0.toString() == "bc", "Basic delete works (position 0)")
        XCTAssertEqual(delta, [YEvent.Delta(delete: 1)])
        
        text0.delete(1, length: 1)
        
        XCTAssert(text0.toString() == "b", "Basic delete works (position 1)")
        
        XCTAssertEqual(delta, [YEvent.Delta(retain: 1), YEvent.Delta(delete: 1)])
        
        docs[0].transact{_ in
            text0.insert(0, text: "1")
            text0.delete(0, length: 1)
        }
        
        XCTAssertEqual(delta, [])
        try YAssertEqualDocs(docs)
    }
    
    func testBasicFormat() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], docs = test.docs
        
        var delta: [YEvent.Delta]?
        text0.observe{ event, _ in delta = event.delta() }
        
        text0.insert(0, text: "abc", attributes: ["bold": true])
        
        XCTAssertEqual(text0.toString(), "abc")
        XCTAssertEqual(text0.toDelta(), [YEvent.Delta(insert: "abc", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEvent.Delta(insert: "abc", attributes: ["bold": true] )])

        text0.delete(0, length: 1)

        XCTAssertEqual(text0.toString(), "bc")
        XCTAssertEqual(text0.toDelta(), [YEvent.Delta(insert: "bc", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEvent.Delta(delete: 1)])

        text0.delete(1, length: 1)

        XCTAssertEqual(text0.toString(), "b", "Basic delete works (position 1)")
        XCTAssertEqual(text0.toDelta(), [YEvent.Delta(insert: "b", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEvent.Delta(retain: 1), YEvent.Delta(delete: 1)])
        
        text0.insert(0, text: "z", attributes: ["bold": true])
        
        XCTAssertEqual(text0.toString(), "zb")
        XCTAssertEqual(text0.toDelta(), [YEvent.Delta(insert: "zb", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEvent.Delta(insert: "z", attributes: ["bold": true])])
        
        let contentString = try XCTUnwrap(text0._start?.right?.asItemRight?.asItemRight?.asItemContentString)
        XCTAssertEqual(contentString.string, "b", "Does not insert duplicate attribute marker")
        
        text0.insert(0, text: "y")
        XCTAssertEqual(text0.toString(), "yzb")
        XCTAssertEqual(text0.toDelta(), [YEvent.Delta(insert: "y"), YEvent.Delta(insert: "zb", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEvent.Delta(insert: "y")])
        
        text0.format(0, length: 2, attributes: ["bold": nil])
        
        XCTAssertEqual(text0.toString(), "yzb")
        XCTAssertEqual(text0.toDelta(), [YEvent.Delta(insert: "yz"), YEvent.Delta(insert: "b", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEvent.Delta(retain: 1), YEvent.Delta(retain: 1, attributes: ["bold": nil] )])
                                             
        try YAssertEqualDocs(docs)
    }
    
    func testMultilineFormat() throws {
        let ydoc = YDocument()
        let testText = ydoc.getText("test")
        testText.insert(0, text: "Test\nMulti-line\nFormatting")
        testText.applyDelta([
            YEvent.Delta(retain: 4, attributes: ["bold": true]),
            YEvent.Delta(retain: 1),
            YEvent.Delta(retain: 10, attributes: ["bold": true]),
            YEvent.Delta(retain: 1),
            YEvent.Delta(retain: 10, attributes: ["bold": true])
        ])
        
        XCTAssertEqual(testText.toDelta(), [
            YEvent.Delta(insert: "Test", attributes: ["bold": true]),
            YEvent.Delta(insert: "\n"),
            YEvent.Delta(insert: "Multi-line", attributes: ["bold": true]),
            YEvent.Delta(insert: "\n"),
            YEvent.Delta(insert: "Formatting", attributes: ["bold": true])
        ])
    }

    func testNotMergeEmptyLinesFormat() throws {
        let ydoc = YDocument()
        let testText = ydoc.getText("test")
        testText.applyDelta([
            YEvent.Delta(insert: "Text"),
            YEvent.Delta(insert: "\n", attributes: ["title": true]),
            YEvent.Delta(insert: "\nText"),
            YEvent.Delta(insert: "\n", attributes: ["title": true]),
        ])
        
        XCTAssertEqual(testText.toDelta(), [
            YEvent.Delta(insert: "Text"),
            YEvent.Delta(insert: "\n", attributes: ["title": true]),
            YEvent.Delta(insert: "\nText"),
            YEvent.Delta(insert: "\n", attributes: ["title": true]),
        ])
    }

    func testPreserveAttributesThroughDelete() throws {
        let ydoc = YDocument()
        let testText = ydoc.getText("test")
        
        testText.applyDelta([
            YEvent.Delta(insert: "Text"),
            YEvent.Delta(insert: "\n", attributes: ["title": true]),
            YEvent.Delta(insert: "\n"),
        ])
        
        testText.applyDelta([
            YEvent.Delta(retain: 4),
            YEvent.Delta(delete: 1),
            YEvent.Delta(retain: 1, attributes: ["title": true]),
        ])
        
        XCTAssertEqual(testText.toDelta(), [
            YEvent.Delta(insert: "Text"),
            YEvent.Delta(insert: "\n", attributes: ["title": true]),
        ])
    }
    
    func testGetDeltaWithEmbeds() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]
        
        text0.applyDelta([
            YEvent.Delta(insert: ["linebreak": "s"])
        ])
        
        XCTAssertEqual(text0.toDelta(), [
            YEvent.Delta(insert: ["linebreak": "s"])
        ])
    }

    func testTypesAsEmbed() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], text1 = test.text[1], connector = test.connector
        
        text0.applyDelta([
            YEvent.Delta(insert: ["key": "val"])
        ])
        
        XCTAssertEqualJSON(text0.toDelta()[0].insert, ["key": "val"])
        
        var firedEvent = false
        text1.observe{ event, _ in
            let d = event.delta()
            
            XCTAssertEqual(d.count, 1)
            XCTAssertEqualJSON(d.map{ $0.insert }, [["key": "val"]])
            
            firedEvent = true
        }
        try connector.flushAllMessages()
        let delta = text1.toDelta()
        
        XCTAssertEqual(delta.count, 1)
        XCTAssertEqualJSON(delta[0].insert, ["key": "val"])
        XCTAssert(firedEvent, "fired the event observer containing a Type-Embed")
    }

    func testSnapshot() throws {
        let test = try YTest<Any>(docs: 1, gc: false)
        let text0 = test.text[0], doc0 = test.docs[0]
        
        text0.applyDelta([
            YEvent.Delta(insert: "abcd"),
        ])
        let snapshot1 = YSnapshot(doc: doc0)
        text0.applyDelta([
            YEvent.Delta(retain: 1),
            YEvent.Delta(insert: "x"),
            YEvent.Delta(delete: 1),
        ])
        let snapshot2 = YSnapshot(doc: doc0)
        text0.applyDelta([
            YEvent.Delta(retain: 2),
            YEvent.Delta(delete: 3),
            YEvent.Delta(insert: "x"),
            YEvent.Delta(delete: 1),
        ])
        let state1 = text0.toDelta(snapshot1)
        XCTAssertEqual(state1, [YEvent.Delta(insert: "abcd")])
        let state2 = text0.toDelta(snapshot2)
        XCTAssertEqual(state2, [YEvent.Delta(insert: "axcd")])
        let state2Diff = text0.toDelta(snapshot2, prevSnapshot: snapshot1)
        
        state2Diff.forEach{ v in
            if (v.attributes != nil && v.attributes!.value["ychange"] != nil) {
                // cannot do that in Swift
//                (v.attributes?.value["ychange"] as! [String: Any]).removeValue(forKey: "user")
            }
        }
        XCTAssertEqual(state2Diff, [
            YEvent.Delta(insert: "a" ),
            YEvent.Delta(insert: "x", attributes: ["ychange": ["type": "added"]]),
            YEvent.Delta(insert: "b", attributes: ["ychange": ["type": "removed"]]),
            YEvent.Delta(insert: "cd")
        ])
    }

    func testSnapshotDeleteAfter() throws {
        let test = try YTest<Any>(docs: 1, gc: false)
        let text0 = test.text[0], doc0 = test.docs[0]
        
        text0.applyDelta([
            YEvent.Delta(insert: "abcd"),
        ])
        let snapshot1 = YSnapshot(doc: doc0)
        text0.applyDelta([
            YEvent.Delta(retain: 4),
            YEvent.Delta(insert: "e"),
        ])
        let state1 = text0.toDelta(snapshot1)
        XCTAssertEqual(state1, [YEvent.Delta(insert: "abcd")])
    }

    func testToJson() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]
        
        text0.insert(0, text: "abc", attributes: ["bold": true])
        
        XCTAssertEqualJSON(text0.toJSON(), "abc", "toJSON returns the unformatted text")
    }
    
    func testToDeltaEmbedAttributes() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]

        text0.insert(0, text: "ab", attributes: ["bold": true])
        text0.insertEmbed(1, embed: ["image": "imageSrc.png"], attributes: ["width": 100])
        let delta0 = text0.toDelta()
        
        XCTAssertEqual(delta0, [
            YEvent.Delta(insert: "a", attributes: ["bold": true] ),
            YEvent.Delta(insert: ["image": "imageSrc.png"], attributes: ["width": 100]),
            YEvent.Delta(insert: "b", attributes: ["bold": true])
        ])
    }

    func testToDeltaEmbedNoAttributes() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]

        text0.insert(0, text: "ab", attributes: ["bold": true])
        text0.insertEmbed(1, embed: ["image": "imageSrc.png"], attributes: nil)
        
        let delta0 = text0.toDelta()
        XCTAssertEqual(delta0, [
            YEvent.Delta(insert: "a", attributes: ["bold": true]),
            YEvent.Delta(insert: ["image": "imageSrc.png"]),
            YEvent.Delta(insert: "b", attributes: ["bold": true])
        ], "toDelta does not set attributes key when no attributes are present")
    }


//    func testFormattingRemoved() throws {
//        let test = YTest<Any>(docs: 1)
//        let text0 = test.text[0]
//
//        text0.insert(0, text: "ab", attributes: ["bold": true])
//        text0.delete(0, length: 2)
//        print(text0.getChildren())
//        XCTAssertEqual(text0.getChildren().count, 1)
//    }


//    func testFormattingRemovedInMidText() throws {
//        let test = YTest<Any>(docs: 1)
//        let text0 = test.text[0]
//
//        text0.insert(0, "1234")
//        text0.insert(2, "ab", ["bold": true])
//        text0.delete(2, 2)
//        XCTAssert(text0.getChildren().length === 3)
//    }
//
//
//    func testFormattingDeltaUnnecessaryAttributeChange() throws {
//        let test = YTest<Any>(docs: 2)
//        let connector = test.connector, text0 = test.text[0], text1 = test.text[1]
//
//        text0.insert(0, "\n", {
//            PARAGRAPH_STYLES: "normal",
//            LIST_STYLES: "bullet"
//        })
//        text0.insert(1, "abc", {
//            PARAGRAPH_STYLES: "normal"
//        })
//        connector.flushAllMessages()
//        /**
//         * @type {Array<any>}
//         */
//        let deltas = [
//
//        ]
//        text0.observe(event => {
//            deltas.push(event.delta)
//        })
//        text1.observe(event => {
//            deltas.push(event.delta)
//        })
//        text1.format(0, 1, ["LIST_STYLES": "number"])
//        connector.flushAllMessages()
//        let filteredDeltas = deltas.filter(d => d.length > 0)
//        XCTAssert(filteredDeltas.length === 2)
//        XCTAssertEqual(filteredDeltas[0], [
//            YEvent.Delta(retain: 1, attributes: ["LIST_STYLES": "number"]),
//        ])
//        XCTAssertEqual(filteredDeltas[0], filteredDeltas[1])
//    }

}

extension YStructure {
    var asItemRight: YStructure? {
        return (self as? YItem)?.right
    }
    var asItemContentString: YStringContent? {
        return (self as? YItem)?.content as? YStringContent
    }
}
