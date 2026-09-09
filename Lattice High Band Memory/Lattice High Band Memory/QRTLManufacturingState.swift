//
//  File.swift
//  Lattice High Band Memory
//
//  Created by David Nishimoto on 9/6/26.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

@MainActor

final class QRTLManufacturingState: ObservableObject {

    // MARK: - Manufacturing Progress

    @Published var currentLayer: Int = 0

    @Published var depositedQDs: Int = 0

    @Published var totalQDs: Int = 0

    @Published var placedWires: Int = 0

    @Published var totalWires: Int = 0

    // IMPORTANT:

    // This is the textual manufacturing status.

    // It is deliberately NOT called manufacturingState,

    // because manufacturingState is the QRTLManufacturingState object.

    @Published var status: String = "INITIALIZING"

    // MARK: - Data Rates

    @Published var writeRate: String = "0 b/s"

    @Published var readRate: String = "0 b/s"

    @Published var writeBytes: String = "0 B/s"

    @Published var readBytes: String = "0 B/s"

    // MARK: - Storage

    @Published var storageCapacity: String = "0 B"

    // MARK: - Manufacturing Rate

    @Published var qdPrintRate: String = "0.00 QD/s"

    // MARK: - DWORD TEST STATE

    @Published var dwordMetrics = QRTLDWordMetrics()
    @Published var memoryTestStatus: String = "READY"

    /// Base byte address for the first DWORD.
    let dwordBaseAddress: UInt32 = 0x0100

    /// One logical bit per physical QD storage site.
    var memoryBitCells: [Int: Int] = [:]

    let lowSignal: Double = 0.10
    let highSignal: Double = 1.00
    let readThreshold: Double = 0.50
    let simulatedWriteTimePerBit: Double = 0.000001
    let simulatedReadTimePerBit: Double = 0.0000005

    // MARK: - Update

    func update(

        layer: Int,

        deposited: Int,

        total: Int,

        wires: Int,

        totalWires: Int,

        state: String,

        rateModel: QRTLDataRateModel

    ) {

        currentLayer = layer

        depositedQDs = deposited

        totalQDs = total

        placedWires = wires

        self.totalWires = totalWires

        status = state

        writeRate =

            QRTLDataRateModel.formatRate(

                rateModel.writeBitsPerSecond

            )

        readRate =

            QRTLDataRateModel.formatRate(

                rateModel.readBitsPerSecond

            )

        writeBytes =

            QRTLDataRateModel.formatBytes(

                rateModel.writeBytesPerSecond

            )

        readBytes =

            QRTLDataRateModel.formatBytes(

                rateModel.readBytesPerSecond

            )

        storageCapacity =

            QRTLDataRateModel.formatBytes(

                rateModel.storageBytes

            )

        qdPrintRate =

            String(

                format: "%.2f QD/s",

                rateModel.qdsPrintedPerSecond

            )

    }

}

extension QRTLManufacturingState {
    func resetDWORDMetrics() {
        dwordMetrics = QRTLDWordMetrics()
        memoryTestStatus = "READY"
    }

