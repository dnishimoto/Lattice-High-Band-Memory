/*
 The cleanest way to think about a 3D memory system is that a memory address normally selects a **word** or block of bits rather than one physical wire corresponding to one individual bit. For example, suppose the memory has 1,024 addressable locations and each location stores a 64-bit word. Address `0000` selects one group of 64 bits, address `0001` selects another group of 64 bits, and so on through address `1023`. If address `0372` is selected, the memory returns or updates the 64 stored values in that particular word, such as `b63, b62, b61 ... b2, b1, b0`. In this arrangement, an address identifies the location of a multi-bit data block, not the position of a single isolated bit.

 The address wires form an address bus, such as `A0, A1, A2 ... An`, which carries a binary address into an address decoder. The decoder converts that binary number into a one-of-many selection signal. For instance, when the controller sends address `0372`, the decoder activates only the select line for word `0372`. All other words remain electrically disconnected from the current read or write operation. This lets a relatively small set of address wires choose among a very large number of memory blocks.

 The bits in those blocks can share a common data bus. In a 64-bit design, the bus might contain 64 data lines, `D0` through `D63`. Each memory word has circuitry that connects its 64 stored bits to these shared data wires only when that word is selected. Thus, word `0000` and word `1023` can both be physically connected to the same logical 64-bit data bus, but only the selected word is permitted to drive the bus during a read or receive data from it during a write. The select signal prevents every block from trying to access the shared wires at once.

 For a stacked 3D memory architecture, the same principle can be extended across physical layers. A memory controller sends address information and read/write control signals into decoding circuitry. The address can be divided into components such as a layer number, row number, and column number. For example, `Layer = 12`, `Row = 37`, and `Column = 18` could select one specific memory block inside a three-dimensional array. A layer selector first activates layer 12, then row and column decoding activate the particular block at row 37 and column 18 within that layer. Each layer can contain many blocks, and each block can hold a 64-bit QRTL word or another chosen word width.

 Conceptually, the overall structure would be organized as a collection of layers, with each layer containing many addressable blocks. Layer 0 might contain address 0, address 1, address 2, and so forth, with every address mapping to 64 bits. Layer 1 would contain another set of blocks, and Layer 2 another set. The full memory address therefore identifies a particular location in the three-dimensional structure, while the selected location contains the actual individual bits.

 During a read, the CPU or memory controller could issue an address such as `12:37:18`. The address decoder would activate Layer 12, Row 37, and Column 18, selecting one memory block. If that block contains 64 QRTL bits, the block’s output circuitry places those 64 stored values onto the 64 shared data wires, which then carry the word back to the CPU. During a write operation, the same address selects the block, but the data bus carries new values from the CPU into the block instead.

 The key idea is that the address wires do not need to run individually to every stored bit. Instead, they feed decoding circuitry that determines which memory block is active. The active block then connects to the data bus through controlled access circuitry. For your 3D architecture, the major design choice is whether one address should select a full block of QRTL bits on a particular layer or whether one address should select one individual QRTL memory cell. Selecting a word is generally more efficient for moving larger data units, while selecting individual cells provides finer-grained control but requires more complex addressing and access circuitry.
 */

//  QRTLQDJet3DPrintingScene.swift

//

//  QRTL Quantum-Dot 3D Memory Manufacturing Animation

//

//  Manufacturing sequence:

//

//  EXTERNAL QDs

//       ↓

//  QD INK RESERVOIR

//       ↓

//  EHD QD JET

//       ↓

//  XYZ PRECISION POSITIONING

//       ↓

//  LAYER-BY-LAYER QD DEPOSITION

//       ↓

//  COMPLETE 3D QD CUBE

//       ↓

//  ROBOTIC ACCESS-WIRE PLACEMENT

//       ↓

//  WIRE / QD REGISTRATION

//       ↓

//  READ / WRITE DATA TRANSFER

//

//  IMPORTANT:

//  Data-rate values are configurable simulation targets.

//  They are NOT experimentally established QD-memory performance.

//

//  SceneKit is used here because this project already uses SceneKit.

//  Apple currently marks SceneKit as deprecated in favor of RealityKit.

//

import Foundation

import SwiftUI

import SceneKit

import UIKit

import Combine

// MARK: - QRTL SYSTEM INTENT

enum QRTLSystemIntent: String {
    case visualizationPrototype = "Visualization Prototype"
    case hbmReplacementArchitecture = "HBM Replacement Architecture"
}

/// Cooling solutions considered for the package, each with a
/// conservative sustained power-density ceiling drawn from published
/// datacenter/HPC cooling literature. These are reference ceilings
/// for comparison against the modeled power density -- not a
/// guarantee that any specific hardware implementation achieves them.
enum QRTLCoolingClass: String, CaseIterable {
    case passiveAirAmbient = "Passive Air (No Active Cooling)"
    case forcedAirHeatsink = "Forced-Air Heatsink"
    case coldPlateLiquid = "Cold-Plate Liquid Cooling"
    case microfluidicInterlayer = "Microfluidic Interlayer Cooling"
    case twoPhaseImmersion = "Two-Phase Immersion Cooling"

    var maxSustainedPowerDensityWattsPerSquareCentimeter: Double {
        switch self {
        case .passiveAirAmbient: return 1.0
        case .forcedAirHeatsink: return 50.0
        case .coldPlateLiquid: return 150.0
        case .microfluidicInterlayer: return 300.0
        case .twoPhaseImmersion: return 500.0
        }
    }
}

/// Models the proposed scalable production QRTL architecture,
/// completely independent from the small SceneKit demo lattice
/// rendered by QRTLMemoryParameters below. Nothing in this struct
/// drives SceneKit node counts; it is a pure numerical model used
/// to reason about and display the 1 PB/s design target.
struct QRTLArchitectureParameters {

    // ---------------------------------------------------------
    // DECLARATION OF INTENT
    // ---------------------------------------------------------

    /// This model represents a proposed scalable architecture,
    /// not experimentally measured QD device performance.
    let systemIntent: QRTLSystemIntent = .hbmReplacementArchitecture

    /// Architectural goal: replace or exceed HBM-class memory
    /// through massively parallel monolithic 3D QD memory tiles.
    let intendedRole =
        "Scalable HBM-replacement / near-compute memory architecture"

    /// Target is usable one-direction payload bandwidth per QRTL package.
    let targetPayloadBytesPerSecond: Double = 1_000_000_000_000_000

    /// Explicit semantics prevent ambiguity in future analysis.
    let targetDescription =
        "1 PB/s sustained one-direction payload bandwidth per QRTL package"

    // ---------------------------------------------------------
    // HIERARCHICAL ARCHITECTURE
    //
    // QD cell -> subarray -> bank -> tile -> layer -> cube/package
    //
    // Calibrated to land just over the 1 PB/s target using a
    // compact bank count rather than maximum theoretical parallelism.
    // ---------------------------------------------------------

    let cubesPerPackage: Int = 1
    let layersPerCube: Int = 1_000

    let tilesPerLayer: Int = 1_000
    let banksPerTile: Int = 1

    /// Independent local access lanes per bank.
    let lanesPerBank: Int = 1

    /// Payload bits moved by every active lane per access event.
    ///
    /// Use 1 for a single-bit cell operation, or a wider burst
    /// width when a lane returns a vector/word from a local bank.
    let payloadBitsPerLaneAccess: Double = 1.0

    /// Local lane access cadence assumed by the architecture model.
    /// This is a proposed model parameter, not a measured device rate.
    let accessFrequencyHz: Double = 10_100_000_000

    // ---------------------------------------------------------
    // EFFICIENCY / OVERHEAD
    // ---------------------------------------------------------

    /// Fraction of lanes doing useful work under sustained load.
    let sustainedUtilization: Double = 0.90

    /// Yield after defects, redundancy, mapping, and manufacturing loss.
    let physicalYieldEfficiency: Double = 0.95

    /// Payload fraction after ECC, framing, arbitration, and protocol cost.
    let payloadEfficiency: Double = 0.94

    /// Fraction of theoretical array throughput that reaches compute logic.
    let fabricDeliveryEfficiency: Double = 0.99

    // ---------------------------------------------------------
    // CAPACITY MODEL
    // ---------------------------------------------------------

    /// Total addressable QD cells per bank.
    let cellsPerBank: Double = 1_000_000_000

    /// Logical bits stored by each QD cell.
    let bitsPerQDCell: Double = 1.0

    // ---------------------------------------------------------
    // LATENCY / POWER TARGETS
    //
    // Explicitly targets, not experimental claims.
    // ---------------------------------------------------------

    let targetRandomReadLatencyNanoseconds: Double = 20.0
    let targetRandomWriteLatencyNanoseconds: Double = 30.0

    /// Full package electrical power target under sustained transfer.
    let targetPowerWattsAtSustainedBandwidth: Double = 10_000.0

    // ---------------------------------------------------------
    // DERIVED COUNTS
    // ---------------------------------------------------------

    var totalTiles: Double {
        Double(cubesPerPackage * layersPerCube * tilesPerLayer)
    }

    var totalBanks: Double {
        totalTiles * Double(banksPerTile)
    }

    var totalIndependentLanes: Double {
        totalBanks * Double(lanesPerBank)
    }

    var totalQDCells: Double {
        totalBanks * cellsPerBank
    }

    // ---------------------------------------------------------
    // BANDWIDTH MODEL
    // ---------------------------------------------------------

    /// The raw internal array bit rate before all losses/overheads.
    var rawArrayBitsPerSecond: Double {
        totalIndependentLanes *
        accessFrequencyHz *
        payloadBitsPerLaneAccess
    }

    /// The factor converting raw internal activity to useful payload.
    var totalPayloadEfficiency: Double {
        sustainedUtilization *
        physicalYieldEfficiency *
        payloadEfficiency *
        fabricDeliveryEfficiency
    }

    /// Sustained payload rate available to the compute-side interface.
    var sustainedPayloadBitsPerSecond: Double {
        rawArrayBitsPerSecond * totalPayloadEfficiency
    }

    var sustainedPayloadBytesPerSecond: Double {
        sustainedPayloadBitsPerSecond / 8.0
    }

    /// Ratio to the declared 1 PB/s target.
    var targetAchievementRatio: Double {
        guard targetPayloadBytesPerSecond > 0 else { return 0 }
        return sustainedPayloadBytesPerSecond /
            targetPayloadBytesPerSecond
    }

    var meetsOnePBPerSecondTarget: Bool {
        sustainedPayloadBytesPerSecond >=
            targetPayloadBytesPerSecond
    }

    // ---------------------------------------------------------
    // CAPACITY MODEL
    // ---------------------------------------------------------

    var logicalStorageBits: Double {
        totalQDCells * bitsPerQDCell
    }

    var logicalStorageBytes: Double {
        logicalStorageBits / 8.0
    }

    // ---------------------------------------------------------
    // ENERGY MODEL
    // ---------------------------------------------------------

    /// System energy per useful payload bit.
    ///
    /// Includes the package power budget divided by delivered bits,
    /// but remains a target until hardware power is measured.
    var targetEnergyPerPayloadBitJoules: Double {
        guard sustainedPayloadBitsPerSecond > 0 else { return 0 }
        return targetPowerWattsAtSustainedBandwidth /
            sustainedPayloadBitsPerSecond
    }

    var targetEnergyPerPayloadBitPicojoules: Double {
        targetEnergyPerPayloadBitJoules * 1_000_000_000_000
    }

