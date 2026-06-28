# Promise

A lightweight, thread‑safe Promise/Future implementation written in Swift. Slightly modified for (beat).

Promise focuses on three goals:

- Minimal overhead: a single lock guards state; no dispatch queues or allocs after settlement
- Expressive API: an operator set that mirrors Combine and Swift Concurrency
- Easy interop: bridges for Combine, Swift async/await, Grand Central Dispatch, and URLSession



---



## Features

- Familiar chaining (`map`, `flatMap`, `catch`, `finally`, `timeout`, `wait`, and more)
- Value and error transformation operators
- Racing and zipping helpers such as `merge`, `combine`, `combineAll`
- Swift Concurrency bridges (`promise.value`, detached tasks, `Task.promise`)
- Combine bridges (`promise.publisher()` and `Publisher.firstValue()`)
- GCD helpers for running work on queues or delaying delivery
- URLSession convenience wrappers (`session.fetch`, `session.data`)
- Built‑in debug aids (`print`, `measureInterval`, `breakpointOnError`)
- Optional resolver/rejector objects that raise on deinit if unused
- Fully Sendable on supported platforms
- Requires no external dependencies



---



## Requirements

| Platform | Minimum Version |
| -------- | --------------- |
| iOS      | 12.0            |
| macOS    | 10.15           |
| tvOS     | 12.0            |
| watchOS  | 4.0             |

Swift 6 or later and Xcode 17 are recommended.



---



## Installation

### Swift Package Manager

Add the package URL in Xcode:
```

https://github.com/ObuchiYuki/Promise.git

```
or add it to `dependencies` in `Package.swift`:

```swift
.package(url: "https://github.com/ObuchiYuki/Promise.git", from: "1.0.0")
```

Then declare a target dependency:

```swift
.target(
    name: "YourApp",
    dependencies: ["Promise"]
)
```



------



## Quick start

```swift
// Wrap URLSession into a promise
func loadImage(from url: URL) -> Promise<UIImage, Error> {
    URLSession.shared.data(for: url)
        .map(UIImage.init(data:))
        .tryMap { image -> UIImage in
            guard let image else { throw URLError(.cannotDecodeContentData) }
            return image
        }
}

// Consume with Combine‑style operators
loadImage(from: url)
    .timeout(5)
    .peek { print("loaded image with size \($0.size)") }
    .catch { print("failed:", $0) }

// Or with async/await
let image = try await loadImage(from: url).value
```



------



## Documentation



------



## License

Promise is released under the MIT License.
See the `LICENSE` file for details.

