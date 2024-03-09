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


struct Quote: Codable {
	var id: Int
	var text: String
	var author: String?
	var createdAt: Date
}


func runServer() throws {
#if DEBUG
	let configPath = URL(string: "../../etc/demo.conf", relativeTo: URL(fileURLWithPath: #file))!.path
#else
	let configPath: String = ConfigFile.defaultFile(named: "demo.conf")
#endif

	let globals = try Globals(path: configPath)

	try HTTPServer(globals: globals)

		.get(path: "/version") { _ in
			HTTPResponse(Version())
		}

		.get(path: "/quotes") { handler in
			try await handler.withDBConnection { conn in
				HTTPResponse(try await conn.query(type: Quote.self, "SELECT * FROM quotes", binds: []))
			}
		}

		.get(path: "^/quotes/([0-9]+)$") { handler in
			try await handler.withDBConnection { conn in
				let result = try await conn.query(type: Quote.self, "SELECT * FROM quotes WHERE id = ?", binds: [handler.matchInt64(1)]).first
				guard let result else {
					throw HTTPErrorResponse.notFound()
				}
				return HTTPResponse(result)
			}
		}

		.run()
}


do {
	try runServer()
}
catch {
	Log.error(error.localizedDescription)
	exit(1)
}
