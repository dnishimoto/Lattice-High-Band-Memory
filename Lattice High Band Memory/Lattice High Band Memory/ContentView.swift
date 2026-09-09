/*
 Think of your 3D memory as a gigantic **multi-story library**.

 The entire memory system is the library building. Each physical memory layer is one floor of the building. Each floor contains rows of shelves, and each shelf contains many numbered boxes. Instead of an address pointing to one individual letter printed on a page, it points to one specific box that contains a whole bundle of information.

 For example, imagine the library has 64-page packets stored in every box. A memory address such as `Layer 12 : Row 37 : Column 18` is like telling a robot librarian: “Go to floor 12, find aisle 37, then select box 18.” That location identifies one particular memory block. Inside that box are 64 separate pages, analogous to the 64 individual bits in a memory word. Each page can contain either a `0` or a `1`.

 The address wires are like the instructions sent from the librarian’s control desk to the robot. They do not need to connect directly to every page in every box in the building. Instead, they provide a location code. The robot interprets the code through an address decoder, which is like a detailed navigation system: it figures out the correct floor, the correct aisle, and the correct box.

 The data wires are like a shared conveyor belt that runs through the library. Every box has a possible connection to the conveyor belt, but the box remains closed and disconnected unless the robot has selected it. When the address selects the box at Layer 12, Row 37, Column 18, that box opens and places its 64 pages on the conveyor belt. The belt carries all 64 page values back to the control desk at the same time.

 For a write operation, the process runs in reverse. The control desk places 64 new pages onto the shared conveyor belt and sends the location code for the target box. The address decoder directs the robot to the specified floor, row, and column, opens only that one box, and replaces the 64 pages inside it. Every other box stays closed, so no other stored information is changed.

 In this analogy, one QRTL memory cell is like a single page containing one mark: either `0` or `1`. A 64-bit word is like a packet of 64 pages stored together in one numbered box. A memory address is the box’s complete location label, not a label for every individual page. The decoder is the navigation system that finds the box, and the data bus is the shared conveyor belt used to carry the selected packet to or from the controller.

 So the important point is: the system does not need a separate private hallway from the control desk to every page in the entire library. It only needs a way to identify one box and temporarily connect that box to the shared conveyor belt.
 
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


struct LatticeAddress {
    let layer: Int
    let shelf: Int
    let box: Int
}
// MARK: - QRTL SCENE

@MainActor



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

