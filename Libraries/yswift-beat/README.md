
# yswift

**NOTE:** This version has been modified for (beat) and is NOT the same as ObuchiYuki's original repo. Main differences are some quite serious bug fixes and minor stylization. The (beat) version also includes client class (`YClient`) with dependency-free networking. I'm completely indebted to the work of Yuki, and this library still relies on unmodified `lib0-swift` and `Promise` libraries.

 The original README begins now.

---------

Swift version of [yjs](https://github.com/yjs/yjs). 

[y-uniffi](https://github.com/y-crdt/y-uniffi) is a great yjs Swift implementation though,
I have created a completely Swift reimplementation of yjs, as y-uniffi dose not yet have a nested Map, UndoManager, etc. implementation.

##### Important

Now this library is based on yjs and implemented in Swift for a **personal** use and is not intended to be fully compatible with yjs.    


## Install

```
dependencies: [
    .package(url: "https://github.com/ObuchiYuki/yswift.git", branch: "1.0.0"),
]
```



## Features


-  Supported collaborative types:
  - [x] Text
    - [x] text insertion
    - [x] embedded elements insertion
    - [x] insertion of formatting attributes
    - [x] observe events and deltas
  - [x] Map
    - [x] insertion, update and removal of primitive JSON-like elements
    - [x] recursive insertion, update and removal of other collaborative elements of any type
    - [x] observe events and deltas
    - [x] deep observe events bubbling up from nested collections
  - [x] Array
      - [x] insertion and removal of primitive JSON-like elements
      - [x] recursive insertion of other collaborative elements of any type
      - [x] observe events and deltas
      - [x] deep observe events bubbling up from nested collections
      - [ ] move index positions
  - [ ] XML Types (Intentionally not supported)
  - [x] Sub documents
  - [x] Transaction origin
  - [x] Undo/redo manager
- Encoding formats:
  - [x] lib0 v1 encoding
  - [x] lib0 v2 encoding
- Transaction events:
  - [x] on event update
  - [x] on after transaction
- Tests
  - [x] yjs tests
    - [x] doc.tests
    - [x] encoding.tests
    - [x] snapshot.tests
    - [x] undo-redo.tests
    - [x] udpates.tests
    - [x] y-array.tests
    - [x] y-map.tests
    - [x] y-test.tests
  - [x] yswift tests
    - [x] y-array.swift.tests
    - [x] y-map.swift.tests
    - [x] y-object.swift.tests
    - [x] integration.swift.tests




## Objects

#### `YArray`

Swift implementation of YArray

```swift
final public class YArray<Element: YElement> 
```



##### example

```swift
// init with array literal
let intArray: YArray<Int> = [1, 2] 
print(intArray) // [1, 2]
// index access
print(intArray[1]) // 2

// append Element
intArray.append(3) 
print(intArray) // [1, 2, 3]

// append Sequence
intArray.append(contentsOf: [4, 5]) 
print(intArray) // [1, 2, 3, 4, 5]

// range access
print(intArray[2...]) // [3, 4, 5]

// use as Sequence
for i in intArray { 
    print(i) // 1, 2 ...
}

// YArray with YMap type
let mapArray: YArray<YMap<Int>> = [
    ["Apple": 160]
]

mapArray.append(["Banana": 240])
```



#### `YMap`

Swift implementation of YMap

```swift
final public class YMap<Value: YElement> 
```



##### example

```swift
// init with dictionary literal
let intMap: YMap<Int> = [
    "Apple": 160
] 

// subscript access
intMap["Banana"] = 240
print(intMap["Apple"]) // 160

// nested map
let arrayMap: YMap<YArray<Int>> [
    "Alice": [12, 24],
    "Bob": [24, 64, 75]
]
```



#### `YObject`

Binding to classes based on YMap

```swift
open class YObject: YOpaqueObject
```



##### example

```swift
class Person: YObject {
    // Syncronized property
    @Property var name: String = ""
    // nested proeprty
    @WProperty var children: YArray<Person> = []
    
    required init() {
        super.init()
        self.register(_name, "name")
        self.register(_children, "children")
    }
    
    convenience init(name: String) {
        self.init()
        self.name = name
    }
}

let person = Person(name: "Alice")

// can use as Combine Publisher
person.$name
	.sink{ print("name is \($0)") }.store(in: &bag)

person.$children
	.sink{ print("children is \($0)") }.store(in: &bag)

// update to property to sync
person.name = "Bob"

// update nested type to sync
person.children.append(Person(name: "Bobson"))
```



##### `YRefrence`

Store a reference to an object.

```swift
class Layer: YObject {
    @Property var parent: YReference<Layer>? = nil
    @WProperty var children: YArray<Person> = []
    
    func addChild(_ child: Layer) {
        self.children.append(child)
        // make Reference
        child.parent = YReference(self)
    }
    ...
}

let root = Layer("root")
root.addChild(Layer("child0"))

// copy dosen't change a reference.
let copiedRoot = root.copy()
// fail
assert(copiedRoot.children[0].parent.value === copiedRoot) 

// smart copy changes a reference.
let smartCopiedRoot = root.smartCopy()
// success
assert(smartCopiedRoot.children[0].parent.value === smartCopiedRoot)
```



##### `YElement`

`YElement` is a protocol that is inherited by values that can be `YArray`, `YMap` values, and `YObject` properties.

```swift
public protocol YElement {
    /// Make opaque data concrete.
    static func fromOpaque(_ opaque: Any?) -> Self
    
    /// Make concrete data opaque.
    func toOpaque() -> Any?
}
```



You can use `YCodable` to turn a `Codable` value into a `YElement`, or `YRawRepresentable` to turn an enum into a `YElement`.



```swift
struct Point: YCodable {
    var x: CGFloat
    var y: CGFloat
}

let array = YArray<Point>()
array.append(Point(x: 1, y: 3))

enum LayerKind: String, YRawRepresentable {
    case rect
    case text
    case path
}

let map = YMap<LayerKind>()
map["rect"] = .rect
map["text"] = .text
```



Or you can create a `YElement` by defining your own encoding and decoding.



```swift
enum Delta<T: YElement>: YElement {
    case by(T)
    case to(T)
    
    public func toOpaque() -> Any? { 
        switch self {
        case .by(let value): return ["by": value.toOpaque()]
        case .to(let value): return ["to": value.toOpaque()]
        }
    }
    
    public static func fromOpaque(_ opaque: Any?) -> Self {
        let (key, value) = (opaque as! [String: Any?]).first
        if (key == "by") { return .by(T.fromOpaque(value)) }
        if (key == "to") { return .to(T.fromOpaque(value)) }
        fatalError("Unexpected case.")
    }
}
```















