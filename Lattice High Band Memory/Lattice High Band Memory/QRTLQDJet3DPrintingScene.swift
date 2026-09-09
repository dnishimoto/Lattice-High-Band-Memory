//
//  QRTLQDJet3DPrintingScene.swift
//  Lattice High Band Memory
//
//  Created by David Nishimoto on 9/6/26.
//

import Foundation
import SceneKit
import SwiftUI

final class QRTLQDJet3DPrintingScene {

    private var selectedLayerNode: SCNNode?
    private var selectedShelfNode: SCNNode?
    private var selectedBoxNode: SCNNode?
    private var selectedAccessWire: SCNNode?
    private var selectedQDNode: SCNNode?
    
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
        // SCENE BACKGROUND
        // ================================================================

        scene.background.contents = UIColor(
            white: 0.008,
            alpha: 1.0
        )

        // ================================================================
        // ROOT NODE HIERARCHY
        // ================================================================

        scene.rootNode.addChildNode(manufacturingRoot)

        manufacturingRoot.addChildNode(printerRoot)
        manufacturingRoot.addChildNode(latticeRoot)
        manufacturingRoot.addChildNode(robotRoot)
        manufacturingRoot.addChildNode(wireRoot)
        manufacturingRoot.addChildNode(dataRoot)

        // ================================================================
        // CAMERA TARGET
        //
        // The target is between the lattice center and printer nozzle.
        //
        // Lattice: approximately y = 0.75 to y = 5.75
        // Nozzle: y = 5.9
        // Carriage: y = 6.5
        // Gantry: y = 7.0
        // ================================================================

        let cameraTargetNode = SCNNode()

        cameraTargetNode.name = "CAMERA_TARGET"

        cameraTargetNode.position = SCNVector3(
            -0.5,
            3.75,
            0.0
        )

        scene.rootNode.addChildNode(cameraTargetNode)

        // ================================================================
        // CAMERA
        // ================================================================

        let cameraNode = SCNNode()
        let camera = SCNCamera()

        camera.fieldOfView = 55.0
        camera.zNear = 0.1
        camera.zFar = 200.0

        cameraNode.camera = camera

        // Explicit starting position.
        // The positive Z position looks toward the model centered near Z = 0.
        cameraNode.position = SCNVector3(
            13.0,
            9.5,
            18.0
        )

        let lookAtConstraint = SCNLookAtConstraint(
            target: cameraTargetNode
        )

        lookAtConstraint.isGimbalLockEnabled = true

        cameraNode.constraints = [
            lookAtConstraint
        ]

        scene.rootNode.addChildNode(cameraNode)

        // ================================================================
        // AMBIENT LIGHT
        // ================================================================

        let ambientNode = SCNNode()
        let ambientLight = SCNLight()

        ambientLight.type = .ambient
        ambientLight.intensity = 700.0
        ambientLight.color = UIColor(
            white: 0.82,
            alpha: 1.0
        )

        ambientNode.light = ambientLight

        scene.rootNode.addChildNode(ambientNode)

        // ================================================================
        // KEY LIGHT
        // ================================================================

        let keyLightNode = SCNNode()
        let keyLight = SCNLight()

        keyLight.type = .omni
        keyLight.intensity = 1600.0
        keyLight.color = UIColor.white
        keyLight.attenuationStartDistance = 5.0
        keyLight.attenuationEndDistance = 60.0

        keyLightNode.light = keyLight

        keyLightNode.position = SCNVector3(
            8.0,
            13.0,
            10.0
        )

        scene.rootNode.addChildNode(keyLightNode)

        // ================================================================
        // FILL LIGHT
        // ================================================================

        let fillLightNode = SCNNode()
        let fillLight = SCNLight()

        fillLight.type = .omni
        fillLight.intensity = 1100.0
        fillLight.color = UIColor(
            red: 0.72,
            green: 0.82,
            blue: 1.0,
            alpha: 1.0
        )