    // ---------------------------------------------------------
    // HBM REFERENCE COMPARISON
    //
    // This is a configurable reference, not an assumption that all
    // HBM products have the same stack bandwidth.
    // ---------------------------------------------------------

    let hbmReferenceStackBytesPerSecond: Double =
        1_200_000_000_000

    var hbmEquivalentStackCount: Double {
        sustainedPayloadBytesPerSecond /
            hbmReferenceStackBytesPerSecond
    }

    // ---------------------------------------------------------
    // THERMAL / POWER SAFETY MODEL
    //
    // A monolithic 3D stack concentrates its power budget into a
    // small external footprint, so the bandwidth/power target above
    // is only physically meaningful if the resulting power density
    // and steady-state temperature stay inside safe limits for a
    // stated cooling solution. This section is a check on the
    // targets above; it does not feed back into the bandwidth model.
    // ---------------------------------------------------------

    /// Assumed cooling solution for the package. A ~10 kW monolithic
    /// 3D stack cannot rely on passive air, so this assumption is
    /// made explicit rather than left implied.
    let coolingClass: QRTLCoolingClass = .twoPhaseImmersion

    /// External package footprint exposed to the cooling solution.
    /// Modeled at wafer-scale-class area (order of a 300 mm wafer),
    /// independent of the layer/tile/bank counts above.
    let packageFootprintAreaSquareCentimeters: Double = 700.0

    /// Ambient temperature the cooling solution is designed against.
    let ambientTemperatureCelsius: Double = 25.0

    /// Maximum safe device temperature before reliability, retention,
    /// and error rate are assumed to degrade. A QD-memory-specific
    /// design target, not a general silicon figure.
    let maxSafeDeviceTemperatureCelsius: Double = 85.0

    /// Target device-to-ambient thermal resistance for the cooling
    /// solution. A design target for the cooling system, not a
    /// measured value.
    let targetThermalResistanceCelsiusPerWatt: Double = 0.003

    /// Sustained power dissipated per unit of external footprint.
    var powerDensityWattsPerSquareCentimeter: Double {
        guard packageFootprintAreaSquareCentimeters > 0 else { return 0 }
        return targetPowerWattsAtSustainedBandwidth /
            packageFootprintAreaSquareCentimeters
    }

    var maxSustainedPowerDensityForCoolingClass: Double {
        coolingClass.maxSustainedPowerDensityWattsPerSquareCentimeter
    }

    /// How much headroom the cooling class has versus the modeled
    /// power density. Greater than 1.0 means margin exists.
    var thermalSafetyMarginRatio: Double {
        guard powerDensityWattsPerSquareCentimeter > 0 else { return 0 }
        return maxSustainedPowerDensityForCoolingClass /
            powerDensityWattsPerSquareCentimeter
    }

    var meetsPowerDensitySafetyMargin: Bool {
        powerDensityWattsPerSquareCentimeter <=
            maxSustainedPowerDensityForCoolingClass
    }

    /// Steady-state device temperature estimated from the target
    /// power and the target thermal resistance. A modeled estimate,
    /// not a measured value from fabricated hardware.
    var estimatedSteadyStateDeviceTemperatureCelsius: Double {
        ambientTemperatureCelsius +
            targetPowerWattsAtSustainedBandwidth *
            targetThermalResistanceCelsiusPerWatt
    }

    var meetsDeviceTemperatureSafetyMargin: Bool {
        estimatedSteadyStateDeviceTemperatureCelsius <=
            maxSafeDeviceTemperatureCelsius
    }

    /// Overall thermal safety: both the power-density ceiling for the
    /// stated cooling class and the steady-state temperature estimate
    /// must stay within their safe limits.
    var meetsThermalSafety: Bool {
        meetsPowerDensitySafetyMargin && meetsDeviceTemperatureSafetyMargin
    }

    // ---------------------------------------------------------
    // VALIDATION
    // ---------------------------------------------------------

    var validationWarnings: [String] {
        var warnings: [String] = []

        if !meetsOnePBPerSecondTarget {
            warnings.append(
                "Architecture does not meet the declared 1 PB/s payload target."
            )
        }

        if sustainedUtilization <= 0 || sustainedUtilization > 1 {
            warnings.append("Sustained utilization must be in (0, 1].")
        }

        if physicalYieldEfficiency <= 0 ||
            physicalYieldEfficiency > 1 {
            warnings.append("Physical yield efficiency must be in (0, 1].")
        }

        if payloadEfficiency <= 0 || payloadEfficiency > 1 {
            warnings.append("Payload efficiency must be in (0, 1].")
        }

        if fabricDeliveryEfficiency <= 0 ||
            fabricDeliveryEfficiency > 1 {
            warnings.append(
                "Fabric delivery efficiency must be in (0, 1]."
            )
        }

        if !meetsPowerDensitySafetyMargin {
            warnings.append(
                "Power density (\(String(format: "%.1f", powerDensityWattsPerSquareCentimeter)) W/cm2) " +
                "exceeds the sustained ceiling for \(coolingClass.rawValue) " +
                "(\(String(format: "%.1f", maxSustainedPowerDensityForCoolingClass)) W/cm2)."
            )
        }

        if !meetsDeviceTemperatureSafetyMargin {
            warnings.append(
                "Estimated steady-state device temperature " +
                "(\(String(format: "%.1f", estimatedSteadyStateDeviceTemperatureCelsius))C) " +
                "exceeds the max safe device temperature " +
                "(\(String(format: "%.1f", maxSafeDeviceTemperatureCelsius))C)."
            )
        }

        return warnings
    }
}

extension QRTLArchitectureParameters {

    func architectureSummary() -> [String] {
        [
            "SYSTEM INTENT: \(systemIntent.rawValue)",
            "INTENDED ROLE: \(intendedRole)",
            "TARGET: \(targetDescription)",
            "TOTAL TILES: \(Self.formatCount(totalTiles))",
            "TOTAL BANKS: \(Self.formatCount(totalBanks))",
            "TOTAL INDEPENDENT LANES: \(Self.formatCount(totalIndependentLanes))",
            "RAW ARRAY RATE: \(Self.formatBitRate(rawArrayBitsPerSecond))",
            "SUSTAINED PAYLOAD: \(Self.formatByteRate(sustainedPayloadBytesPerSecond))",
            "TARGET ACHIEVEMENT: \(String(format: "%.3f", targetAchievementRatio))x",
            "1 PB/s TARGET MET: \(meetsOnePBPerSecondTarget ? "YES" : "NO")",
            "HBM STACK EQUIVALENT: \(String(format: "%.1f", hbmEquivalentStackCount)) stacks",
            "TARGET RANDOM READ LATENCY: \(String(format: "%.1f ns", targetRandomReadLatencyNanoseconds))",
            "TARGET ENERGY: \(String(format: "%.4f pJ/bit", targetEnergyPerPayloadBitPicojoules))"
        ]
    }

    func thermalSummary() -> [String] {
        [
            "COOLING CLASS: \(coolingClass.rawValue)",
            "PACKAGE FOOTPRINT: \(String(format: "%.0f", packageFootprintAreaSquareCentimeters)) cm2",
            "POWER DENSITY: \(String(format: "%.2f", powerDensityWattsPerSquareCentimeter)) W/cm2",
            "COOLING CLASS CEILING: \(String(format: "%.1f", maxSustainedPowerDensityForCoolingClass)) W/cm2",
            "THERMAL SAFETY MARGIN: \(String(format: "%.2f", thermalSafetyMarginRatio))x",
            "POWER DENSITY SAFE: \(meetsPowerDensitySafetyMargin ? "YES" : "NO")",
            "ESTIMATED DEVICE TEMP: \(String(format: "%.1f", estimatedSteadyStateDeviceTemperatureCelsius))C",
            "MAX SAFE DEVICE TEMP: \(String(format: "%.1f", maxSafeDeviceTemperatureCelsius))C",
            "TEMPERATURE SAFE: \(meetsDeviceTemperatureSafetyMargin ? "YES" : "NO")",
            "OVERALL THERMAL SAFETY: \(meetsThermalSafety ? "SAFE" : "AT RISK")"
        ]
    }

    static func formatCount(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "%.3f T", value / 1_000_000_000_000)
        }
        if value >= 1_000_000_000 {
            return String(format: "%.3f B", value / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.3f M", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.3f K", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    static func formatBitRate(_ bitsPerSecond: Double) -> String {
        if bitsPerSecond >= 8_000_000_000_000_000 {
            return String(format: "%.3f Pb/s", bitsPerSecond / 1_000_000_000_000_000)
        }
        if bitsPerSecond >= 8_000_000_000_000 {
            return String(format: "%.3f Tb/s", bitsPerSecond / 1_000_000_000_000)
        }
        if bitsPerSecond >= 8_000_000_000 {
            return String(format: "%.3f Gb/s", bitsPerSecond / 1_000_000_000)
        }
        return String(format: "%.3f b/s", bitsPerSecond)
    }

    static func formatByteRate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000_000_000 {
            return String(format: "%.3f PB/s", bytesPerSecond / 1_000_000_000_000_000)
        }
        if bytesPerSecond >= 1_000_000_000_000 {
            return String(format: "%.3f TB/s", bytesPerSecond / 1_000_000_000_000)
        }
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.3f GB/s", bytesPerSecond / 1_000_000_000)
        }
        return String(format: "%.3f B/s", bytesPerSecond)
    }
}

// IMPORTANT ARCHITECTURE DECLARATION:
//
// QRTL is proposed as a scalable monolithic 3D quantum-dot memory
// architecture intended to replace or exceed HBM-class memory.
//
// The SceneKit lattice dimensions, wire count, 100 kHz access values,
// data particles, and DWORD test below are DEMO / VISUALIZATION SCALE
// parameters only. They are not the intended production architecture.
//
// Production target:
// - Role: HBM replacement / near-compute memory
// - Aggregate sustained payload bandwidth: 1 PB/s per QRTL package
// - Scaling method: massively parallel QD cells -> banks -> tiles ->
//   layers -> monolithic 3D cube/package
//
// All hardware performance, energy, reliability, yield, latency, and
// cost values are proposed design targets until experimentally verified.

// MARK: - QD MEMORY PARAMETERS

struct QRTLMemoryParameters {

    // ---------------------------------------------------------

    // 3D LATTICE

    // ---------------------------------------------------------

    var columns: Int = 10

    var rows: Int = 8

    var layers: Int = 6

    var latticeSpacing: Float = 1.0

    var qdRadius: CGFloat = 0.11

    // ---------------------------------------------------------

    // QD PRINTING

    // ---------------------------------------------------------

    var qdPrintFrequencyHz: Double = 120.0

    var qdsPerJetEvent: Double = 1.0

    var printerUtilization: Double = 0.80

    var placementEfficiency: Double = 0.95

    // This remains the configured/model print duration.

    // The visual animation uses a separate print interval below.

    var qdAnimationDuration: TimeInterval = 0.035

    // ---------------------------------------------------------

    // ACCESS WIRES

    // ---------------------------------------------------------

    var wireCount: Int = 12

    var sitesPerWire: Int = 40

    var wireAnimationDuration: TimeInterval = 0.65

    // ---------------------------------------------------------

    // MEMORY

    // ---------------------------------------------------------

    var bitsPerQD: Double = 1.0

    var readChannels: Double = 12

    var writeChannels: Double = 12

    var readFrequencyHz: Double = 100_000

    var writeFrequencyHz: Double = 100_000

    var readUtilization: Double = 0.85

    var writeUtilization: Double = 0.85

    var readEfficiency: Double = 0.995

