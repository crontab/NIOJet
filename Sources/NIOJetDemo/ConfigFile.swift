//
//  ConfigFile.swift
//  NIOJetDemo
//
//  Created by Hovik Melikyan on 08.03.24.
//

import Foundation
import NIOJet


/// A simplified INI file parser
final class ConfigFile {

	private let baseDir: URL
	private let dict: [String: [String: String]]


	/// Loads a INI-formatted config file at the specified absolute file path. See also `defaultFile(named:)`
	init(path: String, require: Bool) throws {
		self.dict = try Self.parse(contentsOfFile: path, require: require)
		self.baseDir = URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL
	}


	/// Returns an entire section as a dictionary
	subscript(section: String) -> [String: String]? {
		dict[section]
	}


	/// Returns a string value from `section` by `name`.
	subscript(section: String, name: String) -> String? {
		dict[section]?[name]
	}


	/// Returns a string value from `section` by `name` with a specified default if not present.
	subscript(section: String, name: String, default: String) -> String {
		self[section, name] ?? `default`
	}


	/// Returns an int value from `section` by `name` with a specified default if not present.
	subscript(section: String, name: String, default: Int) -> Int {
		self[section, name].flatMap(Int.init) ?? `default`
	}


	/// Returns a boolean value from `section` by `name` with a specified default if not present.
	subscript(section: String, name: String, default: Bool) -> Bool {
		guard let result = self[section, name]?.lowercased() else {
			return `default`
		}
		if Self.trueValues.contains(result) {
			return true
		}
		if Self.falseValues.contains(result) {
			return false
		}
		return `default`
	}


	/// Returns a value as a string array from `section` by `name` with a specified default if not present.
	subscript(section: String, name: String, default: [String]) -> [String] {
		self[section, name]?.split(separator: ",").map { $0.trimmed() } ?? `default`
	}


	/// Returns a value as an int array from `section` by `name` with a specified default if not present.
	subscript(section: String, name: String, default: [Int]) -> [Int] {
		self[section, name]?.split(separator: ",").compactMap { Int($0.trimmed()) } ?? `default`
	}


	/// Resolves a file path relative to this config file's location; returns the full path in case it's absolute.
	func resolvePath(_ path: String) -> String {
		URL(string: path, relativeTo: baseDir)?.path ?? path
	}


	/// Returns a file path for the specified file name, located at `../etc/<name>` relative to the executable path.
	static func defaultFile(named: String) -> String {
		let execPath = ProcessInfo.processInfo.arguments[0] // Swift seems to always return the full path
		precondition(execPath.hasPrefix("/"))
		var comps = execPath.components(separatedBy: "/").dropLast(2) // drop the executable name and its directory, typically `bin`
		if comps.isEmpty { // root directory?
			comps = [""]
		}
		let rootIndex = comps.firstIndex(of: ".build") ?? comps.endIndex // see if we are in Swift's build directory
		let path = comps[0..<rootIndex] + ["etc", named]
		return path.joined(separator: "/")
	}


	// MARK: Private part

	private static func parse(contentsOfFile path: String, require: Bool) throws -> [String: [String: String]] {
		var lines: [Substring]
		do {
			lines = try String(contentsOfFile: path).split(separator: "\n")
		}
		catch {
			if require {
				throw ConfigFileError.couldNotOpen(path: path, error: error)
			}
			else {
				Log.warning("No configuration file loaded")
				lines = []
			}
		}

		var dict: [String: [String: String]] = ["main": [:]]
		var currentSection = "main"

		for i in lines.indices {
			let line = lines[i].trimmed()

			if line.isEmpty || line.hasPrefix("#") {
				continue
			}

			if line.hasPrefix("[") {
				let s = line.dropFirst()
				if !s.hasSuffix("]") {
					throw ConfigFileError.invalidSectionHeader(path: path, lineNumber: i)
				}
				let sectionName = s.dropLast().trimmed()
				if sectionName.isEmpty {
					throw ConfigFileError.invalidSectionHeader(path: path, lineNumber: i)
				}
				if dict[sectionName] == nil {
					dict[sectionName] = [:]
				}
				currentSection = sectionName
				continue
			}

			let a = line.split(separator: "=", maxSplits: 2).map { $0.trimmed() }
			if a.count != 2 || a[0].isEmpty {
				throw ConfigFileError.invalidDefinition(path: path, lineNumber: i)
			}
			dict[currentSection]![a[0]] = a[1]
		}

		return dict
	}


	private static let trueValues = ["true", "yes", "1"]
	private static let falseValues = ["false", "no", "0"]
}



enum ConfigFileError: LocalizedError {
	case couldNotOpen(path: String, error: Error)
	case invalidSectionHeader(path: String, lineNumber: Int)
	case invalidDefinition(path: String, lineNumber: Int)

	public var errorDescription: String? {
		switch self {
			case .couldNotOpen(let path, let error):
				return "Couldn't open \(path) [\(error.localizedDescription)]"
			case .invalidSectionHeader(let path, let lineNumber):
				return "Invalid section header - \(path) line \(lineNumber)"
			case .invalidDefinition(let path, let lineNumber):
				return "Invalid definition - \(path) line \(lineNumber)"
		}
	}
}


private extension Substring {

	func trimmed() -> String {
		trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
	}
}
