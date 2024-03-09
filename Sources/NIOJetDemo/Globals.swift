//
//  Globals.swift
//  NIOJetDemo
//
//  Created by Hovik Melikyan on 08.03.24.
//

import Foundation
import NIO
import NIOJet
import MySQLNIOEx


final class Globals: HTTPServerGlobals {

	// Protocol implementation
	let eventLoopGroup: EventLoopGroup
	let bindAddress: SocketAddress

	// Demo project-sepcific globals
	let dbPool: EventLoopGroupConnectionPool<MySQLConnectionSource>


	init(path: String) throws {
		let file = try ConfigFile(path: path, require: true)

		self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

		if let host = file["main", "bind_host"] {
			self.bindAddress = try SocketAddress.makeAddressResolvingHost(host, port: file["main", "bind_port", 8080])
		}
		else if let sock = file["main", "bind_socket"] {
			self.bindAddress = try SocketAddress(unixDomainSocketPath: file.resolvePath(sock))
		}
		else {
			self.bindAddress = try SocketAddress.makeAddressResolvingHost("localhost", port: 8080)
		}

		// NB: the number of connections per event loop is 1 by default; can be changed below
		let source = MySQLConnectionSource(configuration: file.dbConfig(section: "db_main"))
		self.dbPool = EventLoopGroupConnectionPool(source: source, maxConnectionsPerEventLoop: 1, logger: Log.shared, on: eventLoopGroup)
	}


	func shutdown() {
		dbPool.shutdown()
	}


	static var versionString: String {
		"1.0" + (isDebug ? " (DEBUG)" : "")
	}


	static var isDebug: Bool {
#if DEBUG
		true
#else
		false
#endif
	}
}


private extension ConfigFile {

	func dbConfig(section: String) -> MySQLConfiguration {
		if let dbHost = self[section, "host"] {
			return MySQLConfiguration(
				hostname: dbHost,
				port: self[section, "port", 3306],
				username: self[section, "user", ""],
				password: self[section, "password", ""],
				database: self[section, "database", ""],
				tlsConfiguration: nil)
		}
		else if let dbSocket = self[section, "socket"] {
			return MySQLConfiguration(
				unixDomainSocketPath: self.resolvePath(dbSocket),
				username: self[section, "user", ""],
				password: self[section, "password", ""],
				database: self[section, "database", ""])
		}
		else {
			fatalError("DB configuration is not defined in the config file")
		}
	}
}
