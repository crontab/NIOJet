//
//  MySQLDecoder.swift
//  MySQLNIOEx
//
//  Created by Hovik Melikyan on 09.03.24.
//

import Foundation
import NIOFoundationCompat
import MySQLNIO


public struct MySQLDecoder {

	public init() { }

	public func decode<T: Decodable>(_ type: T.Type, from row: MySQLRow) throws -> T {
		return try DecoderImpl(row: row).decode(type: type)
	}
}


// MARK: - MySQL Row Decoder Implementation

private struct DecoderImpl: Decoder {

	let row: MySQLRow

	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey: Any] = [:]

	func decode<T: Decodable>(type: T.Type) throws -> T {
		try T(from: self)
	}

	func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
		KeyedDecodingContainer(try KeyedContainer(impl: self))
	}

	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Array decoding is not supported"))
	}

	func singleValueContainer() throws -> SingleValueDecodingContainer {
		throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Single value decoding is not supported"))
	}
}


// MARK: - KeyedDecodingContainer

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

	var impl: DecoderImpl
	var codingPath: [CodingKey] { impl.codingPath }
	var dict: [String: (def: MySQLProtocol.ColumnDefinition41, data: ByteBuffer?)]
	var allKeys: [Key] { dict.keys.compactMap { Key(stringValue: $0) } }


	init(impl: DecoderImpl) throws {
		self.impl = impl
		self.dict = [:]
		if impl.row.columnDefinitions.count != impl.row.values.count {
			throw notSupported()
		}
		for i in impl.row.columnDefinitions.indices {
			let def = impl.row.columnDefinitions[i]
			dict[def.name] = (def, impl.row.values[i])
		}
	}


	private func getData(forKey key: Key) throws -> MySQLData {
		guard let item = dict[key.stringValue] else {
			throw keyNotFound(key)
		}
		return .init(type: item.def.columnType, format: impl.row.format, buffer: item.data, isUnsigned: item.def.flags.contains(.COLUMN_UNSIGNED))
	}

	@inline(__always)
	private func ensure<T>(key: Key, data: MySQLData, value: T?) throws -> T {
		guard let value else {
			throw typeMismatch(T.self, key: key, data: data)
		}
		return value
	}

	func contains(_ key: Key) -> Bool {
		dict[key.stringValue] != nil
	}

	func decodeNil(forKey key: Key) throws -> Bool {
		let data = try getData(forKey: key)
		return data.type == .null || data.buffer == nil
	}

	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.bool)
	}

	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.string)
	}

	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.double)
	}

	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.float)
	}

	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.int)
	}

	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.int8)
	}

	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.int16)
	}

	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.int32)
	}

	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.int64)
	}

	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.uint)
	}

	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.uint8)
	}

	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.uint16)
	}

	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.uint32)
	}

	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		let data = try getData(forKey: key)
		return try ensure(key: key, data: data, value: data.uint64)
	}

	func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
		let data = try getData(forKey: key)
		if type == Date.self {
			return try ensure(key: key, data: data, value: data.date) as! T
		}
		else if type == Decimal.self {
			return try ensure(key: key, data: data, value: data.decimal) as! T
		}
		else if type == Data.self {
			return try ensure(key: key, data: data, value: data.data) as! T
		}
		else if type == URL.self {
			guard let url = data.string.flatMap({ URL(string: $0) }) else {
				throw typeMismatch(type, key: key, data: data)
			}
			return try ensure(key: key, data: data, value: url) as! T
		}
		else if data.type == .json {
			return try decodeJSON(type, data: data, forKey: key)
		}
		else {
			let newDecoder = SingleValueDecoder(data: data, codingPath: codingPath + [key])
			return try T(from: newDecoder)
		}
	}

	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		throw notSupported(key)
	}

	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		throw notSupported(key)
	}

	func superDecoder() throws -> Decoder {
		throw notSupported()
	}

	func superDecoder(forKey key: Key) throws -> Decoder {
		throw notSupported(key)
	}


	// MARK: Internal (non-protocol) decoding methods

	private func decodeJSON<T: Decodable>(_ type: T.Type, data: MySQLData, forKey key: Key) throws -> T {
		let json = try data.json(as: type, decoder: JSONDecoder())
		return try ensure(key: key, data: data, value: json)
	}


	// MARK: Error creation shortcuts

	private func typeMismatch(_ type: Any.Type, key: Key, data: MySQLData) -> DecodingError {
		DecodingError.typeMismatch(type, .init(
			codingPath: codingPath + [key], debugDescription: "Expected to decode \(type) but found '\(data.description)' instead."
		))
	}

	private func keyNotFound(_ key: Key) -> DecodingError {
		DecodingError.keyNotFound(key, .init(
			codingPath: codingPath + [key], debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
		))
	}

	private func notSupported(_ key: Key) -> DecodingError {
		DecodingError.dataCorrupted(.init(
			codingPath: codingPath + [key], debugDescription: "Decoding for \(key) not supported or data corrupted."
		))
	}

	private func notSupported() -> DecodingError {
		DecodingError.dataCorrupted(.init(
			codingPath: codingPath, debugDescription: "Decoding operation not supported or data corrupted."
		))
	}
}


