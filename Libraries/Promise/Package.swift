// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Promise",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(name: "Promise", targets: ["Promise"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", .upToNextMajor(from: "1.4.5"))
    ],
    targets: [
        .target(name: "Promise"),
        .testTarget(name: "PromiseTests", dependencies: ["Promise"])
    ]
)
