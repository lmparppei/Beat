import XCTest
import Promise
import Combine
@testable import yswift

final class YArraySwiftyTests: XCTestCase {
    
    func testArrayNestedDeleteAndRemove() throws {
        let test = try YTest<Any>(docs: 2)

        let (array0, array1) = test.swiftyArray2(YMap<Int>.self)
        
        var map0: YMap<Int> = ["Apple": 120, "Banana": 240]
        
        array0.append(map0)
        try test.sync()
        XCTAssertEqual(array1, [["Apple": 120, "Banana": 240]])
        
        map0 = array0.remove(at: 0)
        try test.sync()
        XCTAssertEqual(array1, [])
        
        array0.append(map0)
        try test.sync()
        XCTAssertEqual(array1, [["Apple": 120, "Banana": 240]])
        
        XCTAssertEqual(map0, ["Apple": 120, "Banana": 240])
    }
    
    func testArrayPrimitiveTypeSync() throws {
        let test = try YTest<Any>(docs: 2)
        let array0 = test.swiftyArray(Int.self, 0), array1 = test.swiftyArray(Int.self, 1)
        
        array0.append(1)
        array1.append(2)
        
        try test.sync()
        XCTAssertEqual(array0, array1)
        
        array1.insert(0, at: 0)
        try test.sync()
        
        XCTAssert(array0.starts(with: [0]))
        XCTAssert(array1.starts(with: [0]))
    }
    
    func testArrayEventCheck() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
        
        var event: YArray<Int>.Event?
        
        array.eventPublisher
            .sink{ event = $0 }.store(in: &objectBag)
        
        array.append(1)
        XCTAssertEqual(event, YArray<Int>.Event(insert: [1]))
        array.delete(at: 0)
        XCTAssertEqual(event, YArray<Int>.Event(delete: 1))
        array.append(1)
        XCTAssertEqual(event, YArray<Int>.Event(insert: [1]))
    }
            
    func testArrayPrimitiveType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
                
        array.append(1)
        array.append(2)
        array.append(3)
                
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0], 1)
        XCTAssertEqual(array[1], 2)
        XCTAssertEqual(array[2], 3)
        
        XCTAssertEqual(array[1..<2], [2])
        XCTAssertEqual(array[1...2], [2, 3])
        XCTAssertEqual(array[1...], [2, 3])
        XCTAssertEqual(array[...1], [1, 2])
        XCTAssertEqual(array[..<1], [1])
    }
    
    func testArrayConcreteType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(YArray<Int>.self, 0)

        array.append(YArray([ 1 ]))
        array.append(YArray([ 1, 2 ]))
        array.append(YArray([ 1, 2, 3 ]))

        XCTAssertEqual(array.count, 3)

        XCTAssertEqual(array[0].count, 1)
        XCTAssertEqual(array[1].count, 2)
        XCTAssertEqual(array[2].count, 3)
    }
    
    
    func testArrayCodableType() throws {
        struct Point: Codable, Equatable, YElement {
            var x: Double, y: Double
            
            func toOpaque() -> Any? { ["x": x, "y": y] }
            static func fromOpaque(_ opaque: Any?) -> Point {
                let opaque = opaque as! [String: Double]
                return Point(x: opaque["x"]!, y: opaque["y"]!)
            }
        }

        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Point.self, 0)
        
        array.append(Point(x: 1, y: 11))
        array.append(Point(x: 2, y: 22))
        array.append(Point(x: 3, y: 33))
        
        XCTAssertEqual(array[0], Point(x: 1, y: 11))
        XCTAssertEqual(array[1], Point(x: 2, y: 22))
        XCTAssertEqual(array[2], Point(x: 3, y: 33))
    }
    
    func testArrayNestedType() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(YArray<YArray<String>>.self, 0)
        
        array.append(YArray([ YArray([ "Hello", "World" ]) ]))
        
        XCTAssertEqual(array[0][0].toArray(), [ "Hello", "World" ])
    }
    
    func testArrayPublisher() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
        
        var deltas = [YEvent.Delta]()
        array.opaqueEventPublisher
            .sink{ deltas.append(contentsOf: $0.delta()) }
            .store(in: &objectBag)
        
        array.append(12876)
        
        XCTAssertEqual(deltas, [ YEvent.Delta(insert: [12876]) ])
    }
    
    func testArrayNoneExclusiveAccess() throws {
        let test = try YTest<Any>(docs: 1)
        let array = test.swiftyArray(Int.self, 0)
        
        array.eventPublisher
            .sink{_ in if array.count < 10 { array.append(array.count) } }
            .store(in: &objectBag)
        
        array.append(0)
        
        XCTAssertEqual(array.toArray(), (0..<10).map{ $0 })
    }
    
    func testDocumentGetArray() throws {
        let test = try YTest<Any>(docs: 1)
        let doc = test.docs[0]
        
        let root = doc.getMap(YArray<Int>.self)
        
        root["alice"] = [1, 2, 3]
        root["bob"] = [4, 5, 6]
        
        XCTAssertEqualJSON(root.toJSON(), [
            "alice": [1, 2, 3],
            "bob": [4, 5, 6],
        ])
    }
}

