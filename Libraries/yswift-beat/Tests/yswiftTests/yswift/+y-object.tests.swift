import XCTest
import Promise
@testable import yswift

final class Person: YObject {
    @Property public var name: String = ""
    @Property public var age: Int = 0
    
    required init() {
        super.init()
        self.register(_name, for: "name")
        self.register(_age, for: "age")
    }
    
    convenience init(name: String, age: Int) {
        self.init()
        self.name = name
        self.age = age
    }
}

final class PersonOptional: YObject {
    @Property public var name: String?
    @Property public var age: Int?
    
    required init() {
        super.init()
        self.register(_name, for: "name")
        self.register(_age, for: "age")
    }
}

final class PersonPair: YObject {
    @Property var person0: Person?
    @Property var person1: Person?
    
    required init() {
        super.init()
        self.register(_person0, for: "p0")
        self.register(_person1, for: "p1")
    }
}

class Base: YObject {
    @Property var base: String = "base"
    
    required init() {
        super.init()
        self.register(_base, for: "base")
    }
}

final class Sub1: Base {
    @Property var sub1: String = "sub1"
    
    required init() {
        super.init()
        self.register(_sub1, for: "sub1")
    }
}

final class Sub2: Base {
    @Property var sub2: String = "sub2"
    
    required init() {
        super.init()
        self.register(_sub2, for: "sub2")
    }
}

final class BaseContainer: YObject {
    @Property var content: Base?
    
    required init() {
        super.init()
        self.register(_content, for: "base")
    }
}

final class InitialValue: YObject {
    @Property var value: String = "Initial Value"
    
    required init() {
        super.init()
        self.register(_value, for: "value")
    }
}

final class ObjectTests: XCTestCase {
    
    override func setUp() async throws {
        Person.registerAuto()
        PersonPair.registerAuto()
        PersonOptional.registerAuto()
        Base.registerAuto()
        Sub1.registerAuto()
        Sub2.registerAuto()
        BaseContainer.registerAuto()
        InitialValue.registerAuto()
    }
    override func tearDown() async throws {
        Person.unregister()
        PersonPair.unregister()
        PersonOptional.unregister()
        Base.unregister()
        Sub1.unregister()
        Sub2.unregister()
        BaseContainer.unregister()
        InitialValue.unregister()
    }
    
