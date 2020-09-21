// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftFSM",
    products: [
        .library(
            name: "SwiftFSM",
            targets: ["SwiftFSM"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftFSM",
            dependencies: []),
        .testTarget(
            name: "SwiftFSMTests",
            dependencies: ["SwiftFSM"]),
    ]
)