    var writeEfficiency: Double = 0.995

    // ---------------------------------------------------------

    // DATA ANIMATION

    // ---------------------------------------------------------

    var dataParticleCount: Int = 12

}

// MARK: - DATA RATE MODEL

struct QRTLDataRateModel {

    let parameters: QRTLMemoryParameters

    // N_QD = columns × rows × layers

    var totalQDSites: Double {

        Double(

            parameters.columns *

            parameters.rows *

            parameters.layers

        )

    }

    // C = N_QD × B_QD

    var storageBits: Double {

        totalQDSites *

        parameters.bitsPerQD

    }

    var storageBytes: Double {

        storageBits / 8.0

    }

    // ---------------------------------------------------------

    // WRITE

    //

    // R_in =

    // N_w × f_w × B_QD × U_w × η_w

    // ---------------------------------------------------------

    var writeBitsPerSecond: Double {

        parameters.writeChannels *

        parameters.writeFrequencyHz *

        parameters.bitsPerQD *

        parameters.writeUtilization *

        parameters.writeEfficiency

    }

    // ---------------------------------------------------------

    // READ

    //

    // R_out =

    // N_r × f_r × B_QD × U_r × η_r

    // ---------------------------------------------------------

    var readBitsPerSecond: Double {

        parameters.readChannels *

        parameters.readFrequencyHz *

        parameters.bitsPerQD *

        parameters.readUtilization *

        parameters.readEfficiency

    }

    var writeBytesPerSecond: Double {

        writeBitsPerSecond / 8.0

    }

    var readBytesPerSecond: Double {

        readBitsPerSecond / 8.0

    }

    // ---------------------------------------------------------

    // QD PRINTING RATE

    //

    // R_QD =

    // f_jet × QDs/event × U × η

    // ---------------------------------------------------------

    var qdsPrintedPerSecond: Double {

        parameters.qdPrintFrequencyHz *

        parameters.qdsPerJetEvent *

        parameters.printerUtilization *

        parameters.placementEfficiency

    }

    // ---------------------------------------------------------

    // THEORETICAL LIMITS

    // ---------------------------------------------------------

    var theoreticalWriteBitsPerSecond: Double {

        parameters.writeChannels *

        parameters.writeFrequencyHz *

        parameters.bitsPerQD

    }

    var theoreticalReadBitsPerSecond: Double {

        parameters.readChannels *

        parameters.readFrequencyHz *

        parameters.bitsPerQD

    }

    // ---------------------------------------------------------

    // FORMATTING

    // ---------------------------------------------------------

    static func formatRate(_ bitsPerSecond: Double) -> String {
        if bitsPerSecond >= 1_000_000_000_000_000 {
            return String(format: "%.3f Pb/s", bitsPerSecond / 1_000_000_000_000_000)
        }
        if bitsPerSecond >= 1_000_000_000_000 {
            return String(format: "%.3f Tb/s", bitsPerSecond / 1_000_000_000_000)
        }
        if bitsPerSecond >= 1_000_000_000 {
            return String(format: "%.3f Gb/s", bitsPerSecond / 1_000_000_000)
        }
        if bitsPerSecond >= 1_000_000 {
            return String(format: "%.3f Mb/s", bitsPerSecond / 1_000_000)
        }
        if bitsPerSecond >= 1_000 {
            return String(format: "%.3f kb/s", bitsPerSecond / 1_000)
        }
        return String(format: "%.3f b/s", bitsPerSecond)
    }

    static func formatBytes(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000_000_000 {
            return String(format: "%.3f PB/s", bytesPerSecond / 1_000_000_000_000_000)
        }
        if bytesPerSecond >= 1_000_000_000_000 {
            return String(format: "%.3f TB/s", bytesPerSecond / 1_000_000_000_000)
        }
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.3f GB/s", bytesPerSecond / 1_000_000_000)
        }
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.3f MB/s", bytesPerSecond / 1_000_000)
        }
        if bytesPerSecond >= 1_000 {
            return String(format: "%.3f KB/s", bytesPerSecond / 1_000)
        }
        return String(format: "%.3f B/s", bytesPerSecond)
    }

}

// MARK: - MANUFACTURING STATE

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


// MARK: - DWORD MEMORY VALIDATION

/// Engineering-level logical validation of one 32-bit memory word.
/// The test maps one DWORD to 32 physical QD lattice sites.
struct QRTLDWordMetrics {
    var memoryAddress: UInt32 = 0
    var cellStartIndex: Int = 0
    var cellEndIndex: Int = 31
    var writeCommand: UInt32 = 0
    var bitStates: [Int] = Array(repeating: 0, count: 32)
    var writeTimeSeconds: Double = 0
    var readAddress: UInt32 = 0
    var readSignals: [Double] = Array(repeating: 0, count: 32)
    var detectedBits: [Int] = Array(repeating: 0, count: 32)
    var readTimeSeconds: Double = 0
    var writeAccuracyPercent: Double = 0
    var readAccuracyPercent: Double = 0
    var retentionSeconds: Double = 0
    var retentionPercent: Double = 0
    var requestedCycles: Int = 0
    var successfulCycles: Int = 0
    var cycleSuccessRatePercent: Double = 0
    var incorrectBits: Int = 0
    var totalBitsTested: Int = 0
    var errorRatePercent: Double = 0
    var returnedDWORD: UInt32 = 0
    var verificationPassed: Bool = false
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

// MARK: - QRTL SCENE

@MainActor

final class QRTLQDJet3DPrintingScene {

    private let dataRateModel: QRTLDataRateModel

    let scene: SCNScene

    private let parameters:

        QRTLMemoryParameters

    private weak var state:

        QRTLManufacturingState?

    // ---------------------------------------------------------

    // ROOTS

    // ---------------------------------------------------------

    private let manufacturingRoot =

        SCNNode()

    private let printerRoot =

        SCNNode()

    private let latticeRoot =

        SCNNode()

    private let robotRoot =

        SCNNode()

    private let wireRoot =

        SCNNode()

    private let dataRoot =

        SCNNode()

    // ---------------------------------------------------------

    // PRINTER

    // ---------------------------------------------------------

    private let nozzle =

        SCNNode()

    private let nozzleCarriage =

        SCNNode()

    private let reservoir =

        SCNNode()

    // ---------------------------------------------------------

    // ROBOT

    // ---------------------------------------------------------

    private let robotArm =

        SCNNode()

    private let robotForearm =

        SCNNode()

    private let robotGripper =

        SCNNode()

    // ---------------------------------------------------------

    // LATTICE

    // ---------------------------------------------------------

    private var qdNodes:

        [SCNNode] = []

    private var accessWires:

        [SCNNode] = []

    private var dataParticles:

        [SCNNode] = []

    private var layerVolumes:

        [SCNNode] = []

    private var latticeCube:

        SCNNode?

    // First 32 QD sites are the physical cells used by the DWORD test.
    private var dwordBarrierNodes: [SCNNode] = []

    // ---------------------------------------------------------

    // ANIMATION

    // ---------------------------------------------------------

    private var animationGeneration = 0

    init(
        parameters: QRTLMemoryParameters,
        state: QRTLManufacturingState
    ) {
        self.parameters = parameters

        self.state = state

        self.dataRateModel =
            QRTLDataRateModel(
                parameters: parameters
            )

        self.scene =
            SCNScene()

        configureScene()

        buildEnvironment()

        buildQDJetPrinter()

        buildLattice()

        buildDWORDStorageIndicators()

        buildRoboticWireSystem()

        buildDataInterface()
    }
    
    private func configureScene() {

        // ================================================================

        // Scene

        // ================================================================

        scene.background.contents = UIColor(

            white: 0.008,

            alpha: 1.0

        )



        // ================================================================

        // Manufacturing root

        // ================================================================

        scene.rootNode.addChildNode(manufacturingRoot)

        manufacturingRoot.addChildNode(printerRoot)

        manufacturingRoot.addChildNode(latticeRoot)

        manufacturingRoot.addChildNode(robotRoot)

        manufacturingRoot.addChildNode(wireRoot)

        manufacturingRoot.addChildNode(dataRoot)



        // ================================================================
        // Camera
        // ================================================================

        let cameraNode = SCNNode()
        let camera = SCNCamera()

        camera.fieldOfView = 50.0
        camera.zNear = 0.1
        camera.zFar = 200.0

        cameraNode.camera = camera

        // ---------------------------------------------------------------
        // Frame the camera around the actual scene geometry instead of a
        // fixed hand-tuned offset, so it zooms in tightly on the lattice
        // (and stays correctly framed if columns/rows/layers/spacing
        // ever change) rather than sitting far back with the lattice
        // occupying only a small part of the frame.
        //
        // The scene the camera must fit spans:
        //   - the QD lattice footprint: columns x rows x latticeSpacing
        //   - vertically, from the base of the lattice (y = 0.75, set
        //     in buildLattice()) up to the nozzle carriage height
        //     (y = 6.5, set in the printer setup above), so the
        //     nozzle stays in frame together with the growing cube.
        // ---------------------------------------------------------------

        let latticeHalfWidth =
            Float(parameters.columns - 1) * parameters.latticeSpacing * 0.5
        let latticeHalfDepth =
            Float(parameters.rows - 1) * parameters.latticeSpacing * 0.5

        let sceneBottomY: Float = 0.75
        let sceneTopY: Float = 6.5
        let sceneCenterY = (sceneBottomY + sceneTopY) * 0.5
        let sceneHalfHeight = (sceneTopY - sceneBottomY) * 0.5

        // Point the camera at the true center of that volume.
        let cameraTarget = SCNVector3(0.0, sceneCenterY, 0.0)

        // Half-diagonal of the scene's bounding box, padded slightly so
        // the outermost QD spheres and the nozzle aren't clipped at the
        // edge of the frame.
        let sceneBoundingRadius =
            sqrt(
                latticeHalfWidth * latticeHalfWidth +
                latticeHalfDepth * latticeHalfDepth +
                sceneHalfHeight * sceneHalfHeight
            ) + Float(parameters.qdRadius)

        // Distance needed to fit a sphere of sceneBoundingRadius inside
        // the camera's field of view, with a small framing margin.
        let halfFieldOfViewRadians =
            Float(camera.fieldOfView) * 0.5 * Float.pi / 180.0

        let framingPadding: Float = 1.1

        let cameraDistance =
            (sceneBoundingRadius / sin(halfFieldOfViewRadians)) *
            framingPadding

        // Keep the same cinematic viewing angle as before (slightly to
        // the side, slightly above, looking back toward the lattice),
        // just placed at the distance that actually zooms in on it.
        let viewDirectionRaw = SCNVector3(0.6, 0.35, 0.8)
        let viewDirectionLength = sqrt(
            viewDirectionRaw.x * viewDirectionRaw.x +
            viewDirectionRaw.y * viewDirectionRaw.y +
            viewDirectionRaw.z * viewDirectionRaw.z
        )
        let viewDirection = SCNVector3(
            viewDirectionRaw.x / viewDirectionLength,
            viewDirectionRaw.y / viewDirectionLength,
            viewDirectionRaw.z / viewDirectionLength
        )

        cameraNode.position = SCNVector3(
            cameraTarget.x + viewDirection.x * cameraDistance,
            cameraTarget.y + viewDirection.y * cameraDistance,
            cameraTarget.z + viewDirection.z * cameraDistance
        )

        // Point camera directly at the lattice/nozzle volume.
        cameraNode.lookAt(cameraTarget)

        scene.rootNode.addChildNode(cameraNode)



        // ================================================================

        // Lighting

        // ================================================================

        // Ambient light

        let ambientNode = SCNNode()

        let ambientLight = SCNLight()

        ambientLight.type = .ambient

        ambientLight.intensity = 650.0

        ambientLight.color = UIColor(

            white: 0.75,

            alpha: 1.0

        )

        ambientNode.light = ambientLight

        scene.rootNode.addChildNode(ambientNode)



        // Key light

        let keyLightNode = SCNNode()

        let keyLight = SCNLight()

        keyLight.type = .omni

        keyLight.intensity = 1400.0

        keyLight.color = UIColor(

            white: 1.0,

            alpha: 1.0

        )

        keyLight.attenuationStartDistance = 5.0

        keyLight.attenuationEndDistance = 50.0

        keyLightNode.light = keyLight

        keyLightNode.position = SCNVector3(

            8.0,

            13.0,

            10.0

        )

        scene.rootNode.addChildNode(keyLightNode)



        // Fill light

        let fillLightNode = SCNNode()

        let fillLight = SCNLight()

        fillLight.type = .omni

        fillLight.intensity = 900.0

        fillLight.color = UIColor(

            white: 0.85,

            alpha: 1.0

        )

        fillLight.attenuationStartDistance = 5.0

        fillLight.attenuationEndDistance = 45.0

        fillLightNode.light = fillLight

        fillLightNode.position = SCNVector3(

            -10.0,

            8.0,

            -8.0

        )

        scene.rootNode.addChildNode(fillLightNode)

    }

