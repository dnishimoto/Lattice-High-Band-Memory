
//
//  QRTLQDJet3DPrintingScene.swift
//
//  QRTL Quantum-Dot 3D Memory Manufacturing Animation
//
//  Pipeline:
//
//  EXTERNAL QDs
//      ↓
//  QD INK RESERVOIR
//      ↓
//  EHD QD JET
//      ↓
//  XYZ PRECISION POSITIONING
//      ↓
//  QD LATTICE DEPOSITION
//      ↓
//  LAYER-BY-LAYER 3D BUILD
//      ↓
//  ROBOTIC ACCESS-WIRE PLACEMENT
//      ↓
//  WIRE / QD REGISTRATION
//      ↓
//  READ / WRITE DATA PATH
//
//  IMPORTANT:
//  This is a visualization and engineering model.
//  The data-rate values are configurable simulation targets,
//  NOT experimentally established QD-memory performance.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

// MARK: - QD Memory Simulation Parameters

struct QRTLMemoryParameters {

    // ---------------------------------------------------------
    // LATTICE
    // ---------------------------------------------------------

    var columns: Int = 10
    var rows: Int = 8
    var layers: Int = 6

    // Scene-space distance between QD sites.
    var latticeSpacing: Float = 1.0

    // Visual QD radius.
    var qdRadius: CGFloat = 0.11

    // ---------------------------------------------------------
    // QD PRINTING
    // ---------------------------------------------------------

    // Simulated QD deposition frequency.
    var qdPrintFrequencyHz: Double = 120.0

    // Number of QDs deposited during one simulated jet event.
    var qdsPerJetEvent: Double = 1.0

    // Positioning/printing utilization.
    var printerUtilization: Double = 0.80

    // Estimated placement efficiency.
    var placementEfficiency: Double = 0.95

    // ---------------------------------------------------------
    // ACCESS WIRES
    // ---------------------------------------------------------

    var wireCount: Int = 12

    // Number of QD sites addressed by one wire.
    var sitesPerWire: Int = 40

    // ---------------------------------------------------------
    // MEMORY
    // ---------------------------------------------------------

    // Bits stored per QD.
    //
    // 1 = binary QD state.
    // 2 = four-state model.
    // etc.
    var bitsPerQD: Double = 1.0

    // Parallel read/write channels.
    var readChannels: Double = 12
    var writeChannels: Double = 12

    // Read/write operating frequency.
    var readFrequencyHz: Double = 100_000
    var writeFrequencyHz: Double = 100_000

    // Fraction of cycles actually transferring data.
    var readUtilization: Double = 0.85
    var writeUtilization: Double = 0.85

    // Read/write success probability.
    var readEfficiency: Double = 0.995
    var writeEfficiency: Double = 0.995

    // ---------------------------------------------------------
    // ANIMATION
    // ---------------------------------------------------------

    var qdAnimationDuration: TimeInterval = 0.12
    var wireAnimationDuration: TimeInterval = 0.8

    // Number of QDs animated before advancing the layer.
    var qdsPerAnimationBatch: Int = 10
}


// MARK: - Data Rate Model

struct QRTLDataRateModel {

    var parameters: QRTLMemoryParameters

    // ---------------------------------------------------------
    // Total number of QD storage sites
    // ---------------------------------------------------------

    var totalQDSites: Double {
        Double(
            parameters.columns *
            parameters.rows *
            parameters.layers
        )
    }

    // ---------------------------------------------------------
    // Storage capacity
    //
    // C = N_QD × B_QD
    // ---------------------------------------------------------

    var storageBits: Double {
        totalQDSites * parameters.bitsPerQD
    }

    var storageBytes: Double {
        storageBits / 8.0
    }

    // ---------------------------------------------------------
    // INPUT / WRITE RATE
    //
    // R_in =
    // N_channels × f_write × bits/QD
    // × utilization × efficiency
    //
    // ---------------------------------------------------------

    var writeBitsPerSecond: Double {

        parameters.writeChannels *
        parameters.writeFrequencyHz *
        parameters.bitsPerQD *
        parameters.writeUtilization *
        parameters.writeEfficiency
    }

