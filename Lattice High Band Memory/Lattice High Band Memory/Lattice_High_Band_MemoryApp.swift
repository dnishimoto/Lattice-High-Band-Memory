//
//  Lattice_High_Band_MemoryApp.swift
//  Lattice High Band Memory
//
//  Created by David Nishimoto on 9/6/26.
//

import SwiftUI
import CoreData

@main
struct Lattice_High_Band_MemoryApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
