//
//  TCPClientInboundHandler.swift
//  
//
//  Created by Mathias Gisch on 26.12.20.
//

import Foundation
import NIO

public final class TCPClientChannelHandler: ChannelDuplexHandler {

    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = String
    public typealias OutboundOut = ByteBuffer
    private var numBytes = 0

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
