import SwiftUI
import SceneKit
import Combine

// ================================================================
// QRTL DWORD MEMORY TEST
// ================================================================
//
// One DWORD = 32 bits
//
// Memory pipeline:
//
// ADDRESS
//    ↓
// SELECT 32 CELLS
//    ↓
// WRITE 0 / 1
//    ↓
// LATTICE BIT STATE
//    ↓
// WRITE TIME
//    ↓
// READ ADDRESS
//    ↓
// READ SIGNAL
//    ↓
// THRESHOLD DETECTION
//    ↓
// DETECTED 0 / 1
//    ↓
// RECONSTRUCT DWORD
//    ↓
// VERIFY
//    ↓
// RETENTION
//    ↓
// READ/WRITE CYCLES
//    ↓
// ERROR RATE
//
// This is an engineering simulation, not experimental proof of
// the proposed QRTL physical mechanism.
// ================================================================


// MARK: - DWORD Metrics

struct QRTLDWordMetrics {

    // ------------------------------------------------------------
    // 1. MEMORY ADDRESS
    // ------------------------------------------------------------

    var memoryAddress: UInt32 = 0

    // Physical cell indices associated with this DWORD.
    var cellStartIndex: Int = 0
    var cellEndIndex: Int = 31

    // ------------------------------------------------------------
    // 2. WRITE COMMAND
    // ------------------------------------------------------------

    var writeCommand: UInt32 = 0

    // ------------------------------------------------------------
    // 3. BIT STATE
    // ------------------------------------------------------------

    var bitStates: [Int] = Array(repeating: 0, count: 32)

    // ------------------------------------------------------------
    // 4. WRITE TIME
    // ------------------------------------------------------------

    var writeTimeSeconds: Double = 0

    // ------------------------------------------------------------
    // 5. READ COMMAND
    // ------------------------------------------------------------

    var readAddress: UInt32 = 0

    // ------------------------------------------------------------
    // 6. READ SIGNAL
    // ------------------------------------------------------------

    var readSignals: [Double] = Array(repeating: 0, count: 32)

    // ------------------------------------------------------------
    // 7. DETECTED BIT
    // ------------------------------------------------------------

    var detectedBits: [Int] = Array(repeating: 0, count: 32)

    // ------------------------------------------------------------
    // 8. READ TIME
    // ------------------------------------------------------------

    var readTimeSeconds: Double = 0

    // ------------------------------------------------------------
    // 9. WRITE ACCURACY
    // ------------------------------------------------------------

    var writeAccuracyPercent: Double = 0

    // ------------------------------------------------------------
    // 10. READ ACCURACY
    // ------------------------------------------------------------

    var readAccuracyPercent: Double = 0

    // ------------------------------------------------------------
    // 11. BIT RETENTION
    // ------------------------------------------------------------

    var retentionSeconds: Double = 0
    var retentionPercent: Double = 0

    // ------------------------------------------------------------
    // 12. READ/WRITE CYCLES
    // ------------------------------------------------------------

    var requestedCycles: Int = 0
    var successfulCycles: Int = 0
    var cycleSuccessRatePercent: Double = 0

    // ------------------------------------------------------------
    // 13. ERROR RATE
    // ------------------------------------------------------------

    var incorrectBits: Int = 0
    var totalBitsTested: Int = 0
    var errorRatePercent: Double = 0

    // ------------------------------------------------------------
    // FINAL
    // ------------------------------------------------------------

    var returnedDWORD: UInt32 = 0

    var verificationPassed: Bool = false
}


// MARK: - Memory Test State

@MainActor
final class QRTLMemoryTestState: ObservableObject {

    @Published var readAddress: UInt32 = 0

    @Published var baseAddress: UInt32 = 0x0100

    @Published var testDWORDs: [UInt32] = [
        0x00000000,
        0xFFFFFFFF,
        0xAAAAAAAA,
        0x55555555,
        0xA5A5A5A5
    ]

    @Published var selectedDWORDIndex: Int = 0

