// ===================================
// DATAMANAGER.swift - CORREGIDO PARA PERSISTENCIA DE ARTÍCULOS
// ===================================

import SwiftUI
import Combine

class DataManager: ObservableObject {
    @Published var codigos: [CodigoBarras] = [] {
        didSet {
            // Solo guardar si no estamos cargando datos
            if !isLoadingData {
                saveData()
                objectWillChange.send()
            }
        }
    }
    
    @Published var articulos: [Articulo] = [] {
        didSet {
            // Solo guardar si no estamos cargando datos
            if !isLoadingData {
                saveData()
                objectWillChange.send()
            }
        }
    }
    
    private let codigosKey = "codigos_guardados"
    private let articulosKey = "articulos_guardados"
    private var isLoadingData = false // Flag para evitar guardado durante carga
    
    init() {
        loadData()
    }
    
    private func setupDefaultArticulos() {
        // Solo agregar artículos por defecto si NO hay ninguno guardado
        if articulos.isEmpty {
            articulos = [
                Articulo(nombre: "Producto A", descripcion: "Descripción del producto A"),
                Articulo(nombre: "Producto B", descripcion: "Descripción del producto B"),
            ]
            print("📦 Artículos por defecto creados")
        }
    }
    
    func addCodigo(_ codigo: CodigoBarras) {
        codigos.append(codigo)
    }
    
    func updateCodigo(_ updatedCodigo: CodigoBarras) {
        if let index = codigos.firstIndex(where: { $0.id == updatedCodigo.id }) {
            var codigoToUpdate = updatedCodigo
            codigoToUpdate.fechaModificacion = Date()
            
            DispatchQueue.main.async {
                self.codigos[index] = codigoToUpdate
                print("🔄 Código actualizado: \(codigoToUpdate.codigo)")
            }
        }
    }
    
    func deleteCodigo(_ codigo: CodigoBarras) {
        codigos.removeAll { $0.id == codigo.id }
    }
    
    func addArticulo(_ articulo: Articulo) {
        DispatchQueue.main.async {
            self.articulos.append(articulo)
            print("✅ Artículo agregado: \(articulo.nombre)")
        }
    }
    
    func deleteArticulo(_ articulo: Articulo) {
        DispatchQueue.main.async {
            self.articulos.removeAll { $0.id == articulo.id }
            print("🗑️ Artículo eliminado: \(articulo.nombre)")
        }
    }
    
    func updateArticulo(_ updatedArticulo: Articulo) {
        if let index = articulos.firstIndex(where: { $0.id == updatedArticulo.id }) {
            DispatchQueue.main.async {
                self.articulos[index] = updatedArticulo
                print("🔄 Artículo actualizado: \(updatedArticulo.nombre)")
            }
        }
    }
    
    private func saveData() {
        // No guardar si estamos cargando datos
        guard !isLoadingData else {
            print("⏸️ Guardado pausado - cargando datos")
            return
        }
        
        // Guardar códigos
        if let codigosData = try? JSONEncoder().encode(codigos) {
            UserDefaults.standard.set(codigosData, forKey: codigosKey)
            print("💾 Códigos guardados: \(codigos.count)")
        } else {
            print("❌ Error al guardar códigos")
        }
        
        // Guardar artículos
        if let articulosData = try? JSONEncoder().encode(articulos) {
            UserDefaults.standard.set(articulosData, forKey: articulosKey)
            print("💾 Artículos guardados: \(articulos.count)")
        } else {
            print("❌ Error al guardar artículos")
        }
    }
    
    private func loadData() {
        isLoadingData = true // Evitar que didSet guarde durante la carga
        
        // Cargar códigos
        if let codigosData = UserDefaults.standard.data(forKey: codigosKey),
           let decodedCodigos = try? JSONDecoder().decode([CodigoBarras].self, from: codigosData) {
            codigos = decodedCodigos
            print("📱 Códigos cargados: \(codigos.count)")
        } else {
            print("📱 No hay códigos guardados o error al cargar")
        }
        
        // Cargar artículos
        if let articulosData = UserDefaults.standard.data(forKey: articulosKey),
           let decodedArticulos = try? JSONDecoder().decode([Articulo].self, from: articulosData) {
            articulos = decodedArticulos
            print("📱 Artículos cargados: \(articulos.count)")
        } else {
            print("📱 No hay artículos guardados, creando artículos por defecto")
            // SOLO crear artículos por defecto si realmente no hay datos guardados
            setupDefaultArticulos()
        }
        
        isLoadingData = false // Reactivar guardado automático
        print("🔄 Carga de datos completada - isLoadingData: \(isLoadingData)")
    }
    
