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
    
    // NUEVO: Estados adicionales para gestión mejorada de edición
    @State private var showingChangeDateSheet = false
    @State private var codigoToChangeDate: CodigoBarras?
    @State private var newDateForCodigo = Date()
    @State private var refreshID = UUID()
    
    @FocusState private var isSearchFieldFocused: Bool
    
    // Estado para activar el filtro de duplicados
    @State private var isFilteringDuplicates = false

    // La propiedad ahora considera el filtro de duplicados
    var filteredCodigos: [CodigoBarras] {
        // 1. Determinar la lista base: todos los códigos o solo los duplicados.
        let baseList = isFilteringDuplicates
            ? dataManager.codigos.filter { duplicatedCodigos.contains($0.codigo) }
            : dataManager.codigos

        // 2. Si no hay texto de búsqueda, devolver la lista base ordenada.
        if searchText.isEmpty {
            return baseList.sorted { $0.fechaCreacion > $1.fechaCreacion }
        }
        
        // 3. Si hay texto, filtrar la lista base.
        return baseList.filter { codigo in
            matchesCodigo(codigo.codigo, searchText: searchText)
        }.sorted { $0.fechaCreacion > $1.fechaCreacion }
    }
    
    var duplicatedCodigos: Set<String> {
        let counts = dataManager.codigos.reduce(into: [String: Int]()) { $0[$1.codigo, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Search Bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Buscar por últimas 3 o 4 cifras...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .focused($isSearchFieldFocused)
                            .onSubmit(hideKeyboard)
                        
                        if isSearchFieldFocused {
                            Button("Hecho") { hideKeyboard() }
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        } else if !searchText.isEmpty {
                            Button("Limpiar") { searchText = "" }
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { showingSearchInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if showingSearchInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📋 Formato de código: 12345678T-01-000").font(.caption).foregroundColor(.secondary)
                            Text("🔍 Busca por:").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                            Text("• Últimas 3 cifras: 000").font(.caption).foregroundColor(.secondary)
                            Text("• Últimas 4 caracteres: 678T").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.horizontal).padding(.vertical, 8).background(Color.blue.opacity(0.1)).cornerRadius(8).padding(.horizontal)
                    }
                }
                .padding(.top)
                
                // MARK: - Results Header
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
                
                // MARK: - Results List
                if filteredCodigos.isEmpty && (!searchText.isEmpty || isFilteringDuplicates) {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass").font(.system(size: 50)).foregroundColor(.gray)
                        Text("No se encontraron códigos").font(.title2).fontWeight(.medium)
                        Text("Verifica los filtros o el término de búsqueda").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if dataManager.codigos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "barcode.viewfinder").font(.system(size: 50)).foregroundColor(.gray)
                        Text("No hay códigos escaneados").font(.title2).fontWeight(.medium)
                        Text("Los códigos que escanees aparecerán aquí").font(.body).foregroundColor(.secondary)
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
                                hideKeyboard()
                                selectedCodigo = codigo
                                showingDetail = true
                            }
                            // NUEVO: Menú contextual mejorado
                            .contextMenu {
                                Button(action: {
                                    hideKeyboard()
                                    selectedCodigo = codigo
                                    showingDetail = true
                                }) {
                                    Label("Ver Detalles", systemImage: "info.circle")
                                }
                                
                                Button(action: {
                                    UIPasteboard.general.string = codigo.codigo
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }) {
                                    Label("Copiar Código", systemImage: "doc.on.doc")
                                }
                                
                                Button(action: {
                                    hideKeyboard()
                                    codigoToChangeDate = codigo
                                    newDateForCodigo = codigo.fechaCreacion
                                    showingChangeDateSheet = true
                                }) {
                                    Label("Cambiar Fecha", systemImage: "calendar")
                                }
                            }
                            .onLongPressGesture {
                                UIPasteboard.general.string = codigo.codigo
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                        .onDelete(perform: deleteCodigos)
                    }
                    .listStyle(PlainListStyle())
                    .simultaneousGesture(DragGesture().onChanged { _ in if isSearchFieldFocused { hideKeyboard() } })
                }
            }
            .id(refreshID) // NUEVO: Para forzar actualización cuando sea necesario
            .navigationTitle(isFilteringDuplicates ? "Buscar Duplicados" : "Buscar Códigos")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Toggle(isOn: $isFilteringDuplicates) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(isFilteringDuplicates ? .blue : .primary)
                    }
                    .toggleStyle(.button)
                    .disabled(duplicatedCodigos.isEmpty)
                    
                    EditButton()
                        .disabled(filteredCodigos.isEmpty)
                }
            }
            .onTapGesture(perform: hideKeyboard)
            // MODIFICADO: Usar el wrapper correcto para consistencia
            .sheet(isPresented: $showingDetail) {
                CodigoDetailViewWrapper(
                    codigo: selectedCodigo,
                    onSave: { updatedCodigo in
                        dataManager.updateCodigo(updatedCodigo)
                        refreshID = UUID()
                    }
                )
            }
            // NUEVO: Sheet para cambio de fecha
            .sheet(isPresented: $showingChangeDateSheet) {
                changeDateSheetView
            }
        }
    }
    
    // NUEVO: Vista para el sheet de cambio de fecha
    private var changeDateSheetView: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let codigo = codigoToChangeDate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cambiar Fecha de Creación").font(.title2).fontWeight(.bold)
                        Text("Código: \(codigo.codigo)").font(.headline).foregroundColor(.blue)
                        Text("Fecha actual: \(codigo.fechaCreacion, style: .date)").font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(10)
                }
                DatePicker("Nueva fecha", selection: $newDateForCodigo, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { showingChangeDateSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") { changeDateForCodigo() }.fontWeight(.semibold)
                }
            }
        }
    }
    
    // NUEVO: Función para cambiar la fecha
    private func changeDateForCodigo() {
        guard let codigo = codigoToChangeDate else { return }
        
        let updatedCodigo = CodigoBarras(
            id: codigo.id,
            codigo: codigo.codigo,
            fechaCreacion: Calendar.current.startOfDay(for: newDateForCodigo),
            articulo: codigo.articulo,
            auditado: codigo.auditado,
            cantidadPuntas: codigo.cantidadPuntas,
            fechaEmbarque: codigo.fechaEmbarque,
            fechaModificacion: Date(),
            operacionHistory: codigo.operacionHistory
        )
        
        dataManager.updateCodigo(updatedCodigo)
        refreshID = UUID()
        showingChangeDateSheet = false
    }
    
    private func hideKeyboard() {
        isSearchFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func matchesCodigo(_ codigo: String, searchText: String) -> Bool {
        let cleanSearchText = searchText.trimmingCharacters(in: .whitespaces)
        guard !cleanSearchText.isEmpty else { return true }
        
        let components = codigo.split(separator: "-")
        guard components.count >= 3 else { return false }
        
        let firstPart = String(components[0])
        let lastPart = String(components[2])
        
        if lastPart.contains(cleanSearchText) { return true }
        if firstPart.count >= 4 {
            let lastFourChars = String(firstPart.suffix(4))
            if lastFourChars.contains(cleanSearchText) { return true }
        }
        if codigo.lowercased().contains(cleanSearchText.lowercased()) { return true }
        
        return false
    }
    
    private func deleteCodigos(at offsets: IndexSet) {
        offsets.forEach { index in
            let codigo = filteredCodigos[index]
            dataManager.deleteCodigo(codigo)
        }
        
        // Si después de borrar ya no hay duplicados, se desactiva el filtro
        if isFilteringDuplicates && duplicatedCodigos.isEmpty {
            isFilteringDuplicates = false
        }
        
        // NUEVO: Actualizar la vista
        refreshID = UUID()
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
        .background(backgroundColorForCode)
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
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

// MARK: - Preview
struct SearchCodigosView_Previews: PreviewProvider {
    static var previews: some View {
        SearchCodigosView()
            .environmentObject(DataManager())
    }
}