    // ------------------------------------------------------------
    // CURRENT TEST
    // ------------------------------------------------------------

    @Published var memoryAddress: UInt32 = 0

    @Published var writeCommand: UInt32 = 0

    @Published var returnedDWORD: UInt32 = 0

    @Published var status: String = "READY"

    // ------------------------------------------------------------
    // BIT INFORMATION
    // ------------------------------------------------------------

    @Published var bitStates: [Int] =
        Array(repeating: 0, count: 32)

    @Published var detectedBits: [Int] =
        Array(repeating: 0, count: 32)

    @Published var readSignals: [Double] =
        Array(repeating: 0, count: 32)

    // ------------------------------------------------------------
    // METRICS
    // ------------------------------------------------------------

    @Published var writeTimeSeconds: Double = 0

    @Published var readTimeSeconds: Double = 0

    @Published var writeAccuracyPercent: Double = 0

    @Published var readAccuracyPercent: Double = 0

    @Published var retentionPercent: Double = 0

    @Published var retentionSeconds: Double = 0

    @Published var requestedCycles: Int = 0

    @Published var successfulCycles: Int = 0

    @Published var cycleSuccessRatePercent: Double = 0

    @Published var incorrectBits: Int = 0

    @Published var totalBitsTested: Int = 0

    @Published var errorRatePercent: Double = 0

    @Published var verificationPassed: Bool = false

    // ------------------------------------------------------------
    // PHYSICAL MEMORY MODEL
    // ------------------------------------------------------------

    private var memoryCells: [Int: Int] = [:]

    // ------------------------------------------------------------
    // READ SIGNAL MODEL
    // ------------------------------------------------------------

    //
    // Simulated signal levels:
    //
    // 0 → LOW_SIGNAL
    // 1 → HIGH_SIGNAL
    //
    // The threshold determines whether the measured signal
    // is interpreted as 0 or 1.
    //

    let lowSignal: Double = 0.10
    let highSignal: Double = 1.00

    let readThreshold: Double = 0.50

    // ------------------------------------------------------------
    // TIMING MODEL
    // ------------------------------------------------------------

    let simulatedWriteTimePerBit: Double = 0.000001
    let simulatedReadTimePerBit: Double = 0.0000005

    // ------------------------------------------------------------
    // WRITE DWORD
    // ------------------------------------------------------------

    func writeDWORD(
        address: UInt32,
        value: UInt32
    ) {

        memoryAddress = address
        writeCommand = value

        let start = CFAbsoluteTimeGetCurrent()

        let dwordNumber =
            Int((address - baseAddress) / 4)

        let startingCell =
            dwordNumber * 32

        for bitIndex in 0..<32 {

            // ----------------------------------------------------
            // Equation:
            //
            // bᵢ = (D >> i) & 1
            // ----------------------------------------------------

            let bit =
                Int((value >> UInt32(bitIndex)) & 1)

            let cellIndex =
                startingCell + bitIndex

            memoryCells[cellIndex] = bit

            bitStates[bitIndex] = bit
        }

        let measured =
            CFAbsoluteTimeGetCurrent() - start

        // Ensure the simulation reports the modeled operation
        // time rather than zero when the CPU operation is too fast.
        writeTimeSeconds =
            max(
                measured,
                simulatedWriteTimePerBit * 32
            )

        // --------------------------------------------------------
        // WRITE ACCURACY
        //
        // Correct writes / attempted writes × 100
        // --------------------------------------------------------

        var correct = 0

        for bitIndex in 0..<32 {

            let expected =
                Int((value >> UInt32(bitIndex)) & 1)

            let cellIndex =
                startingCell + bitIndex

            let stored =
                memoryCells[cellIndex] ?? 0

            if stored == expected {
                correct += 1
            }
        }

        writeAccuracyPercent =
            Double(correct) / 32.0 * 100.0

        status = "DWORD WRITTEN"
    }

