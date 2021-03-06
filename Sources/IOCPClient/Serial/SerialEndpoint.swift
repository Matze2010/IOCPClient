//
//  File.swift
//  
//
//  Created by Mathias Gisch on 26.12.20.
//

import Foundation
import NIO


public enum SerialError: Int32, Error {
    case failedToOpen = -1 // refer to open()
    case invalidPath
    case mustReceiveOrTransmit
    case mustBeOpen
    case stringsMustBeUTF8
    case unableToConvertByteToCharacter
    case deviceNotConnected
    case ChannelNotWritable
    case ChannelNotAvailable
}


class SerialEndpoint: ChannelInboundHandler {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = String
    public typealias OutboundOut = ByteBuffer

    private var buffer = CircularBuffer<UInt8>()

    private var registeredPositionNames = Set<IOCPPositionName>()

    let path: String
    let connectionLabel: String
    var fileDescriptor: Int32?
    var channel: Channel?

    public init(path: String, label: String) {
        self.path = path
        self.connectionLabel = label

        NotificationCenter.default.addObserver(self, selector: #selector(TCPconnected), name: .TCPClientDidConnectToServer, object: nil)
    }

    public func openPort() throws {
        try openPort(toReceive: true, andTransmit: true)
    }

    public func openPort(toReceive receive: Bool, andTransmit transmit: Bool) throws {
        guard !path.isEmpty else {
            throw SerialError.invalidPath
        }

        guard receive || transmit else {
            throw SerialError.mustReceiveOrTransmit
        }

        var readWriteParam : Int32

        if receive && transmit {
            readWriteParam = O_RDWR
        } else if receive {
            readWriteParam = O_RDONLY
        } else if transmit {
            readWriteParam = O_WRONLY
        } else {
            fatalError()
        }

    #if os(Linux)
        fileDescriptor = open(path, readWriteParam | O_NOCTTY)
    #elseif os(OSX)
        fileDescriptor = open(path, readWriteParam | O_NOCTTY | O_EXLOCK)
    #endif

        // Throw error if open() failed
        if fileDescriptor == SerialError.failedToOpen.rawValue {
            throw SerialError.failedToOpen
        }

        do {
            self.channel = try bootstrap.withInputOutputDescriptor(fileDescriptor!).wait()
        } catch let error {
            throw error
        }
        
    }

    public func setSettings(receiveRate: BaudRate,
                            transmitRate: BaudRate,
                            minimumBytesToRead: Int,
                            timeout: Int = 0, /* 0 means wait indefinitely */
                            parityType: ParityType = .none,
                            sendTwoStopBits: Bool = false, /* 1 stop bit is the default */
                            dataBitsSize: DataBitsSize = .bits8,
                            useHardwareFlowControl: Bool = false,
                            useSoftwareFlowControl: Bool = false,
                            processOutput: Bool = false) {

        guard let fileDescriptor = fileDescriptor else {
            return
        }


        // Set up the control structure
        var settings = termios()

        // Get options structure for the port
        tcgetattr(fileDescriptor, &settings)

        // Set baud rates
        cfsetispeed(&settings, receiveRate.speedValue)
        cfsetospeed(&settings, transmitRate.speedValue)

        // Enable parity (even/odd) if needed
        settings.c_cflag |= parityType.parityValue

        // Set stop bit flag
        if sendTwoStopBits {
            settings.c_cflag |= tcflag_t(CSTOPB)
        } else {
            settings.c_cflag &= ~tcflag_t(CSTOPB)
        }

        // Set data bits size flag
        settings.c_cflag &= ~tcflag_t(CSIZE)
        settings.c_cflag |= dataBitsSize.flagValue

        //Disable input mapping of CR to NL, mapping of NL into CR, and ignoring CR
        settings.c_iflag &= ~tcflag_t(ICRNL | INLCR | IGNCR)

        // Set hardware flow control flag
    #if os(Linux)
        if useHardwareFlowControl {
            settings.c_cflag |= tcflag_t(CRTSCTS)
        } else {
            settings.c_cflag &= ~tcflag_t(CRTSCTS)
        }
    #elseif os(OSX)
        if useHardwareFlowControl {
            settings.c_cflag |= tcflag_t(CRTS_IFLOW)
            settings.c_cflag |= tcflag_t(CCTS_OFLOW)
        } else {
            settings.c_cflag &= ~tcflag_t(CRTS_IFLOW)
            settings.c_cflag &= ~tcflag_t(CCTS_OFLOW)
        }
    #endif

        // Set software flow control flags
        let softwareFlowControlFlags = tcflag_t(IXON | IXOFF | IXANY)
        if useSoftwareFlowControl {
            settings.c_iflag |= softwareFlowControlFlags
        } else {
            settings.c_iflag &= ~softwareFlowControlFlags
        }

        // Turn on the receiver of the serial port, and ignore modem control lines
        settings.c_cflag |= tcflag_t(CREAD | CLOCAL)

        // Turn off canonical mode
        settings.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)

        // Set output processing flag
        if processOutput {
            settings.c_oflag |= tcflag_t(OPOST)
        } else {
            settings.c_oflag &= ~tcflag_t(OPOST)
        }

        //Special characters
        //We do this as c_cc is a C-fixed array which is imported as a tuple in Swift.
        //To avoid hardcoding the VMIN or VTIME value to access the tuple value, we use the typealias instead
    #if os(Linux)
        typealias specialCharactersTuple = (VINTR: cc_t, VQUIT: cc_t, VERASE: cc_t, VKILL: cc_t, VEOF: cc_t, VTIME: cc_t, VMIN: cc_t, VSWTC: cc_t, VSTART: cc_t, VSTOP: cc_t, VSUSP: cc_t, VEOL: cc_t, VREPRINT: cc_t, VDISCARD: cc_t, VWERASE: cc_t, VLNEXT: cc_t, VEOL2: cc_t, spare1: cc_t, spare2: cc_t, spare3: cc_t, spare4: cc_t, spare5: cc_t, spare6: cc_t, spare7: cc_t, spare8: cc_t, spare9: cc_t, spare10: cc_t, spare11: cc_t, spare12: cc_t, spare13: cc_t, spare14: cc_t, spare15: cc_t)
        var specialCharacters: specialCharactersTuple = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) // NCCS = 32
    #elseif os(OSX)
        typealias specialCharactersTuple = (VEOF: cc_t, VEOL: cc_t, VEOL2: cc_t, VERASE: cc_t, VWERASE: cc_t, VKILL: cc_t, VREPRINT: cc_t, spare1: cc_t, VINTR: cc_t, VQUIT: cc_t, VSUSP: cc_t, VDSUSP: cc_t, VSTART: cc_t, VSTOP: cc_t, VLNEXT: cc_t, VDISCARD: cc_t, VMIN: cc_t, VTIME: cc_t, VSTATUS: cc_t, spare: cc_t)
        var specialCharacters: specialCharactersTuple = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) // NCCS = 20
    #endif

        specialCharacters.VMIN = cc_t(minimumBytesToRead)
        specialCharacters.VTIME = cc_t(timeout)
        settings.c_cc = specialCharacters

        // Commit settings
        tcsetattr(fileDescriptor, TCSANOW, &settings)
    }

    private var bootstrap: NIOPipeBootstrap {
        return NIOPipeBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandler(self)
            }
    }

    internal func processSerialReadInput(_ data: String) {

        let action = IOCPMessageAction.parsing(data)
        let message = IOCPMessage(action: action, origin: .Serial(self))

        switch action {
        case .Registration(let newPositions):
            self.registeredPositionNames.formUnion(newPositions)
            MessageDistributor.shared.enqueueMessage(message)

        case .Update(_):
            MessageDistributor.shared.enqueueMessage(message)

        case .Exit, .KeepAlive, .Invalid, .Unknown:
            break;

        }
        //NSLog("\(command)")
    }

    @discardableResult
    public func handleIncomingAction(_ action: IOCPMessageAction) -> EventLoopFuture<Void>? {

        switch action {

        case .Update(let updatedPositions):
            let validPositions = updatedPositions.filter({ return self.registeredPositionNames.contains($0.name) })
            if validPositions.count > 0 {
                let cleanAction = IOCPMessageAction.Update(validPositions)
                return self.forwardActionToDevice(cleanAction)
            }

        case .Registration(_):
            break

        case .KeepAlive:
            return forwardActionToDevice(action)

        case .Exit:
            break

        case .Invalid:
            break

        case .Unknown:
            break
        }

        return nil
    }

    @discardableResult
    internal func forwardActionToDevice(_ action: IOCPMessageAction) -> EventLoopFuture<Void> {

        guard let channel = self.channel else {
            return group.next().makeFailedFuture(SerialError.ChannelNotAvailable)
        }

        if channel.isWritable {
            let buffer = channel.allocator.buffer(string: String(describing: action) + "\r\n")
            return channel.writeAndFlush(buffer)
        }

        return group.next().makeFailedFuture(SerialError.ChannelNotWritable)
    }

    public func channelActive(context: ChannelHandlerContext) {
        print("Client connected to \(context) (\(self.connectionLabel))")
        self.forwardActionToDevice(IOCPMessageAction.KeepAlive)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var readableBytes = self.unwrapInboundIn(data)
        if let keepBytes = readableBytes.readBytes(length: readableBytes.writerIndex-readableBytes.readerIndex) {
            self.buffer.append(contentsOf: keepBytes)
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        while let rawAction = self.buffer.removeUntilNextNewline() {
            self.processSerialReadInput(rawAction)
        }

    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }

    @objc func TCPconnected() {
        self.handleIncomingAction(IOCPMessageAction.KeepAlive)
    }
    
}

