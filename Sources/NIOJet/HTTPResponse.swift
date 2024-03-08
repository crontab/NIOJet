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
	let status: HTTPResponseStatus
	let mime: String?
	private let object: Encodable?


	public init(status: HTTPResponseStatus = .ok, mime: String? = nil) {
		self.status = status
		self.mime = mime
		self.object = nil
	}


	public init<T: Encodable>(status: HTTPResponseStatus = .ok, _ object: T) {
		self.status = status
		self.mime = "application/json"
		self.object = object
	}


	internal func encode(with allocator: ByteBufferAllocator) throws -> ByteBuffer? {
		try object?.jsonEncode(allocator: allocator)
	}
}


// MARK: - HTTPErrorResponse

public struct HTTPErrorResponse: Error {

	let wrapped: HTTPResponse


	public init(status: HTTPResponseStatus, code: String, message: String? = nil) {
		struct Response: Encodable {
			let code: String
			let message: String?
		}
		wrapped = .init(status: status, Response(code: code, message: message))
	}


	public static func `internal`(code: String = "internal_error", message: String? = nil) -> HTTPErrorResponse {
		Log.error("Internal error, \(message ?? "-")")
		return Self(status: .internalServerError, code: code, message: message)
	}


	public static func notImpl(code: String = "not_implemented", message: String? = nil) -> HTTPErrorResponse {
		Log.error("Internal error, \(message ?? "Feature not implemented yet")")
		return Self(status: .internalServerError, code: code, message: message)
	}


	public static func notFound(message: String? = nil) -> HTTPErrorResponse {
		Self.init(status: .notFound, code: "not_found", message: message)
	}


	public static func badRequest(message: String? = nil) -> HTTPErrorResponse {
		Self.init(status: .badRequest, code: "invalid_found", message: message)
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