    // ---------------------------------------------------------
    // OUTPUT / READ RATE
    //
    // R_out =
    // N_channels × f_read × bits/QD
    // × utilization × efficiency
    //
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
    // f_jet × QDs/event × utilization × efficiency
    // ---------------------------------------------------------

    var qdsPrintedPerSecond: Double {

        parameters.qdPrintFrequencyHz *
        parameters.qdsPerJetEvent *
        parameters.printerUtilization *
        parameters.placementEfficiency
    }

    // ---------------------------------------------------------
    // THEORETICAL WRITE BANDWIDTH
    //
    // Useful upper bound before interface limitations.
    // ---------------------------------------------------------

    var theoreticalWriteBitsPerSecond: Double {

        parameters.writeChannels *
        parameters.writeFrequencyHz *
        parameters.bitsPerQD
    }

    // ---------------------------------------------------------
    // THEORETICAL READ BANDWIDTH
    // ---------------------------------------------------------

    var theoreticalReadBitsPerSecond: Double {

        parameters.readChannels *
        parameters.readFrequencyHz *
        parameters.bitsPerQD
    }

    // ---------------------------------------------------------
    // Human-readable formatting
    // ---------------------------------------------------------

    static func formatRate(_ bitsPerSecond: Double) -> String {

        if bitsPerSecond >= 1_000_000_000 {
            return String(
                format: "%.2f Gb/s",
                bitsPerSecond / 1_000_000_000
            )
        }

        if bitsPerSecond >= 1_000_000 {
            return String(
                format: "%.2f Mb/s",
                bitsPerSecond / 1_000_000
            )
        }

        if bitsPerSecond >= 1_000 {
            return String(
                format: "%.2f kb/s",
                bitsPerSecond / 1_000
            )
        }

        return String(
            format: "%.2f b/s",
            bitsPerSecond
        )
    }

    static func formatBytes(_ bytesPerSecond: Double) -> String {

        if bytesPerSecond >= 1_000_000_000 {
            return String(
                format: "%.2f GB/s",
                bytesPerSecond / 1_000_000_000
            )
        }

        if bytesPerSecond >= 1_000_000 {
            return String(
                format: "%.2f MB/s",
                bytesPerSecond / 1_000_000
            )
        }

        if bytesPerSecond >= 1_000 {
            return String(
                format: "%.2f KB/s",
                bytesPerSecond / 1_000
            )
        }

        return String(
            format: "%.2f B/s",
            bytesPerSecond
        )
    }
}


// MARK: - Manufacturing State

@MainActor
final class QRTLManufacturingState: ObservableObject {

    @Published var currentLayer: Int = 0

    @Published var depositedQDs: Int = 0

    @Published var totalQDs: Int = 0

    @Published var placedWires: Int = 0

    @Published var totalWires: Int = 0

    @Published var manufacturingState: String =
        "INITIALIZING"

    @Published var writeRate: String = "0 b/s"

    @Published var readRate: String = "0 b/s"

    @Published var writeBytes: String = "0 B/s"

    @Published var readBytes: String = "0 B/s"

    @Published var storageCapacity: String = "0 B"

    @Published var qdPrintRate: String = "0 QD/s"

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
        manufacturingState = state

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


// MARK: - QRTL Scene Builder

final class QRTLQDJet3DPrintingScene {

    let scene: SCNScene

    private let parameters: QRTLMemoryParameters

    private weak var state: QRTLManufacturingState?

    // Scene hierarchy
    private let manufacturingRoot = SCNNode()
    private let printerRoot = SCNNode()
    private let latticeRoot = SCNNode()
    private let robotRoot = SCNNode()
    private let wireRoot = SCNNode()
    private let dataRoot = SCNNode()

    // Animated printer nozzle
    private let nozzle = SCNNode()

    // QD source
    private let reservoir = SCNNode()

    // Robotic arm
    private let robotArm = SCNNode()
    private let robotGripper = SCNNode()

    // Storage sites
    private var qdNodes: [SCNNode] = []

    // Access wires
    private var accessWires: [SCNNode] = []

    // Data particles
    private var dataParticles: [SCNNode] = []

    // Animation state
    private var animationGeneration = 0