extension SerialEndpoint: Hashable {

    static func == (lhs: SerialEndpoint, rhs: SerialEndpoint) -> Bool {
        return (lhs.connectionLabel == rhs.connectionLabel)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.connectionLabel)
    }
}

extension CircularBuffer where Element == UInt8 {

    public mutating func removeUntilNextNewline() -> String? {

        var result: String?

        var extractIndex: CircularBuffer<Element>.Index?
        let startIndex = self.startIndex
        let endIndex = self.endIndex
        var currentIndex = startIndex

        if (self.startIndex >= self.endIndex) {
            return nil
        }

        precondition(self.startIndex < self.endIndex, "Invalid bounds.")

        while currentIndex < self.index(before: endIndex) {
            let advancedIndex = self.index(after: currentIndex)
            let firstByte = self[currentIndex]
            let secondByte = self[advancedIndex]

            if (firstByte == 0x0D && secondByte == 0x0A) {
                extractIndex = advancedIndex
                break;
            }
            currentIndex = self.index(after: currentIndex)
        }

        if let extractIndex = extractIndex {

            let extractionRange = self.startIndex..<self.index(before: extractIndex)
            let removeRange = self.startIndex..<self.index(after: extractIndex)

            let data = ByteBuffer(bytes: self[extractionRange])
            result =  String(buffer: data)

            self.removeSubrange(removeRange)
        }

        return result

    }

}

