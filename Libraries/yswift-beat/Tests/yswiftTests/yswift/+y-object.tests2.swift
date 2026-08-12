import XCTest
import Promise
@testable import yswift

class NameContainer: YObject {
    class Name: YObject {
        @Property var name: String = ""
        
        convenience init(_ name: String) { self.init(); self.name = name }
        required init() { super.init(); self.register(_name, for: "name") }
    }
    
    @WProperty var names: YArray<Name> = []
    
    convenience init(_ names: [Name]) { self.init(); self.names.append(contentsOf: names) }
    required init() { super.init(); self.register(_names, for: "names") }
}

final class YObjectTests2: XCTestCase {
    override func setUp() {
        NameContainer.registerAuto()
        NameContainer.Name.registerAuto()
    }
    
    func testObjectAtRootOfDocument() throws {
        class Object: YObject {
            @Property var name: String = "default"
            
            required init() {
                super.init()
                self.register(_name, for: "name")
            }
            
            convenience init(name: String) {
                self.init()
                self.name = name
            }
        }
        Object.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let object0 = test.docs[0].getObject(Object.self), object1 = test.docs[1].getObject(Object.self)
        try test.sync()
        
        object0.name = "second"
        
        print(object0.name)
        print(object1.name)
    }
    
    func testArrayOrMapWithReferenceSmartCopy() throws {
        class Object: YObject, CustomStringConvertible {
            @Property private(set) var name: String = ""
            
            @WProperty var children: YArray<Object> = []
            
            @WProperty var array: YArray<YReference<Object>> = []
            @WProperty var arrayOptional: YArray<YReference<Object>?> = []
            @WProperty var map: YMap<YReference<Object>> = [:]
            @WProperty var mapOptional: YMap<YReference<Object>?> = [:]
            
            var description: String {
                var components = [(String, Any?)]()
                components.append(("#", self.objectID.value))
                if !children.isEmpty { components.append(("children", children)) }
                if !array.isEmpty { components.append(("array", array)) }
                if !arrayOptional.isEmpty { components.append(("arrayOptional", arrayOptional)) }
                if !map.isEmpty { components.append(("map", map)) }
                if !mapOptional.isEmpty { components.append(("mapOptional", mapOptional)) }
                return makeDescription(from: components)
            }
            
            required init() {
                super.init()
                self.register(_name, for: "name")
                self.register(_children, for: "children")
                self.register(_array, for: "array")
                self.register(_arrayOptional, for: "arrayOptional")
                self.register(_map, for: "map")
                self.register(_mapOptional, for: "mapOptional")
            }
            
            convenience init(name: String) {
                self.init()
                self.name = name
            }
        }
        Object.registerAuto()
        
        let parent = Object(name: "Parent")
        let child0 = Object(name: "Child0")
        let child1 = Object(name: "Child1")
        let child2 = Object(name: "Child2")
        let child3 = Object(name: "Child3")
        
        parent.children.assign([ child0, child1, child2, child3 ])
        parent.array.append(child0.reference())
        parent.arrayOptional.append(contentsOf: [child1.reference(), nil])
        parent.map["child"] = child2.reference()
        parent.mapOptional["child"] = child3.reference()
        parent.mapOptional["child_nil"] = nil
        
        let parentCopy = parent.smartCopy()
        
        print(parent)
        print(parentCopy)
        
        XCTAssert(parentCopy.array[0].value === parentCopy.children[0])
        
    }
    
    func testReferenceObject() throws {
        class Layer: YObject {
            @Property var name: String = ""
            @Property var parent: YReference<Layer>?
            @WProperty var children: YArray<Layer> = []
            
            convenience init(_ name: String = "", _ children: [Layer] = []) {
                self.init()
                self.name = name
                self.children.append(contentsOf: children)
                children.forEach{ $0.parent = .reference(self) }
            }
            
            required init() {
                super.init()
                self.register(_name, for: "name")
                self.register(_parent, for: "parent")
                self.register(_children, for: "children")
            }
        }
        Layer.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Layer.self, 0), map1 = test.swiftyMap(Layer.self, 1)