    init(
        parameters: QRTLMemoryParameters,
        state: QRTLManufacturingState
    ) {

        self.parameters = parameters
        self.state = state

        scene = SCNScene()

        configureScene()
        buildEnvironment()
        buildQDJetPrinter()
        buildLattice()
        buildRoboticWireSystem()
        buildDataInterface()
    }


    // MARK: Scene Configuration

    private func configureScene() {

        scene.background.contents = UIColor(
            white: 0.015,
            alpha: 1.0
        )

        scene.rootNode.addChildNode(
            manufacturingRoot
        )

        manufacturingRoot.addChildNode(
            printerRoot
        )

        manufacturingRoot.addChildNode(
            latticeRoot
        )

        manufacturingRoot.addChildNode(
            robotRoot
        )

        manufacturingRoot.addChildNode(
            wireRoot
        )

        manufacturingRoot.addChildNode(
            dataRoot
        )

        let cameraNode = SCNNode()

        cameraNode.camera = SCNCamera()

        cameraNode.camera?.fieldOfView = 55

        cameraNode.position = SCNVector3(
            13,
            11,
            18
        )

        cameraNode.lookAt(
            SCNVector3(
                0,
                2,
                0
            )
        )

        scene.rootNode.addChildNode(
            cameraNode
        )

        let ambient = SCNNode()

        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 700

        scene.rootNode.addChildNode(
            ambient
        )

        let keyLight = SCNNode()

        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 1200

        keyLight.position = SCNVector3(
            8,
            12,
            8
        )

        scene.rootNode.addChildNode(
            keyLight
        )
    }


    // MARK: Environment

    private func buildEnvironment() {

        let base = SCNBox(
            width: 18,
            height: 0.35,
            length: 14,
            chamferRadius: 0.15
        )

        base.firstMaterial?.diffuse.contents =
            UIColor(
                white: 0.08,
                alpha: 1
            )

        let baseNode = SCNNode(
            geometry: base
        )

        baseNode.position = SCNVector3(
            0,
            -0.2,
            0
        )

        manufacturingRoot.addChildNode(
            baseNode
        )

        // Printer platform

        let printerPlatform = SCNBox(
            width: 7,
            height: 0.25,
            length: 7,
            chamferRadius: 0.08
        )

        printerPlatform.firstMaterial?.diffuse.contents =
            UIColor(
                white: 0.15,
                alpha: 1
            )

        let platformNode = SCNNode(
            geometry: printerPlatform
        )

        platformNode.position = SCNVector3(
            -1.5,
            0.1,
            0
        )

        manufacturingRoot.addChildNode(
            platformNode
        )
    }


    // MARK: QD Jet Printer

    private func buildQDJetPrinter() {

        // Reservoir

        let reservoirGeometry = SCNCylinder(
            radius: 0.65,
            height: 1.6
        )

        reservoirGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemBlue

        reservoir.geometry = reservoirGeometry

        reservoir.position = SCNVector3(
            -7,
            3.2,
            -1
        )

        printerRoot.addChildNode(
            reservoir
        )

        // Supply tube

        let supplyTube = makeCylinder(
            radius: 0.10,
            height: 3.5,
            color: UIColor.systemBlue
        )

        supplyTube.position = SCNVector3(
            -5.3,
            3.2,
            -1
        )

        supplyTube.eulerAngles.z = .pi / 2

        printerRoot.addChildNode(
            supplyTube
        )

        // Printer gantry

        let gantry = SCNBox(
            width: 8,
            height: 0.35,
            length: 0.35,
            chamferRadius: 0.05
        )

        gantry.firstMaterial?.diffuse.contents =
            UIColor(
                white: 0.25,
                alpha: 1
            )

        let gantryNode = SCNNode(
            geometry: gantry
        )

        gantryNode.position = SCNVector3(
            -1.5,
            7,
            0
        )

        printerRoot.addChildNode(
            gantryNode
        )

        // Nozzle carriage

        let carriage = SCNBox(
            width: 0.55,
            height: 0.55,
            length: 0.55,
            chamferRadius: 0.08
        )

        carriage.firstMaterial?.diffuse.contents =
            UIColor.systemGray

        let carriageNode = SCNNode(
            geometry: carriage
        )

        carriageNode.position = SCNVector3(
            -2,
            6.6,
            0
        )

        printerRoot.addChildNode(
            carriageNode
        )

        // Nozzle

        let nozzleGeometry = SCNCone(
            topRadius: 0.08,
            bottomRadius: 0.02,
            height: 0.8
        )

        nozzleGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemOrange

        nozzle.geometry = nozzleGeometry

        nozzle.position = SCNVector3(
            -2,
            6.0,
            0
        )

        printerRoot.addChildNode(
            nozzle
        )
    }


