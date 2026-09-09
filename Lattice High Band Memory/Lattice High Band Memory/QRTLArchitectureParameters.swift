//
//  File.swift
//  Lattice High Band Memory
//
//  Created by David Nishimoto on 9/6/26.
//

import Foundation

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
    // DEFECT, YIELD, REDUNDANCY, AND REMAPPING MODEL
    // ---------------------------------------------------------
    /// Defect density in defects/cm2 (assumed or measured)
    let defectDensityPerCm2: Double = 0.2 // Example, override as needed
    /// Area of active memory (cm2)
    let activeMemoryAreaCm2: Double = 650.0
    /// Per-layer yield as estimated from Poisson statistics
    var cellsPerLayer: Double { totalQDCells / Double(layersPerCube) }
    var defectsPerLayer: Double { defectDensityPerCm2 * (activeMemoryAreaCm2 / Double(layersPerCube)) }
    var perLayerYield: Double {
        exp(-defectsPerLayer / cellsPerLayer)
    }
    /// Compound yield (no repair, just stacking layers)
    var compoundYield: Double {
        pow(perLayerYield, Double(layersPerCube))
    }
    /// Spare cells per layer for redundancy/repair
    let spareCellsPerLayer: Double = 10_000
    var repairedCellsPerLayer: Double { min(defectsPerLayer, spareCellsPerLayer) }
    var repairedYieldPerLayer: Double {
        let effectiveDefects = max(defectsPerLayer - repairedCellsPerLayer, 0)
        return exp(-effectiveDefects / cellsPerLayer)
    }
    var functionalYield: Double {
        pow(repairedYieldPerLayer, Double(layersPerCube))
    }
    /// Usable QD cells after defects and repair
    var usableQDCells: Double {
        functionalYield * totalQDCells
    }

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
    // BOTTLENECK & PASS/FAIL
    // ---------------------------------------------------------
    var bottleneck: String {
        let minBW = min(sustainedPayloadBytesPerSecond, packageIOBandwidthBytesPerSecond)
        if minBW == sustainedPayloadBytesPerSecond && minBW < packageIOBandwidthBytesPerSecond {
            return "ARRAY"
        } else if minBW < sustainedPayloadBytesPerSecond {
            return "PACKAGE I/O"
        }
        if !meetsThermalSafety { return "THERMAL" }
        if estimatedBitErrorRate > 1e-4 { return "RELIABILITY" }
        if !meetsOnePBPerSecondTarget { return "PERFORMANCE TARGET" }
        return "NONE/LIMIT UNKNOWN"
    }
    var sustainableBandwidthBytesPerSecond: Double {
        min(sustainedPayloadBytesPerSecond, packageIOBandwidthBytesPerSecond)
    }
    var passFail: Bool {
        meetsOnePBPerSecondTarget && meetsThermalSafety && estimatedBitErrorRate < 1e-4
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
    // RELIABILITY & ERROR MODEL
    // ---------------------------------------------------------
    /// Write error rate per bit (from measurement or estimate)
    let baseWriteErrorRate: Double = 0.00001 // Example 10 ppm
    /// Read error rate per bit (from measurement or estimate)
    let baseReadErrorRate: Double = 0.00002 // Example 20 ppm
    /// Retention loss rate per second (fraction of signal lost per second at reference temp)
    let baseRetentionLossPerSecond: Double = 0.0001
    /// Endurance limit (writes per cell before error rate rises)
    let baseEnduranceCycles: Double = 1_000_000
    /// Temperature dependence factors (errors rise with temp)
    let errorTempCoeffWrite: Double = 0.02 // per °C over 25C
    let errorTempCoeffRead: Double = 0.025
    let retentionTempCoeff: Double = 0.01
    /// Current temperature reference for calculation
    var referenceTemperatureCelsius: Double { ambientTemperatureCelsius }
    var currentTemperatureCelsius: Double { estimatedSteadyStateDeviceTemperatureCelsius }
    var writeErrorRate: Double {
        let tempDelta = max(0, currentTemperatureCelsius - 25.0)
        return baseWriteErrorRate * (1.0 + errorTempCoeffWrite * tempDelta)
    }
    var readErrorRate: Double {
        let tempDelta = max(0, currentTemperatureCelsius - 25.0)
        return baseReadErrorRate * (1.0 + errorTempCoeffRead * tempDelta)
    }
    var retentionLossPerSecond: Double {
        let tempDelta = max(0, currentTemperatureCelsius - 25.0)
        return baseRetentionLossPerSecond * (1.0 + retentionTempCoeff * tempDelta)
    }
    /// Simulated bit error rate over time
    func estimatedBitRetentionAfter(seconds: Double) -> Double {
        exp(-retentionLossPerSecond * seconds)
    }
    /// Estimated total error rate (read + write + retention, not counting ECC)
    var estimatedBitErrorRate: Double {
        1.0 - (1.0 - writeErrorRate) * (1.0 - readErrorRate) * estimatedBitRetentionAfter(seconds: 1.0)
    }

    // ---------------------------------------------------------
    // PACKAGE I/O MODEL
    // ---------------------------------------------------------
    /// Number of high-speed I/O lanes on the package
    let packageIOLaneCount: Double = 2048
    /// Lane signaling rate in Hz
    let packageIOLaneFrequencyHz: Double = 112_000_000_000
    /// Bits per lane transfer (payload)
    let packageIOBitsPerTransfer: Double = 1.0
    /// Encoding efficiency (e.g., 0.85 for 64b/66b)
    let packageIOEncodingEfficiency: Double = 0.97
    /// Protocol efficiency (framing, control, etc.)
    let packageIOProtocolEfficiency: Double = 0.98
    /// Link utilization under sustained load
    let packageIOUtilization: Double = 0.92
    /// Calculated package I/O bandwidth (payload bits/sec)
    var packageIOBandwidthBitsPerSecond: Double {
        packageIOLaneCount * packageIOLaneFrequencyHz * packageIOBitsPerTransfer * packageIOEncodingEfficiency * packageIOProtocolEfficiency * packageIOUtilization
    }
    var packageIOBandwidthBytesPerSecond: Double { packageIOBandwidthBitsPerSecond / 8.0 }
    /// Lanes required for target bandwidth
    var requiredIOLanesForTarget: Double {
        guard targetPayloadBytesPerSecond > 0 else { return 0 }
        return targetPayloadBytesPerSecond * 8.0 /
            (packageIOLaneFrequencyHz * packageIOBitsPerTransfer * packageIOEncodingEfficiency * packageIOProtocolEfficiency * packageIOUtilization)
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

    struct QRTLArchitectureResult {
        let label: String
        let value: String
        let type: String  // (Target, Assumption, Calculated, Simulated, Reference, Measured)
        let units: String
        let passFail: Bool?
        let trace: String?
    }
    func fullArchitectureAudit() -> [QRTLArchitectureResult] {
        [
            .init(label: "Target Payload Bandwidth", value: QRTLArchitectureParameters.formatByteRate(targetPayloadBytesPerSecond), type: "Target", units: "B/s", passFail: nil, trace: "External requirement"),
            .init(label: "Sustained Payload Bandwidth", value: QRTLArchitectureParameters.formatByteRate(sustainedPayloadBytesPerSecond), type: "Calculated", units: "B/s", passFail: meetsOnePBPerSecondTarget, trace: "From lanes, freq, utilization, yield, efficiency"),
            .init(label: "Package I/O Bandwidth", value: QRTLArchitectureParameters.formatByteRate(packageIOBandwidthBytesPerSecond), type: "Calculated", units: "B/s", passFail: packageIOBandwidthBytesPerSecond >= targetPayloadBytesPerSecond, trace: "From lanes, freq, coding, protocol, utilization"),
            .init(label: "Bottleneck", value: bottleneck, type: "Diagnostic", units: "", passFail: nil, trace: "Lowest sustained BW or failed constraint"),
            .init(label: "Compound Yield (no repair)", value: String(format: "%.5f", compoundYield), type: "Calculated", units: "fraction", passFail: nil, trace: "Poisson defect model"),
            .init(label: "Functional Yield (after repair)", value: String(format: "%.5f", functionalYield), type: "Calculated", units: "fraction", passFail: nil, trace: "After remapping spare cells"),
            .init(label: "Usable QD Cells", value: QRTLArchitectureParameters.formatCount(usableQDCells), type: "Calculated", units: "cells", passFail: nil, trace: "After repair/remapping"),
            .init(label: "Energy per Payload Bit", value: String(format: "%.4f pJ", targetEnergyPerPayloadBitPicojoules), type: "Calculated", units: "pJ/bit", passFail: nil, trace: "Power/BW"),
            .init(label: "Power Density", value: String(format: "%.2f", powerDensityWattsPerSquareCentimeter), type: "Calculated", units: "W/cm2", passFail: meetsPowerDensitySafetyMargin, trace: "Power/area"),
            .init(label: "Device Temp", value: String(format: "%.1f", estimatedSteadyStateDeviceTemperatureCelsius), type: "Estimated", units: "C", passFail: meetsDeviceTemperatureSafetyMargin, trace: "Power, cooling"),
            .init(label: "Estimated Bit Error Rate", value: String(format: "%.2e", estimatedBitErrorRate), type: "Simulated", units: "errors/bit", passFail: estimatedBitErrorRate < 1e-4, trace: "Write/read/retention"),
            .init(label: "PASS/FAIL", value: passFail ? "PASS" : "FAIL", type: "System", units: "", passFail: passFail, trace: "All constraints")
        ]
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