    // MARK: - ENVIRONMENT

    private func buildEnvironment() {

        let baseGeometry =

            SCNBox(

                width: 20,

                height: 0.35,

                length: 15,

                chamferRadius: 0.12

            )

        baseGeometry.firstMaterial?.diffuse.contents =

            UIColor(

                white: 0.08,

                alpha: 1

            )

        let base =

            SCNNode(

                geometry: baseGeometry

            )

        base.position =

            SCNVector3(

                0,

                -0.25,

                0

            )

        manufacturingRoot.addChildNode(

            base

        )

        // -----------------------------------------------------

        // PLATFORM

        // -----------------------------------------------------

        let platformGeometry =

            SCNBox(

                width: 9,

                height: 0.3,

                length: 9,

                chamferRadius: 0.08

            )

        platformGeometry.firstMaterial?.diffuse.contents =

            UIColor(

                white: 0.15,

                alpha: 1

            )

        let platform =

            SCNNode(

                geometry: platformGeometry

            )

        platform.position =

            SCNVector3(

                -1.0,

                0.05,

                0

            )

        manufacturingRoot.addChildNode(

            platform

        )

    }

    // MARK: - QD JET PRINTER

    private func buildQDJetPrinter() {

        // -----------------------------------------------------

        // RESERVOIR

        // -----------------------------------------------------

        let reservoirGeometry =

            SCNCylinder(

                radius: 0.7,

                height: 1.8

            )

        reservoirGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemBlue

        reservoirGeometry.firstMaterial?.emission.contents =

            UIColor(

                red: 0.0,

                green: 0.0,

                blue: 0.15,

                alpha: 1.0

            )

        reservoir.geometry =

            reservoirGeometry

        reservoir.position =

            SCNVector3(

                -7.0,

                4.0,

                -1.0

            )

        printerRoot.addChildNode(

            reservoir

        )

        // -----------------------------------------------------

        // SUPPLY TUBE

        // -----------------------------------------------------

        let supplyTube =

            makeCylinder(

                radius: 0.10,

                height: 3.6,

                color: UIColor.systemBlue

            )

        supplyTube.position =

            SCNVector3(

                -5.2,

                4.0,

                -1.0

            )

        supplyTube.eulerAngles.z =

            .pi / 2

        printerRoot.addChildNode(

            supplyTube

        )

        // -----------------------------------------------------

        // GANTRY

        // -----------------------------------------------------

        let gantryGeometry =

            SCNBox(

                width: 9,

                height: 0.35,

                length: 0.35,

                chamferRadius: 0.05

            )

        gantryGeometry.firstMaterial?.diffuse.contents =

            UIColor(

                white: 0.25,

                alpha: 1

            )

        let gantry =

            SCNNode(

                geometry: gantryGeometry

            )

        gantry.position =

            SCNVector3(

                -1.5,

                7.0,

                0

            )

        printerRoot.addChildNode(

            gantry

        )

        // -----------------------------------------------------

        // CARRIAGE

        // -----------------------------------------------------

        let carriageGeometry =

            SCNBox(

                width: 0.65,

                height: 0.65,

                length: 0.65,

                chamferRadius: 0.08

            )

        carriageGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemGray

        nozzleCarriage.geometry =

            carriageGeometry

        nozzleCarriage.position =

            SCNVector3(

                -2,

                6.5,

                0

            )

        printerRoot.addChildNode(

            nozzleCarriage

        )

        // -----------------------------------------------------

        // NOZZLE

        // -----------------------------------------------------

        let nozzleGeometry =

            SCNCone(

                topRadius: 0.11,

                bottomRadius: 0.025,

                height: 0.85

            )

        nozzleGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemOrange

        nozzleGeometry.firstMaterial?.emission.contents =

            UIColor.systemOrange

        nozzle.geometry =

            nozzleGeometry

        nozzle.position =

            SCNVector3(

                -2,

                5.9,

                0

            )

        printerRoot.addChildNode(

            nozzle

        )

    }

    // MARK: - 3D LATTICE

    private func buildLattice() {

        qdNodes.removeAll()

        let startX =

            -Float(parameters.columns - 1)

            *

            parameters.latticeSpacing

            *

            0.5

        let startZ =

            -Float(parameters.rows - 1)

            *

            parameters.latticeSpacing

            *

            0.5

        let startY: Float = 0.75

        // -----------------------------------------------------

        // QD STORAGE SITES

        // -----------------------------------------------------

        for layer in 0..<parameters.layers {

            for row in 0..<parameters.rows {

                for column in 0..<parameters.columns {

                    let geometry =

                        SCNSphere(

                            radius:

                                parameters.qdRadius

                        )

                    geometry.firstMaterial?.diffuse.contents =

                        UIColor.systemTeal

                    geometry.firstMaterial?.emission.contents =

                        UIColor.systemTeal

                    let qd =

                        SCNNode(

                            geometry: geometry

                        )

                    qd.name =

                        "QD_\\(column)_\\(row)_\\(layer)"

                    qd.position =

                        SCNVector3(

                            startX +

                            Float(column)

                            *

                            parameters.latticeSpacing,

                            startY +

                            Float(layer)

                            *

                            parameters.latticeSpacing,

                            startZ +

                            Float(row)

                            *

                            parameters.latticeSpacing

                        )

                    qd.opacity = 0

                    qd.scale =

                        SCNVector3(

                            0.01,

                            0.01,

                            0.01

                        )

                    qdNodes.append(qd)

                    latticeRoot.addChildNode(

                        qd

                    )

                }

            }

        }

        // -----------------------------------------------------

        // BUILD LAYER VOLUMES

        // -----------------------------------------------------

        let width =

            CGFloat(parameters.columns)

            *

            CGFloat(parameters.latticeSpacing)

        let depth =

            CGFloat(parameters.rows)

            *

            CGFloat(parameters.latticeSpacing)

        let layerHeight =

            CGFloat(parameters.latticeSpacing)

        for layer in 0..<parameters.layers {

            let geometry =

                SCNBox(

                    width: width,

                    height: layerHeight,

                    length: depth,

                    chamferRadius: 0.03

                )

            let material =

                SCNMaterial()

            material.diffuse.contents =

                UIColor(

                    red: 0.0,

                    green: 1.0,

                    blue: 1.0,

                    alpha: 0.08

                )

            material.emission.contents =

                UIColor(

                    red: 0.0,

                    green: 0.05,

                    blue: 0.05,

                    alpha: 0.04

                )

            material.isDoubleSided =

                true

            geometry.materials =

                [material]

            let volume =

                SCNNode(

                    geometry: geometry

                )

            volume.position =

                SCNVector3(

                    0,

                    0.75 +

                    Float(layer)

                    *

                    parameters.latticeSpacing,

                    0

                )

            volume.opacity = 0

            latticeRoot.addChildNode(

                volume

            )

            layerVolumes.append(

                volume

            )

        }

        createFinalCubeOutline()

    }

    // MARK: - FINAL CUBE OUTLINE

    private func createFinalCubeOutline() {

        let width =

            CGFloat(parameters.columns)

            *

            CGFloat(parameters.latticeSpacing)

        let depth =

            CGFloat(parameters.rows)

            *

            CGFloat(parameters.latticeSpacing)

        let height =

            CGFloat(parameters.layers)

            *

            CGFloat(parameters.latticeSpacing)

        let cube =

            SCNBox(

                width: width + 0.15,

                height: height + 0.15,

                length: depth + 0.15,

                chamferRadius: 0.03

            )

        let material =

            SCNMaterial()

        material.diffuse.contents =

            UIColor.systemCyan

        material.emission.contents =

            UIColor.systemCyan

        material.fillMode =

            .lines

        material.transparency =

            0.55

        cube.materials =

            [material]

        let cubeNode =

            SCNNode(

                geometry: cube

            )

        cubeNode.position =

            SCNVector3(

                0,

                0.75 +

                Float(height / 2.0),

                0

            )

        cubeNode.opacity = 0

        latticeRoot.addChildNode(

            cubeNode

        )

        latticeCube =

            cubeNode

    }

    // MARK: - DWORD STORAGE VISUALIZATION

    private func buildDWORDStorageIndicators() {
        dwordBarrierNodes.removeAll()

        let count = min(32, qdNodes.count)
        for index in 0..<count {
            let geometry = SCNTorus(
                ringRadius: 0.18,
                pipeRadius: 0.025
            )
            geometry.firstMaterial?.diffuse.contents = UIColor.systemGray
            geometry.firstMaterial?.emission.contents = UIColor.clear

            let barrier = SCNNode(geometry: geometry)
            barrier.name = "dwordBarrier_\(index)"
            barrier.position = qdNodes[index].position
            barrier.opacity = 0.0

            latticeRoot.addChildNode(barrier)
            dwordBarrierNodes.append(barrier)
        }
    }

    func updateDWORDStorageVisualization(_ metrics: QRTLDWordMetrics) {
        guard dwordBarrierNodes.count == 32 else { return }

        let hasTestData = metrics.totalBitsTested > 0 || metrics.writeCommand != 0

        for index in 0..<32 {
            let bit = metrics.bitStates[index]
            let barrier = dwordBarrierNodes[index]
            guard let material = barrier.geometry?.firstMaterial else { continue }

            barrier.opacity = hasTestData ? 1.0 : 0.0

            if bit == 1 {
                material.diffuse.contents = UIColor.systemGreen
                material.emission.contents = UIColor.systemGreen
                barrier.scale = SCNVector3(1.35, 1.35, 1.35)
            } else {
                material.diffuse.contents = UIColor.systemGray
                material.emission.contents = UIColor.clear
                barrier.scale = SCNVector3(0.90, 0.90, 0.90)
            }
        }
    }

    // MARK: - ROBOTIC ARM