        let inner0 = Layer("layer1_0")
        let root0 = Layer("root", [
            Layer("layer0_0"),
            Layer("container1", [ inner0 ]),
        ])
        
        XCTAssert(inner0.parent?.value.parent?.value === root0)
        
        map0["root"] = root0
        XCTAssert(inner0.parent?.value.parent?.value === root0)
        
        try test.sync()
        let root1 = try XCTUnwrap(map1["root"])
        
        
        let inner1 = root0.children[1].children[0]
        
        XCTAssert(inner1.parent?.value.parent?.value === root1)
    }
    
    func testArrayPublisherSync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(NameContainer.self, 0), map1 = test.swiftyMap(NameContainer.self, 1)

        let container0 = NameContainer()
        map0["container"] = container0
        try test.sync()
        let container1 = try XCTUnwrap(map1["container"])
        
        var names = [String]()
        container1.$names.map{ $0.map{ $0.$name }.combineLatestHandleEmpty }.switchToLatest()
            .sink{ names = $0.map{ $0 } }.store(in: &objectBag)
        
        XCTAssertEqual(names, [])

        container0.names.append(.init("Alice"))
        try test.sync()
        XCTAssertEqual(names, ["Alice"])
        
        container0.names.append(.init("Bob"))
        try test.sync()
        XCTAssertEqual(names, ["Alice", "Bob"])
        
        container0.names[0].name = "Alisa"
        try test.sync()
        XCTAssertEqual(names, ["Alisa", "Bob"])
    }
    
    
    func testArrayPublisherLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(NameContainer.self, 0)

        let container0 = NameContainer()
        
        var names = [String]()
        container0.$names.map{ $0.map{ $0.$name }.combineLatestHandleEmpty }.switchToLatest()
            .sink{ names = $0.map{ $0 } }.store(in: &objectBag)
        
        map0["container"] = container0
        XCTAssertEqual(names, [])

        container0.names.append(.init("Alice"))
        XCTAssertEqual(names, ["Alice"])
        
        container0.names.append(.init("Bob"))
        XCTAssertEqual(names, ["Alice", "Bob"])
        
        container0.names[0].name = "Alisa"
        XCTAssertEqual(names, ["Alisa", "Bob"])
    }
    
    func testSmartCopy() throws {
        class Layer: YObject {
            @Property var name: String = ""
            @Property var parent: YReference<Layer>? = nil
            @WProperty var children: YArray<Layer> = []
            
            convenience init(_ name: String, _ children: [Layer] = []) {
                self.init()
                self.name = name
                self.children.assign(children)
                children.forEach{ $0.parent = .reference(self) }
            }
            
            required init() {
                super.init()
                self.register(_name, for: "name")
                self.register(_parent, for: "parent")
                self.register(_children, for: "children")
            }
        }
        Layer.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let (map0, map1) = test.swiftyMap2(Layer.self)
        
        let root0 = Layer("root", [
            Layer("child0", [
                Layer("child1")
            ])
        ])
        let inner = root0.children[0].children[0]
        XCTAssert(inner.parent?.value.parent?.value === root0)
        
        map0["root"] = root0
        XCTAssert(map0["root"]?.children[0].children[0].parent?.value.parent?.value === map0["root"])
        
        try test.sync()
        let root1 = try XCTUnwrap(map1["root"])
        XCTAssert(root1.children[0].children[0].parent?.value.parent?.value === root1)
        
        let root0Copy = root0.smartCopy()
        
        XCTAssertEqual(root0Copy.children[0].children[0].parent?.value.parent?.value.objectID, root0Copy.objectID)

        map0["rootcopy"] = root0Copy
        try test.sync()

        let root1Copy = try XCTUnwrap(map1["rootcopy"])

        XCTAssertEqual(root1Copy.children[0].children[0].parent?.value.parent?.value.objectID, root1Copy.objectID)
    }
}
