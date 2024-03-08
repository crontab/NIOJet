//
//  main.swift
//  NIOJetDemo
//
//  Created by Hovik Melikyan on 08.03.24.
//

import Foundation
import NIOJet


struct Version: Encodable {
	let version = Globals.versionString
}


func runServer() throws {
#if DEBUG
	let configPath = URL(string: "../../etc/demo.conf", relativeTo: URL(fileURLWithPath: #file))!.path
#else
	let configPath: String = ConfigFile.defaultFile(named: "demo.conf")
#endif

	let globals = try Globals(path: configPath)
	Log.info(globals.bindAddress.description)
}


do {
	try runServer()
}
catch {
	Log.error(error.localizedDescription)
	exit(1)
}
