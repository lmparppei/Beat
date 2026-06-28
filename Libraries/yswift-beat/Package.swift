// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yswift-beat",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(name: "yswift", targets: ["yswift"]),
    ],
    dependencies: [
        .package(url: "../Promise", .upToNextMajor(from: "1.0.14")),
        .package(url: "https://github.com/ObuchiYuki/lib0-swift.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "yswift",
            dependencies: [
                .product(name: "Promise", package: "Promise"),
                .product(name: "lib0", package: "lib0-swift"),
            ]
        ),
        .testTarget(name: "yswiftTests", dependencies: ["yswift"])
    ]
)
