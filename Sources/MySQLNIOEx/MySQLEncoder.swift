//
//  MySQLEncoder.swift
//  MySQLNIOEx
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation


public struct MySQLEncoderResult {
	public fileprivate(set) var names: [String] = []
	public fileprivate(set) var values: [MySQLData] = []

	public var nameList: String { names.joined(separator: ", ") }
	public var paramList: String { names.map { _ in "?" }.joined(separator: ", ") }
	public var assignments: String { names.map { "`\($0)` = ?" }.joined(separator: ", ") }

	public var isEmpty: Bool { names.isEmpty }
}


public class MySQLEncoder {

	public init() { }

	public func encode<T: Encodable>(_ object: T) throws -> MySQLEncoderResult {
		return try EncoderImpl(codingPath: []).encode(object: object)
	}
}


// MARK: - MySQL Encoder Implementation

private class EncoderImpl: Encoder {
	var codingPath: [CodingKey]
	var userInfo: [CodingUserInfoKey: Any] = [:]
	var result: MySQLEncoderResult

	init(codingPath: [CodingKey]) {
		self.codingPath = codingPath
		self.result = MySQLEncoderResult()
	}

	func encode<T: Encodable>(object: T) throws -> MySQLEncoderResult {
		try object.encode(to: self)
		return result
	}

	func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
		KeyedEncodingContainer(KeyedContainer<Key>(impl: self))
	}

	func unkeyedContainer() -> UnkeyedEncodingContainer {
		UnkeyedContainer()
	}

	func singleValueContainer() -> SingleValueEncodingContainer {
		SingleValueContainer(impl: self)
	}

	fileprivate func encodeJSON<T: Encodable>(_ value: T) throws -> MySQLData {
		let data = try JSONEncoder().encodeAsByteBuffer(value, allocator: ByteBufferAllocator())
		return .init(jsonData: data)
	}
}


// MARK: - KeyedEncodingContainer

private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

	var codingPath: [CodingKey] { impl.codingPath }
	var impl: EncoderImpl

	init(impl: EncoderImpl) {
		self.impl = impl
	}

	mutating func encodeNil(forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .null)
	}

	mutating func encode(_ value: Bool, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(bool: value))
	}

	mutating func encode(_ value: String, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(string: value))
	}

	mutating func encode(_ value: Double, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(double: value))
	}

	mutating func encode(_ value: Float, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(float: value))
	}

	mutating func encode(_ value: Int, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: value))
	}

	mutating func encode(_ value: Int8, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: Int16, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: Int32, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: Int64, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: UInt, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: UInt8, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: UInt16, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: UInt32, forKey key: Key) throws {
		impl.result.append(name: key.stringValue, value: .init(int: Int(value)))
	}

	mutating func encode(_ value: UInt64, forKey key: Key) throws {
		throw EncodingError.invalidValue(value, .init(codingPath: codingPath + [key], debugDescription: "Unsigned 64-bit integers are not supported"))
	}

	mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
		var result: MySQLData
		switch value {
			case let date as Date:
				result = .init(date: date)
			case let decimal as Decimal:
				result = .init(decimal: decimal)
			case let data as Data:
				result = .init(data: data)
			case let url as URL:
				result = .init(string: url.absoluteString)
			default:
				// Any other encodable is translated to JSON data
				result = try impl.encodeJSON(value)
		}
		impl.result.append(name: key.stringValue, value: result)
	}


	// MARK: Error creation shortcuts

	mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
		preconditionFailure()
	}

	mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
		preconditionFailure()
	}

	mutating func superEncoder() -> Encoder {
		preconditionFailure()
	}

	mutating func superEncoder(forKey key: Key) -> Encoder {
		preconditionFailure()
	}
}


// MARK: - UnkeyedEncodingContainer

// Always fails as we don't support arrays at the top level

private struct UnkeyedContainer: UnkeyedEncodingContainer {

	var codingPath: [CodingKey] = []
	var count: Int = 0

	private func fail(_ value: Any) -> EncodingError {
		EncodingError.invalidValue(value, .init(codingPath: codingPath, debugDescription: "Array value encoding is not supported"))
	}

	func encodeNil() throws { throw fail(0) }

	func encode<T>(_ value: T) throws where T : Encodable { throw fail(value) }

	mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
		preconditionFailure()
	}

	mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
		preconditionFailure()
	}

	mutating func superEncoder() -> Encoder {
		preconditionFailure()
	}
}


// MARK: - SingleValueEncodingContainer

// Single value encoder is used for property wrappers, such as NullCodable, and nested JSON objects

private struct SingleValueContainer: SingleValueEncodingContainer {

	var codingPath: [CodingKey] { impl.codingPath }
	var impl: EncoderImpl

	init(impl: EncoderImpl) {
		self.impl = impl
	}

	private func setResult(_ data: MySQLData) {
		impl.result.setSingleValue(data)
	}

	func encodeNil() throws { setResult(.null) }

	func encode<T: Encodable>(_ value: T) throws {
		// The specialized encode() methods aren't called for some reason, so we have to do all the work here:
		// TODO: is there a better way to do this?
		switch value {
			case let value as Date: setResult(.init(date: value))
			case let value as Decimal: setResult(.init(decimal: value))
			case let value as Data: setResult(.init(data: value))
			case let value as Bool: setResult(.init(bool: value))
			case let value as String: setResult(.init(string: value))
			case let value as Double: setResult(.init(double: value))
			case let value as Float: setResult(.init(float: value))
			case let value as Int: setResult(.init(int: value))
			case let value as Int8: setResult(.init(int: Int(value)))
			case let value as Int16: setResult(.init(int: Int(value)))
			case let value as Int32: setResult(.init(int: Int(value)))
			case let value as Int64: setResult(.init(int: Int(value)))
			case let value as UInt8: setResult(.init(int: Int(value)))
			case let value as UInt16: setResult(.init(int: Int(value)))
			case let value as UInt32: setResult(.init(int: Int(value)))
			case let value as UInt64:
				throw EncodingError.invalidValue(value, .init(codingPath: codingPath, debugDescription: "Unsigned 64-bit integers are not supported"))
			default:
				setResult(try impl.encodeJSON(value))
		}
	}
}


// MARK: -

private extension MySQLEncoderResult {

	mutating func append(name: String, value: MySQLData) {
		names.append(name)
		values.append(value)
	}

	mutating func setSingleValue(_ value: MySQLData) {
		names = [""]
		values = [value]
	}
}


private extension MySQLData {

	init(jsonData: ByteBuffer) {
		self.init(type: .string, format: .text, buffer: jsonData, isUnsigned: false)
	}

	init(data: Data) {
		var buffer = ByteBufferAllocator().buffer(capacity: data.count)
		buffer.writeBytes(data)
		self.init(type: .blob, format: .binary, buffer: buffer, isUnsigned: false)
	}
}