    // ------------------------------------------------------------
    // READ DWORD
    // ------------------------------------------------------------

    func readDWORD(
        address: UInt32
    ) -> UInt32 {

        memoryAddress = address
        readAddress = address

        let start = CFAbsoluteTimeGetCurrent()

        let dwordNumber =
            Int((address - baseAddress) / 4)

        let startingCell =
            dwordNumber * 32

        var reconstructed: UInt32 = 0

        for bitIndex in 0..<32 {

            let cellIndex =
                startingCell + bitIndex

            let physicalState =
                memoryCells[cellIndex] ?? 0

            // ----------------------------------------------------
            // READ SIGNAL EQUATION
            //
            // Sᵢ = S₀ + (S₁ - S₀)bᵢ
            // ----------------------------------------------------

            let signal =
                lowSignal +
                (highSignal - lowSignal)
                * Double(physicalState)

            readSignals[bitIndex] = signal

            // ----------------------------------------------------
            // DETECTION EQUATION
            //
            // detected bit = 1 if signal >= threshold
            // detected bit = 0 otherwise
            // ----------------------------------------------------

            let detected =
                signal >= readThreshold ? 1 : 0

            detectedBits[bitIndex] = detected

            if detected == 1 {

                reconstructed |=
                    UInt32(1) << UInt32(bitIndex)
            }
        }

        let measured =
            CFAbsoluteTimeGetCurrent() - start

        readTimeSeconds =
            max(
                measured,
                simulatedReadTimePerBit * 32
            )

        returnedDWORD = reconstructed

        status = "DWORD READ"

        return reconstructed
    }

    // ------------------------------------------------------------
    // VERIFY DWORD
    // ------------------------------------------------------------

    func verifyDWORD(
        expected: UInt32,
        returned: UInt32
    ) {

        var correctBits = 0

        for bitIndex in 0..<32 {

            let expectedBit =
                Int(
                    (expected >> UInt32(bitIndex)) & 1
                )

            let returnedBit =
                Int(
                    (returned >> UInt32(bitIndex)) & 1
                )

            if expectedBit == returnedBit {
                correctBits += 1
            }
        }

        // --------------------------------------------------------
        // READ ACCURACY EQUATION
        //
        // Correct bits / total bits × 100
        // --------------------------------------------------------

        readAccuracyPercent =
            Double(correctBits) / 32.0 * 100.0

        incorrectBits =
            32 - correctBits

        totalBitsTested = 32

        // --------------------------------------------------------
        // ERROR RATE EQUATION
        //
        // Errors / total bits
        // --------------------------------------------------------

        errorRatePercent =
            Double(incorrectBits)
            / Double(totalBitsTested)
            * 100.0

        verificationPassed =
            expected == returned

        status =
            verificationPassed
            ? "MEMORY PASS"
            : "MEMORY FAIL"
    }

    // ------------------------------------------------------------
    // RETENTION TEST
    // ------------------------------------------------------------

    func testRetention(
        address: UInt32,
        expected: UInt32,
        interval: Double
    ) {

        let originalBits = bitStates

        // --------------------------------------------------------
        // Simulated retention interval.
        //
        // The actual application can replace this with a real
        // timed delay and physical measurement.
        // --------------------------------------------------------

        retentionSeconds = interval

        let returned =
            readDWORD(address: address)

        var unchanged = 0

        for bitIndex in 0..<32 {

            if originalBits[bitIndex]
                == detectedBits[bitIndex] {

                unchanged += 1
            }
        }

        // --------------------------------------------------------
        // RETENTION EQUATION
        //
        // unchanged bits / tested bits × 100
        // --------------------------------------------------------

        retentionPercent =
            Double(unchanged) / 32.0 * 100.0

        returnedDWORD = returned
    }

    // ------------------------------------------------------------
    // READ / WRITE CYCLE TEST
    // ------------------------------------------------------------