    // MARK: 3D QD Lattice

    private func buildLattice() {

        let startX =
            -Float(parameters.columns - 1)
            * parameters.latticeSpacing
            * 0.5

        let startZ =
            -Float(parameters.rows - 1)
            * parameters.latticeSpacing
            * 0.5

        let startY: Float = 0.7

        for layer in 0..<parameters.layers {

            for row in 0..<parameters.rows {

                for column in 0..<parameters.columns {

                    let geometry = SCNSphere(
                        radius: parameters.qdRadius
                    )

                    geometry.firstMaterial?.diffuse.contents =
                        UIColor.systemTeal

                    geometry.firstMaterial?.emission.contents =
                        UIColor.systemTeal

                    let qd = SCNNode(
                        geometry: geometry
                    )

                    qd.name =
                        "QD_\(column)_\(row)_\(layer)"

                    qd.position = SCNVector3(
                        startX +
                        Float(column)
                        * parameters.latticeSpacing,

                        startY +
                        Float(layer)
                        * parameters.latticeSpacing,

                        startZ +
                        Float(row)
                        * parameters.latticeSpacing
                    )

                    // Start hidden.
                    qd.opacity = 0

                    latticeRoot.addChildNode(
                        qd
                    )

                    qdNodes.append(qd)
                }
            }
        }

        // Lattice boundary

        let width =
            CGFloat(parameters.columns - 1)
            * CGFloat(parameters.latticeSpacing)

        let depth =
            CGFloat(parameters.rows - 1)
            * CGFloat(parameters.latticeSpacing)

        let height =
            CGFloat(parameters.layers - 1)
            * CGFloat(parameters.latticeSpacing)

        let latticeFrame = SCNBox(
            width: width + 0.7,
            height: height + 0.7,
            length: depth + 0.7,
            chamferRadius: 0.05
        )

        latticeFrame.firstMaterial?.diffuse.contents =
            UIColor(
                white: 0.15,
                alpha: 0.08
            )

        latticeFrame.firstMaterial?.isDoubleSided = true

        let frameNode = SCNNode(
            geometry: latticeFrame
        )

        frameNode.position = SCNVector3(
            0,
            0.7 + Float(height / 2),
            0
        )

        latticeRoot.addChildNode(
            frameNode
        )
    }


    // MARK: Robotic Access-Wire System

    private func buildRoboticWireSystem() {

        // Robot base

        let robotBaseGeometry = SCNCylinder(
            radius: 1.0,
            height: 0.5
        )

        robotBaseGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemGray

        let robotBase = SCNNode(
            geometry: robotBaseGeometry
        )

        robotBase.position = SCNVector3(
            7,
            0.4,
            0
        )

        robotRoot.addChildNode(
            robotBase
        )

        // Main arm

        let armGeometry = SCNCylinder(
            radius: 0.25,
            height: 4.0
        )

        armGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemGray2

        robotArm.geometry = armGeometry

        robotArm.position = SCNVector3(
            7,
            2.5,
            0
        )

        robotRoot.addChildNode(
            robotArm
        )

        // Gripper

        let gripperGeometry = SCNBox(
            width: 0.5,
            height: 0.25,
            length: 0.5,
            chamferRadius: 0.04
        )

        gripperGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemOrange

        robotGripper.geometry =
            gripperGeometry

        robotGripper.position =
            SCNVector3(
                7,
                4.7,
                0
            )

        robotRoot.addChildNode(
            robotGripper
        )
    }


    // MARK: Access Wires

    private func createAccessWire(
        index: Int
    ) -> SCNNode {

        let wireGeometry = SCNCylinder(
            radius: 0.035,
            height: 5.0
        )

        wireGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemYellow

        let wire = SCNNode(
            geometry: wireGeometry
        )

        wire.name =
            "ACCESS_WIRE_\(index)"

        return wire
    }