#if os(Linux)
public enum BaudRate {
    case baud0
    case baud50
    case baud75
    case baud110
    case baud134
    case baud150
    case baud200
    case baud300
    case baud600
    case baud1200
    case baud1800
    case baud2400
    case baud4800
    case baud9600
    case baud19200
    case baud38400
    case baud57600
    case baud115200
    case baud230400
    case baud460800
    case baud500000
    case baud576000
    case baud921600
    case baud1000000
    case baud1152000
    case baud1500000
    case baud2000000
    case baud2500000
    case baud3500000
    case baud4000000

    var speedValue: speed_t {
        switch self {
        case .baud0:
            return speed_t(B0)
        case .baud50:
            return speed_t(B50)
        case .baud75:
            return speed_t(B75)
        case .baud110:
            return speed_t(B110)
        case .baud134:
            return speed_t(B134)
        case .baud150:
            return speed_t(B150)
        case .baud200:
            return speed_t(B200)
        case .baud300:
            return speed_t(B300)
        case .baud600:
            return speed_t(B600)
        case .baud1200:
            return speed_t(B1200)
        case .baud1800:
            return speed_t(B1800)
        case .baud2400:
            return speed_t(B2400)
        case .baud4800:
            return speed_t(B4800)
        case .baud9600:
            return speed_t(B9600)
        case .baud19200:
            return speed_t(B19200)
        case .baud38400:
            return speed_t(B38400)
        case .baud57600:
            return speed_t(B57600)
        case .baud115200:
            return speed_t(B115200)
        case .baud230400:
            return speed_t(B230400)
        case .baud460800:
            return speed_t(B460800)
        case .baud500000:
            return speed_t(B500000)
        case .baud576000:
            return speed_t(B576000)
        case .baud921600:
            return speed_t(B921600)
        case .baud1000000:
            return speed_t(B1000000)
        case .baud1152000:
            return speed_t(B1152000)
        case .baud1500000:
            return speed_t(B1500000)
        case .baud2000000:
            return speed_t(B2000000)
        case .baud2500000:
            return speed_t(B2500000)
        case .baud3500000:
            return speed_t(B3500000)
        case .baud4000000:
            return speed_t(B4000000)
        }
    }
}
#elseif os(OSX)
public enum BaudRate {
    case baud0
    case baud50
    case baud75
    case baud110
    case baud134
    case baud150
    case baud200
    case baud300
    case baud600
    case baud1200
    case baud1800
    case baud2400
    case baud4800
    case baud9600
    case baud19200
    case baud38400
    case baud57600
    case baud115200
    case baud230400