    func runCycles(
        address: UInt32,
        value: UInt32,
        cycles: Int
    ) {

        requestedCycles = cycles
        successfulCycles = 0

        for _ in 0..<cycles {

            writeDWORD(
                address: address,
                value: value
            )

            let returned =
                readDWORD(
                    address: address
                )

            if returned == value {
                successfulCycles += 1
            }
        }

        // --------------------------------------------------------
        // CYCLE SUCCESS EQUATION
        //
        // successful cycles / total cycles × 100
        // --------------------------------------------------------

        if cycles > 0 {

            cycleSuccessRatePercent =
                Double(successfulCycles)
                / Double(cycles)
                * 100.0
        } else {

            cycleSuccessRatePercent = 0
        }

        // Update final verification.
        verifyDWORD(
            expected: value,
            returned: returnedDWORD
        )

        status = "CYCLE TEST COMPLETE"
    }

    // ------------------------------------------------------------
    // COMPLETE DWORD TEST
    // ------------------------------------------------------------

    func runCompleteTest(
        dwordIndex: Int,
        retentionInterval: Double = 1.0,
        cycles: Int = 100
    ) {

        guard
            dwordIndex >= 0,
            dwordIndex < testDWORDs.count
        else {
            status = "INVALID DWORD INDEX"
            return
        }

        selectedDWORDIndex = dwordIndex

        let address =
            baseAddress +
            UInt32(dwordIndex * 4)

        let value =
            testDWORDs[dwordIndex]

        // --------------------------------------------------------
        // STEP 1
        // WRITE
        // --------------------------------------------------------

        status = "WRITING DWORD..."

        writeDWORD(
            address: address,
            value: value
        )

        // --------------------------------------------------------
        // STEP 2
        // READ
        // --------------------------------------------------------

        status = "READING DWORD..."

        let returned =
            readDWORD(
                address: address
            )

        // --------------------------------------------------------
        // STEP 3
        // VERIFY
        // --------------------------------------------------------

        verifyDWORD(
            expected: value,
            returned: returned
        )

        // --------------------------------------------------------
        // STEP 4
        // RETENTION
        // --------------------------------------------------------

        testRetention(
            address: address,
            expected: value,
            interval: retentionInterval
        )

        // --------------------------------------------------------
        // STEP 5
        // REPEATED CYCLES
        // --------------------------------------------------------

        runCycles(
            address: address,
            value: value,
            cycles: cycles
        )

        // Restore final expected/read values.
        writeCommand = value
        memoryAddress = address
        readAddress = address
        returnedDWORD = returned

        status =
            verificationPassed
            ? "DWORD TEST PASS"
            : "DWORD TEST FAIL"
    }

    // ------------------------------------------------------------
    // FORMAT DWORD
    // ------------------------------------------------------------

    func hexString(
        _ value: UInt32
    ) -> String {

        String(
            format: "0x%08X",
            value
        )
    }

    // ------------------------------------------------------------
    // FORMAT BITS
    // ------------------------------------------------------------

    func binaryString(
        _ value: UInt32
    ) -> String {

        let binary =
            String(
                value,
                radix: 2
            )

        return String(
            repeating: "0",
            count: max(0, 32 - binary.count)
        ) + binary
    }
}


// MARK: - QRTL Memory Scene

@MainActor
final class QRTLMemoryScene {

    let scene = SCNScene()

    private let root = SCNNode()

    private var bitNodes: [SCNNode] = []

    private let spacing: Float = 0.65

    init(
        state: QRTLMemoryTestState
    ) {

        scene.rootNode.addChildNode(root)

        configureScene()
        buildLighting()
        buildMemoryLattice()

        updateBitVisualization(
            state: state
        )
    }

    // ------------------------------------------------------------
    // SCENE CONFIGURATION
    // ------------------------------------------------------------

    private func configureScene() {

        scene.background.contents =
            UIColor.black

        let cameraNode =
            SCNNode()

        let camera =
            SCNCamera()

        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 100

        cameraNode.camera = camera

        cameraNode.position =
            SCNVector3(
                0,
                10,
                24
            )

        cameraNode.lookAt(
            SCNVector3(
                0,
                0,
                0
            )
        )

        scene.rootNode.addChildNode(
            cameraNode
        )
    }

