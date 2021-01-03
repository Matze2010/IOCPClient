//
//  TCPClient.swift
//  
//
//  Created by Mathias Gisch on 26.12.20.
//

import Foundation
import NIO

enum TCPClientError: Error {
    case invalidHost
    case invalidPort
    case ChannelNotWritable
    case ChannelNotAvailable
}

class TCPClient {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var host: String?
    private var port: Int?

    private var channel: Channel?


    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func start() throws {
        guard let host = host else {
            throw TCPClientError.invalidHost
        }
        guard let port = port else {
            throw TCPClientError.invalidPort
        }
        do {
            channel = try bootstrap.connect(host: host, port: port).wait()
            //try channel?.closeFuture.wait()
        } catch let error {
            throw error
        }
    }

    func stop() {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Error shutting down \(error.localizedDescription)")
            exit(0)
        }
        print("Client connection closed")
    }

    @discardableResult
    func sendToServer(data: String) -> EventLoopFuture<Void> {
        guard let channel = self.channel else {
            return group.next().makeFailedFuture(TCPClientError.ChannelNotAvailable)
        }

        if channel.isWritable {
            let buffer = channel.allocator.buffer(string: data + "\r\n")
            return channel.writeAndFlush(buffer)
        }

        return group.next().makeFailedFuture(TCPClientError.ChannelNotWritable)
    }

    private var bootstrap: ClientBootstrap {
        return ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(self)

        }

    }
}

extension TCPClient: ChannelDuplexHandler {

    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = String
    public typealias OutboundOut = ByteBuffer

    public func channelActive(context: ChannelHandlerContext) {
        NotificationCenter.default.post(name: .TCPClientDidConnectToServer, object: nil)

        /// With SIOC-Server it needs an empty line after connecting
        let buffer = context.channel.allocator.buffer(string: "\r\n")
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let byteBuffer = self.unwrapInboundIn(data)
        let string = String(buffer: byteBuffer)

        let command = IOCPMessageAction.parsing(string)
        let message = IOCPMessage(action: command, origin: IOCPOrigin.SIOC)
        MessageDistributor.shared.enqueueMessage(message)
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }

}

extension TCPClient: Equatable {

    static func == (lhs: TCPClient, rhs: TCPClient) -> Bool {
        return (lhs.host == rhs.host) && (lhs.port == rhs.port)
    }
}

extension Notification.Name {
    static let TCPClientDidConnectToServer = Notification.Name(rawValue: "TCPClientDidConnectToServer")
}