// MARK: - Single Value (MySQLData) Decoder Implementation

// Single value decoder is here because of property wrappers, such as NullCodable; otherwise we shouldn't ever need it with MySQLRow decoding.

private class SingleValueDecoder: Decoder {

	var codingPath: [CodingKey]
	var userInfo: [CodingUserInfoKey: Any] = [:]
	var data: MySQLData

	init(data: MySQLData, codingPath: [CodingKey]) {
		self.data = data
		self.codingPath = codingPath
	}

	func decode<T: Decodable>(type: T.Type) throws -> T {
		try T(from: self)
	}

	func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
		throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Keyed decoding is not supported"))
	}

	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Array decoding is not supported"))
	}

	func singleValueContainer() throws -> SingleValueDecodingContainer {
		SingleValueContainer(impl: self)
	}
}


private struct SingleValueContainer: SingleValueDecodingContainer {

	var impl: SingleValueDecoder
	var codingPath: [CodingKey] { impl.codingPath }
	var data: MySQLData { impl.data }

	init(impl: SingleValueDecoder) {
		self.impl = impl
	}

	@inline(__always)
	private func ensure<T>(_ value: T?) throws -> T {
		guard let value else {
			throw typeMismatch(T.self, data: data)
		}
		return value
	}

	func decodeNil() -> Bool { data.type == .null || data.buffer == nil }

	func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
		// The specialized decode() methods aren't called for some reason, so we have to do all the work here:
		// TODO: is there a better way to do this?
		if type == Date.self { return try ensure(data.date) as! T }
		else if type == Decimal.self { return try ensure(data.decimal) as! T }
		else if type == Data.self { return try ensure(data.data) as! T }
		else if type == Bool.self { return try ensure(data.bool) as! T }
		else if type == String.self { return try ensure(data.string) as! T }
		else if type == Double.self { return try ensure(data.double) as! T }
		else if type == Float.self { return try ensure(data.float) as! T }
		else if type == Int.self { return try ensure(data.int) as! T }
		else if type == Int8.self { return try ensure(data.int8) as! T }
		else if type == Int16.self { return try ensure(data.int16) as! T }
		else if type == Int32.self { return try ensure(data.int32) as! T }
		else if type == Int64.self { return try ensure(data.int64) as! T }
		else if type == UInt.self { return try ensure(data.uint) as! T }
		else if type == UInt8.self { return try ensure(data.uint8) as! T }
		else if type == UInt16.self { return try ensure(data.uint16) as! T }
		else if type == UInt32.self { return try ensure(data.uint32) as! T }
		else if type == UInt64.self { return try ensure(data.uint64) as! T }
		// JSON special case
		else if data.type == .json {
			return try decodeJSON(type)
		}
		// Unknown type
		else {
			throw notSupported()
		}
	}

	private func decodeJSON<T: Decodable>(_ type: T.Type) throws -> T {
		let json = try data.json(as: type, decoder: JSONDecoder())
		return try ensure(json)
	}

	private func typeMismatch(_ type: Any.Type, data: MySQLData) -> DecodingError {
		DecodingError.typeMismatch(type, .init(
			codingPath: codingPath, debugDescription: "Expected to decode \(type) but found '\(data.description)' instead."
		))
	}

	private func notSupported() -> DecodingError {
		DecodingError.dataCorrupted(.init(
			codingPath: codingPath, debugDescription: "Decoding not supported or data corrupted."
		))
	}
}


// MARK: -

private extension MySQLData {

	func json<Value>(as type: Value.Type, decoder: JSONDecoder) throws -> Value? where Value: Decodable {
		guard self.type == .json else {
			return nil
		}
		guard let buffer else {
			return nil
		}
		return try decoder.decode(Value.self, from: buffer)
	}

	var data: Data? {
		guard [.blob, .longBlob, .mediumBlob, .tinyBlob].contains(self.type) else {
			return nil
		}
		return buffer.flatMap { $0.getData(at: $0.readerIndex, length: $0.readableBytes) }
	}
}
