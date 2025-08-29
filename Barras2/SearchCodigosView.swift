// SOLUCIÓN PARA OCULTAR TECLADO EN SearchCodigosView.swift
// Agrega estas modificaciones SIN eliminar ninguna función existente

import SwiftUI
import AVFoundation
import Combine

struct SearchCodigosView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedCodigo: CodigoBarras?
    @State private var showingDetail = false
    @State private var showingSearchInfo = false
    
    // NUEVO: Agregar FocusState para controlar el teclado
    @FocusState private var isSearchFieldFocused: Bool
    
    // Computed property para códigos filtrados (SIN CAMBIOS)
    var filteredCodigos: [CodigoBarras] {
        if searchText.isEmpty {
            return dataManager.codigos.sorted { $0.fechaCreacion > $1.fechaCreacion }
        }
        
        return dataManager.codigos.filter { codigo in
            matchesCodigo(codigo.codigo, searchText: searchText)
        }.sorted { $0.fechaCreacion > $1.fechaCreacion }
    }
    
    // Propiedad para detectar duplicados (SIN CAMBIOS)
    var duplicatedCodigos: Set<String> {
        let counts = dataManager.codigos.reduce(into: [String: Int]()) { $0[$1.codigo, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Search Bar MODIFICADO para ocultar teclado
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Buscar por últimas 3 o 4 cifras...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .focused($isSearchFieldFocused) // NUEVO: Conectar con FocusState
                            .onSubmit {
                                // NUEVO: Ocultar teclado al presionar "buscar"
                                hideKeyboard()
                            }
                        
                        // NUEVO: Botón para ocultar teclado cuando está activo
                        if isSearchFieldFocused {
                            Button("Hecho") {
                                hideKeyboard()
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        } else if !searchText.isEmpty {
                            Button("Limpiar") {
                                searchText = ""
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            showingSearchInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Mostrar info de búsqueda si está activada (SIN CAMBIOS)
                    if showingSearchInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📋 Formato de código: 12345678T-01-000")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("🔍 Busca por:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("• Últimas 3 cifras: 000")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• Últimas 4 caracteres: 678T")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                // MARK: - Results Header (SIN CAMBIOS)
                HStack {
                    Text("Resultados: \(filteredCodigos.count)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !searchText.isEmpty {
                        Text("para '\(searchText)'")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // MARK: - Results List (SIN CAMBIOS PERO AGREGAMOS GESTURE)
                if filteredCodigos.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No se encontraron códigos")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Verifica que el término de búsqueda sea correcto")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Sugerencias de búsqueda
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 Ejemplos de búsqueda:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("• Para código '12345678T-01-000' → busca: '000'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• Para código '12345678T-01-000' → busca: '678T'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    Spacer()
                    
                } else if filteredCodigos.isEmpty && searchText.isEmpty {
                    // Estado vacío cuando no hay códigos
                    VStack(spacing: 16) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No hay códigos escaneados")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Los códigos escaneados aparecerán aquí")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Spacer()
                    
                } else {
                    List {
                        ForEach(filteredCodigos) { codigo in
                            SearchResultRow(
                                codigo: codigo,
                                isDuplicate: duplicatedCodigos.contains(codigo.codigo),
                                searchText: searchText
                            )
                            .onTapGesture {
                                // NUEVO: Ocultar teclado al tocar una fila
                                hideKeyboard()
                                selectedCodigo = codigo
                                showingDetail = true
                            }
                            .onLongPressGesture {
                                UIPasteboard.general.string = codigo.codigo
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                        .onDelete { offsets in
                            deleteCodigos(at: offsets)
                        }
                    }
                    .listStyle(PlainListStyle())
                    // NUEVO: Gesto para ocultar teclado al hacer scroll
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                                if isSearchFieldFocused {
                                    hideKeyboard()
                                }
                            }
                    )
                }
            }
            .navigationTitle("Buscar Códigos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(filteredCodigos.isEmpty)
                    }
            }
            .onTapGesture {
                hideKeyboard()
            }
            // NUEVO: Detectar cuando aparece/desaparece la vista
            .onAppear {
                // Opcional: enfocar automáticamente el campo de búsqueda
                // isSearchFieldFocused = true
            }
            .sheet(isPresented: $showingDetail) {
                if let codigo = selectedCodigo {
                    // La hoja presenta la vista de detalles con el código guardado
                    CodigoDetailView(
                        codigo: codigo,
                        isNew: false
                    ) { updatedCodigo in
                        dataManager.updateCodigo(updatedCodigo)
                    }
                    .environmentObject(dataManager)
                }
            }
        }
    }
    
    // MARK: - Helper Methods (SIN CAMBIOS + NUEVA FUNCIÓN)
    
    // NUEVA FUNCIÓN: Para ocultar el teclado
    private func hideKeyboard() {
        isSearchFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Función para verificar si un código coincide con el texto de búsqueda (SIN CAMBIOS)
    private func matchesCodigo(_ codigo: String, searchText: String) -> Bool {
        let cleanSearchText = searchText.trimmingCharacters(in: .whitespaces)
        
        guard !cleanSearchText.isEmpty else { return true }
        
        // Separar el código por guiones
        let components = codigo.split(separator: "-")
        
        guard components.count >= 3 else { return false }
        
        let firstPart = String(components[0])  // "12345678T"
        let lastPart = String(components[2])   // "000"
        
        // Opción 1: Buscar en las últimas 3 cifras (última parte)
        if lastPart.contains(cleanSearchText) {
            return true
        }
        
        // Opción 2: Buscar en las últimas 4 cifras de la primera parte
        if firstPart.count >= 4 {
            let lastFourChars = String(firstPart.suffix(4))
            if lastFourChars.contains(cleanSearchText) {
                return true
            }
        }
        
        // Opción 3: Coincidencia exacta con el código completo (fallback)
        if codigo.lowercased().contains(cleanSearchText.lowercased()) {
            return true
        }
        
        return false
    }
    
    private func deleteCodigos(at offsets: IndexSet) {
        offsets.forEach { index in
            let codigo = filteredCodigos[index]
            dataManager.deleteCodigo(codigo)
        }
    }
}

// MARK: - Search Result Row (SIN CAMBIOS - mantener todas las funciones existentes)
struct SearchResultRow: View {
    let codigo: CodigoBarras
    let isDuplicate: Bool
    let searchText: String
    
    // Formateador para mostrar duraciones de tiempo
    private static let timeFormatter: DateComponentsFormatter = {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            return formatter
        }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // MARK: - Header con código y estado
            HStack {
                // Código con highlighting
                Text(highlightedCodigo)
                    .fontWeight(.bold)
                    .font(.system(.body, design: .monospaced))
                
                Spacer()
                
                // Estados (empaque/auditado)
                HStack(spacing: 8) {
                    if let currentLog = codigo.currentOperacionLog,
                       currentLog.operacion.rawValue.lowercased() == "empaque" {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("EMPAQUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    } else if codigo.auditado {
                        HStack(spacing: 4) {
                            Image(systemName: "a.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("AUDITADO")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if isDuplicate {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
            
            // MARK: - Información del artículo
            if let articulo = codigo.articulo {
                Label(articulo.nombre, systemImage: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // MARK: - Información de operación
            if let currentLog = codigo.currentOperacionLog {
                HStack {
                    Label("Actual", systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Text("\(currentLog.operacion.rawValue)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("(\(currentLog.timestamp, style: .time))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Tiempo transcurrido si hay operación anterior
                if let previousLog = codigo.previousOperacionLog {
                        let interval = currentLog.timestamp.timeIntervalSince(previousLog.timestamp)
                        // Usamos la propiedad estática
                        if let timeString = SearchResultRow.timeFormatter.string(from: interval) {
                            HStack {
                                Label("Duración", systemImage: "timer")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                
                                Text(timeString)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
            } else {
                Label("Sin operación asignada", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // MARK: - Información adicional
            HStack {
                if let cantidadPuntas = codigo.cantidadPuntas {
                    Label("\(cantidadPuntas) puntas", systemImage: "number.circle")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
                
                Spacer()
                
                Text(codigo.fechaCreacion, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(backgroundColorForCode) // MANTENIDO - SIN CAMBIOS
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties (SIN CAMBIOS - mantener todas las funciones existentes)
    
    /// Color de fondo según el estado del código
    private var backgroundColorForCode: Color {
        if let currentLog = codigo.currentOperacionLog,
           currentLog.operacion.rawValue.lowercased() == "empaque" {
            return Color.blue.opacity(0.15)
        } else if isDuplicate {
            return Color.yellow.opacity(0.25)
        } else {
            return Color.clear
        }
    }
    
    /// Texto del código con highlighting del término de búsqueda
    private var highlightedCodigo: AttributedString {
        var attributedString = AttributedString(codigo.codigo)
        
        if !searchText.isEmpty {
            let cleanSearchText = searchText.trimmingCharacters(in: .whitespaces)
            let codigoLower = codigo.codigo.lowercased()
            let searchLower = cleanSearchText.lowercased()
            
            if let range = codigoLower.range(of: searchLower) {
                let startIndex = attributedString.index(attributedString.startIndex,
                                                      offsetByCharacters: codigoLower.distance(from: codigoLower.startIndex, to: range.lowerBound))
                let endIndex = attributedString.index(startIndex,
                                                    offsetByCharacters: searchLower.count)
                
                attributedString[startIndex..<endIndex].backgroundColor = .yellow
                attributedString[startIndex..<endIndex].foregroundColor = .black
            }
        }
        
        return attributedString
    }
}

// MARK: - Preview (SIN CAMBIOS)
struct SearchCodigosView_Previews: PreviewProvider {
    static var previews: some View {
        SearchCodigosView()
            .environmentObject(DataManager())
    }
}
