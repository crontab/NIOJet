//
//  Database.swift
//  NIOJetDemo
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation
import NIOJet
import MySQLNIOEx


extension HTTPHandler<Globals> {

	// Convenience shortcut for request handlers
	func withDBConnection<Result>(_ closure: @escaping (MySQLConnectionSource.Connection) async throws -> Result) async throws -> Result {
		try await globals.dbPool.withDBConnection(eventLoop: eventLoop, closure)
	}
}
