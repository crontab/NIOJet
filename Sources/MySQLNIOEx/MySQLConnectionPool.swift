//
//  MySQLConnectionPool.swift
//  MySQLNIOEx
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation
import MySQLNIO
import AsyncKit


//  Based on MySQLKit's MySQLConnectionSource


public struct MySQLConfiguration {
	public let address: () throws -> SocketAddress
	public let username: String
	public let password: String
	public let database: String?
	public let tlsConfiguration: TLSConfiguration?

	public init(hostname: String, port: Int = 3306, username: String, password: String, database: String? = nil, tlsConfiguration: TLSConfiguration? = .makeClientConfiguration()) {
		self.address = {
			try SocketAddress.makeAddressResolvingHost(hostname, port: port)
		}
		self.username = username
		self.database = database
		self.password = password
		self.tlsConfiguration = tlsConfiguration
	}

	public init(unixDomainSocketPath: String, username: String, password: String, database: String? = nil) {
		self.address = {
			try SocketAddress.init(unixDomainSocketPath: unixDomainSocketPath)
		}
		self.username = username
		self.password = password
		self.database = database
		self.tlsConfiguration = nil
	}
}


extension MySQLConnection: ConnectionPoolItem { }


public struct MySQLConnectionSource: ConnectionPoolSource {
	public let configuration: MySQLConfiguration

	public init(configuration: MySQLConfiguration) {
		self.configuration = configuration
	}

	public func makeConnection(logger: Logger, on eventLoop: EventLoop) -> EventLoopFuture<MySQLConnection> {
		let address: SocketAddress
		do {
			address = try configuration.address()
		} catch {
			return eventLoop.makeFailedFuture(error)
		}
		return MySQLConnection.connect(
			to: address,
			username: configuration.username,
			database: configuration.database ?? self.configuration.username,
			password: configuration.password,
			tlsConfiguration: configuration.tlsConfiguration,
			logger: logger,
			on: eventLoop
		)
	}
}