    // MARK: - Funciones de utilidad para manejo de datos
    func exportarDatos() -> String? {
        struct DatosExportacion: Codable {
            let codigos: [CodigoBarras]
            let articulos: [Articulo]
        }
        
        let datosCompletos = DatosExportacion(codigos: codigos, articulos: articulos)
        
        if let data = try? JSONEncoder().encode(datosCompletos),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return nil
    }
    
    func limpiarTodosLosDatos() {
        UserDefaults.standard.removeObject(forKey: codigosKey)
        UserDefaults.standard.removeObject(forKey: articulosKey)
        
        DispatchQueue.main.async {
            self.codigos.removeAll()
            self.articulos.removeAll()
            self.setupDefaultArticulos() // Recrear artículos por defecto
            print("🧹 Todos los datos limpiados")
        }
    }
    
    func obtenerEstadisticasDeGuardado() -> (codigosGuardados: Int, articulosGuardados: Int) {
        return (codigos.count, articulos.count)
    }
    
    // MARK: - Statistics
    func codigosPorOperacion() -> [(Operacion, Int)] {
        let grouped = Dictionary(grouping: codigos.compactMap { $0.currentOperacionLog?.operacion }) { $0 }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }
    
    func codigosPorArticulo() -> [(String, Int)] {
        let grouped = Dictionary(grouping: codigos.compactMap { $0.articulo?.nombre }) { $0 }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }
    
    func codigosOrdenadosPorFecha() -> [CodigoBarras] {
        return codigos.sorted { $0.fechaCreacion < $1.fechaCreacion }
    }
    
    func codigosPorOperacion(_ operacion: Operacion) -> [CodigoBarras] {
        return codigos.filter { $0.currentOperacionLog?.operacion == operacion }.sorted { $0.fechaCreacion < $1.fechaCreacion }
    }
    
    func codigosPorArticulo(_ articulo: String) -> [CodigoBarras] {
        return codigos.filter { $0.articulo?.nombre == articulo }.sorted { $0.fechaCreacion < $1.fechaCreacion }
    }
    
    // MARK: - Operaciones Especiales
    func updateCodigoOperacion(_ codigo: CodigoBarras, nuevaOperacion: Operacion) {
        if let index = codigos.firstIndex(where: { $0.id == codigo.id }) {
            var updatedCodigo = codigos[index]
            
            let newLog = OperacionLog(operacion: nuevaOperacion, timestamp: Date())
            updatedCodigo.operacionHistory.append(newLog)
            
            if nuevaOperacion.rawValue.lowercased() == "empaque" {
                updatedCodigo.auditado = false
                print("🔄 Código \(codigo.codigo) movido a Empaque - Estado auditado removido")
            }
            
            updatedCodigo.fechaModificacion = Date()
            
            DispatchQueue.main.async {
                self.codigos[index] = updatedCodigo
                self.objectWillChange.send()
                print("🔄 Operación actualizada para código: \(codigo.codigo) -> \(nuevaOperacion.rawValue)")
            }
        }
    }
    
    func marcarComoAuditado(_ codigo: CodigoBarras) {
        if let index = codigos.firstIndex(where: { $0.id == codigo.id }) {
            var updatedCodigo = codigos[index]
            
            if let currentLog = updatedCodigo.currentOperacionLog,
               currentLog.operacion.rawValue.lowercased() == "empaque" {
                print("⚠️ No se puede auditar - Código \(codigo.codigo) está en Empaque")
                return
            }
            
            updatedCodigo.auditado = true
            updatedCodigo.fechaModificacion = Date()
            
            DispatchQueue.main.async {
                self.codigos[index] = updatedCodigo
                self.objectWillChange.send()
                print("🔄 Código marcado como auditado: \(codigo.codigo)")
            }
        }
    }
    
    // MARK: - Funciones de debug para verificar persistencia
    func debugUserDefaults() {
        print("🔍 Debug UserDefaults:")
        print("   - Códigos key exists: \(UserDefaults.standard.object(forKey: codigosKey) != nil)")
        print("   - Artículos key exists: \(UserDefaults.standard.object(forKey: articulosKey) != nil)")
        
        if let articulosData = UserDefaults.standard.data(forKey: articulosKey) {
            print("   - Artículos data size: \(articulosData.count) bytes")
            if let decoded = try? JSONDecoder().decode([Articulo].self, from: articulosData) {
                print("   - Artículos decodificados: \(decoded.count)")
                for articulo in decoded {
                    print("     * \(articulo.nombre)")
                }
            } else {
                print("   - Error al decodificar artículos")
            }
        }
    }
    
    // Función para forzar guardado manual (útil para debug)
    func forzarGuardado() {
        saveData()
        print("💾 Guardado forzado completado")
    }
}
