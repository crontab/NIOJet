//
//  Logger.swift
//  NIOJet
//
//  Created by Hovik Melikyan on 25/04/2022.
//

import Foundation
import Logging


public class Log {

	public static var shared: Logger = {
		var logger = Logger(label: "[niojet]")
#if DEBUG
		logger.logLevel = .debug
#endif
		return logger
	}()

	public static func info(_ message: String) {
		shared.info(Logger.Message(stringLiteral: message))
	}

	public static func warning(_ message: String) {
		shared.warning(Logger.Message(stringLiteral: message))
	}

	public static func error(_ message: String) {
		shared.error(Logger.Message(stringLiteral: message))
	}
}
