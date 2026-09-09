//
//  File.swift
//  Lattice High Band Memory
//
//  Created by David Nishimoto on 9/6/26.
//

import Foundation
import SwiftUI
import SceneKit


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
