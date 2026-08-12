import XCTest
import Promise
import Combine
@testable import yswift

final class IntegrationsTests: XCTestCase {
    
    func testMapObject() throws {
        class Person: YObject {
            @Property var name: String = ""
            convenience init(name: String) { self.init(); self.name = name }
            required init() { super.init(); self.register(_name, for: "name") }
        }
        Person.registerAuto()
        
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Person.self, 0),
            array0 = test.swiftyArray(Person.self, 0)

        let alice0 = Person(name: "Alice")
        map0["alice"] = alice0
        array0.append(alice0)
        let alice0_map = try XCTUnwrap(map0["alice"])
        let alice0_array = try XCTUnwrap(array0.first)
        
        XCTAssert(alice0 === alice0_map)
        XCTAssert(alice0 === alice0_array)
    }
    
    func testEnum() throws {
        enum Sex: Int, YRawRepresentable { case man = 0, weman = 1 }
        
        class Person: YObject {
            @Property var name: String = ""
            @Property var sex: Sex = .man
            
            convenience init(name: String, sex: Sex) {
                self.init()
                self.name = name
                self.sex = sex
            }
            
            required init() {
                super.init()
                self.register(_sex, for: "sex")
                self.register(_name, for: "name")
            }
        }
        Person.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0), map1 = test.swiftyMap(Person.self, 1)
        
        let alice0 = Person(name: "Alice", sex: .weman)
        map0["alice"] = alice0
        
        try test.sync()
        
        let alice1 = try XCTUnwrap(map1["alice"])
        
        XCTAssertEqual(alice1.name, "Alice")
        XCTAssertEqual(alice1.sex, .weman)
    }
    
    func testStruct() throws {
        struct Point: YCodable, Hashable {
            var x: Float
            var y: Float
        }
                
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Point.self, 0), map1 = test.swiftyMap(Point.self, 1)

        map0["point"] = Point(x: 12, y: 10)
        
        try test.sync()
        
        let point1 = try XCTUnwrap(map1["point"])
        
        XCTAssertEqual(point1, Point(x: 12, y: 10))
    }
    
    func testStructExisting() throws {
        let test = try YTest<Any>(docs: 2)
        
        class Container: YObject {
            @Property var point: CGPoint = .zero
            @Property var size: CGSize = .zero
            @Property var rect: CGRect = .zero
            
            required init() {
                super.init()
                self.register(_point, for: "p")
                self.register(_size, for: "s")
                self.register(_rect, for: "r")
            }
            
            convenience init(point: CGPoint, size: CGSize, rect: CGRect) {
                self.init()
                self.point = point
                self.size = size
                self.rect = rect
            }
        }
        Container.registerAuto()
        
        let map0 = test.swiftyMap(Container.self, 0),
            map1 = test.swiftyMap(Container.self, 1)
        
        let container0 = Container(
            point: CGPoint(x: 12, y: 36),
            size: CGSize(width: 21, height: 89),
            rect: CGRect(x: 12, y: 23, width: 34, height: 45)
        )
        
        map0["container"] = container0
        
        try test.sync()
        
        let container1 = try XCTUnwrap(map1["container"])
        
        XCTAssertEqual(container1.point, CGPoint(x: 12, y: 36))
        XCTAssertEqual(container1.size, CGSize(width: 21, height: 89))
        XCTAssertEqual(container1.rect, CGRect(x: 12, y: 23, width: 34, height: 45))
    }
}

extension CGRect: YCodable {}
extension CGSize: YCodable {}
extension CGPoint: YCodable {}
