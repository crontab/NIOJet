// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NIOJet",

	products: [
		.library(name: "NIOJet", targets: ["NIOJet"]),
	],

	dependencies: [
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.64.0"),
//		.package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.11.0"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
	],

	targets: [
		.target(
			name: "NIOJet",
			dependencies: [
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "Logging", package: "swift-log"),
			]
		),
        .executableTarget(
            name: "NIOJetDemo",
			dependencies: [
				"NIOJet",
			]
		),
    ]
)
