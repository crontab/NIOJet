//
//  Globals.swift
//  NIOJetDemo
//
//  Created by Hovik Melikyan on 30/04/2022.
//

import Foundation
import NIO
import NIOJet


final class Globals: HTTPServerGlobals {

	// Protocol implementation
	let eventLoopGroup: EventLoopGroup
	let bindAddress: SocketAddress


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
	}


	func shutdown() {
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
