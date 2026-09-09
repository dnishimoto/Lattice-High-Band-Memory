// QRTLArduinoBridge.swift
// Simulates the Arduino as a protocol bridge for QRTL lattice memory.
// Receives memory commands from the laptop (host), interacts with controller, and returns responses.

import Foundation

/// Types of memory commands sent from laptop to Arduino.
public enum QRTLMemCommandType: String, Codable {
    case write
    case read
    case writeDWORD
    case readDWORD
}

/// A memory operation command/message from host to Arduino.
public struct QRTLMemCommand: Codable {
    public let type: QRTLMemCommandType
    public let address: QRTLLogicalAddress?
    public let bit: Bool?
    public let addresses: [QRTLLogicalAddress]?
    public let word: UInt32?
    public init(type: QRTLMemCommandType, address: QRTLLogicalAddress? = nil, bit: Bool? = nil, addresses: [QRTLLogicalAddress]? = nil, word: UInt32? = nil) {
        self.type = type
        self.address = address
        self.bit = bit
        self.addresses = addresses
        self.word = word
    }
}

/// Possible responses from Arduino to host.
public enum QRTLMemResponse {
    case ok
    case bit(Bool)
    case dword(UInt32)
    case error(String)
}

/// The simulated Arduino which parses commands and calls the controller.
public final class QRTLArduinoBridge {
    private let controller: QRTLArduinoControllerProtocol
    public init(controller: QRTLArduinoControllerProtocol) {
        self.controller = controller
    }
    
    /// Receives and executes a command from the laptop/host.
    public func handle(command: QRTLMemCommand) -> QRTLMemResponse {
        do {
            switch command.type {
            case .write:
                guard let address = command.address, let bit = command.bit else { return .error("Missing address/bit") }
                try controller.write(address: address, bit: bit)
                return .ok
            case .read:
                guard let address = command.address else { return .error("Missing address") }
                let result = try controller.read(address: address)
                return .bit(result)
            case .writeDWORD:
                guard let addresses = command.addresses, let word = command.word else { return .error("Missing addresses/word") }
                try controller.writeDWORD(addresses: addresses, word: word)
                return .ok
            case .readDWORD:
                guard let addresses = command.addresses else { return .error("Missing addresses") }
                let result = try controller.readDWORD(addresses: addresses)
                return .dword(result)
            }
        } catch {
            return .error("Arduino error: \(error)")
        }
    }
}

// Example: The host (laptop) sends messages via this bridge object. Extend as needed for async/queue or real serial/network communication.

