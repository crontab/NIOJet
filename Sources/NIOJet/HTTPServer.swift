//
//  HTTPServer.swift
//  NIOJet
//
//  Created by Hovik Melikyan on 08.03.24.
//

import Foundation
import NIO
import NIOExtras


public protocol HTTPServerGlobals {
	var bindAddress: SocketAddress { get }
	var eventLoopGroup: EventLoopGroup { get }

	func shutdown()
}


public struct HTTPServer<Globals: HTTPServerGlobals> {

	/// Adds a GET route
	@discardableResult
	public mutating func get(path: String, handler: @escaping (_ handler: HTTPHandler<Globals>) async throws -> HTTPResponse) -> Self {
		router.add(method: .GET, path: path, callback: .get(callback: handler))
		return self
	}


	/// Adds a POST route that assumes the request body should contain a JSON object of type `type`
	@discardableResult
	public mutating func post<T: Decodable>(path: String, type: T.Type, callback: @escaping (_ handler: HTTPHandler<Globals>, _ object: T) async throws -> HTTPResponse) -> Self {
		router.add(method: .POST, path: path, callback: .jsonBody(type: type, callback: { try await callback($0, $1 as! T) } ))
		return self
	}


	/// Adds a PUT route that assumes the request body should contain a JSON object of type `type`
	@discardableResult
	public mutating func put<T: Decodable>(path: String, type: T.Type, callback: @escaping (_ handler: HTTPHandler<Globals>, _ object: T) async throws -> HTTPResponse) -> Self {
		router.add(method: .PUT, path: path, callback: .jsonBody(type: type, callback: { try await callback($0, $1 as! T) } ))
		return self
	}


	/// Adds a PATCH route that assumes the request body should contain a JSON object of type `type`
	@discardableResult
	public mutating func patch<T: Decodable>(path: String, type: T.Type, callback: @escaping (_ handler: HTTPHandler<Globals>, _ object: T) async throws -> HTTPResponse) -> Self {
		router.add(method: .PATCH, path: path, callback: .jsonBody(type: type, callback: { try await callback($0, $1 as! T) } ))
		return self
	}


	/// Adds a DELETE route
	@discardableResult
	public mutating func delete(path: String, handler: @escaping (_ handler: HTTPHandler<Globals>) async throws -> HTTPResponse) -> Self {
		router.add(method: .DELETE, path: path, callback: .get(callback: handler))
		return self
	}


	/// Runs the service; should be called after routes are addded. Returns only after a graceful shutdown, i.e. when SIGINT is received.
	public func run() throws {
		let group = globals.eventLoopGroup
		let quiesce = ServerQuiescingHelper(group: group)
		let signalQueue = DispatchQueue(label: "io.NIOJet.signalHandlingQueue")
		let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
		let fullyShutdownPromise: EventLoopPromise<Void> = group.next().makePromise()
		signalSource.setEventHandler {
			signalSource.cancel()
			Log.info("Received signal, initiating shutdown.")
			quiesce.initiateShutdown(promise: fullyShutdownPromise)
		}
		signal(SIGINT, SIG_IGN)
		signalSource.resume()

		let bootstrap = ServerBootstrap(group: group)
			.serverChannelOption(ChannelOptions.backlog, value: 256)
			.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.serverChannelInitializer { channel in
				channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
			}
			.childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
			.childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
			.childChannelInitializer { channel in
				channel.pipeline.configureHTTPServerPipeline().flatMap {
					channel.pipeline.addHandler(HTTPHandler(router: self.router, globals: self.globals))
				}
			}

		do {
			if let path = globals.bindAddress.pathname {
				// Delete the previous socket file
				try? FileManager.default.removeItem(atPath: path)
			}

			// Bind the socket
			let server = try bootstrap.bind(to: globals.bindAddress).wait()

			if let path = globals.bindAddress.pathname {
				// Set the socket file permissions to 777, otherwise Nginx can't open it even if run as root
				try FileManager.default.setAttributes([.posixPermissions: NSNumber(0o777)], ofItemAtPath: path)
			}

			// Wait forever, or until Ctrl-C (SIGINT)
			Log.info("Server is running on \(globals.bindAddress.description), pid=\(getpid())")
			try server.closeFuture.wait()
		}

		catch {
			globals.shutdown()
			try group.syncShutdownGracefully()
			throw ServerError.bindFailed(message: "Bind failed, shutting down the server - \(error.localizedDescription)")
		}

		try fullyShutdownPromise.futureResult.wait()
		globals.shutdown()
		try group.syncShutdownGracefully()
	}


	// MARK: - internal & private

	private var router = HTTPRouter<Globals>()
	private let globals: Globals
}


public enum ServerError: LocalizedError {
	case bindFailed(message: String)
	case config(message: String)

	public var errorDescription: String? {
		switch self {
			case .bindFailed(let message), .config(let message):
				return message
		}
	}
}
