//
//  HTTPServer.swift
//  NIOJet
//
//  Created by Hovik Melikyan on 08.03.24.
//

import Foundation
import NIO


public protocol HTTPServerGlobals {
	var bindAddress: SocketAddress { get }
	var eventLoopGroup: EventLoopGroup { get }

	func shutdown()
}