        fillLight.attenuationStartDistance = 5.0
        fillLight.attenuationEndDistance = 60.0

        fillLightNode.light = fillLight

        fillLightNode.position = SCNVector3(
            -10.0,
            9.0,
            -8.0
        )

        scene.rootNode.addChildNode(fillLightNode)

        // ================================================================
        // FRONT LIGHT
        //
        // Prevents the lattice from becoming too dark when the camera is
        // viewing from positive X / positive Z.
        // ================================================================

        let frontLightNode = SCNNode()
        let frontLight = SCNLight()

        frontLight.type = .omni
        frontLight.intensity = 900.0
        frontLight.color = UIColor(
            red: 0.75,
            green: 0.95,
            blue: 1.0,
            alpha: 1.0
        )

        frontLight.attenuationStartDistance = 3.0
        frontLight.attenuationEndDistance = 45.0

        frontLightNode.light = frontLight

        frontLightNode.position = SCNVector3(
            10.0,
            5.0,
            15.0
        )

        scene.rootNode.addChildNode(frontLightNode)
    }
    private func latticeAddressForDemoTransfer() -> LatticeAddress {
        LatticeAddress(
            layer: min(3, parameters.layers - 1),
            shelf: min(4, parameters.rows - 1),
            box: min(7, parameters.columns - 1)
        )
    }

    private func qdIndex(
        layer: Int,
        shelf: Int,
        box: Int
    ) -> Int {
        layer * parameters.rows * parameters.columns +
        shelf * parameters.columns +
        box
    }

    private func latticePosition(
        layer: Int,
        shelf: Int,
        box: Int
    ) -> SCNVector3 {

        let startX =
            -Float(parameters.columns - 1) *
            parameters.latticeSpacing *
            0.5

        let startZ =
            -Float(parameters.rows - 1) *
            parameters.latticeSpacing *
            0.5

        let startY: Float = 0.75

        return SCNVector3(
            startX + Float(box) * parameters.latticeSpacing,
            startY + Float(layer) * parameters.latticeSpacing,
            startZ + Float(shelf) * parameters.latticeSpacing
        )
    }

    private func clearLatticeAccessSelection() {
        selectedLayerNode?.removeFromParentNode()
        selectedShelfNode?.removeFromParentNode()
        selectedBoxNode?.removeFromParentNode()
        selectedAccessWire?.removeFromParentNode()

        selectedLayerNode = nil
        selectedShelfNode = nil
        selectedBoxNode = nil
        selectedAccessWire = nil

        selectedQDNode?.removeAllActions()

        if let material = selectedQDNode?.geometry?.firstMaterial {
            material.diffuse.contents = UIColor.systemTeal
            material.emission.contents = UIColor.systemTeal
        }

        selectedQDNode = nil
    }

    private func makeTransparentMaterial(
        color: UIColor,
        alpha: CGFloat,
        emission: UIColor
    ) -> SCNMaterial {

        let material = SCNMaterial()

        material.diffuse.contents = color.withAlphaComponent(alpha)
        material.emission.contents = emission
        material.isDoubleSided = true
        material.transparency = alpha

        return material
    }

    private func animateLatticeAccess(
        generation: Int,
        completion: @escaping () -> Void
    ) {
        guard generation == animationGeneration else {
            return
        }

        guard !qdNodes.isEmpty else {
            completion()
            return
        }

        clearLatticeAccessSelection()

        let address = latticeAddressForDemoTransfer()

        let selectedIndex = qdIndex(
            layer: address.layer,
            shelf: address.shelf,
            box: address.box
        )

        guard selectedIndex >= 0,
              selectedIndex < qdNodes.count else {
            completion()
            return
        }

        let selectedPosition = latticePosition(
            layer: address.layer,
            shelf: address.shelf,
            box: address.box
        )

        let selectedQD = qdNodes[selectedIndex]
        selectedQDNode = selectedQD

        let cubeWidth =
            CGFloat(parameters.columns) *
            CGFloat(parameters.latticeSpacing)

        let cubeDepth =
            CGFloat(parameters.rows) *
            CGFloat(parameters.latticeSpacing)

        let cubeHeight =
            CGFloat(parameters.layers) *
            CGFloat(parameters.latticeSpacing)

        let latticeBaseY: Float = 0.75

        let layerY =
            latticeBaseY +
            Float(address.layer) * parameters.latticeSpacing

        // -------------------------------------------------------------
        // STEP 1: LAYER SELECT
        // The horizontal glowing plane represents choosing one floor.
        // -------------------------------------------------------------

        let layerGeometry = SCNBox(
            width: cubeWidth + 0.18,
            height: 0.12,
            length: cubeDepth + 0.18,
            chamferRadius: 0.04
        )

        layerGeometry.materials = [
            makeTransparentMaterial(
                color: UIColor.systemPurple,
                alpha: 0.26,
                emission: UIColor.systemPurple
            )
        ]

        let layerNode = SCNNode(geometry: layerGeometry)
        layerNode.name = "SELECTED_LAYER_\(address.layer)"
        layerNode.position = SCNVector3(0, layerY, 0)
        layerNode.opacity = 0

        latticeRoot.addChildNode(layerNode)
        selectedLayerNode = layerNode

        // -------------------------------------------------------------
        // STEP 2: SHELF SELECT
        // A glowing horizontal shelf/row corridor along the X axis.
        // -------------------------------------------------------------

        let shelfGeometry = SCNBox(
            width: cubeWidth + 0.24,
            height: 0.20,
            length: CGFloat(parameters.latticeSpacing) * 0.42,
            chamferRadius: 0.04
        )

        shelfGeometry.materials = [
            makeTransparentMaterial(
                color: UIColor.systemOrange,
                alpha: 0.78,
                emission: UIColor.systemOrange
            )
        ]

        let shelfNode = SCNNode(geometry: shelfGeometry)
        shelfNode.name = "SELECTED_SHELF_\(address.shelf)"
        shelfNode.position = SCNVector3(
            0,
            selectedPosition.y,
            selectedPosition.z
        )
        shelfNode.opacity = 0

        latticeRoot.addChildNode(shelfNode)
        selectedShelfNode = shelfNode

        // -------------------------------------------------------------
        // STEP 3: BOX SELECT
        // A small highlight cube marks the selected addressable box.
        // -------------------------------------------------------------

        let boxGeometry = SCNBox(
            width: CGFloat(parameters.latticeSpacing) * 0.70,
            height: CGFloat(parameters.latticeSpacing) * 0.70,
            length: CGFloat(parameters.latticeSpacing) * 0.70,
            chamferRadius: 0.08
        )

        let boxMaterial = makeTransparentMaterial(
            color: UIColor.systemYellow,
            alpha: 0.90,
            emission: UIColor.systemYellow
        )

        boxMaterial.fillMode = .lines

        boxGeometry.materials = [boxMaterial]

        let boxNode = SCNNode(geometry: boxGeometry)
        boxNode.name = "SELECTED_BOX_\(address.box)"
        boxNode.position = selectedPosition
        boxNode.opacity = 0

        latticeRoot.addChildNode(boxNode)
        selectedBoxNode = boxNode

        // -------------------------------------------------------------
        // ACCESS WIRE
        // Represents the lattice wire at the selected shelf/box position.
        // It spans the stack and is energized only for the selected path.
        // -------------------------------------------------------------

        let wireGeometry = SCNCylinder(
            radius: 0.075,
            height: cubeHeight + 1.10
        )

        wireGeometry.firstMaterial?.diffuse.contents = UIColor.systemYellow
        wireGeometry.firstMaterial?.emission.contents = UIColor.systemYellow

        let wireNode = SCNNode(geometry: wireGeometry)
        wireNode.name = "ACTIVE_ACCESS_WIRE"

        wireNode.position = SCNVector3(
            selectedPosition.x,
            latticeBaseY + Float(parameters.layers - 1) *
            parameters.latticeSpacing * 0.5,
            selectedPosition.z
        )

        wireNode.opacity = 0

        wireRoot.addChildNode(wireNode)
        selectedAccessWire = wireNode

        // -------------------------------------------------------------
        // SELECTED QD CELL
        // This is the actual physical storage cell reached by the address.
        // -------------------------------------------------------------

        selectedQD.removeAllActions()

        if let material = selectedQD.geometry?.firstMaterial {
            material.diffuse.contents = UIColor.systemGreen
            material.emission.contents = UIColor.systemGreen
        }

        selectedQD.runAction(
            SCNAction.repeatForever(
                SCNAction.sequence([
                    SCNAction.scale(to: 1.85, duration: 0.32),
                    SCNAction.scale(to: 1.20, duration: 0.32)
                ])
            ),
            forKey: "selectedQDCellPulse"
        )

        state?.status =
            "ADDRESS DECODE — LAYER \(address.layer), " +
            "SHELF \(address.shelf), BOX \(address.box)"

        let selectLayer = SCNAction.sequence([
            SCNAction.fadeIn(duration: 0.35),
            SCNAction.wait(duration: 0.55)
        ])

        let selectShelf = SCNAction.sequence([
            SCNAction.fadeIn(duration: 0.30),
            SCNAction.wait(duration: 0.55)
        ])

        let selectBox = SCNAction.sequence([
            SCNAction.fadeIn(duration: 0.25),
            SCNAction.wait(duration: 0.50)
        ])

        let energizeWire = SCNAction.sequence([
            SCNAction.fadeIn(duration: 0.25),
            SCNAction.wait(duration: 0.40)
        ])

        layerNode.runAction(
            SCNAction.sequence([
                selectLayer,
                SCNAction.run { [weak self] _ in
                    self?.state?.status =
                        "LAYER \(address.layer) SELECTED — FLOOR ACTIVATED"
                }
            ])
        )

        shelfNode.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: 0.90),
                selectShelf,
                SCNAction.run { [weak self] _ in
                    self?.state?.status =
                        "SHELF \(address.shelf) SELECTED — ROW ACTIVATED"
                }
            ])
        )

        boxNode.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: 1.80),
                selectBox,
                SCNAction.run { [weak self] _ in
                    self?.state?.status =
                        "BOX \(address.box) SELECTED — MEMORY WORD CONNECTED"
                }
            ])
        )

        wireNode.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: 2.55),
                energizeWire,
                SCNAction.run { [weak self] _ in
                    self?.state?.status =
                        "ACCESS WIRE ENABLED — DATA PATH OPEN"
                },
                SCNAction.wait(duration: 0.45),
                SCNAction.run { _ in
                    completion()
                }
            ])
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
        guard generation == animationGeneration else {
            return
        }

        state?.status = "MEMORY ADDRESS ACCESS SEQUENCE"

        animateLatticeAccess(generation: generation) { [weak self] in
            guard let self = self else {
                return
            }

            guard generation == self.animationGeneration else {
                return
            }

            self.state?.status =
                "WRITE — DATA BUS ENTERING SELECTED LATTICE BOX"

            self.createWriteParticles()

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 1.5
            ) {
                guard generation == self.animationGeneration else {
                    return
                }

                self.state?.status =
                    "READ — SELECTED LATTICE BOX RETURNING DATA"

                self.createReadParticles()
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 3.0
            ) {
                guard generation == self.animationGeneration else {
                    return
                }

                self.state?.status =
                    "3D MEMORY ONLINE — LAYER / SHELF / BOX ADDRESSING ACTIVE"
            }
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