    func testObjectWithInitialValueOverrideInConvenienceInitScope() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Object.self, 0), map1 = test.swiftyMap(Object.self, 1)
        
        class Object: YObject {
            @Property var value = 0
            required init() { super.init(); self.register(_value, for: "value") }
            convenience init(value: Int) { self.init(); self.value = value }
        }
        Object.registerAuto()
        
        let object0 = Object(value: 10)
        XCTAssertEqual(object0.value, 10)
        
        map0["object"] = object0
        try test.sync()
        
        let object1 = try XCTUnwrap(map1["object"])
        XCTAssertEqual(object1.value, 10) 
        
    }
    
    func testObjectWithArrayPropertyNestedPublisherSync() throws {
        class Inner: YObject {
            @Property var name: String = "Alice"
            required init() { super.init(); self.register(_name, for: "name") }
            convenience init(_ name: String) { self.init(); self.name = name }
        }
        class Object: YObject {
            @WProperty var array = YArray<Inner>()
            required init() { super.init(); self.register(_array, for: "array") }
        }
        Inner.registerAuto()
        Object.registerAuto()
        
        
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Object.self, 0)
        
        let object0 = Object()
        map0["object"] = object0
                
        var result = [[String]]()
        
        object0.array.publisher
            .sink{ result.append($0.map{ $0.name }) }.store(in: &objectBag)
        
        XCTAssertEqual(result, [[]])
        
        object0.array.append(Inner("Alice"))
        
        XCTAssertEqual(result, [[], ["Alice"]])
        
        object0.array.append(Inner("Bob"))
        
        XCTAssertEqual(result, [[], ["Alice"], ["Alice", "Bob"]])
    }
    
    func testObjectWithArrayPropertyNestedPublisherSyncInner() throws {
        class Inner: YObject {
            @Property var name: String = "Alice"
            required init() { super.init(); self.register(_name, for: "name") }
            convenience init(_ name: String) { self.init(); self.name = name }
        }
        class Object: YObject {
            @WProperty var array = YArray<Inner>()
            required init() { super.init(); self.register(_array, for: "array") }
        }
        Inner.registerAuto()
        Object.registerAuto()
        
        
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Object.self, 0)
        
        let object0 = Object()
        map0["object"] = object0
                
        var latest = [String]()
        
        object0.array.publisher.map{ $0.map{ $0.$name }.combineLatestHandleEmpty }.switchToLatest()
            .sink{ latest = $0.map{ $0 } }.store(in: &objectBag)
        
        XCTAssertEqual(latest, [])
        
        do {
            let inner = Inner("Alice")
            object0.array.append(inner)
            
            XCTAssertEqual(latest, ["Alice"])
            inner.name = "Bob"
            XCTAssertEqual(latest, ["Bob"])
        }
        
        do {
            let inner = Inner("Alice")
            object0.array.append(inner)
            
            XCTAssertEqual(latest, ["Bob", "Alice"])
            inner.name = "Bob"
            XCTAssertEqual(latest, ["Bob", "Bob"])
        }
        
        
    }
    
    func testObjectWithArrayPropertyNestedLocal() throws {
        class Inner: YObject {
            @Property var name: String = "Alice"
            
            required init() {
                super.init()
                self.register(_name, for: "name")
            }
            convenience init(_ name: String) {
                self.init()
                self.name = name
            }
        }
        class ObjectWithArray: YObject {
            @WProperty var array = YArray<Inner>()
            
            required init() {
                super.init()
                self.register(_array, for: "array")
            }
        }
        Inner.registerAuto()
        ObjectWithArray.registerAuto()
        
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(ObjectWithArray.self, 0)
        
        let object = ObjectWithArray()
        map0["object"] = object
        
        object.array.append(Inner("Alice"))
        object.array.append(Inner("Bob"))
        
        XCTAssertEqual(object.array.count, 2)
        
        XCTAssertEqual(object.array[0].name, "Alice")
        XCTAssertEqual(object.array[1].name, "Bob")
    }
    
    func testObjectWithArrayPropertyBasic() throws {
        final class ObjectWithArray: YObject {
            @Property var array: [Int] = []
            required init() { super.init(); self.register(_array, for: "array") }
        }
        ObjectWithArray.registerAuto()
        
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(ObjectWithArray.self, 0), map1 = test.swiftyMap(ObjectWithArray.self, 1)
                
        ObjectWithArray.registerAuto()
        
        let object0 = ObjectWithArray()
        map0["object"] = object0
        
        try test.connector.flushAllMessages()
        
        let object1 = try XCTUnwrap(map1["object"])
        
        XCTAssertEqual(object0.array, [])

        object0.array.append(1)
        XCTAssertEqual(object0.array, [1])
        
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(object1.array, [1])
    }
    
    
    func testInitialValueObjectSync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(InitialValue.self, 0), map1 = test.swiftyMap(InitialValue.self, 1)
        
        let object0 = InitialValue()
        map0["object_1"] = object0
        
        XCTAssertEqual(object0.value, "Initial Value")
        
        try test.connector.flushAllMessages()
        
        let object1 = try XCTUnwrap(map1["object_1"])

        XCTAssertEqual(object1.value, "Initial Value")
    }
    
    func testInitialValueObjectOverride() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(InitialValue.self, 0), map1 = test.swiftyMap(InitialValue.self, 1)
        
        let object0 = InitialValue()
        map0["object_2"] = object0
        
        XCTAssertEqual(object0.value, "Initial Value")
        
        object0.value = "Second Value"
        
        try test.connector.flushAllMessages()
        
        let object1 = try XCTUnwrap(map1["object_2"])

        XCTAssertEqual(object1.value, "Second Value")
    }
    
    func testInitialValueLazyProperty() throws {
        
        class Object: YObject {
            static var initializeCount = 0
            @Property var value = {
                Object.initializeCount += 1
                return "Hello World"
            }()
            
            required init() {
                super.init()
                self.register(_value, for: "value")
            }
        }
        Object.registerAuto()
        defer { Object.unregister() }
        
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Object.self, 0), map1 = test.swiftyMap(Object.self, 1)
        
        let object0 = Object()
        map0["object"] = object0
        
        XCTAssertEqual(Object.initializeCount, 1)
        XCTAssertEqual(object0.value, "Hello World")
        
        try test.connector.flushAllMessages()
        
        let object1 = try XCTUnwrap(map1["object"])
        
        XCTAssertEqual(Object.initializeCount, 1)
        XCTAssertEqual(object1.value, "Hello World")
        
        object0.value = "Hello Override"
        
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(Object.initializeCount, 1)
        XCTAssertEqual(object1.value, "Hello Override")
    }
    
    func testInheritedObjectPublisherLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(BaseContainer.self, 0)

        let container = BaseContainer()
        map0["container"] = container

        var baseNames = [String]()
        var sub1Names = [String]()
        var sub2Names = [String]()

        container.$content.compactMap{ $0?.$base }.switchToLatest()
            .sink{ baseNames.append($0) }.store(in: &objectBag)
        container.$content.compactMap{ ($0 as? Sub1)?.$sub1 }.switchToLatest()
            .sink{ sub1Names.append($0) }.store(in: &objectBag)
        container.$content.compactMap{ ($0 as? Sub2)?.$sub2 }.switchToLatest()
            .sink{ sub2Names.append($0) }.store(in: &objectBag)

        let base = Base()
        let sub1 = Sub1()
        let sub2 = Sub2()

        XCTAssertEqual(container.content, nil)

        container.content = base
        XCTAssertEqual(baseNames, ["base"])
        container.content?.base = "base2"
        XCTAssertEqual(baseNames, ["base", "base2"])
        container.content = sub1
        XCTAssertEqual(baseNames, ["base", "base2", "base"])
        XCTAssertEqual(sub1Names, ["sub1"])
        
        container.content = sub2
        XCTAssertEqual(baseNames, ["base", "base2", "base", "base"])
        XCTAssertEqual(sub1Names, ["sub1"])
        XCTAssertEqual(sub2Names, ["sub2"])
    }
    
    func testInheritedObjectSync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(BaseContainer.self, 0), map1 = test.swiftyMap(BaseContainer.self, 1)
        
        let container0 = BaseContainer()
        map0["container"] = container0
        
        try test.connector.flushAllMessages()
        
        let container1 = try XCTUnwrap(map1["container"])
        
        XCTAssertNil(container0.content)
        XCTAssertNil(container1.content)
        
        container0.content = Sub1()
        try test.connector.flushAllMessages()
        XCTAssert(container1.content is Sub1)
        
        container0.content = Sub2()
        try test.connector.flushAllMessages()
        XCTAssert(container1.content is Sub2)
        
    }
    
    func testInheritedObjectLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(BaseContainer.self, 0)
        
        let container = BaseContainer()
        map0["container"] = container
        
        let base = Base()
        let sub1 = Sub1()
        let sub2 = Sub2()
        
        XCTAssertEqual(container.content, nil)
        
        container.content = base
        XCTAssert(container.content === base)
        
        container.content = sub1
        XCTAssert(container.content === sub1)
        
        container.content = sub2
        XCTAssert(container.content === sub2)
    }
    
    func testNestedObjectPropertyLocal() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(PersonPair.self, 0)
        
        let pair = PersonPair()
        let alice0 = Person(name: "Alice", age: 16)
        let bob0 = Person(name: "Bob", age: 24)
        
        map0["pair"] = pair
        
        XCTAssertNil(pair.person0)
        XCTAssertNil(pair.person1)
        
        pair.person0 = alice0
        
        XCTAssertEqual(try XCTUnwrap(pair.person0).name, "Alice")
        XCTAssertEqual(try XCTUnwrap(pair.person0).age, 16)
        
        pair.person1 = bob0
        
        XCTAssertEqual(try XCTUnwrap(pair.person1).name, "Bob")
        XCTAssertEqual(try XCTUnwrap(pair.person1).age, 24)
    }
    
    func testNestedObjectPropertyPublisherLocal() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(PersonPair.self, 0)
        
        let pair = PersonPair()
        map0["pair"] = pair
        
        var receivedNames = [String]()
        pair.$person0.compactMap{ $0?.$name }.switchToLatest()
            .sink{ receivedNames.append($0) }.store(in: &objectBag)
        
        let alice0 = Person(name: "Alice", age: 16)
        let bob0 = Person(name: "Bob", age: 24)

        XCTAssertEqual(receivedNames, [])
        
        pair.person0 = alice0
        
        XCTAssertEqual(receivedNames, ["Alice"])
        
        pair.person0 = bob0
        
        XCTAssertEqual(receivedNames, ["Alice", "Bob"])
    }
    
    func testOptionalPropertyLocal() throws {
        let person = PersonOptional()
        
        XCTAssertEqual(person.name, nil)
        XCTAssertEqual(person.age, nil)
        
        person.name = "Alice"
        
        XCTAssertEqual(person.name, "Alice")
        
        person.age = 16
        
        XCTAssertEqual(person.age, 16)
    }
    
    func testOptionalPropertySync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(PersonOptional.self, 0), map1 = test.swiftyMap(PersonOptional.self, 1)
        
        let person0 = PersonOptional()
        map0["person"] = person0
        
        XCTAssertNil(person0.name)
        XCTAssertNil(person0.age)
        
        person0.name = "Alice"
        XCTAssertEqual(person0.name, "Alice")
        
        try test.connector.flushAllMessages()
        let person1 = try XCTUnwrap(map1["person"])
        
        XCTAssertEqual(person1.name, "Alice")
        XCTAssertNil(person1.age)
    }
    
    func testObjectPropertySync() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0), map1 = test.swiftyMap(Person.self, 1)
        
        let alice0 = Person(name: "Alice", age: 16)
        XCTAssertEqual(alice0.name, "Alice")
        XCTAssertEqual(alice0.age, 16)
        
        map0["person"] = alice0
        XCTAssertEqual(alice0.name, "Alice")
        XCTAssertEqual(alice0.age, 16)
        
        try test.connector.flushAllMessages()
        
        let alice1 = try XCTUnwrap(map1["person"])
        XCTAssertEqual(alice1.name, "Alice")
        XCTAssertEqual(alice1.age, 16)
        
        alice0.name = "Bob"
        alice0.age = 24
        
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(alice1.name, "Bob")
        XCTAssertEqual(alice1.age, 24)
    }
    
    func testObjectPropertySyncPublisherLocal() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Person.self, 0)
        
        let person = Person(name: "Alice", age: 16)
        
        var receivedNames = [String]()
        var receivedAges = [Int]()
        
        person.$name.sink{ receivedNames.append($0) }.store(in: &objectBag)
        person.$age.sink{ receivedAges.append($0) }.store(in: &objectBag)
        
        // published initial value
        XCTAssertEqual(receivedNames, ["Alice"])
        XCTAssertEqual(receivedAges, [16])
        
        map0["person"] = person
        
        // set don't make publish
        XCTAssertEqual(receivedNames, ["Alice"])
        XCTAssertEqual(receivedAges, [16])
        
        // set make publish for specific property
        person.name = "Bob"
        XCTAssertEqual(receivedNames, ["Alice", "Bob"])
        XCTAssertEqual(receivedAges, [16])
        
        // set make publish for specific property
        person.age = 24
        XCTAssertEqual(receivedNames, ["Alice", "Bob"])
        XCTAssertEqual(receivedAges, [16, 24])
    }
    
    func testObjectPropertySyncPublisher() throws {
        let test = try YTest<Any>(docs: 2)
        let map0 = test.swiftyMap(Person.self, 0)
        let map1 = test.swiftyMap(Person.self, 1)

        let person0 = Person(name: "Alice", age: 16)
        
        var received0Names = [String]()
        var received0Ages = [Int]()
        
        person0.$name.sink{ received0Names.append($0) }.store(in: &objectBag)
        person0.$age.sink{ received0Ages.append($0) }.store(in: &objectBag)

        //
        XCTAssertEqual(received0Names, ["Alice"])
        XCTAssertEqual(received0Ages, [16])
        
        map0["person"] = person0
        XCTAssertEqual(received0Names, ["Alice"])
        XCTAssertEqual(received0Ages, [16])
        
        XCTAssertNil(map1["person"])
        
        try test.connector.flushAllMessages()
        
        let person1 = try XCTUnwrap(map1["person"])
        
        var received1Names = [String]()
        var received1Ages = [Int]()
        
        person1.$name.sink{ received1Names.append($0) }.store(in: &objectBag)
        person1.$age.sink{ received1Ages.append($0) }.store(in: &objectBag)
        
        XCTAssertEqual(received0Names, ["Alice"])
        XCTAssertEqual(received0Ages, [16])
        XCTAssertEqual(received1Names, ["Alice"])
        XCTAssertEqual(received1Ages, [16])
        
        person0.name = "Bob"
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(received0Names, ["Alice", "Bob"])
        XCTAssertEqual(received0Ages, [16])
        XCTAssertEqual(received1Names, ["Alice", "Bob"])
        XCTAssertEqual(received1Ages, [16])
        
        person0.age = 24
        try test.connector.flushAllMessages()
        
        XCTAssertEqual(received0Names, ["Alice", "Bob"])
        XCTAssertEqual(received0Ages, [16, 24])
        XCTAssertEqual(received1Names, ["Alice", "Bob"])
        XCTAssertEqual(received1Ages, [16, 24])
    }
    
    
}


extension YObject {
    fileprivate static var count: UInt = 0
    static func registerAuto() {
        self.register(count)
        self.count += 1
    }
}