    // MARK: Data Interface

    private func buildDataInterface() {

        let interfaceGeometry = SCNBox(
            width: 3.5,
            height: 0.6,
            length: 3.5,
            chamferRadius: 0.1
        )

        interfaceGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemIndigo

        let interfaceNode = SCNNode(
            geometry: interfaceGeometry
        )

        interfaceNode.position =
            SCNVector3(
                7,
                0.8,
                -4.0
            )

        dataRoot.addChildNode(
            interfaceNode
        )
    }


    // MARK: Start Manufacturing Animation

    func startManufacturing() {

        animationGeneration += 1

        let generation =
            animationGeneration

        // Reset everything.

        for node in qdNodes {
            node.removeAllActions()
            node.opacity = 0
        }

        for wire in accessWires {
            wire.removeFromParentNode()
        }

        accessWires.removeAll()

        for particle in dataParticles {
            particle.removeFromParentNode()
        }

        dataParticles.removeAll()

        state?.update(
            layer: 0,
            deposited: 0,
            total: qdNodes.count,
            wires: 0,
            totalWires: parameters.wireCount,
            state: "QD-JET INITIALIZING",
            rateModel: QRTLDataRateModel(
                parameters: parameters
            )
        )

        animateLayer(
            layer: 0,
            generation: generation
        )
    }


    // MARK: Layer Animation

    private func animateLayer(
        layer: Int,
        generation: Int
    ) {

        guard generation == animationGeneration else {
            return
        }

        guard layer < parameters.layers else {

            animateRoboticWirePlacement(
                generation: generation
            )

            return
        }

        state?.update(
            layer: layer + 1,
            deposited: layer
                * parameters.columns
                * parameters.rows,
            total: qdNodes.count,
            wires: 0,
            totalWires: parameters.wireCount,
            state: "PRINTING QD LAYER \(layer + 1)",
            rateModel: QRTLDataRateModel(
                parameters: parameters
            )
        )

        let start =
            layer *
            parameters.columns *
            parameters.rows

        let end =
            start +
            parameters.columns *
            parameters.rows

        var index = start

        func printNextQD() {

            guard generation == self.animationGeneration else {
                return
            }

            guard index < end else {

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.5
                ) {

                    self.animateLayer(
                        layer: layer + 1,
                        generation: generation
                    )
                }

                return
            }

            let qd =
                self.qdNodes[index]

            let target =
                qd.position

            let nozzleStart =
                SCNVector3(
                    target.x,
                    6.0,
                    target.z
                )

            self.nozzle.position =
                nozzleStart

            let moveNozzle =
                SCNAction.move(
                    to: nozzleStart,
                    duration: 0.05
                )

            let printQD =
                SCNAction.run { node in

                    // Create visible QD jet.

                    self.animateQDJet(
                        from: node.position,
                        to: target
                    )

                    qd.opacity = 1.0

                    qd.scale =
                        SCNVector3(
                            0.1,
                            0.1,
                            0.1
                        )

                    qd.runAction(
                        SCNAction.scale(
                            to: 1.0,
                            duration: 0.10
                        )
                    )

                    let deposited =
                        index + 1

                    self.state?.update(
                        layer: layer + 1,
                        deposited: deposited,
                        total: self.qdNodes.count,
                        wires: 0,
                        totalWires: self.parameters.wireCount,
                        state:
                            "DEPOSITING QD \(deposited)",
                        rateModel:
                            QRTLDataRateModel(
                                parameters:
                                    self.parameters
                            )
                    )
                }

            self.nozzle.runAction(
                SCNAction.sequence(
                    [
                        moveNozzle,
                        printQD
                    ]
                )
            )

            index += 1

            DispatchQueue.main.asyncAfter(
                deadline:
                    .now() +
                    self.parameters.qdAnimationDuration
            ) {

                printNextQD()
            }
        }

        printNextQD()
    }


    // MARK: QD Jet Visualization