    // ------------------------------------------------------------
    // LIGHTING
    // ------------------------------------------------------------

    private func buildLighting() {

        let keyNode =
            SCNNode()

        let keyLight =
            SCNLight()

        keyLight.type = .omni
        keyLight.intensity = 1200

        keyLight.color =
            UIColor.white

        keyNode.light = keyLight

        keyNode.position =
            SCNVector3(
                0,
                12,
                12
            )

        scene.rootNode.addChildNode(
            keyNode
        )

        let fillNode =
            SCNNode()

        let fillLight =
            SCNLight()

        fillLight.type = .omni
        fillLight.intensity = 600

        fillLight.color =
            UIColor(
                red: 0.2,
                green: 0.45,
                blue: 1.0,
                alpha: 1.0
            )

        fillNode.light = fillLight

        fillNode.position =
            SCNVector3(
                -10,
                5,
                10
            )

        scene.rootNode.addChildNode(
            fillNode
        )
    }

    // ------------------------------------------------------------
    // BUILD 32-BIT MEMORY LATTICE
    // ------------------------------------------------------------

    private func buildMemoryLattice() {

        for bitIndex in 0..<32 {

            let column =
                bitIndex % 8

            let row =
                bitIndex / 8

            let x =
                Float(column - 3)
                * spacing

            let y =
                Float(3 - row)
                * spacing

            let bitNode =
                createBitNode(
                    index: bitIndex
                )

            bitNode.position =
                SCNVector3(
                    x,
                    y,
                    0
                )

            root.addChildNode(
                bitNode
            )

            bitNodes.append(
                bitNode
            )
        }
    }

    // ------------------------------------------------------------
    // CREATE INDIVIDUAL MEMORY CELL
    // ------------------------------------------------------------

    private func createBitNode(
        index: Int
    ) -> SCNNode {

        let group =
            SCNNode()

        // --------------------------------------------------------
        // QD STORAGE SITE
        // --------------------------------------------------------

        let sphereGeometry =
            SCNSphere(
                radius: 0.20
            )

        let sphereMaterial =
            SCNMaterial()

        sphereMaterial.diffuse.contents =
            UIColor(
                red: 0.05,
                green: 0.20,
                blue: 0.40,
                alpha: 1.0
            )

        sphereMaterial.emission.contents =
            UIColor(
                red: 0.0,
                green: 0.05,
                blue: 0.15,
                alpha: 1.0
            )

        sphereGeometry.firstMaterial =
            sphereMaterial

        let qd =
            SCNNode(
                geometry: sphereGeometry
            )

        group.addChildNode(qd)

        // --------------------------------------------------------
        // LATTICE BARRIER
        //
        // The torus visually represents the storage barrier.
        //
        // 0 = closed/dim
        // 1 = active/bright
        // --------------------------------------------------------

        let barrierGeometry =
            SCNTorus(
                ringRadius: 0.28,
                pipeRadius: 0.035
            )

        let barrierMaterial =
            SCNMaterial()

        barrierMaterial.diffuse.contents =
            UIColor(
                red: 0.10,
                green: 0.15,
                blue: 0.25,
                alpha: 1.0
            )

        barrierMaterial.emission.contents =
            UIColor(
                red: 0.0,
                green: 0.05,
                blue: 0.10,
                alpha: 1.0
            )

        barrierGeometry.firstMaterial =
            barrierMaterial

        let barrier =
            SCNNode(
                geometry: barrierGeometry
            )

        barrier.name =
            "barrier_\(index)"

        group.addChildNode(
            barrier
        )

        return group
    }

    // ------------------------------------------------------------
    // UPDATE VISUAL BIT STATES
    // ------------------------------------------------------------

