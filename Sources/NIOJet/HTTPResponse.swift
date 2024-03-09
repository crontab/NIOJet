//
//  HTTPResponse.swift
//  NIOJet
//
//  Created by Hovik Melikyan on 08.03.24.
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat


// MARK: - HTTPResponse

public struct HTTPResponse {
	let status: Int
	let mime: String?
	private let object: Encodable?


	public init(status: Int = 200, mime: String? = nil) {
		self.status = status
		self.mime = mime
		self.object = nil
	}


	public init<T: Encodable>(status: Int = 200, object: T?) {
		self.status = status
		self.mime = "application/json"
		self.object = object
	}


	public init(error: ErrorResponse) {
		self.init(status: error.status, object: error)
	}


	func encode(with allocator: ByteBufferAllocator) throws -> ByteBuffer? {
		try object?.jsonEncode(allocator: allocator)
	}
}


// MARK: - ErrorResponse

public struct ErrorResponse: Encodable, LocalizedError {
	public let status: Int
	public let code: String
	public let message: String?


	public var errorDescription: String? {
		"\(message ?? "Error") (\(status) \(code))"
	}


	// Frequently used responses:

	public static func badRequest(message: String? = nil) -> ErrorResponse {
		Self.init(status: 400, code: "invalid_request", message: message)
	}


	public static func unauthorized(message: String? = nil) -> ErrorResponse {
		Self.init(status: 401, code: "unauthorized", message: message)
	}


	public static func forbidden(message: String? = nil) -> ErrorResponse {
		Self.init(status: 403, code: "forbidden", message: message)
	}


	public static func notFound(message: String? = nil) -> ErrorResponse {
		Self.init(status: 404, code: "not_found", message: message)
	}


	public static func methodNotAllowed(message: String? = nil) -> ErrorResponse {
		Self.init(status: 405, code: "invalid_method", message: message)
	}


	public static func conflict(message: String? = nil) -> ErrorResponse {
		Self.init(status: 409, code: "conflict", message: message)
	}


	public static func `internal`(message: String? = nil) -> ErrorResponse {
		Log.error("Internal error, \(message ?? "-")")
		return Self(status: 500, code: "internal_error", message: message)
	}


	public static func notImpl(message: String? = nil) -> ErrorResponse {
		Log.error("Not implemented, \(message ?? "-")")
		return Self(status: 501, code: "not_implemented", message: message ?? "Feature not implemented yet")
	}
}


public extension Encodable {

	func jsonEncode(allocator: ByteBufferAllocator? = nil, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601) throws -> ByteBuffer {
		let allocator = allocator ?? ByteBufferAllocator()
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = dateEncodingStrategy
#if DEBUG
		encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
#else
		encoder.outputFormatting = [.withoutEscapingSlashes]
#endif
		var buffer = try encoder.encodeAsByteBuffer(self, allocator: allocator)
#if DEBUG
		buffer.writeString("\n")
#endif
		return buffer
	}
}