    private func animateQDJet(
        from start: SCNVector3,
        to target: SCNVector3
    ) {

        let jetGeometry = SCNSphere(
            radius: 0.035
        )

        jetGeometry.firstMaterial?.diffuse.contents =
            UIColor.systemOrange

        jetGeometry.firstMaterial?.emission.contents =
            UIColor.systemOrange

        let jetParticle =
            SCNNode(
                geometry: jetGeometry
            )

        jetParticle.position =
            start

        printerRoot.addChildNode(
            jetParticle
        )

        let move =
            SCNAction.move(
                to: target,
                duration: 0.10
            )

        let fade =
            SCNAction.fadeOut(
                duration: 0.05
            )

        let remove =
            SCNAction.removeFromParentNode()

        jetParticle.runAction(
            SCNAction.sequence(
                [
                    move,
                    fade,
                    remove
                ]
            )
        )
    }


    // MARK: Robotic Wire Placement

    private func animateRoboticWirePlacement(
        generation: Int
    ) {

        guard generation == animationGeneration else {
            return
        }

        state?.manufacturingState =
            "ROBOTIC ACCESS-WIRE PLACEMENT"

        placeWire(
            index: 0,
            generation: generation
        )
    }


    private func placeWire(
        index: Int,
        generation: Int
    ) {

        guard generation == animationGeneration else {
            return
        }

        guard index < parameters.wireCount else {

            state?.manufacturingState =
                "3D MEMORY READY"

            animateDataTransfer(
                generation: generation
            )

            return
        }

        let wire =
            createAccessWire(
                index: index
            )

        let x =
            -3.5 +
            Float(index % parameters.columns)
            * 0.7

        let z =
            -2.5 +
            Float(index / parameters.columns)
            * 0.8

        // Robot starts above the lattice.

        wire.position =
            SCNVector3(
                7,
                6.0,
                0
            )

        wire.opacity = 0

        wireRoot.addChildNode(
            wire
        )

        accessWires.append(
            wire
        )

        let approach =
            SCNAction.group(
                [
                    SCNAction.move(
                        to: SCNVector3(
                            x,
                            5.0,
                            z
                        ),
                        duration: 0.45
                    ),

                    SCNAction.fadeIn(
                        duration: 0.25
                    )
                ]
            )

        let descend =
            SCNAction.move(
                to: SCNVector3(
                    x,
                    2.5,
                    z
                ),
                duration: 0.45
            )

        let lock =
            SCNAction.run { _ in

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
                        "WIRE \(index + 1) REGISTERED",
                    rateModel:
                        QRTLDataRateModel(
                            parameters:
                                self.parameters
                        )
                )
            }

        wire.runAction(
            SCNAction.sequence(
                [
                    approach,
                    descend,
                    lock
                ]
            )
        )

        // Animate robot gripper following wire.

        robotGripper.runAction(
            SCNAction.move(
                to: SCNVector3(
                    x,
                    3.5,
                    z
                ),
                duration: 0.8
            )
        )

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() +
                parameters.wireAnimationDuration
        ) {

            self.placeWire(
                index: index + 1,
                generation: generation
            )
        }
    }


    // MARK: Data Transfer

    private func animateDataTransfer(
        generation: Int
    ) {

        guard generation == animationGeneration else {
            return
        }

        state?.manufacturingState =
            "READ / WRITE DATA TRANSFER"

        createWriteParticles()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 2.0
        ) {

            guard generation ==
                    self.animationGeneration
            else {
                return
            }

            self.createReadParticles()
        }
    }


    // MARK: Write Data Flow

    private func createWriteParticles() {

        for i in 0..<12 {

            let particleGeometry =
                SCNSphere(
                    radius: 0.06
                )

            particleGeometry.firstMaterial?.diffuse.contents =
                UIColor.systemGreen

            particleGeometry.firstMaterial?.emission.contents =
                UIColor.systemGreen

            let particle =
                SCNNode(
                    geometry:
                        particleGeometry
                )

            particle.position =
                SCNVector3(
                    7,
                    1.5,
                    -4
                )

            dataRoot.addChildNode(
                particle
            )

            dataParticles.append(
                particle
            )

            let target =
                qdNodes[
                    i % qdNodes.count
                ].position

            let path =
                SCNAction.move(
                    to: target,
                    duration: 1.0
                )

            let remove =
                SCNAction.removeFromParentNode()

            particle.runAction(
                SCNAction.sequence(
                    [
                        path,
                        remove
                    ]
                )
            )
        }
    }


    // MARK: Read Data Flow

    private func createReadParticles() {

        for i in 0..<12 {

            let particleGeometry =
                SCNSphere(
                    radius: 0.06
                )

            particleGeometry.firstMaterial?.diffuse.contents =
                UIColor.systemCyan

            particleGeometry.firstMaterial?.emission.contents =
                UIColor.systemCyan

            let particle =
                SCNNode(
                    geometry:
                        particleGeometry
                )

            let source =
                qdNodes[
                    i % qdNodes.count
                ].position

            particle.position =
                source

            dataRoot.addChildNode(
                particle
            )

            dataParticles.append(
                particle
            )

            let target =
                SCNVector3(
                    7,
                    1.5,
                    -4
                )

            particle.runAction(
                SCNAction.sequence(
                    [
                        SCNAction.move(
                            to: target,
                            duration: 1.0
                        ),

                        SCNAction.removeFromParentNode()
                    ]
                )
            )
        }
    }


    // MARK: Utility

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


