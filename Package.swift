// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NIOJet",

	products: [
		.library(name: "NIOJet", targets: ["NIOJet"]),
	],

	targets: [
		.target(
			name: "NIOJet"
		),
        .executableTarget(
            name: "NIOJetDemo",
			dependencies: [
				"NIOJet",
			]
		),
    ]
)
