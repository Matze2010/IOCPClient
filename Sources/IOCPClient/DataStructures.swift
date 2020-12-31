//
//  DataStructures.swift
//  IOCPClient
//
//  Created by Mathias Gisch on 25.12.20.
//

import Foundation
import SharedIOCP

typealias IOCPPositionName = Int
typealias IOCPPositionValue = Int

struct IOCPPosition {
    let name: IOCPPositionName
    let value: IOCPPositionValue

    static func parsing(_ rawData: String) -> IOCPPosition? {
        let parts = rawData.components(separatedBy: IOCP_VALUE_SEPARATOR)

        if (parts.count != 2) {
            return nil
        }

        guard let name = IOCPPositionName(parts[0]), let value = IOCPPositionName(parts[1]) else {
            return nil
        }

        return IOCPPosition(name: name, value: value)
    }
}

struct IOCPMessage {
    let action: IOCPMessageAction
    let origin: IOCPOrigin
}

enum IOCPMessageAction {
    case Registration(Set<IOCPPositionName>)
    case Update([IOCPPosition])
    case KeepAlive
    case Exit
    case Invalid
    case Unknown

    static func parsing(_ rawData: String) -> IOCPMessageAction {

        let newCommand: IOCPMessageAction
        let cleanData = rawData.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanData.hasPrefix(IOCP_HEADER) {
            NSLog("Not valid IOCP-Protocol: \(cleanData)")
            return IOCPMessageAction.Unknown
        }

        switch cleanData {

        case let command where command.hasPrefix(IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_REGISTRATION_COMMAND):
            let parts = command.components(separatedBy: IOCP_CONTENT_SEPARATOR).dropFirst()
            let names = Set(parts.compactMap { IOCPPositionName($0) })
            if names.count > 0 {
                newCommand = IOCPMessageAction.Registration(names)
            } else {
                newCommand = IOCPMessageAction.Invalid
            }

        case let command where command.hasPrefix(IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_UPDATE_COMMAND):
            let parts = command.components(separatedBy: IOCP_CONTENT_SEPARATOR).dropFirst()
            let positions = parts.compactMap { IOCPPosition.parsing($0) }
            if positions.count > 0 {
                newCommand = IOCPMessageAction.Update(positions)
            } else {
                newCommand = IOCPMessageAction.Invalid
            }

        case let command where command.hasPrefix(IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_KEEPALIVE_COMMAND):
            newCommand = IOCPMessageAction.KeepAlive

        case let command where command.hasPrefix(IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_EXIT_COMMAND):
            newCommand = IOCPMessageAction.Exit

        default:
            newCommand = IOCPMessageAction.Unknown
        }

        return newCommand
    }
}

extension IOCPMessageAction: CustomStringConvertible {

    var description: String {
        switch self {
        case .Registration(let positions):
            let stringList = positions.map({ String($0) }).reduce("") { (buffer, next) -> String in
                return buffer + next + IOCP_CONTENT_SEPARATOR
            }
            return IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_REGISTRATION_COMMAND + IOCP_CONTENT_SEPARATOR + stringList

        case .Update(let positions):
            let stringList = positions.map({ String(describing: $0) }).reduce("") { (buffer, next) -> String in
                return buffer + next + IOCP_CONTENT_SEPARATOR
            }
            return IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_UPDATE_COMMAND + IOCP_CONTENT_SEPARATOR + stringList

        case .KeepAlive:
            return IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_KEEPALIVE_COMMAND + IOCP_CONTENT_SEPARATOR

        case .Exit:
            return IOCP_HEADER + IOCP_COMMAND_SEPARATOR + IOCP_EXIT_COMMAND + IOCP_CONTENT_SEPARATOR

        case .Invalid:
            return "INVALID ACTION"

        case .Unknown:
            return "UNKNOWN ACTION"
        }
    }
}

extension IOCPPosition: CustomStringConvertible {

    var description: String {
        return String(self.name) + IOCP_VALUE_SEPARATOR + String(self.value)
    }
        
}

enum IOCPOrigin {
    case Serial(SerialEndpoint)
    case SIOC
}