    var speedValue: speed_t {
        switch self {
        case .baud0:
            return speed_t(B0)
        case .baud50:
            return speed_t(B50)
        case .baud75:
            return speed_t(B75)
        case .baud110:
            return speed_t(B110)
        case .baud134:
            return speed_t(B134)
        case .baud150:
            return speed_t(B150)
        case .baud200:
            return speed_t(B200)
        case .baud300:
            return speed_t(B300)
        case .baud600:
            return speed_t(B600)
        case .baud1200:
            return speed_t(B1200)
        case .baud1800:
            return speed_t(B1800)
        case .baud2400:
            return speed_t(B2400)
        case .baud4800:
            return speed_t(B4800)
        case .baud9600:
            return speed_t(B9600)
        case .baud19200:
            return speed_t(B19200)
        case .baud38400:
            return speed_t(B38400)
        case .baud57600:
            return speed_t(B57600)
        case .baud115200:
            return speed_t(B115200)
        case .baud230400:
            return speed_t(B230400)
        }
    }
}
#endif

public enum DataBitsSize {
    case bits5
    case bits6
    case bits7
    case bits8

    var flagValue: tcflag_t {
        switch self {
        case .bits5:
            return tcflag_t(CS5)
        case .bits6:
            return tcflag_t(CS6)
        case .bits7:
            return tcflag_t(CS7)
        case .bits8:
            return tcflag_t(CS8)
        }
    }

}

public enum ParityType {
    case none
    case even
    case odd

    var parityValue: tcflag_t {
        switch self {
        case .none:
            return 0
        case .even:
            return tcflag_t(PARENB)
        case .odd:
            return tcflag_t(PARENB | PARODD)
        }
    }
}