    func updateBitVisualization(
        state: QRTLMemoryTestState
    ) {

        guard bitNodes.count == 32 else {
            return
        }

        for bitIndex in 0..<32 {

            let bit =
                state.bitStates[bitIndex]

            let node =
                bitNodes[bitIndex]

            let barrier =
                node.childNode(
                    withName:
                        "barrier_\(bitIndex)",
                    recursively: true
                )

            guard
                let material =
                    barrier?
                    .geometry?
                    .firstMaterial
            else {
                continue
            }

            if bit == 1 {

                material.diffuse.contents =
                    UIColor(
                        red: 0.05,
                        green: 0.75,
                        blue: 1.0,
                        alpha: 1.0
                    )

                material.emission.contents =
                    UIColor(
                        red: 0.0,
                        green: 0.35,
                        blue: 1.0,
                        alpha: 1.0
                    )

                node.scale =
                    SCNVector3(
                        1.25,
                        1.25,
                        1.25
                    )

            } else {

                material.diffuse.contents =
                    UIColor(
                        red: 0.10,
                        green: 0.15,
                        blue: 0.25,
                        alpha: 1.0
                    )

                material.emission.contents =
                    UIColor(
                        red: 0.0,
                        green: 0.02,
                        blue: 0.05,
                        alpha: 1.0
                    )

                node.scale =
                    SCNVector3(
                        1.0,
                        1.0,
                        1.0
                    )
            }
        }
    }
}


// MARK: - SceneKit Camera Helper

extension SCNNode {

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


// MARK: - SceneKit View

struct QRTLMemorySceneView:
    UIViewRepresentable {

    @ObservedObject
    var state: QRTLMemoryTestState

    final class Coordinator {

        var memoryScene:
            QRTLMemoryScene?

        var sceneView:
            SCNView?
    }

    func makeCoordinator()
        -> Coordinator {

        Coordinator()
    }

    func makeUIView(
        context: Context
    ) -> SCNView {

        let memoryScene =
            QRTLMemoryScene(
                state: state
            )

        context.coordinator.memoryScene =
            memoryScene

        let view =
            SCNView(
                frame: .zero
            )

        context.coordinator.sceneView =
            view

        view.scene =
            memoryScene.scene

        view.backgroundColor =
            UIColor.black

        view.isPlaying =
            true

        view.rendersContinuously =
            true

        view.preferredFramesPerSecond =
            60

        view.allowsCameraControl =
            true

        view.autoenablesDefaultLighting =
            false

        view.showsStatistics =
            false

        return view
    }

    func updateUIView(
        _ view: SCNView,
        context: Context
    ) {

        view.isPlaying =
            true

        view.rendersContinuously =
            true

        context.coordinator
            .memoryScene?
            .updateBitVisualization(
                state: state
            )
    }
}


// MARK: - Content View

struct ContentView: View {

    @StateObject
    private var memoryState =
        QRTLMemoryTestState()

    @State
    private var selectedDWORD =
        0

    @State
    private var retentionInterval =
        1.0

