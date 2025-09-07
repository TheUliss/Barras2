//
//  Barras2App.swift
//  Barras2
//
//  Created by Ulises Islas on 18/07/25.
//
/*
import SwiftUI

@main
struct Barras2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
*/

import SwiftUI

@main
struct Barras2App: App {
    // Instanciamos ambos managers como @StateObject para que vivan durante todo el ciclo de la app.
    @StateObject private var dataManager = DataManager()
    @StateObject private var settingsManager = SettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView() // O tu vista de inicio
                // Inyectamos ambos en el entorno para que cualquier vista pueda acceder a ellos.
                .environmentObject(dataManager)
                .environmentObject(settingsManager)
        }
    }
}
