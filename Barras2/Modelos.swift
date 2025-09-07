// ===================================
// 1. MODELOS.swift - CORREGIDO
// ===================================

import SwiftUI
import AVFoundation
import Combine
import Foundation

// MARK: - Models
struct CodigoBarras: Identifiable, Codable, Hashable {
    var id = UUID()
    let codigo: String
    let fechaCreacion: Date
    
    var articulo: Articulo?
    var auditado: Bool = false
    var cantidadPuntas: Int?
    var fechaEmbarque: Date?
    var fechaModificacion: Date?
    // Historial de operaciones en lugar de una sola operación
    var operacionHistory: [OperacionLog] = []
    
    var currentOperacionLog: OperacionLog? {
        operacionHistory.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    var previousOperacionLog: OperacionLog? {
        let sorted = operacionHistory.sorted { $0.timestamp > $1.timestamp }
        return sorted.count > 1 ? sorted[1] : nil
    }
    
    init(codigo: String) {
        self.codigo = codigo
        self.auditado = false
        self.fechaCreacion = Date()
    }
    
    static func == (lhs: CodigoBarras, rhs: CodigoBarras) -> Bool {
        lhs.codigo == rhs.codigo
    }
}

struct Articulo: Identifiable, Codable, Hashable {
    var id = UUID()
    var nombre: String
    var descripcion: String?
    var cantidadPuntasEsperadas: Int? // ← NUEVO CAMPO
    
    init(nombre: String, descripcion: String? = nil, cantidadPuntasEsperadas: Int? = nil) {
        self.nombre = nombre
        self.descripcion = descripcion
        self.cantidadPuntasEsperadas = cantidadPuntasEsperadas
    }
}

enum Operacion: String, CaseIterable, Codable {
        case ribonizado = "Ribonizado"
        case ensamble = "Ensamble"
        case pulido = "Pulido"
        case limpGeo = "Limp/Geo"
        case armado = "Armado"
        case etiquetas = "Etiquetas"
        case polaridad = "Polaridad"
        case prueba = "Prueba"
        case limpieza = "Limp|QA"
    case empaque = "Empaque"
}

struct OperacionLog: Identifiable, Codable, Hashable {
    var id = UUID()
    var operacion: Operacion
    var timestamp: Date
}

// MARK: - Extensiones para CodigoBarras
extension CodigoBarras {
    /// Cantidad de puntas faltantes para completar el artículo
    var puntasFaltantes: Int? {
        guard let esperadas = articulo?.cantidadPuntasEsperadas,
              let contadas = cantidadPuntas else { return nil }
        return max(0, esperadas - contadas)
    }
    
    /// Porcentaje de completitud del conteo de puntas
    var porcentajeCompletitud: Double? {
        guard let esperadas = articulo?.cantidadPuntasEsperadas,
              esperadas > 0,
              let contadas = cantidadPuntas else { return nil }
        return min(100.0, (Double(contadas) / Double(esperadas)) * 100.0)
    }
    
    /// Indica si hay discrepancia entre puntas esperadas y contadas
    var tieneDiscrepancia: Bool {
        guard let esperadas = articulo?.cantidadPuntasEsperadas,
              let contadas = cantidadPuntas else { return false }
        return contadas != esperadas
    }
    
    /// Texto descriptivo del estado de las puntas
    var estadoPuntas: String {
        guard let esperadas = articulo?.cantidadPuntasEsperadas else {
            if let contadas = cantidadPuntas {
                return "\(contadas) puntas"
            }
            return "Sin información de puntas"
        }
        
        guard let contadas = cantidadPuntas else {
            return "0/\(esperadas) puntas"
        }
        
        if contadas == esperadas {
            return "✅ \(contadas)/\(esperadas) puntas (Completo)"
        } else if contadas < esperadas {
            let faltantes = esperadas - contadas
            return "⚠️ \(contadas)/\(esperadas) puntas (Faltan \(faltantes))"
        } else {
            let exceso = contadas - esperadas
            return "🔴 \(contadas)/\(esperadas) puntas (+\(exceso) exceso)"
        }
    }
    
    /// Color del indicador basado en el estado de las puntas
    var colorEstadoPuntas: Color {
        guard let esperadas = articulo?.cantidadPuntasEsperadas,
              let contadas = cantidadPuntas else { return .secondary }
        
        if contadas == esperadas {
            return .green
        } else if contadas < esperadas {
            return .orange
        } else {
            return .red
        }
    }
}
