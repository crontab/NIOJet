//
//  HTTPHandler.swift
//  NIOJet
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation
import NIO
import NIOHTTP1


public final class HTTPHandler<Globals>: ChannelInboundHandler {

	public let globals: Globals
	public var eventLoop: EventLoop { context.eventLoop }

	public private(set) var requestHead: HTTPRequestHead?
	public private(set) var requestData: ByteBuffer?
	public private(set) var requestPath: String = "" // URI, path only

	// Utilities
	public func queryItem(_ key: String) -> String { queryItems[key] ?? "" }
	public func queryItem(_ key: String, `default`: Int) -> Int { queryItems[key].flatMap { Int($0) } ?? `default` }

	public func match(_ i: Int) -> Substring { matchGroups.indices.contains(i) ? matchGroups[i] : "" } // regex match groups in the URI
	public func matchInt64(_ i: Int) -> Int64 { Int64(match(i)) ?? 0 }

	public func requestHeader(_ name: String) -> String? { requestHead?.headers.first(name: name) }


	// MARK: - internal & private

	public typealias InboundIn = HTTPServerRequestPart
	public typealias OutboundOut = HTTPServerResponsePart

	private var context: ChannelHandlerContext! // kind of guaranteed
	private let router: HTTPRouter<Globals>
	private lazy var queryItems: [String: String] = [:]
	private var matchGroups: [Substring] = []
	private var responseHTTPVersion: HTTPVersion { requestHead?.version ?? .init(major: 1, minor: 1) }
	private var headersSent: Bool = false
	private var callback: HTTPRouter<Globals>.Callback?
	private var routerError: Error? = nil


	init(router: HTTPRouter<Globals>, globals: Globals) {
		self.router = router
		self.globals = globals
	}


	public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		
		self.context = context

		switch unwrapInboundIn(data) {

			// MARK: HEAD
			case .head(let head):
				requestHead = nil
				requestData = nil
				requestPath = ""
				headersSent = false
				callback = nil
				queryItems = [:]
				matchGroups = []
				routerError = nil

				let contentLength = head.headers["content-length"].first.flatMap(Int.init) ?? 0

				// TODO: the limit should come from the config
				if contentLength > 1_000_000 {
					context.close(promise: nil)
					return
				}

				requestHead = head
				requestData = contentLength > 0 ? context.channel.allocator.buffer(capacity: contentLength) : nil
				queryItems = requestHead?.uri.uriQueryItems ?? [:]

				do {
					let path = head.uri.uriPath ?? "/"
					(callback, matchGroups) = try router.match(method: head.method, path: path)
					requestPath = path
				}
				catch {
					routerError = error
				}


			// MARK: BODY
			case .body(var data):
				requestData?.writeBuffer(&data)


			// MARK: END
			case .end:
				guard let requestHead else {
					context.close(promise: nil)
					return
				}

				// This is where our async world enters the future world (or the other way around?)
				let future = context.eventLoop.makeFutureWithTask { [self] in
					try await route()
				}
				future.whenSuccess { [self] response in
					emit(response)
				}
				future.whenFailure { [self] error in
					let error = error as? ErrorResponse ?? .internal(message: error.localizedDescription)
					emit(HTTPResponse(error: error))
				}
				future.whenComplete { _ in
					if !requestHead.isKeepAlive {
						context.close(promise: nil)
					}
				}
		}
	}


	private func route() async throws -> HTTPResponse {
		// Either `callback` or `routerError` should be defined at this point
		if let routerError {
			throw routerError
		}
		guard let callback else {
			preconditionFailure()
		}

		switch callback {

			case .get(callback: let callback):
				return HTTPResponse(object: try await callback(self))

			case .jsonBody(type: let type, callback: let callback):
				guard let requestData else {
					throw ErrorResponse.badRequest(message: "Invalid request body: \(String(describing: type)) expected")
				}

				let object: Decodable
				do {
					object = try type.jsonDecode(from: requestData)
				}

				// JSON decoding error:
				catch let error as DecodingError {
					var descr: String
					switch error {
#if DEBUG
						case DecodingError.dataCorrupted(let context), DecodingError.keyNotFound(_, let context), DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context):
							descr = "\(context.debugDescription) \(context.codingPath.map { $0.stringValue })"
#endif
						default:
							descr = error.localizedDescription
					}
					throw ErrorResponse.badRequest(message: "JSON error: \(descr)")
				}

				return HTTPResponse(object: try await callback(self, object))
		}
	}


	private func emit(_ response: HTTPResponse, ignoreExceptions: Bool = false) {
		guard let context else { preconditionFailure() }

		guard !headersSent else {
			Log.warning("Headers already sent")
			return
		}

		do {
			let buffer = try response.encode(with: context.channel.allocator)

			var head = HTTPResponseHead(version: responseHTTPVersion, status: .init(statusCode: response.status))
			head.headers.replaceOrAdd(name: "content-length", value: String(buffer?.writerIndex ?? 0))
			response.mime.map {
				head.headers.replaceOrAdd(name: "content-type", value: $0)
			}

			headersSent = true

			context.write(wrapOutboundOut(.head(head)), promise: nil)
			buffer.map {
				context.write(wrapOutboundOut(.body(IOData.byteBuffer($0))), promise: nil)
			}
			context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
		}
		catch {
			if ignoreExceptions { // repeated error, likely JSON encoding one
				context.close(promise: nil)
			}
			else {
				emit(HTTPResponse(error: .internal(message: error.localizedDescription)), ignoreExceptions: true)
			}
		}
	}
}


private extension Decodable {

	static func jsonDecode(from: ByteBuffer, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601) throws -> Self {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = dateDecodingStrategy
		return try decoder.decode(self, from: from)
	}
}



private extension String {

	var uriPath: String? {
		URLComponents(string: self)?.path
	}

	var uriQueryItems: [String: String]? {
		URLComponents(string: self)?.queryItems?.reduce(into: [String: String]()) {
			$0[$1.name] = $1.value
		}
	}
}