    @MainActor
    func runDWORDTest(
        address: UInt32,
        value: UInt32,
        retentionInterval: Double = 1.0,
        cycles: Int = 100
    ) {
        let start = CFAbsoluteTimeGetCurrent()
        let cellStart = Int(address >= dwordBaseAddress ? (address - dwordBaseAddress) / 4 : 0) * 32
        dwordMetrics.memoryAddress = address
        dwordMetrics.cellStartIndex = cellStart
        dwordMetrics.cellEndIndex = cellStart + 31
        dwordMetrics.writeCommand = value

        // WRITE: each DWORD bit is stored in one physical lattice cell.
        for bitIndex in 0..<32 {
            let bit = Int((value >> UInt32(bitIndex)) & 1)
            let cell = cellStart + bitIndex
            memoryBitCells[cell] = bit
            dwordMetrics.bitStates[bitIndex] = bit
        }

        dwordMetrics.writeTimeSeconds = max(
            CFAbsoluteTimeGetCurrent() - start,
            32.0 * simulatedWriteTimePerBit
        )

        var writeCorrect = 0
        for bitIndex in 0..<32 {
            let expected = Int((value >> UInt32(bitIndex)) & 1)
            let actual = memoryBitCells[cellStart + bitIndex] ?? 0
            if expected == actual { writeCorrect += 1 }
        }
        dwordMetrics.writeAccuracyPercent = Double(writeCorrect) / 32.0 * 100.0

        // READ: convert each stored cell state into a signal and threshold it.
        dwordMetrics.readAddress = address
        let readStart = CFAbsoluteTimeGetCurrent()
        var returned: UInt32 = 0
        for bitIndex in 0..<32 {
            let physicalState = memoryBitCells[cellStart + bitIndex] ?? 0
            let signal = lowSignal + (highSignal - lowSignal) * Double(physicalState)
            dwordMetrics.readSignals[bitIndex] = signal
            let detected = signal >= readThreshold ? 1 : 0
            dwordMetrics.detectedBits[bitIndex] = detected
            if detected == 1 {
                returned |= UInt32(1) << UInt32(bitIndex)
            }
        }
        dwordMetrics.readTimeSeconds = max(
            CFAbsoluteTimeGetCurrent() - readStart,
            32.0 * simulatedReadTimePerBit
        )
        dwordMetrics.returnedDWORD = returned

        calculateDWORDAccuracy(expected: value, returned: returned)

        // Retention metric: in this deterministic model the stored lattice
        // state is sampled again after the requested interval. No drift is
        // injected unless the user later adds a physical error model.
        dwordMetrics.retentionSeconds = retentionInterval
        let retentionReturned = readStoredDWORD(address: address)
        var retained = 0
        for bitIndex in 0..<32 {
            if dwordMetrics.bitStates[bitIndex] == Int((retentionReturned >> UInt32(bitIndex)) & 1) {
                retained += 1
            }
        }
        dwordMetrics.retentionPercent = Double(retained) / 32.0 * 100.0

        // Repeated write/read cycles.
        dwordMetrics.requestedCycles = max(0, cycles)
        dwordMetrics.successfulCycles = 0
        if cycles > 0 {
            for _ in 0..<cycles {
                for bitIndex in 0..<32 {
                    memoryBitCells[cellStart + bitIndex] = Int((value >> UInt32(bitIndex)) & 1)
                }
                let cycleRead = readStoredDWORD(address: address)
                if cycleRead == value {
                    dwordMetrics.successfulCycles += 1
                }
            }
            dwordMetrics.cycleSuccessRatePercent =
                Double(dwordMetrics.successfulCycles) / Double(cycles) * 100.0
        } else {
            dwordMetrics.cycleSuccessRatePercent = 0
        }

        // Final verification after the cycle test.
        let finalReturned = readStoredDWORD(address: address)
        calculateDWORDAccuracy(expected: value, returned: finalReturned)
        dwordMetrics.returnedDWORD = finalReturned
        dwordMetrics.verificationPassed = finalReturned == value

        memoryTestStatus = dwordMetrics.verificationPassed
            ? "DWORD TEST PASS"
            : "DWORD TEST FAIL"
        status = memoryTestStatus
    }

    private func readStoredDWORD(address: UInt32) -> UInt32 {
        let cellStart = Int(address >= dwordBaseAddress ? (address - dwordBaseAddress) / 4 : 0) * 32
        var result: UInt32 = 0
        for bitIndex in 0..<32 {
            let physicalState = memoryBitCells[cellStart + bitIndex] ?? 0
            let signal = lowSignal + (highSignal - lowSignal) * Double(physicalState)
            let detected = signal >= readThreshold ? 1 : 0
            if detected == 1 {
                result |= UInt32(1) << UInt32(bitIndex)
            }
        }
        return result
    }

    private func calculateDWORDAccuracy(expected: UInt32, returned: UInt32) {
        var correct = 0
        for bitIndex in 0..<32 {
            let a = Int((expected >> UInt32(bitIndex)) & 1)
            let b = Int((returned >> UInt32(bitIndex)) & 1)
            if a == b { correct += 1 }
        }
        dwordMetrics.readAccuracyPercent = Double(correct) / 32.0 * 100.0
        dwordMetrics.incorrectBits = 32 - correct
        dwordMetrics.totalBitsTested = 32
        dwordMetrics.errorRatePercent = Double(dwordMetrics.incorrectBits) / 32.0 * 100.0
    }

    func dwordHex(_ value: UInt32) -> String {
        String(format: "0x%08X", value)
    }

    func dwordBinary(_ value: UInt32) -> String {
        let bits = String(value, radix: 2)
        return String(repeating: "0", count: max(0, 32 - bits.count)) + bits
    }
}
