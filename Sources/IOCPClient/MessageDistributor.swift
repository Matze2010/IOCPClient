//
//  MessageDistributor.swift
//  
//
//  Created by Mathias Gisch on 26.12.20.
//

import Foundation


class MessageDistributor {
    static let shared = MessageDistributor()

    private var serialEndpoints = Set<SerialEndpoint>()
    private var siocEndpoint: TCPClient?


    private init() { }

    public func registerEndpoint(_ aSerialEndpoint: SerialEndpoint) {
        self.serialEndpoints.insert(aSerialEndpoint)
    }

    public func registerEndpoint(_ aSIOCEndpoint: TCPClient) {
        self.siocEndpoint = aSIOCEndpoint
    }

    public func enqueueMessage(_ newMessage: IOCPMessage) {

        let origin = newMessage.origin

        if !self.validateOrigin(origin) {
            return
        }

        switch origin {
        case .Serial(_):
            self.processMessageComingFromSerial(newMessage)

        case .SIOC:
            self.processMessageComingFromSIOC(newMessage)
        }
    }

    private func processMessageComingFromSerial(_ message: IOCPMessage) {
        self.forwardActionToSIOC(message.action)
        if case IOCPMessageAction.Update(_) = message.action, case IOCPOrigin.Serial(let exceptEndpoint) = message.origin {
            self.fowardActionToSerialEndpoints(message.action, except: [exceptEndpoint])
        }
    }

    private func processMessageComingFromSIOC(_ message: IOCPMessage) {
        switch message.action {

        case .Registration(_):
            break
        case .Update(_):
            self.fowardActionToAllSerialEndpoints(message.action)
            break
        case .KeepAlive:
            self.forwardActionToSIOC(IOCPMessageAction.KeepAlive)
        case .Exit:
            break
        case .Invalid, .Unknown:
            break
        }
    }

    private func forwardActionToSIOC(_ action: IOCPMessageAction) {
        if let sioc = self.siocEndpoint {
            sioc.sendToServer(data: String(describing: action)).whenComplete { (result) in
                switch result {
                case .success():
                    NSLog("To SIOC: \(action)")
                case .failure(let error):
                    NSLog("Error To SIOC: \(action) \(error)")
                }
            }
        }
    }

    private func fowardActionToAllSerialEndpoints(_ action: IOCPMessageAction) {
        self.serialEndpoints.forEach { (endPoint) in
            endPoint.handleIncomingAction(action)?.whenComplete({ (result) in
                switch result {
                case .success():
                    NSLog("To Serial: \(action)")
                case .failure(let error):
                    NSLog("Error To Serial: \(action) \(error)")
                }
            })

        }
    }

    private func fowardActionToSerialEndpoints(_ action: IOCPMessageAction, except: [SerialEndpoint]) {
        self.serialEndpoints.subtracting(except).forEach { (endPoint) in
            endPoint.handleIncomingAction(action)?.whenComplete({ (result) in
                switch result {
                case .success():
                    NSLog("To Serial: \(action)")
                case .failure(let error):
                    NSLog("Error To Serial: \(action) \(error)")
                }
            })
        }
    }

    private func validateOrigin(_ testOrigin: IOCPOrigin) -> Bool {
        switch testOrigin {
        case .Serial(let serialEndpoint):
            if self.serialEndpoints.contains(serialEndpoint) {
                return true
            }

        case .SIOC:
            return true
        }

        return false
    }
}
