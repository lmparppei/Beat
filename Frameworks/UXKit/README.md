<h2>UXKit
<img src="http://zeezide.com/img/UXKitIcon1024.png"
  align="right" width="128" height="128" />
</h2>

![Swift3](https://img.shields.io/badge/swift-3-blue.svg)
![Swift4](https://img.shields.io/badge/swift-4-blue.svg)
![Swift5](https://img.shields.io/badge/swift-5-blue.svg)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![iOS](https://img.shields.io/badge/os-iOS-green.svg?style=flat)
![Travis](https://travis-ci.org/ZeeZide/UXKit.svg?branch=develop)

There is a rumor that something called *UXKit* exists as part of the Apple
Photos application, enabling the same codebase to run on macOS and iOS.
Though the
[article](https://medium.com/@guilhermerambo/why-uikit-for-macos-is-important-ff4e74a82cf0)
is probably incorrect in that this is an UIKit implementation for macOS:

> UIKit for macOS already exists, and it is called UXKit
> I heard about UXKit when Apple first introduced the new Photos app for macOS.

At [ZeeZide](http://www.zeezide.de/) we are using something along the lines to
build all applications for both, macOS and iOS.
One demo of that are the
[CodeCows](http://zeezide.com/en/products/codecows/index.html)
and
[ASCII Cows](http://zeezide.com/en/products/asciicows/index.html)
applications, which share about 90% of the code, while offering unique system
features on both platforms (e.g. Stickers on iOS and System Services on macOS).

This is not only useful for actual deployment to macOS, but also during
development, as it saves you a lot of the simulator or device testing hassle if
you develop for macOS first. (e.g. you can do CoreBluetooth development on
macOS)

## ZeeZide UXKit

The Apple acquired UXKit is not an official API, and there are good reasons for
this.
UXKit is more of a hack to get stuff running in both environments,
and not a beautiful framework wrapping UIKit and/or AppKit.

This codebase while not small, has very little 'actual' code.
Most stuff is just typealiases, constant aliases, etc.

The idea of this is NOT to provide a full cross platform abstraction.
It is expected that a lot of apps will still carry `#if os(macOS)` like code to
enable/disable specific features.

WORK IN PROGRESS: Still cleaning up the stuff.

## How to do write Cross-Platform Code using UXKit

### View Aliases

Generally instead of using `UIView` or `NSView`, you are using `UXView` in
UXKit. UXKit provides a lot of such aliases to streamline the available classes.

Sometimes different aliases point to the same class in one or the other
framework. For example UIKit has `UILabel` and `UITextField` as distinct
classes, while AppKit uses `NSTextField` for both, readonly and editable
textfields.
In UXKit you should then use the more specific UXKit variant. E.g. on AppKit,
use `UXLabel` for readonly texts and `UXTextField` for editable lines, even
though both alias to `NSTextField`. This way the code will work right on
both platforms.

Note: The far majority of those are really just typealiases and not subclasses.

TODO

### View Identifiers

TODO:
- all views have `identifiers`
  - uses accessibilityIdentifier on UIKit (is that OK?)
- special type in Swift 4

### Target/Action

In UIKit one can attach multiple handlers to a single control action,
and quite often there are multiple options on when the action fires
(e.g. `touchUpInside` etc).
This isn't usually available in AppKit. In AppKit a control usually has
a single target, and usually one action (sometimes a second for double clicks).

When doing a UXKit application, the code needs to constraint itself to using
a single, 'semantic', action.
For example this UIKit code:

```swift
button.addTarget(self, action: #selector(doIt(:_)), for: .touchUpInside)
```

Becomes:

```swift
button.onClick(self, #selector(doIt(:_)))
```

And works on both, UIKit and AppKit.

TODO
- gestures (below)

### Table Views

`UITableView` is incorrectly labeled 'table view' - it really is a
'list view' with support for sections.
The AppKit `NSTableView` is an actual tableview with support for columns
(and also sections).

There are other differences. For example UIKit has a `UITableViewCell` which
is a full implementation of a cell which can be used as-is in the table view.
On AppKit, the corresponding `NSTableCellView` is just a shallow wrapper object
maintaining just outlets to associated labels and such.
To streamline the porting, UXKit adds a `NSTableViewCell` which matches the
`UITableViewCell`.
All of those are properly aliases to the corresponding UX names (i.e.
`UXTableViewCell`).

Another example is that UIKit *requires* the datasource to return an instance
of `UITableViewCell` or a subclass of it.
In AppKit you can return arbitrary views. So avoid doing that when you write
portable code.

Row editing is also different on UIKit and AppKit. For example reordering is
done using drag&drop on AppKit, while UIKit has special builtin support for
that.

TODO
- sectioned list view vs table view vs outline view
- source lists
- integrate the `UXTableViewController` into UXKit
- row indexing is different, it includes sections on AppKit, but not on iOS
  - this also affects things like selectedRow!


### Collection Views

TODO
- VC vs View factory
- items are VCs on AppKit and Views on UIKit
- layouts can be shared

### Layer based views

TODO
- explain the tricky parts
- e.g. how layers transforms are reset in unexpected ways on AppKit

### View Controllers

TODO
- representedObject for UIKit

### Control Values

TODO
- formatters attached to controls
- `objectValue` vs `intValue` etc

### Gestures

TODO

### Alerts

TODO
- on AppKit buttons are selected by index
- on UIKit actions are triggered by individual closures

### Who

**UXKit** is brought to you by
[ZeeZide](http://zeezide.de).
We like feedback, GitHub stars, cool contract work,
presumably any form of praise you can think of.
