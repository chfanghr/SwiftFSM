// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftFSM",
	products: [
			.library(name: "SwiftFSM", targets: ["SwiftFSM"]),
	],
	dependencies: [],
	targets: [
			.target(name: "SwiftFSM"),
			.target(name: "ExampleUtilities", path: "Sources/Examples/Utilities"),
			.target(name: "simple", dependencies: ["SwiftFSM", "ExampleUtilities"], path: "Sources/Examples/simple"),
			.target(name: "async", dependencies: ["SwiftFSM", "ExampleUtilities"], path: "Sources/Examples/async"),
			.target(name: "structure", dependencies: ["SwiftFSM", "ExampleUtilities"], path: "Sources/Examples/structure"),
			.testTarget(name: "SwiftFSMTests", dependencies: ["SwiftFSM"]),
	]
)
