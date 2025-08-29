//
//  ContentView.swift
//  Barras2
//
//  Created by Ulises Islas on 18/07/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Main View
struct ContentView: View {
    @StateObject private var dataManager = DataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DebugScannerView()
                .environmentObject(dataManager)
                .tabItem {
                    Image(systemName: "barcode.viewfinder")
                    Text("Scanner")
                }
                .tag(0)
            
            CodigosListView()
                .environmentObject(dataManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Códigos")
                }
                .tag(1)
            
            StatisticsView()
                .environmentObject(dataManager)
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Resumen")
                }
                .tag(2)
            
            SearchCodigosView()
                .environmentObject(dataManager)
                .tabItem {
                    Image(systemName: "eye.square.fill")
                    Text("Busqueda")
                }
                .tag(3)

        }
    }
}


// MARK: - App
struct BarcodeScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
