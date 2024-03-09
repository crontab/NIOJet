//
//  MySQLEx.swift
//  MySQLNIOEx
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation
import MySQLNIO


public extension MySQLConnection {


	// MARK: MySQLRow-based methods

	func query(_ sql: String, binds: [Any?]) async throws -> [MySQLRow] {
		try await query(sql, binds.map { MySQLData.from(value: $0) }).get()
	}


	func firstValue(_ sql: String, binds: [Any?]) async throws -> MySQLData? {
		try await query(sql, binds: binds).first?.value(at: 0)
	}


	func queryNoResult(_ sql: String, binds: [Any?]) async throws -> Void {
		_ = try await query(sql, binds: binds)
	}


	func insert(_ sql: String, binds: [Any?]) async throws -> Int {
		var lastInsertId: Int = 0
		_ = try await query(sql, binds.map { MySQLData.from(value: $0) }) { meta in
			lastInsertId = meta.lastInsertID.map { Int($0) } ?? 0
		}.get()
		return lastInsertId
	}


	func update(_ sql: String, binds: [Any?]) async throws -> Int {
		var affectedRows: Int = 0
		_ = try await query(sql, binds.map { MySQLData.from(value: $0) }) { meta in
			affectedRows = Int(meta.affectedRows)
		}.get()
		return affectedRows
	}


	func simpleQuery(_ sql: String) async throws -> Void {
		_ = try await simpleQuery(sql).get()
	}


	// MARK: Transaction

	func transaction<T>(_ closure: @escaping () async throws -> T) async throws -> T {
		try await simpleQuery("START TRANSACTION")
		do {
			let result = try await closure()
			try await simpleQuery("COMMIT")
			return result
		}
		catch {
			try await simpleQuery("ROLLBACK")
			throw error
		}
	}
}


// MARK: - Private extensions

private extension MySQLData {

	static func from(value: Any?) -> Self {
		switch value {
			case let value as MySQLData: 
				value
			case let value as String:
				.init(string: value)
			case let value as Substring:
				.init(string: String(value))
			case let value as Int: 
				.init(int: value)
			case let value as Int64:
				.init(int: Int(value))
			case let value as Bool:
				.init(bool: value)
			case let value as Double:
				.init(double: value)
			case let value as Decimal:
				.init(decimal: value)
			case let value as Date:
				.init(date: value)
			case let value as Encodable:
				(try? .init(json: value)) ?? .init(type: .null, buffer: nil)
			default:
				.null
		}
	}
}


private extension MySQLRow {

	func value(at i: Int) -> MySQLData? {
		guard values.indices.contains(i), columnDefinitions.indices.contains(i) else {
			return nil
		}
		let column = columnDefinitions[i]
		return MySQLData(type: column.columnType, format: format, buffer: values[i], isUnsigned: column.flags.contains(.COLUMN_UNSIGNED))
	}
}
