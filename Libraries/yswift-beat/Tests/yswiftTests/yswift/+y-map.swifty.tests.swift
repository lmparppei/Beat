import XCTest
import Promise
@testable import yswift

final class YMapSwiftyTests: XCTestCase {
        
    func testMapPrimitiveType() throws {
        let test = try YTest<Any>(docs: 1)
        let map = test.swiftyMap(Int.self, 0)
                
        map["apple"] = 120
        map["banana"] = 200
        map["chocolate"] = 100
        
        XCTAssertEqual(map["apple"], 120)
        XCTAssertEqual(map["banana"], 200)
        XCTAssertEqual(map["chocolate"], 100)
    }
    
    func testMapConcreteType() throws {
        let test = try YTest<Any>(docs: 1)
        let map = test.swiftyMap(YArray<String>.self, 0)
        
        map["today"] = ["Apple", "Banana"]
        map["tomorrow"] = ["Chocolate"]
        
        XCTAssertEqualJSON(map.toJSON(), [
            "today": ["Apple", "Banana"],
            "tomorrow": ["Chocolate"]
        ])
    }
    
    func testMapNestedType() throws {
        let test = try YTest<Any>(docs: 1)
        let map = test.swiftyMap(YArray<YMap<String>>.self, 0)
        
        XCTAssertTrue(map.isEmpty)
        
        map["members"] = [
            ["name": "Alice", "age": "16"],
            ["name": "Bob", "age": "24"],
        ]
        
        XCTAssertFalse(map.isEmpty)
        
        XCTAssertEqual(map["members"]?[0]["name"], "Alice")
        XCTAssertEqual(map["members"]?[1]["name"], "Bob")
    }
    
    func testMapIterator() throws {
        let test = try YTest<Any>(docs: 1)
        let map = test.swiftyMap(Int.self, 0)
                        
        map["apple"] = 120
        map["banana"] = 200
        map["chocolate"] = 100
        
        var keys = Set<String>()
        var values = Set<Int>()
        for (key, value) in map {
            keys.insert(key)
            values.insert(value)
        }
        
        XCTAssertEqual(keys, ["apple", "banana", "chocolate"])
        XCTAssertEqual(values, [120, 200, 100])
    }
    
    func testMapNil() throws {
        let test = try YTest<Any>(docs: 1)
        let map = test.swiftyMap(Optional<Int>.self, 0)
        
        XCTAssertFalse(map.contains("apple"))
        
        map["apple"] = nil
        XCTAssertTrue(map.contains("apple"))
        
        XCTAssertEqual(map["apple"], nil)
    }
}