    private func buildRoboticWireSystem() {

        // -----------------------------------------------------

        // ROBOT BASE

        // -----------------------------------------------------

        let baseGeometry =

            SCNCylinder(

                radius: 1.0,

                height: 0.55

            )

        baseGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemGray

        let base =

            SCNNode(

                geometry: baseGeometry

            )

        base.position =

            SCNVector3(

                7.0,

                0.45,

                0

            )

        robotRoot.addChildNode(

            base

        )

        // -----------------------------------------------------

        // ARM

        // -----------------------------------------------------

        let armGeometry =

            SCNCylinder(

                radius: 0.25,

                height: 3.2

            )

        armGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemGray2

        robotArm.geometry =

            armGeometry

        robotArm.position =

            SCNVector3(

                7.0,

                2.2,

                0

            )

        robotRoot.addChildNode(

            robotArm

        )

        // -----------------------------------------------------

        // FOREARM

        // -----------------------------------------------------

        let forearmGeometry =

            SCNCylinder(

                radius: 0.20,

                height: 2.6

            )

        forearmGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemGray3

        robotForearm.geometry =

            forearmGeometry

        robotForearm.position =

            SCNVector3(

                7.0,

                4.8,

                0

            )

        robotRoot.addChildNode(

            robotForearm

        )

        // -----------------------------------------------------

        // GRIPPER

        // -----------------------------------------------------

        let gripperGeometry =

            SCNBox(

                width: 0.55,

                height: 0.28,

                length: 0.55,

                chamferRadius: 0.04

            )

        gripperGeometry.firstMaterial?.diffuse.contents =

            UIColor.systemOrange

        gripperGeometry.firstMaterial?.emission.contents =

            UIColor(

                red: 0.15,

                green: 0.06,

                blue: 0,

                alpha: 1

            )

        robotGripper.geometry =

            gripperGeometry

        robotGripper.position =

            SCNVector3(

                7.0,

                6.0,

                0

            )

        robotRoot.addChildNode(

            robotGripper

        )

    }

    // MARK: - ACCESS-WIRE

    private func createAccessWire(

        index: Int,

        x: Float,

        z: Float

    ) -> SCNNode {

        let cubeHeight =

            Float(parameters.layers)

            *

            parameters.latticeSpacing

        let geometry =

            SCNCylinder(

                radius: 0.045,

                height:

                    CGFloat(cubeHeight + 0.8)

            )

        geometry.firstMaterial?.diffuse.contents =

            UIColor.systemYellow

        geometry.firstMaterial?.emission.contents =

            UIColor(

                red: 0.20,

                green: 0.16,

                blue: 0,

                alpha: 1

            )

        let wire =

            SCNNode(

                geometry: geometry

            )

        wire.name =

            "ACCESS_WIRE_\\(index)"

        wire.position =

            SCNVector3(

                x,

                0.75 +

                cubeHeight / 2.0,

                z

            )

        return wire

    }

    // MARK: - DATA INTERFACE

    private func buildDataInterface() {

        let geometry =

            SCNBox(

                width: 3.5,

                height: 0.65,

                length: 3.5,

                chamferRadius: 0.10

            )

        geometry.firstMaterial?.diffuse.contents =

            UIColor.systemIndigo

        geometry.firstMaterial?.emission.contents =

            UIColor(

                red: 0.05,

                green: 0,

                blue: 0.15,

                alpha: 1

            )

        let interfaceNode =

            SCNNode(

                geometry: geometry

            )

        interfaceNode.position =

            SCNVector3(

                7,

                0.85,

                -4

            )

        dataRoot.addChildNode(

            interfaceNode

        )

    }

    // MARK: - START MANUFACTURING

    func startManufacturing() {

        animationGeneration += 1

        let generation =

            animationGeneration

        // -----------------------------------------------------

        // RESET QDs

        // -----------------------------------------------------

        for qd in qdNodes {

            qd.removeAllActions()

            qd.opacity = 0

            qd.scale =

                SCNVector3(

                    0.01,

                    0.01,

                    0.01

                )

        }

        // -----------------------------------------------------

        // RESET LAYER VOLUMES

        // -----------------------------------------------------

        for volume in layerVolumes {

            volume.removeAllActions()

            volume.opacity = 0

        }

        // -----------------------------------------------------

        // RESET CUBE

        // -----------------------------------------------------

        latticeCube?.removeAllActions()

        latticeCube?.opacity = 0

        // -----------------------------------------------------

        // REMOVE WIRES

        // -----------------------------------------------------

        for wire in accessWires {

            wire.removeAllActions()

            wire.removeFromParentNode()

        }

        accessWires.removeAll()

        // -----------------------------------------------------

        // REMOVE DATA PARTICLES

        // -----------------------------------------------------

        for particle in dataParticles {

            particle.removeAllActions()

            particle.removeFromParentNode()

        }

        dataParticles.removeAll()

        // -----------------------------------------------------

        // RESET NOZZLE

        // -----------------------------------------------------

        nozzle.removeAllActions()

        nozzle.position =

            SCNVector3(

                -2,

                5.9,

                0

            )

        nozzleCarriage.removeAllActions()

        nozzleCarriage.position =

            SCNVector3(

                -2,

                6.5,

                0

            )

        // -----------------------------------------------------

        // UPDATE STATE

        // -----------------------------------------------------

        let rateModel =

            QRTLDataRateModel(

                parameters: parameters

            )

        state?.update(

            layer: 0,

            deposited: 0,

            total: qdNodes.count,

            wires: 0,

            totalWires: parameters.wireCount,

            state: "QD-JET INITIALIZING",

            rateModel: rateModel

        )

        // -----------------------------------------------------

        // START FIRST LAYER

        // -----------------------------------------------------

        animateLayer(

            layer: 0,

            generation: generation

        )

    }

    // MARK: - LAYER PRINTING

    private func animateLayer(

        layer: Int,

        generation: Int

    ) {

        // ---------------------------------------------------------

        // CANCEL OLD ANIMATION

        // ---------------------------------------------------------

        guard generation == animationGeneration else {

            return

        }

        // ---------------------------------------------------------

        // ALL LAYERS COMPLETE

        // ---------------------------------------------------------

        guard layer < parameters.layers else {

            finishLattice(

                generation: generation

            )

            return

        }

        // ---------------------------------------------------------

        // LAYER INDEX RANGE

        // ---------------------------------------------------------

        let sitesPerLayer =

            parameters.columns *

            parameters.rows

        let layerStartIndex =

            layer *

            sitesPerLayer

        let layerEndIndex =

            layerStartIndex +

            sitesPerLayer

        // ---------------------------------------------------------

        // RATE MODEL

        // ---------------------------------------------------------

        let rateModel =

            QRTLDataRateModel(

                parameters: parameters

            )

        // ---------------------------------------------------------

        // UPDATE STATE

        // ---------------------------------------------------------

        state?.update(

            layer: layer + 1,

            deposited: layerStartIndex,

            total: qdNodes.count,

            wires: accessWires.count,

            totalWires: parameters.wireCount,

            state:

                "QD DEPOSITION — LAYER \\(layer + 1)/\\(parameters.layers)",

            rateModel: rateModel

        )

        // ---------------------------------------------------------

        // SHOW CURRENT LAYER VOLUME

        // ---------------------------------------------------------

        if layer < layerVolumes.count {

            let layerVolume =

                layerVolumes[layer]

            layerVolume.removeAllActions()

            layerVolume.opacity = 0

            layerVolume.runAction(

                SCNAction.fadeIn(

                    duration: 0.25

                )

            )

        }

        // ---------------------------------------------------------

        // PRINT TIMING

        //

        // The visual jet lasts 0.12 seconds.

        //

        // The old interval was 0.035 seconds.

        //

        // That caused multiple jets to overlap heavily.

        //

        // 0.14 seconds gives the viewer a clear:

        //

        // nozzle movement

        //       ↓

        // jet

        //       ↓

        // QD placement

        //       ↓

        // next QD

        // ---------------------------------------------------------

        let printInterval:

            TimeInterval = 0.14

        // ---------------------------------------------------------

        // LOCAL INDEX

        //

        // This replaces the nonexistent

        // depositedQDsInCurrentLayer property.

        // ---------------------------------------------------------

        var index =

            layerStartIndex

        // ---------------------------------------------------------

        // PRINT NEXT QD

        // ---------------------------------------------------------

        func printNextQD() {

            guard generation ==

                    self.animationGeneration

            else {

                return

            }

            // -----------------------------------------------------

            // LAYER COMPLETE

            // -----------------------------------------------------

            guard index < layerEndIndex else {

                DispatchQueue.main.asyncAfter(

                    deadline:

                        .now() + 0.30

                ) {

                    guard generation ==

                            self.animationGeneration

                    else {

                        return

                    }

                    self.animateLayer(

                        layer: layer + 1,

                        generation: generation

                    )

                }

                return

            }

            // -----------------------------------------------------

            // GET QD

            // -----------------------------------------------------

            guard index < self.qdNodes.count else {

                return

            }

            let qd =

                self.qdNodes[index]

            // -----------------------------------------------------

            // CONVERT QD POSITION

            //

            // qd.position is LOCAL to latticeRoot.

            //

            // The nozzle and jet belong to printerRoot.

            //

            // Convert the QD local position into printerRoot space.

            // -----------------------------------------------------

            let targetInPrinterSpace =

                self.latticeRoot.convertPosition(

                    qd.position,

                    to: self.printerRoot

                )

            // -----------------------------------------------------

            // NOZZLE POSITION

            //

            // Keep the nozzle at the printing height.

            // -----------------------------------------------------

            let nozzleTarget =

                SCNVector3(

                    targetInPrinterSpace.x,

                    5.9,

                    targetInPrinterSpace.z

                )

            let carriageTarget =

                SCNVector3(

                    targetInPrinterSpace.x,

                    6.5,

                    targetInPrinterSpace.z

                )

            // -----------------------------------------------------

            // MOVE NOZZLE

            // -----------------------------------------------------

            let moveNozzle =

                SCNAction.move(

                    to: nozzleTarget,

                    duration: 0.025

                )

            // -----------------------------------------------------

            // PRINT QD

            // -----------------------------------------------------

            let printAction =

                SCNAction.run { [weak self, weak qd] _ in

                    guard let self = self else {

                        return

                    }

                    guard let qd = qd else {

                        return

                    }

                    guard generation ==

                            self.animationGeneration

                    else {

                        return

                    }

                    // -------------------------------------------------

                    // CREATE VISIBLE JET

                    //

                    // targetInPrinterSpace is ALREADY in printerRoot

                    // coordinate space.

                    //

                    // Do NOT convert it again.

                    // -------------------------------------------------

                    self.animateQDJet(

                        from: self.nozzle.position,

                        to: targetInPrinterSpace

                    )

                    // -------------------------------------------------

                    // MAKE QD VISIBLE

                    // -------------------------------------------------

                    qd.removeAllActions()

                    qd.opacity = 0

                    qd.scale =

                        SCNVector3(

                            0.01,

                            0.01,

                            0.01

                        )

                    // -------------------------------------------------

                    // QD APPEARANCE

                    // -------------------------------------------------

                    let appear =

                        SCNAction.group(

                            [

                                SCNAction.fadeIn(

                                    duration: 0.025

                                ),

                                SCNAction.scale(

                                    to: 1.0,

                                    duration: 0.045

                                )

                            ]

                        )

                    qd.runAction(

                        appear

                    )

                    // -------------------------------------------------

                    // UPDATE MANUFACTURING STATE

                    // -------------------------------------------------

                    let deposited =

                        index + 1

                    let rateModel =

                        QRTLDataRateModel(

                            parameters:

                                self.parameters

                        )

                    self.state?.update(

                        layer:

                            layer + 1,

                        deposited:

                            deposited,

                        total:

                            self.qdNodes.count,

                        wires:

                            self.accessWires.count,

                        totalWires:

                            self.parameters.wireCount,

                        state:

                            "QD DEPOSITION — LAYER \\(layer + 1)/\\(self.parameters.layers)",

                        rateModel:

                            rateModel

                    )

                }

            // -----------------------------------------------------

            // NOZZLE → PRINT

            // -----------------------------------------------------

            self.nozzle.runAction(

                SCNAction.sequence(

                    [

                        moveNozzle,

                        printAction

                    ]

                )

            )

            // -----------------------------------------------------

            // CARRIAGE

            // -----------------------------------------------------

            self.nozzleCarriage.runAction(

                SCNAction.move(

                    to: carriageTarget,

                    duration: 0.025

                )

            )

            // -----------------------------------------------------

            // ADVANCE INDEX

            // -----------------------------------------------------

            index += 1

            // -----------------------------------------------------

            // SCHEDULE NEXT QD

            // -----------------------------------------------------

            DispatchQueue.main.asyncAfter(

                deadline:

                    .now() + printInterval

            ) {

                guard generation ==

                        self.animationGeneration

                else {

                    return

                }

                printNextQD()

            }

        }

        // ---------------------------------------------------------

        // START PRINTING

        // ---------------------------------------------------------

        printNextQD()

    }

