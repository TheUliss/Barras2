//
//  SettingsManager.swift
//  Barras2
//
//  Created by Ulises Islas on 06/09/25.
//


import SwiftUI
import Combine

// Esta clase manejará el guardado y la carga de las configuraciones de la app.
class SettingsManager: ObservableObject {
    @Published var logoImageData: Data? {
        didSet {
            UserDefaults.standard.set(logoImageData, forKey: "appLogoData")
        }
    }
    
    @Published var nombreRealizador: String {
        didSet {
            UserDefaults.standard.set(nombreRealizador, forKey: "nombreRealizador")
        }
    }
    
    @Published var turnoSeleccionado: String {
        didSet {
            UserDefaults.standard.set(turnoSeleccionado, forKey: "turnoSeleccionado")
        }
    }
    
    // Lista de turnos disponibles
    let turnos = ["N1", "N2", "N3", "N4"]
    
    init() {
        // Cargar los datos guardados al iniciar la app
        self.logoImageData = UserDefaults.standard.data(forKey: "appLogoData")
        self.nombreRealizador = UserDefaults.standard.string(forKey: "nombreRealizador") ?? ""
        self.turnoSeleccionado = UserDefaults.standard.string(forKey: "turnoSeleccionado") ?? "N1"
    }
    
    // Función para obtener la imagen del logo de forma segura
    func getLogoImage() -> Image? {
        guard let data = logoImageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}