// MARK: - SCNVector3 Look-At Helper

private extension SCNNode {

    func lookAt(_ target: SCNVector3) {

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


// MARK: - SwiftUI Scene View

struct QRTLQDJet3DPrintingView: UIViewRepresentable {

    @ObservedObject
    var state: QRTLManufacturingState

    let parameters: QRTLMemoryParameters

    func makeUIView(
        context: Context
    ) -> SCNView {

        let sceneBuilder =
            QRTLQDJet3DPrintingScene(
                parameters: parameters,
                state: state
            )

        context.coordinator.sceneBuilder =
            sceneBuilder

        let view =
            SCNView()

        view.scene =
            sceneBuilder.scene

        view.allowsCameraControl =
            true

        view.autoenablesDefaultLighting =
            false

        view.backgroundColor =
            UIColor.black

        view.showsStatistics =
            false

        sceneBuilder.startManufacturing()

        return view
    }

    func updateUIView(
        _ uiView: SCNView,
        context: Context
    ) {
    }

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator()
    }

    final class Coordinator {

        var sceneBuilder:
            QRTLQDJet3DPrintingScene?
    }
}


// MARK: - Main Content View

struct ContentView: View {

    @StateObject
    private var state =
        QRTLManufacturingState()

    private let parameters =
        QRTLMemoryParameters()

    var body: some View {

        VStack(
            spacing: 0
        ) {

            QRTLQDJet3DPrintingView(
                state: state,
                parameters: parameters
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text(
                        "QRTL QD-JET 3D MEMORY"
                    )
                    .font(
                        .title2.bold()
                    )

                    Text(
                        state.manufacturingState
                    )
                    .font(
                        .headline
                    )

                    Divider()

                    Text(
                        "QD PRINTING"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "Layer: \(state.currentLayer)"
                    )

                    Text(
                        "QDs deposited: \(state.depositedQDs) / \(state.totalQDs)"
                    )

                    Text(
                        "QD jet rate: \(state.qdPrintRate)"
                    )

                    Divider()

                    Text(
                        "ROBOTIC ACCESS WIRES"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "Registered: \(state.placedWires) / \(state.totalWires)"
                    )

                    Divider()

                    Text(
                        "MEMORY DATA TRANSFER"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "WRITE: \(state.writeRate)"
                    )

                    Text(
                        "READ: \(state.readRate)"
                    )

                    Text(
                        "WRITE: \(state.writeBytes)"
                    )

                    Text(
                        "READ: \(state.readBytes)"
                    )

                    Divider()

                    Text(
                        "TOTAL STORAGE"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        state.storageCapacity
                    )

                    Divider()

                    Text(
                        "DATA-RATE EQUATIONS"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "Rᵢₙ = Nw × fw × BQD × Uw × ηw"
                    )
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )

                    Text(
                        "Rₒᵤₜ = Nr × fr × BQD × Ur × ηr"
                    )
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )

                    Text(
                        "C = NQD × BQD"
                    )
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )

                    Text(
                        "RQD = fjet × QDs/event × U × η"
                    )
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )

                    Text(
                        "These rates are simulation parameters, not experimentally established QD-memory performance."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding()
            }
            .frame(
                maxHeight: 330
            )
        }
    }
}


// MARK: - Preview

#Preview {

    ContentView()
}