    // MARK: - QD JET

    private func animateQDJet(

        from start: SCNVector3,

        to targetInPrinterSpace: SCNVector3

    ) {

        // ---------------------------------------------------------

        // CREATE JET PARTICLE

        // ---------------------------------------------------------

        let geometry =

            SCNSphere(

                radius: 0.045

            )

        geometry.firstMaterial?.diffuse.contents =

            UIColor.systemOrange

        geometry.firstMaterial?.emission.contents =

            UIColor.systemOrange

        let jet =

            SCNNode(

                geometry: geometry

            )

        // ---------------------------------------------------------

        // IMPORTANT:

        //

        // jet is a child of printerRoot.

        //

        // Therefore both start and target MUST be in printerRoot

        // coordinate space.

        //

        // animateLayer() already converted the target.

        //

        // DO NOT perform another latticeRoot conversion here.

        // ---------------------------------------------------------

        jet.position =

            start

        printerRoot.addChildNode(

            jet

        )

        // ---------------------------------------------------------

        // JET MOVEMENT

        // ---------------------------------------------------------

        let move =

            SCNAction.move(

                to: targetInPrinterSpace,

                duration: 0.12

            )

        // ---------------------------------------------------------

        // JET SCALE

        // ---------------------------------------------------------

        let scale =

            SCNAction.sequence(

                [

                    SCNAction.scale(

                        to: 1.5,

                        duration: 0.06

                    ),

                    SCNAction.scale(

                        to: 0.5,

                        duration: 0.06

                    )

                ]

            )

        // ---------------------------------------------------------

        // COMPLETE ANIMATION

        // ---------------------------------------------------------

        let animation =

            SCNAction.group(

                [

                    move,

                    scale

                ]

            )

        // ---------------------------------------------------------

        // REMOVE AFTER COMPLETION

        // ---------------------------------------------------------

        jet.runAction(

            SCNAction.sequence(

                [

                    animation,

                    SCNAction.removeFromParentNode()

                ]

            )

        )

    }

    // MARK: - COMPLETE CUBE

    private func finishLattice(

        generation: Int

    ) {

        guard generation ==

                animationGeneration

        else {

            return

        }

        // ---------------------------------------------------------

        // UPDATE STATE

        // ---------------------------------------------------------

        let rateModel =

            QRTLDataRateModel(

                parameters: parameters

            )

        state?.update(

            layer: parameters.layers,

            deposited: qdNodes.count,

            total: qdNodes.count,

            wires: 0,

            totalWires: parameters.wireCount,

            state: "3D QD LATTICE COMPLETED",

            rateModel: rateModel

        )

        // ---------------------------------------------------------

        // SHOW COMPLETE CUBE

        // ---------------------------------------------------------

        latticeCube?.removeAllActions()

        latticeCube?.opacity = 0

        latticeCube?.runAction(

            SCNAction.fadeIn(

                duration: 0.8

            )

        )

        // ---------------------------------------------------------

        // CUBE PULSE

        // ---------------------------------------------------------

        let pulse =

            SCNAction.sequence(

                [

                    SCNAction.fadeOpacity(

                        to: 0.35,

                        duration: 0.5

                    ),

                    SCNAction.fadeOpacity(

                        to: 0.75,

                        duration: 0.5

                    )

                ]

            )

        latticeCube?.runAction(

            SCNAction.sequence(

                [

                    SCNAction.wait(

                        duration: 0.8

                    ),

                    SCNAction.repeat(

                        pulse,

                        count: 2

                    )

                ]

            )

        )

        // ---------------------------------------------------------

        // START ROBOTIC WIRE PLACEMENT

        // ---------------------------------------------------------

        DispatchQueue.main.asyncAfter(

            deadline:

                .now() + 1.8

        ) {

            guard generation ==

                    self.animationGeneration

            else {

                return

            }

            self.animateRoboticWirePlacement(

                generation: generation

            )

        }

    }

    // MARK: - ROBOTIC ACCESS WIRES

    private func animateRoboticWirePlacement(

        generation: Int

    ) {

        guard generation ==

                animationGeneration

        else {

            return

        }

        state?.status =

            "ROBOTIC ACCESS-WIRE PLACEMENT"

        placeWire(

            index: 0,

            generation: generation

        )

    }

    // MARK: - PLACE WIRE

    private func placeWire(

        index: Int,

        generation: Int

    ) {

        guard generation ==

                animationGeneration

        else {

            return

        }

        guard index <

                parameters.wireCount

        else {

            let rateModel =

                QRTLDataRateModel(

                    parameters: parameters

                )

            state?.update(

                layer: parameters.layers,

                deposited: qdNodes.count,

                total: qdNodes.count,

                wires: parameters.wireCount,

                totalWires: parameters.wireCount,

                state: "ACCESS WIRES REGISTERED",

                rateModel: rateModel

            )

            DispatchQueue.main.asyncAfter(

                deadline:

                    .now() + 0.8

            ) {

                guard generation ==

                        self.animationGeneration

                else {

                    return

                }

                self.animateDataTransfer(

                    generation: generation

                )

            }

            return

        }

        // ---------------------------------------------------------

        // SELECT LATTICE COLUMN

        // ---------------------------------------------------------

        let column =

            index %

            parameters.columns

        let row =

            (index /

             parameters.columns)

            %

            parameters.rows

        let startX =

            -Float(parameters.columns - 1)

            *

            parameters.latticeSpacing

            *

            0.5

        let startZ =

            -Float(parameters.rows - 1)

            *

            parameters.latticeSpacing

            *

            0.5

        let targetX =

            startX +

            Float(column)

            *

            parameters.latticeSpacing

        let targetZ =

            startZ +

            Float(row)

            *

            parameters.latticeSpacing

        // ---------------------------------------------------------

        // CREATE WIRE

        // ---------------------------------------------------------

        let wire =

            createAccessWire(

                index: index,

                x: targetX,

                z: targetZ

            )

        let cubeHeight =

            Float(parameters.layers)

            *

            parameters.latticeSpacing

        let wireTopY =

            0.75 +

            cubeHeight +

            0.45

        let wireBottomY =

            0.75 +

            cubeHeight / 2.0

        // ---------------------------------------------------------

        // START AT ROBOT

        // ---------------------------------------------------------

        wire.position =

            SCNVector3(

                7,

                wireTopY + 3,

                0

            )

        wire.opacity = 0

        wireRoot.addChildNode(

            wire

        )

        accessWires.append(

            wire

        )

        // ---------------------------------------------------------

        // ROBOT MOVEMENT

        // ---------------------------------------------------------

        let moveRobotToPickup =

            SCNAction.move(

                to:

                    SCNVector3(

                        7,

                        wireTopY + 2.5,

                        0

                    ),

                duration: 0.30

            )

        let moveToLattice =

            SCNAction.move(

                to:

                    SCNVector3(

                        targetX,

                        wireTopY,

                        targetZ

                    ),

                duration: 0.45

            )

        let descendWire =

            SCNAction.move(

                to:

                    SCNVector3(

                        targetX,

                        wireBottomY,

                        targetZ

                    ),

                duration: 0.65

            )

        // ---------------------------------------------------------

        // WIRE MOVEMENT

        // ---------------------------------------------------------

        wire.runAction(

            SCNAction.sequence(

                [

                    SCNAction.move(

                        to:

                            SCNVector3(

                                targetX,

                                wireTopY,

                                targetZ

                            ),

                        duration: 0.45

                    ),

                    SCNAction.fadeIn(

                        duration: 0.20

                    ),

                    descendWire,

                    SCNAction.run { [weak self] _ in

                        guard let self = self else {

                            return

                        }

                        guard generation ==

                                self.animationGeneration

                        else {

                            return

                        }

                        let rateModel =

                            QRTLDataRateModel(

                                parameters:

                                    self.parameters

                            )

                        self.state?.update(

                            layer:

                                self.parameters.layers,

                            deposited:

                                self.qdNodes.count,

                            total:

                                self.qdNodes.count,

                            wires:

                                index + 1,

                            totalWires:

                                self.parameters.wireCount,

                            state:

                                "WIRE \\(index + 1) REGISTERED",

                            rateModel:

                                rateModel

                        )

                    }

                ]

            )

        )

        // ---------------------------------------------------------

        // GRIPPER

        // ---------------------------------------------------------

        robotGripper.runAction(

            SCNAction.sequence(

                [

                    moveRobotToPickup,

                    moveToLattice,

                    SCNAction.move(

                        to:

                            SCNVector3(

                                targetX,

                                wireBottomY + 0.5,

                                targetZ

                            ),

                        duration: 0.65

                    )

                ]

            )

        )

        // ---------------------------------------------------------

        // FOREARM

        // ---------------------------------------------------------

        robotForearm.runAction(

            SCNAction.move(

                to:

                    SCNVector3(

                        targetX,

                        4.8,

                        targetZ

                    ),

                duration: 1.4

            )

        )

        // ---------------------------------------------------------

        // NEXT WIRE

        // ---------------------------------------------------------

        DispatchQueue.main.asyncAfter(

            deadline:

                .now() +

                parameters.wireAnimationDuration +

                0.55

        ) {

            guard generation ==

                    self.animationGeneration

            else {

                return

            }

            self.placeWire(

                index: index + 1,

                generation: generation

            )

        }

    }

    // MARK: - DATA TRANSFER

    private func animateDataTransfer(

        generation: Int

    ) {

        guard generation ==

                animationGeneration

        else {

            return

        }

        state?.status =

            "READ / WRITE DATA TRANSFER"

        createWriteParticles()

        DispatchQueue.main.asyncAfter(

            deadline:

                .now() + 1.5

        ) {

            guard generation ==

                    self.animationGeneration

            else {

                return

            }

            self.createReadParticles()

        }

        DispatchQueue.main.asyncAfter(

            deadline:

                .now() + 3.0

        ) {

            guard generation ==

                    self.animationGeneration

            else {

                return

            }

            self.state?.status =

                "3D MEMORY ONLINE"

        }

    }

    // MARK: - WRITE DATA

