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
}

class TCPClient {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var host: String?
    private var port: Int?
    private let tcpChannelHandler = TCPClientChannelHandler()

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

    func sendToServer(data: String) {
        guard let channel = self.channel else {
            return
        }

        if channel.isWritable {
            let buffer = channel.allocator.buffer(string: data + "\r\n")
            let _ = channel.writeAndFlush(buffer)
        }
    }

    private var bootstrap: ClientBootstrap {
        return ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(self.tcpChannelHandler)

        }

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
