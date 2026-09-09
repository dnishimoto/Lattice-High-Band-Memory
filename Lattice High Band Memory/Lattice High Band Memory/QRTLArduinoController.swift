// QRTLArduinoController.swift
// QRTL Lattice Memory Arduino Interface Abstraction
// Created for QRTL lattice memory simulation and control

import Foundation

/// Represents a logical address in the QRTL memory system.
public struct QRTLLogicalAddress: Codable, Equatable, Hashable {
    public let bank: Int
    public let band: Int
    public let x: Int
    public let y: Int
    public let z: Int
    
    public init(bank: Int, band: Int, x: Int, y: Int, z: Int) {
        self.bank = bank
        self.band = band
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Protocol describing the commands that can be sent from computer to controller (Arduino).
public protocol QRTLArduinoControllerProtocol: AnyObject {
    /// Write a value to the logical address.
    func write(address: QRTLLogicalAddress, bit: Bool) throws
    /// Read a value from the logical address.
    func read(address: QRTLLogicalAddress) throws -> Bool
    /// Perform a DWORD write/read operation for parallel testing.
    func writeDWORD(addresses: [QRTLLogicalAddress], word: UInt32) throws
    func readDWORD(addresses: [QRTLLogicalAddress]) throws -> UInt32
}

/// Concrete Arduino/controller abstraction for QRTL lattice memory.
public final class QRTLArduinoController: QRTLArduinoControllerProtocol {
    public struct MemoryConfig {
        public let bankCount: Int
        public let bandsPerBank: Int
        public let xCount: Int
        public let yCount: Int
        public let zCount: Int
        
        public init(bankCount: Int, bandsPerBank: Int, xCount: Int, yCount: Int, zCount: Int) {
            self.bankCount = bankCount
            self.bandsPerBank = bandsPerBank
            self.xCount = xCount
            self.yCount = yCount
            self.zCount = zCount
        }
    }
    
    public let config: MemoryConfig
    /// Simulated physical memory: [bank][band][x][y][z]
    private var memory: [[[[[Bool]]]]]
    
    public init(config: MemoryConfig) {
        self.config = config
        memory = Array(
            repeating: Array(
                repeating: Array(
                    repeating: Array(
                        repeating: Array(
                            repeating: false,
                            count: config.zCount
                        ),
                        count: config.yCount
                    ),
                    count: config.xCount
                ),
                count: config.bandsPerBank
            ),
            count: config.bankCount
        )
    }
    
    /// Map a linear logical address to physical coordinates (example placeholder logic)
    public func coordinateForAddress(_ address: QRTLLogicalAddress) -> (bank: Int, band: Int, x: Int, y: Int, z: Int) {
        // Here, address is already decomposed; in real logic, may decode from UInt32 or similar
        return (address.bank, address.band, address.x, address.y, address.z)
    }
    
    public func write(address: QRTLLogicalAddress, bit: Bool) throws {
        let (b, ba, x, y, z) = coordinateForAddress(address)
        guard isValid(b, ba, x, y, z) else { throw ControllerError.invalidAddress }
        memory[b][ba][x][y][z] = bit
    }
    
    public func read(address: QRTLLogicalAddress) throws -> Bool {
        let (b, ba, x, y, z) = coordinateForAddress(address)
        guard isValid(b, ba, x, y, z) else { throw ControllerError.invalidAddress }
        return memory[b][ba][x][y][z]
    }
    
    public func writeDWORD(addresses: [QRTLLogicalAddress], word: UInt32) throws {
        guard addresses.count == 32 else { throw ControllerError.invalidDWORD }
        for i in 0..<32 {
            let bit = ((word >> i) & 0x1) != 0
            try write(address: addresses[i], bit: bit)
        }
    }
    
    public func readDWORD(addresses: [QRTLLogicalAddress]) throws -> UInt32 {
        guard addresses.count == 32 else { throw ControllerError.invalidDWORD }
        var word: UInt32 = 0
        for i in 0..<32 {
            let bit = try read(address: addresses[i])
            if bit {
                word |= (1 << i)
            }
        }
        return word
    }
    
    private func isValid(_ bank: Int, _ band: Int, _ x: Int, _ y: Int, _ z: Int) -> Bool {
        return (bank >= 0 && bank < config.bankCount &&
                band >= 0 && band < config.bandsPerBank &&
                x >= 0 && x < config.xCount &&
                y >= 0 && y < config.yCount &&
                z >= 0 && z < config.zCount)
    }
    
    public enum ControllerError: Error {
        case invalidAddress
        case invalidDWORD
    }
}

// Future: add protocol for hardware communication

