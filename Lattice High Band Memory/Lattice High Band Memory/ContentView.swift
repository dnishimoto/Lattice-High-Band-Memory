
//
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

    static func formatRate(
        _ bitsPerSecond: Double
    ) -> String {

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

    static func formatBytes(
        _ bytesPerSecond: Double
    ) -> String {

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

// MARK: - MANUFACTURING STATE

@MainActor
final class QRTLManufacturingState: ObservableObject {

    @Published var currentLayer: Int = 0

    @Published var depositedQDs: Int = 0
    @Published var totalQDs: Int = 0

    @Published var placedWires: Int = 0
    @Published var totalWires: Int = 0

    @Published var manufacturingState =
        "INITIALIZING"

    @Published var writeRate =
        "0 b/s"

    @Published var readRate =
        "0 b/s"

    @Published var writeBytes =
        "0 B/s"

    @Published var readBytes =
        "0 B/s"

    @Published var storageCapacity =
        "0 B"

    @Published var qdPrintRate =
        "0 QD/s"

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

// MARK: - QRTL SCENE

final class QRTLQDJet3DPrintingScene {

    let scene: SCNScene

    private let parameters: QRTLMemoryParameters

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

        scene = SCNScene()

        configureScene()
        buildEnvironment()
        buildQDJetPrinter()
        buildLattice()
        buildRoboticWireSystem()
        buildDataInterface()
    }

    // MARK: - SCENE CONFIGURATION

    private func configureScene() {

        scene.background.contents =
            UIColor(
                white: 0.008,
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

        // Camera

        let cameraNode = SCNNode()

        cameraNode.camera =
            SCNCamera()

        cameraNode.camera?.fieldOfView =
            48

        cameraNode.position =
            SCNVector3(
                15,
                11,
                19
            )

        cameraNode.lookAt(
            SCNVector3(
                0,
                3.0,
                0
            )
        )

        scene.rootNode.addChildNode(
            cameraNode
        )

        // Ambient light

        let ambient = SCNNode()

        ambient.light =
            SCNLight()

        ambient.light?.type =
            .ambient

        ambient.light?.intensity =
            650

        scene.rootNode.addChildNode(
            ambient
        )

        // Key light

        let keyLight = SCNNode()

        keyLight.light =
            SCNLight()

        keyLight.light?.type =
            .omni

        keyLight.light?.intensity =
            1400

        keyLight.position =
            SCNVector3(
                8,
                13,
                10
            )

        scene.rootNode.addChildNode(
            keyLight
        )

        // Secondary light

        let fillLight = SCNNode()

        fillLight.light =
            SCNLight()

        fillLight.light?.type =
            .omni

        fillLight.light?.intensity =
            900

        fillLight.position =
            SCNVector3(
                -10,
                8,
                -8
            )

        scene.rootNode.addChildNode(
            fillLight
        )
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

        // Build platform

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
                        "QD_\(column)_\(row)_\(layer)"

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

                    qdNodes.append(qd)

                    latticeRoot.addChildNode(
                        qd
                    )
                }
            }
        }

        // -----------------------------------------------------
        // BUILD LAYER VOLUMES
        //
        // Each layer becomes visible as the QDs are printed.
        // This creates the visual impression of a growing cube.
        // -----------------------------------------------------

        let width =
            CGFloat(
                parameters.columns
            )
            *
            CGFloat(
                parameters.latticeSpacing
            )

        let depth =
            CGFloat(
                parameters.rows
            )
            *
            CGFloat(
                parameters.latticeSpacing
            )

        let layerHeight =
            CGFloat(
                parameters.latticeSpacing
            )

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

            material.diffuse.contents = UIColor(
                red: 0.0,
                green: 1.0,
                blue: 1.0,
                alpha: 0.08
            )

            material.emission.contents = UIColor(
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

        // -----------------------------------------------------
        // FINAL CUBE OUTLINE
        // -----------------------------------------------------

        createFinalCubeOutline()
    }

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

        // Wire spans the entire completed cube.

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
            "ACCESS_WIRE_\(index)"

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

        // Reset QDs

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

        // Reset layer volumes

        for volume in layerVolumes {

            volume.removeAllActions()

            volume.opacity = 0
        }

        latticeCube?.removeAllActions()

        latticeCube?.opacity = 0

        // Remove wires

        for wire in accessWires {

            wire.removeFromParentNode()
        }

        accessWires.removeAll()

        // Remove data particles

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
            rateModel:
                QRTLDataRateModel(
                    parameters: parameters
                )
        )

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

        guard generation ==
                animationGeneration
        else {
            return
        }

        guard layer <
                parameters.layers
        else {

            finishLattice()

            DispatchQueue.main.asyncAfter(
                deadline:
                    .now() + 1.0
            ) {

                self.animateRoboticWirePlacement(
                    generation: generation
                )
            }

            return
        }

        let sitesPerLayer =
            parameters.columns *
            parameters.rows

        let start =
            layer *
            sitesPerLayer

        let end =
            start +
            sitesPerLayer

        state?.update(
            layer: layer + 1,
            deposited: start,
            total: qdNodes.count,
            wires: 0,
            totalWires: parameters.wireCount,
            state:
                "PRINTING 3D QD LAYER \(layer + 1)",
            rateModel:
                QRTLDataRateModel(
                    parameters: parameters
                )
        )

        var index = start

        func printNextQD() {

            guard generation ==
                    self.animationGeneration
            else {
                return
            }

            guard index < end
            else {

                // Complete visual layer.

                self.layerVolumes[layer].runAction(
                    SCNAction.fadeIn(
                        duration: 0.25
                    )
                )

                DispatchQueue.main.asyncAfter(
                    deadline:
                        .now() + 0.25
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

            // -------------------------------------------------
            // MOVE NOZZLE TO X/Z TARGET
            // -------------------------------------------------

            let nozzleTarget =
                SCNVector3(
                    target.x,
                    5.9,
                    target.z
                )

            // Carriage follows nozzle.

            let moveNozzle =
                SCNAction.move(
                    to: nozzleTarget,
                    duration: 0.025
                )

            let printAction =
                SCNAction.run { _ in

                    // Show the QD jet.

                    self.animateQDJet(
                        from:
                            self.nozzle.position,
                        to:
                            target
                    )

                    // QD appears at target.

                    qd.opacity = 1

                    qd.scale =
                        SCNVector3(
                            0.01,
                            0.01,
                            0.01
                        )

                    qd.runAction(
                        SCNAction.scale(
                            to: 1.0,
                            duration: 0.045
                        )
                    )

                    let deposited =
                        index + 1

                    self.state?.update(
                        layer:
                            layer + 1,
                        deposited:
                            deposited,
                        total:
                            self.qdNodes.count,
                        wires: 0,
                        totalWires:
                            self.parameters.wireCount,
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
                        printAction
                    ]
                )
            )

            self.nozzleCarriage.runAction(
                SCNAction.move(
                    to:
                        SCNVector3(
                            target.x,
                            6.5,
                            target.z
                        ),
                    duration: 0.025
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

    // MARK: - QD JET

    private func animateQDJet(
        from start: SCNVector3,
        to target: SCNVector3
    ) {

        // -----------------------------------------------------
        // VISIBLE JET PARTICLE
        // -----------------------------------------------------

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

        jet.position =
            start

        printerRoot.addChildNode(
            jet
        )

        let move =
            SCNAction.move(
                to: target,
                duration: 0.08
            )

        let scale =
            SCNAction.sequence(
                [
                    SCNAction.scale(
                        to: 1.5,
                        duration: 0.04
                    ),

                    SCNAction.scale(
                        to: 0.5,
                        duration: 0.04
                    )
                ]
            )

        let remove =
            SCNAction.removeFromParentNode()

        jet.runAction(
            SCNAction.group(
                [
                    move,
                    scale
                ]
            )
        )

        jet.runAction(
            SCNAction.sequence(
                [
                    SCNAction.wait(
                        duration: 0.09
                    ),
                    remove
                ]
            )
        )
    }

    // MARK: - COMPLETE CUBE

    private func finishLattice() {

        state?.manufacturingState =
            "3D QD LATTICE COMPLETED"

        // Make complete cube outline visible.

        latticeCube?.runAction(
            SCNAction.fadeIn(
                duration: 0.8
            )
        )

        // Give the completed cube a subtle pulse.

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
            SCNAction.repeat(
                pulse,
                count: 2
            )
        )
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

        guard generation ==
                animationGeneration
        else {
            return
        }

        guard index <
                parameters.wireCount
        else {

            state?.manufacturingState =
                "ACCESS WIRES REGISTERED"

            DispatchQueue.main.asyncAfter(
                deadline:
                    .now() + 0.8
            ) {

                self.animateDataTransfer(
                    generation: generation
                )
            }

            return
        }

        // -----------------------------------------------------
        // SELECT LATTICE COLUMN
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // CREATE WIRE ABOVE ROBOT
        // -----------------------------------------------------

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

        // Start at robot.

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

        // -----------------------------------------------------
        // ROBOT MOVEMENT
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // WIRE APPROACH
        // -----------------------------------------------------

        let approach =
            SCNAction.group(
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
                        duration: 0.2
                    )
                ]
            )

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

                    descendWire,

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
                ]
            )
        )

        // -----------------------------------------------------
        // GRIPPER TRACKS THE WIRE
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // ARM VISUAL MOVEMENT
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // NEXT WIRE
        // -----------------------------------------------------

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() +
                parameters.wireAnimationDuration
                + 0.55
        ) {

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

        state?.manufacturingState =
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

            self.state?.manufacturingState =
                "3D MEMORY ONLINE"
        }
    }

    // MARK: - WRITE DATA

    private func createWriteParticles() {

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
                    i %
                    qdNodes.count
                ].position

            let move =
                SCNAction.move(
                    to: target,
                    duration: 0.9
                )

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

            particle.runAction(
                SCNAction.group(
                    [
                        move,
                        pulse
                    ]
                )
            )

            particle.runAction(
                SCNAction.sequence(
                    [
                        SCNAction.wait(
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

    // MARK: - READ DATA

    private func createReadParticles() {

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

            let source =
                qdNodes[
                    i %
                    qdNodes.count
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

        view.allowsCameraControl =
            true

        view.autoenablesDefaultLighting =
            false

        view.backgroundColor =
            UIColor.black

        view.showsStatistics =
            false

        builder.startManufacturing()

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

        var builder:
            QRTLQDJet3DPrintingScene?
    }
}

// MARK: - CONTENT VIEW

struct ContentView:
    View {

    @StateObject
    private var state =
        QRTLManufacturingState()

    private let parameters =
        QRTLMemoryParameters()

    var body: some View {

        VStack(
            spacing: 0
        ) {

            // -------------------------------------------------
            // 3D MANUFACTURING SCENE
            // -------------------------------------------------

            QRTLQDJet3DPrintingView(
                state: state,
                parameters: parameters
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

            // -------------------------------------------------
            // MANUFACTURING MONITOR
            // -------------------------------------------------

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

                    // -------------------------------------------------
                    // 3D PRINTING
                    // -------------------------------------------------

                    Text(
                        "3D QD PRINTING"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "Layer: \(state.currentLayer) / \(parameters.layers)"
                    )

                    Text(
                        "QDs deposited: \(state.depositedQDs) / \(state.totalQDs)"
                    )

                    Text(
                        "QD jet rate: \(state.qdPrintRate)"
                    )

                    Divider()

                    // -------------------------------------------------
                    // ROBOTIC WIRES
                    // -------------------------------------------------

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

                    // -------------------------------------------------
                    // MEMORY DATA PATH
                    // -------------------------------------------------

                    Text(
                        "MEMORY DATA TRANSFER"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "WRITE / INPUT: \(state.writeRate)"
                    )

                    Text(
                        "READ / OUTPUT: \(state.readRate)"
                    )

                    Text(
                        "WRITE: \(state.writeBytes)"
                    )

                    Text(
                        "READ: \(state.readBytes)"
                    )

                    Divider()

                    // -------------------------------------------------
                    // STORAGE
                    // -------------------------------------------------

                    Text(
                        "3D MEMORY CAPACITY"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        state.storageCapacity
                    )

                    Text(
                        "\(parameters.columns) × \(parameters.rows) × \(parameters.layers) QD sites"
                    )

                    Divider()

                    // -------------------------------------------------
                    // EQUATIONS
                    // -------------------------------------------------

                    Text(
                        "DATA-RATE EQUATIONS"
                    )
                    .font(
                        .headline
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
                        "RIN = Nw × fw × BQD × Uw × ηw"
                    )
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )

                    Text(
                        "ROUT = Nr × fr × BQD × Ur × ηr"
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

                    Divider()

                    Text(
                        "MODEL NOTE"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "The QD jet, 3D lattice construction, robotic wire placement, and data particles are visualization models. The displayed memory bandwidth and capacity are configurable engineering simulation targets, not experimentally established QD-memory performance."
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
                maxHeight: 350
            )
        }
    }
}

// MARK: - PREVIEW

#Preview {
    ContentView()
}
