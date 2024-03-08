//
//  HTTPRouter.swift
//  NIOJet
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation
import NIO
import NIOHTTP1


internal struct HTTPRouter<Globals> {

	enum Callback {
		typealias GetCallback = (_ handler: HTTPHandler<Globals>) async throws -> HTTPResponse
		typealias JSONCallback = (_ handler: HTTPHandler<Globals>, _ object: Decodable) async throws -> HTTPResponse

		case get(callback: GetCallback)
		case jsonBody(type: Decodable.Type, callback: JSONCallback)
	}


	typealias RouteMatch = (callback: Callback, groups: [Substring])


	mutating func add(method: HTTPMethod, path: String, callback: Callback) {
		if routes[method] == nil {
			routes[method] = MethodRoutes()
		}

		if path.hasPrefix("/") {
			routes[method]!.addLiteral(path, callback: callback)
		}
		else if path.hasPrefix("^") {
			routes[method]!.addPattern(path, callback: callback)
		}
		else {
			fatalError("Pattern should start with '/' or '^' (\(path))")
		}
	}


	func match(method: HTTPMethod, path: String) throws -> RouteMatch {
		if let methodRoutes = routes[method] {
			if let match = methodRoutes.match(path: path) {
				return match
			}
			throw HTTPErrorResponse(status: .notFound, code: "path_not_found")
		}
		throw HTTPErrorResponse(status: .methodNotAllowed, code: "invalid_method")
	}


	// MARK: - private part

	private var routes: [HTTPMethod: MethodRoutes] = [:]


	private struct MethodRoutes {
		private var literals: [String: Callback] = [:]
		private var patterns: [NSRegularExpression: Callback] = [:]

		mutating func addLiteral(_ path: String, callback: Callback) {
			if literals[path] != nil {
				fatalError("Duplicate literal path (\(path))")
			}
			literals[path] = callback
		}

		mutating func addPattern(_ pattern: String, callback: Callback) {
			do {
				let re = try NSRegularExpression(pathPattern: pattern)
				if patterns[re] != nil {
					fatalError("Duplicate pattern (\(pattern))")
				}
				patterns[re] = callback
			}
			catch {
				fatalError("Regular expression error (\(pattern)): \(error.localizedDescription)")
			}
		}

		func match(path: String) -> RouteMatch? {
			if let callback = literals[path] {
				return RouteMatch(callback: callback, groups: [])
			}
			else {
				// TODO: how can linear search of RE patterns be improved?
				let range = NSRange(location: 0, length: path.count)
				for (pattern, callback) in patterns {
					if let match = pattern.matchPath(path, range: range) {
						return RouteMatch(callback: callback, groups: match)
					}
				}
			}
			return nil
		}
	}
}


extension HTTPMethod: Hashable { }


private extension NSRegularExpression {

	convenience init(pathPattern: String) throws {
		try self.init(pattern: pathPattern, options: .caseInsensitive)
	}

	func matchPath(_ path: String, range: NSRange) -> [Substring]? {
		let match = firstMatch(in: path, options: [.anchored], range: range)
		return match.map { match in
			(0..<match.numberOfRanges).map { index in
				Range(match.range(at: index), in: path).map { path[$0] } ?? ""
			}
		}
	}
}