    private func createWriteParticles() {

        guard !qdNodes.isEmpty else {

            return

        }

        let count =

            parameters.dataParticleCount

        for i in 0..<count {

            let geometry =

                SCNSphere(

                    radius: 0.075

                )

            geometry.firstMaterial?.diffuse.contents =

                UIColor.systemGreen

            geometry.firstMaterial?.emission.contents =

                UIColor.systemGreen

            let particle =

                SCNNode(

                    geometry: geometry

                )

            // -----------------------------------------------------

            // DATA INTERFACE IS UNDER dataRoot.

            // -----------------------------------------------------

            let source =

                SCNVector3(

                    7,

                    1.5,

                    -4

                )

            particle.position =

                source

            dataRoot.addChildNode(

                particle

            )

            dataParticles.append(

                particle

            )

            // -----------------------------------------------------

            // CONVERT QD FROM latticeRoot → dataRoot

            // -----------------------------------------------------

            let qd =

                qdNodes[

                    i %

                    qdNodes.count

                ]

            let qdWorldPosition =

                qd.convertPosition(

                    SCNVector3Zero,

                    to: scene.rootNode

                )

            let target =

                dataRoot.convertPosition(

                    qdWorldPosition,

                    from: scene.rootNode

                )

            // -----------------------------------------------------

            // MOVE

            // -----------------------------------------------------

            let move =

                SCNAction.move(

                    to: target,

                    duration: 0.9

                )

            // -----------------------------------------------------

            // PULSE

            // -----------------------------------------------------

            let pulse =

                SCNAction.sequence(

                    [

                        SCNAction.scale(

                            to: 1.4,

                            duration: 0.12

                        ),

                        SCNAction.scale(

                            to: 1.0,

                            duration: 0.12

                        )

                    ]

                )

            // -----------------------------------------------------

            // COMPLETE ANIMATION

            // -----------------------------------------------------

            let animation =

                SCNAction.group(

                    [

                        move,

                        pulse

                    ]

                )

            particle.runAction(

                SCNAction.sequence(

                    [

                        animation,

                        SCNAction.fadeOut(

                            duration: 0.15

                        ),

                        SCNAction.removeFromParentNode()

                    ]

                )

            )

        }

    }

    // MARK: - READ DATA

    private func createReadParticles() {

        guard !qdNodes.isEmpty else {

            return

        }

        let count =

            parameters.dataParticleCount

        for i in 0..<count {

            let geometry =

                SCNSphere(

                    radius: 0.075

                )

            geometry.firstMaterial?.diffuse.contents =

                UIColor.systemCyan

            geometry.firstMaterial?.emission.contents =

                UIColor.systemCyan

            let particle =

                SCNNode(

                    geometry: geometry

                )

            let qd =

                qdNodes[

                    i %

                    qdNodes.count

                ]

            // -----------------------------------------------------

            // QD WORLD POSITION

            // -----------------------------------------------------

            let qdWorldPosition =

                qd.convertPosition(

                    SCNVector3Zero,

                    to: scene.rootNode

                )

            // -----------------------------------------------------

            // CONVERT WORLD → dataRoot

            // -----------------------------------------------------

            let source =

                dataRoot.convertPosition(

                    qdWorldPosition,

                    from: scene.rootNode

                )

            particle.position =

                source

            dataRoot.addChildNode(

                particle

            )

            dataParticles.append(

                particle

            )

            // -----------------------------------------------------

            // DATA INTERFACE TARGET

            // -----------------------------------------------------

            let interfaceWorldPosition =

                dataRoot.convertPosition(

                    SCNVector3(

                        7,

                        1.5,

                        -4

                    ),

                    to: scene.rootNode

                )

            let target =

                dataRoot.convertPosition(

                    interfaceWorldPosition,

                    from: scene.rootNode

                )

            // -----------------------------------------------------

            // READ ANIMATION

            // -----------------------------------------------------

            particle.runAction(

                SCNAction.sequence(

                    [

                        SCNAction.move(

                            to: target,

                            duration: 1.0

                        ),

                        SCNAction.fadeOut(

                            duration: 0.15

                        ),

                        SCNAction.removeFromParentNode()

                    ]

                )

            )

        }

    }

    // MARK: - UTILITY

    private func makeCylinder(

        radius: CGFloat,

        height: CGFloat,

        color: UIColor

    ) -> SCNNode {

        let geometry =

            SCNCylinder(

                radius: radius,

                height: height

            )

        geometry.firstMaterial?.diffuse.contents =

            color

        return SCNNode(

            geometry: geometry

        )

    }

}

// MARK: - SCNNode LOOK AT

private extension SCNNode {

    func lookAt(

        _ target: SCNVector3

    ) {

        let dx =

            target.x - position.x

        let dy =

            target.y - position.y

        let dz =

            target.z - position.z

        let horizontal =

            sqrt(

                dx * dx +

                dz * dz

            )

        eulerAngles.y =

            atan2(

                dx,

                dz

            )

        eulerAngles.x =

            -atan2(

                dy,

                horizontal

            )

    }

}

// MARK: - SWIFTUI SCENE VIEW

struct QRTLQDJet3DPrintingView:

    UIViewRepresentable {

    @ObservedObject

    var state:

        QRTLManufacturingState

    let parameters:

        QRTLMemoryParameters

    // ---------------------------------------------------------

    // MAKE VIEW

    // ---------------------------------------------------------

    func makeUIView(

        context: Context

    ) -> SCNView {

        let builder =

            QRTLQDJet3DPrintingScene(

                parameters:

                    parameters,

                state:

                    state

            )

        context.coordinator.builder =

            builder

        let view =

            SCNView()

        view.scene =

            builder.scene

        // -----------------------------------------------------

        // SCENEKIT RENDER LOOP

        // -----------------------------------------------------

        view.isPlaying =

            true

        view.rendersContinuously =

            true

        view.preferredFramesPerSecond =

            60

        view.scene?.isPaused =

            false

        // -----------------------------------------------------

        // CAMERA

        // -----------------------------------------------------

        view.allowsCameraControl =

            true

        // -----------------------------------------------------

        // LIGHTING

        // -----------------------------------------------------

        view.autoenablesDefaultLighting =

            false

        // -----------------------------------------------------

        // APPEARANCE

        // -----------------------------------------------------

        view.backgroundColor =

            UIColor.black

        view.showsStatistics =

            false

        // -----------------------------------------------------

        // START MANUFACTURING

        // -----------------------------------------------------

        builder.startManufacturing()

        return view

    }

    // ---------------------------------------------------------

    // UPDATE VIEW

    // ---------------------------------------------------------

    func updateUIView(

        _ uiView: SCNView,

        context: Context

    ) {

        uiView.isPlaying =

            true

        uiView.rendersContinuously =

            true

        uiView.scene?.isPaused =

            false

        context.coordinator.builder?.updateDWORDStorageVisualization(
            state.dwordMetrics
        )

    }

    // ---------------------------------------------------------

    // COORDINATOR

    // ---------------------------------------------------------

    func makeCoordinator()

        -> Coordinator

    {

        Coordinator()

    }

    @MainActor

    final class Coordinator {

        var builder:

            QRTLQDJet3DPrintingScene?

    }

}

// MARK: - CONTENT VIEW

struct ContentView: View {
    @StateObject private var state = QRTLManufacturingState()

    // Only controls the SceneKit demonstration cube. This is NOT
    // the production architecture -- see qrtlArchitecture below.
    private let demoParameters = QRTLMemoryParameters()

    // Defines the proposed HBM-replacement architecture. Purely a
    // numerical model; never used to size SceneKit geometry.
    private let qrtlArchitecture = QRTLArchitectureParameters()

    @State private var selectedDWORD: Int = 0
    @State private var retentionInterval: Double = 1.0
    @State private var cycleCount: Int = 100

    private let testDWORDs: [UInt32] = [
        0x00000000,
        0xFFFFFFFF,
        0xAAAAAAAA,
        0x55555555,
        0xA5A5A5A5
    ]

