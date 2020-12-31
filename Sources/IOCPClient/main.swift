//
//  IOCPClient.swift
//  IOCPClient
//
//  Created by Mathias Gisch on 25.12.20.
//

import Foundation
import Configuration
import ArgumentParser
import NIO

struct IOCPClient: ParsableCommand {

    @Argument(help: "The path to the configuration file.") var configurationFile: String?

    func run() throws {

        let manager = ConfigurationManager()
        manager.load(.environmentVariables)
        if let configFile = configurationFile {
            manager.load(file: configFile)
        }

        /// Start TCP-Connection first
        let host = manager["server:host"] as? String ?? "localhost"
        let port = manager["server:port"] as? Int ?? 8092
        let client = TCPClient(host: host, port: port)
        MessageDistributor.shared.registerEndpoint(client)

        do {
            try client.start()
        } catch let error {
            print("TCP-Error: \(error.localizedDescription)")
            client.stop()
        }


        /// Start serial connections
        if let config = manager["endPoints"] as? [Dictionary<String,String>] {
            config.forEach { (singleConfig) in

                let serialConnection = SerialEndpoint(path: singleConfig["port"]!, label: singleConfig["label"]!)
                MessageDistributor.shared.registerEndpoint(serialConnection)
                do {
                    try serialConnection.openPort()
                } catch let error {
                    print("Serial-Error: \(error.localizedDescription)")
                }

            }
        }

        let _ = MultiThreadedEventLoopGroup.withCurrentThreadAsEventLoop { (eventLoop) in
            
        }
        
    }

}

IOCPClient.main()
