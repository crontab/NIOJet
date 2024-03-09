// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NIOJet",

	platforms: [
		.macOS(.v10_15)
	],

	products: [
		.library(name: "NIOJet", targets: ["NIOJet"]),
		.library(name: "MySQLNIOEx", targets: ["MySQLNIOEx"]),
	],

	dependencies: [
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.64.0"),
		.package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.22.0"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
		.package(url: "https://github.com/vapor/async-kit.git", from: "1.19.0"),
		.package(url: "https://github.com/vapor/mysql-nio.git", from: "1.7.1"),
	],

	targets: [
		.target(
			name: "NIOJet",
			dependencies: [
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "NIOHTTP1", package: "swift-nio"),
				.product(name: "NIOFoundationCompat", package: "swift-nio"),
				.product(name: "NIOExtras", package: "swift-nio-extras"),
				.product(name: "Logging", package: "swift-log"),
			]
		),

		.target(
			name: "MySQLNIOEx",
			dependencies: [
				.product(name: "MySQLNIO", package: "mysql-nio"),
				.product(name: "NIOFoundationCompat", package: "swift-nio"),
				.product(name: "AsyncKit", package: "async-kit"),
			]
		),

		.executableTarget(
            name: "NIOJetDemo",
			dependencies: [
				"NIOJet",
			],
			exclude: ["demo-init.sql"]
		),
    ]
)