    @State
    private var cycleCount =
        100

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    spacing: 16
                ) {

                    // ====================================================
                    // TITLE
                    // ====================================================

                    Text(
                        "QRTL DWORD MEMORY VALIDATION"
                    )
                    .font(
                        .title2.bold()
                    )

                    Text(
                        "32-bit storage and retrieval test"
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    // ====================================================
                    // MEMORY LATTICE
                    // ====================================================

                    QRTLMemorySceneView(
                        state: memoryState
                    )
                    .frame(
                        height: 430
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                    )

                    // ====================================================
                    // DWORD SELECTOR
                    // ====================================================

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text(
                            "DWORD Test"
                        )
                        .font(
                            .headline
                        )

                        Picker(
                            "DWORD",
                            selection:
                                $selectedDWORD
                        ) {

                            ForEach(
                                0..<memoryState.testDWORDs.count,
                                id: \.self
                            ) { index in

                                Text(
                                    "DWORD \(index): "
                                    + memoryState.hexString(
                                        memoryState.testDWORDs[index]
                                    )
                                )
                                .tag(index)
                            }
                        }
                        .pickerStyle(
                            .menu
                        )
                    }

                    // ====================================================
                    // TEST BUTTON
                    // ====================================================

                    Button {

                        memoryState.runCompleteTest(
                            dwordIndex:
                                selectedDWORD,
                            retentionInterval:
                                retentionInterval,
                            cycles:
                                cycleCount
                        )

                    } label: {

                        Label(
                            "Run DWORD Test",
                            systemImage:
                                "memorychip"
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )

                    // ====================================================
                    // STATUS
                    // ====================================================

                    Text(
                        memoryState.status
                    )
                    .font(
                        .headline
                    )
                    .foregroundStyle(
                        memoryState.verificationPassed
                        ? .green
                        : .primary
                    )

                    // ====================================================
                    // BASIC DWORD INFORMATION
                    // ====================================================

                    metricSection(
                        title:
                            "DWORD Identification"
                    ) {

                        metricRow(
                            "Memory Address",
                            String(
                                format:
                                    "0x%08X",
                                memoryState.memoryAddress
                            )
                        )

                        metricRow(
                            "Write Command",
                            memoryState.hexString(
                                memoryState.writeCommand
                            )
                        )

                        metricRow(
                            "Read Command",
                            String(
                                format:
                                    "0x%08X",
                                memoryState.readAddress
                            )
                        )

                        metricRow(
                            "Returned DWORD",
                            memoryState.hexString(
                                memoryState.returnedDWORD
                            )
                        )
                    }

                    // ====================================================
                    // BIT STATE
                    // ====================================================

                    metricSection(
                        title:
                            "Bit State"
                    ) {

                        metricRow(
                            "Stored Bits",
                            memoryState.binaryString(
                                memoryState.writeCommand
                            )
                        )

                        metricRow(
                            "Detected Bits",
                            memoryState.binaryString(
                                memoryState.returnedDWORD
                            )
                        )

                        metricRow(
                            "Bit Count",
                            "32"
                        )
                    }

                    // ====================================================
                    // TIMING
                    // ====================================================

                    metricSection(
                        title:
                            "Timing"
                    ) {

                        metricRow(
                            "Write Time",
                            formatSeconds(
                                memoryState.writeTimeSeconds
                            )
                        )

                        metricRow(
                            "Read Time",
                            formatSeconds(
                                memoryState.readTimeSeconds
                            )
                        )

                        metricRow(
                            "Retention Interval",
                            String(
                                format:
                                    "%.3f s",
                                memoryState.retentionSeconds
                            )
                        )
                    }

                    // ====================================================
                    // READ SIGNAL
                    // ====================================================

                    metricSection(
                        title:
                            "Read Signal"
                    ) {

                        metricRow(
                            "Signal 0",
                            String(
                                format:
                                    "%.3f",
                                memoryState.lowSignal
                            )
                        )

                        metricRow(
                            "Signal 1",
                            String(
                                format:
                                    "%.3f",
                                memoryState.highSignal
                            )
                        )

                        metricRow(
                            "Detection Threshold",
                            String(
                                format:
                                    "%.3f",
                                memoryState.readThreshold
                            )
                        )

                        metricRow(
                            "Read Signals",
                            signalSummary()
                        )
                    }

                    // ====================================================
                    // ACCURACY
                    // ====================================================

                    metricSection(
                        title:
                            "Accuracy"
                    ) {

                        metricRow(
                            "Write Accuracy",
                            percent(
                                memoryState.writeAccuracyPercent
                            )
                        )

                        metricRow(
                            "Read Accuracy",
                            percent(
                                memoryState.readAccuracyPercent
                            )
                        )

                        metricRow(
                            "Bit Retention",
                            percent(
                                memoryState.retentionPercent
                            )
                        )
                    }

                    // ====================================================
                    // CYCLES
                    // ====================================================

                    metricSection(
                        title:
                            "Read / Write Cycles"
                    ) {

                        metricRow(
                            "Requested Cycles",
                            "\(memoryState.requestedCycles)"
                        )

                        metricRow(
                            "Successful Cycles",
                            "\(memoryState.successfulCycles)"
                        )

                        metricRow(
                            "Cycle Success Rate",
                            percent(
                                memoryState
                                    .cycleSuccessRatePercent
                            )
                        )
                    }

                    // ====================================================
                    // ERROR RATE
                    // ====================================================

                    metricSection(
                        title:
                            "Error Analysis"
                    ) {

                        metricRow(
                            "Incorrect Bits",
                            "\(memoryState.incorrectBits)"
                        )

                        metricRow(
                            "Total Bits Tested",
                            "\(memoryState.totalBitsTested)"
                        )

                        metricRow(
                            "Error Rate",
                            percent(
                                memoryState.errorRatePercent
                            )
                        )
                    }

                    // ====================================================
                    // VERIFICATION
                    // ====================================================

                    VStack(
                        spacing: 8
                    ) {

                        Text(
                            "DWORD Verification"
                        )
                        .font(
                            .headline
                        )

                        HStack {

                            Text("EXPECTED")

                            Spacer()

                            Text(
                                memoryState.hexString(
                                    memoryState.writeCommand
                                )
                            )
                            .monospaced()
                        }

                        HStack {

                            Text("RETURNED")

                            Spacer()

                            Text(
                                memoryState.hexString(
                                    memoryState.returnedDWORD
                                )
                            )
                            .monospaced()
                        }

                        Divider()

                        Text(
                            memoryState.verificationPassed
                            ? "✓ MEMORY PASS"
                            : "✕ MEMORY FAIL"
                        )
                        .font(
                            .title3.bold()
                        )
                        .foregroundStyle(
                            memoryState.verificationPassed
                            ? .green
                            : .red
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(
                            cornerRadius: 12
                        )
                        .fill(
                            .thinMaterial
                        )
                    )
                }
                .padding()
            }
            .navigationTitle(
                "QRTL Memory"
            )
        }
    }

    // ================================================================
    // METRIC SECTION
    // ================================================================

    @ViewBuilder
    private func metricSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Text(title)
                .font(
                    .headline
                )

            content()
        }
        .padding()
        .background(
            RoundedRectangle(
                cornerRadius: 12
            )
            .fill(
                .thinMaterial
            )
        )
    }

    // ================================================================
    // METRIC ROW
    // ================================================================

    private func metricRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack {

            Text(title)

            Spacer()

            Text(value)
                .font(
                    .system(
                        .body,
                        design: .monospaced
                    )
                )
                .multilineTextAlignment(
                    .trailing
                )
        }
    }

    // ================================================================
    // FORMAT PERCENT
    // ================================================================

    private func percent(
        _ value: Double
    ) -> String {

        String(
            format:
                "%.4f %%",
            value
        )
    }

    // ================================================================
    // FORMAT TIME
    // ================================================================

    private func formatSeconds(
        _ value: Double
    ) -> String {

        if value < 0.001 {

            return String(
                format:
                    "%.3f µs",
                value * 1_000_000
            )

        } else if value < 1.0 {

            return String(
                format:
                    "%.3f ms",
                value * 1_000
            )

        } else {

            return String(
                format:
                    "%.3f s",
                value
            )
        }
    }

    // ================================================================
    // READ SIGNAL SUMMARY
    // ================================================================

    private func signalSummary()
        -> String {

        guard
            !memoryState.readSignals.isEmpty
        else {
            return "—"
        }

        let lowCount =
            memoryState.readSignals
                .filter {
                    $0 < memoryState.readThreshold
                }
                .count

        let highCount =
            memoryState.readSignals
                .filter {
                    $0 >= memoryState.readThreshold
                }
                .count

        return
            "\(lowCount) LOW / \(highCount) HIGH"
    }
}


// MARK: - Preview

#Preview {

    ContentView()
}