    var body: some View {
        VStack(spacing: 0) {
            QRTLQDJet3DPrintingView(
                state: state,
                parameters: demoParameters
            )
            .frame(maxWidth: .infinity, minHeight: 400)
            .frame(maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("QRTL MONOLITHIC 3D QD MEMORY")
                        .font(.title2.bold())

                    Text(state.status)
                        .font(.headline)

                    Divider()

                    Text("DEMO-SCALE QD PRINTING VISUALIZATION")
                        .font(.headline)
                    Text("Layer: \(state.currentLayer) / \(demoParameters.layers)")
                    Text("QDs deposited: \(state.depositedQDs) / \(state.totalQDs)")
                    Text("QD jet rate: \(state.qdPrintRate)")

                    Divider()

                    Text("ROBOTIC ACCESS WIRES")
                        .font(.headline)
                    Text("Registered: \(state.placedWires) / \(state.totalWires)")

                    Divider()

                    architectureTargetPanel

                    Divider()

                    thermalSafetyPanel

                    Divider()

                    Text("DEMO-SCALE LATTICE TRANSFER")
                        .font(.headline)
                    Text("WRITE / INPUT: \(state.writeRate)")
                    Text("READ / OUTPUT: \(state.readRate)")
                    Text("WRITE: \(state.writeBytes)")
                    Text("READ: \(state.readBytes)")

                    Divider()

                    Text("3D MEMORY CAPACITY")
                        .font(.headline)
                    Text(state.storageCapacity)
                    Text("\(demoParameters.columns) × \(demoParameters.rows) × \(demoParameters.layers) QD sites (demo visualization scale)")

                    Divider()

                    dwordTestPanel

                    Divider()

                    Text("DATA-RATE EQUATIONS")
                        .font(.headline)
                    equation("C = NQD × BQD")
                    equation("RIN = Nw × fw × BQD × Uw × ηw")
                    equation("ROUT = Nr × fr × BQD × Ur × ηr")
                    equation("RQD = fjet × QDs/event × U × η")

                    Divider()

                    Text("MODEL NOTE")
                        .font(.headline)
                    Text("ARCHITECTURE INTENT: QRTL is proposed as a scalable monolithic 3D quantum-dot memory architecture intended to replace or exceed HBM-class memory through massively parallel tiled access. The 10 × 8 × 6 SceneKit lattice, 12 animated wires, 100 kHz demo rate, and DWORD test are visualization-scale controls only; they do not define the intended production array size, channel count, or 1 PB/s payload-bandwidth target. All PB/s, latency, energy, reliability, and manufacturing values remain architectural targets until experimentally validated in fabricated hardware.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(maxHeight: 500)
        }
    }

    private var architectureTargetPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QRTL HBM-REPLACEMENT ARCHITECTURE")
                .font(.headline)

            Text(qrtlArchitecture.systemIntent.rawValue)
                .font(.subheadline.bold())
                .foregroundStyle(.cyan)

            metric("Intended Role", qrtlArchitecture.intendedRole)
            metric("Target Definition", qrtlArchitecture.targetDescription)

            Divider()

            Text("SCALE MODEL")
                .font(.subheadline.bold())

            metric("Cubes / Package", "\(qrtlArchitecture.cubesPerPackage)")
            metric("Layers / Cube", "\(qrtlArchitecture.layersPerCube)")
            metric("Tiles / Layer", "\(qrtlArchitecture.tilesPerLayer)")
            metric("Banks / Tile", "\(qrtlArchitecture.banksPerTile)")
            metric(
                "Independent Lanes",
                QRTLArchitectureParameters.formatCount(qrtlArchitecture.totalIndependentLanes)
            )
            metric(
                "Lane Access Rate",
                QRTLArchitectureParameters.formatBitRate(qrtlArchitecture.accessFrequencyHz)
            )

            Divider()

            Text("BANDWIDTH TARGET")
                .font(.subheadline.bold())

            metric(
                "Raw Internal Array Rate",
                QRTLArchitectureParameters.formatBitRate(qrtlArchitecture.rawArrayBitsPerSecond)
            )
            metric(
                "Sustained Payload Rate",
                QRTLArchitectureParameters.formatByteRate(qrtlArchitecture.sustainedPayloadBytesPerSecond)
            )
            metric(
                "1 PB/s Target",
                qrtlArchitecture.meetsOnePBPerSecondTarget ? "MET" : "NOT MET"
            )
            metric(
                "Target Achievement",
                String(format: "%.3fx", qrtlArchitecture.targetAchievementRatio)
            )
            metric(
                "HBM Stack Equivalent",
                String(format: "%.1f stacks at 1.2 TB/s reference", qrtlArchitecture.hbmEquivalentStackCount)
            )

            Divider()

            Text("TARGET SYSTEM METRICS")
                .font(.subheadline.bold())

            metric(
                "Target Read Latency",
                String(format: "%.1f ns", qrtlArchitecture.targetRandomReadLatencyNanoseconds)
            )
            metric(
                "Target Write Latency",
                String(format: "%.1f ns", qrtlArchitecture.targetRandomWriteLatencyNanoseconds)
            )
            metric(
                "Target Package Power",
                String(format: "%.0f W", qrtlArchitecture.targetPowerWattsAtSustainedBandwidth)
            )
            metric(
                "Target Energy / Payload Bit",
                String(format: "%.4f pJ/bit", qrtlArchitecture.targetEnergyPerPayloadBitPicojoules)
            )

            Divider()

            Text(
                "The SceneKit cube is a visual and logical prototype. " +
                "The architecture panel models a proposed scalable monolithic " +
                "3D QD memory intended to replace or exceed HBM-class memory. " +
                "Bandwidth, latency, energy, yield, and reliability figures are " +
                "design targets until validated by fabricated hardware."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
    }

    private var thermalSafetyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THERMAL / POWER SAFETY")
                .font(.headline)

            Text(qrtlArchitecture.meetsThermalSafety ? "WITHIN SAFE THERMAL MARGIN" : "THERMAL RISK — EXCEEDS MODELED SAFE LIMITS")
                .font(.subheadline.bold())
                .foregroundStyle(qrtlArchitecture.meetsThermalSafety ? .green : .red)

            metric("Cooling Class", qrtlArchitecture.coolingClass.rawValue)
            metric(
                "Package Footprint",
                String(format: "%.0f cm²", qrtlArchitecture.packageFootprintAreaSquareCentimeters)
            )

            Divider()

            Text("POWER DENSITY")
                .font(.subheadline.bold())

            metric(
                "Modeled Power Density",
                String(format: "%.2f W/cm²", qrtlArchitecture.powerDensityWattsPerSquareCentimeter)
            )
            metric(
                "Cooling Class Ceiling",
                String(format: "%.1f W/cm²", qrtlArchitecture.maxSustainedPowerDensityForCoolingClass)
            )
            metric(
                "Safety Margin",
                String(format: "%.2fx", qrtlArchitecture.thermalSafetyMarginRatio)
            )
            metric(
                "Power Density Safe",
                qrtlArchitecture.meetsPowerDensitySafetyMargin ? "YES" : "NO"
            )

            Divider()

            Text("STEADY-STATE TEMPERATURE")
                .font(.subheadline.bold())

            metric(
                "Ambient Temperature",
                String(format: "%.1f °C", qrtlArchitecture.ambientTemperatureCelsius)
            )
            metric(
                "Target Thermal Resistance",
                String(format: "%.4f °C/W", qrtlArchitecture.targetThermalResistanceCelsiusPerWatt)
            )
            metric(
                "Estimated Device Temperature",
                String(format: "%.1f °C", qrtlArchitecture.estimatedSteadyStateDeviceTemperatureCelsius)
            )
            metric(
                "Max Safe Device Temperature",
                String(format: "%.1f °C", qrtlArchitecture.maxSafeDeviceTemperatureCelsius)
            )
            metric(
                "Temperature Safe",
                qrtlArchitecture.meetsDeviceTemperatureSafetyMargin ? "YES" : "NO"
            )

            if !qrtlArchitecture.validationWarnings.isEmpty {
                Divider()

                Text("WARNINGS")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)

                ForEach(qrtlArchitecture.validationWarnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            Text(
                "This panel checks the declared power target against a stated " +
                "cooling class and a modeled thermal resistance — it is a design " +
                "check on the architecture target, not a measurement from " +
                "fabricated hardware. A monolithic 3D stack concentrates heat " +
                "into a small footprint, so the cooling class stated here is a " +
                "load-bearing assumption of the whole 1 PB/s target, not an " +
                "afterthought."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
    }

    private var dwordTestPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DWORD STORAGE / RETRIEVAL TEST")
                .font(.headline)

            Picker("DWORD", selection: $selectedDWORD) {
                ForEach(0..<testDWORDs.count, id: \.self) { index in
                    Text("DWORD \(index): \(state.dwordHex(testDWORDs[index]))")
                        .tag(index)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text("Retention")
                Slider(value: $retentionInterval, in: 0.1...10.0, step: 0.1)
                Text(String(format: "%.1f s", retentionInterval))
                    .monospaced()
            }

            HStack {
                Text("Cycles")
                Stepper("\(cycleCount)", value: $cycleCount, in: 1...10000, step: 1)
            }

            Button {
                state.runDWORDTest(
                    address: state.dwordBaseAddress + UInt32(selectedDWORD * 4),
                    value: testDWORDs[selectedDWORD],
                    retentionInterval: retentionInterval,
                    cycles: cycleCount
                )
            } label: {
                Label("Run DWORD Test", systemImage: "memorychip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            metric("Memory Address", state.dwordHex(state.dwordMetrics.memoryAddress))
            metric("Cell Range", "\(state.dwordMetrics.cellStartIndex)–\(state.dwordMetrics.cellEndIndex)")
            metric("Write Command", state.dwordHex(state.dwordMetrics.writeCommand))
            metric("Read Address", state.dwordHex(state.dwordMetrics.readAddress))
            metric("Stored Bits", state.dwordBinary(state.dwordMetrics.writeCommand))
            metric("Detected Bits", state.dwordBinary(state.dwordMetrics.returnedDWORD))
            metric("Returned DWORD", state.dwordHex(state.dwordMetrics.returnedDWORD))
            metric("Write Time", formatTime(state.dwordMetrics.writeTimeSeconds))
            metric("Read Time", formatTime(state.dwordMetrics.readTimeSeconds))
            metric("Write Accuracy", String(format: "%.4f %%", state.dwordMetrics.writeAccuracyPercent))
            metric("Read Accuracy", String(format: "%.4f %%", state.dwordMetrics.readAccuracyPercent))
            metric("Retention", String(format: "%.4f %%", state.dwordMetrics.retentionPercent))
            metric("Read/Write Cycles", "\(state.dwordMetrics.successfulCycles) / \(state.dwordMetrics.requestedCycles)")
            metric("Cycle Success Rate", String(format: "%.4f %%", state.dwordMetrics.cycleSuccessRatePercent))
            metric("Incorrect Bits", "\(state.dwordMetrics.incorrectBits) / \(state.dwordMetrics.totalBitsTested)")
            metric("Error Rate", String(format: "%.4f %%", state.dwordMetrics.errorRatePercent))

            Text(state.memoryTestStatus)
                .font(.title3.bold())
                .foregroundStyle(state.dwordMetrics.verificationPassed ? .green : .red)

            Text("Equations")
                .font(.subheadline.bold())
            equation("Bit_i = (DWORD >> i) & 1")
            equation("S_i = S0 + (S1 − S0) × Bit_i")
            equation("Detected_i = 1 if S_i ≥ T, else 0")
            equation("Accuracy = CorrectBits / 32 × 100")
            equation("ErrorRate = IncorrectBits / TotalBits × 100")
            equation("CycleSuccess = SuccessfulCycles / RequestedCycles × 100")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }

    private func equation(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
    }

    private func formatTime(_ seconds: Double) -> String {
        if seconds < 0.001 {
            return String(format: "%.3f µs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.3f ms", seconds * 1_000)
        }
        return String(format: "%.3f s", seconds)
    }
}

// MARK: - PREVIEW

#Preview {

    ContentView()

}

// MARK: - LATTICE-BASED DATA TRANSFER MEASUREMENT

extension QRTLDataRateModel {

    // ---------------------------------------------------------

    // EXPECTED LATTICE CONFIGURATION

    // ---------------------------------------------------------

    var latticeColumns: Int {

        parameters.columns

    }

    var latticeRows: Int {

        parameters.rows

    }

    var latticeLayers: Int {

        parameters.layers

    }

    // ---------------------------------------------------------

    // TOTAL STORAGE SITES

    // ---------------------------------------------------------

    var latticeQDSites: Int {

        parameters.columns *

        parameters.rows *

        parameters.layers

    }

    // ---------------------------------------------------------

    // TOTAL MEMORY

    // ---------------------------------------------------------

    var latticeStorageBits: Double {

        Double(latticeQDSites) *

        parameters.bitsPerQD

    }

    var latticeStorageBytes: Double {

        latticeStorageBits / 8.0

    }

    // ---------------------------------------------------------

    // ACCESS-WIRE ORGANIZATION

    // ---------------------------------------------------------

    var sitesPerAccessWire: Int {

        parameters.sitesPerWire

    }

    var totalAccessWires: Int {

        parameters.wireCount

    }

    // ---------------------------------------------------------

    // CHANNEL CHECK

    //

    // Expected:

    //

    // 12 wires/channels × 40 sites = 480 sites

    //

    // ---------------------------------------------------------

    var addressableSites: Int {

        totalAccessWires *

        sitesPerAccessWire

    }

    var addressableLatticeMatches: Bool {

        addressableSites == latticeQDSites

    }

    // ---------------------------------------------------------

    // MEASURED INPUT RATE

    //

    // Data entering the lattice.

    // ---------------------------------------------------------

    var measuredInputBitsPerSecond: Double {

        parameters.writeChannels *

        parameters.writeFrequencyHz *

        parameters.bitsPerQD *

        parameters.writeUtilization *

        parameters.writeEfficiency

    }

    // ---------------------------------------------------------

    // MEASURED OUTPUT RATE

    //

    // Data leaving the lattice.

    // ---------------------------------------------------------

    var measuredOutputBitsPerSecond: Double {

        parameters.readChannels *

        parameters.readFrequencyHz *

        parameters.bitsPerQD *

        parameters.readUtilization *

        parameters.readEfficiency

    }

    // ---------------------------------------------------------

    // BYTES / SECOND

    // ---------------------------------------------------------

    var measuredInputBytesPerSecond: Double {

        measuredInputBitsPerSecond / 8.0

    }

    var measuredOutputBytesPerSecond: Double {

        measuredOutputBitsPerSecond / 8.0

    }

    // ---------------------------------------------------------

    // FULL-CUBE TRANSFER TIME

    // ---------------------------------------------------------

    var fullCubeWriteTime: TimeInterval {

        guard measuredInputBitsPerSecond > 0 else {

            return 0

        }

        return latticeStorageBits /

            measuredInputBitsPerSecond

    }

    var fullCubeReadTime: TimeInterval {

        guard measuredOutputBitsPerSecond > 0 else {

            return 0

        }

        return latticeStorageBits /

            measuredOutputBitsPerSecond

    }

}

