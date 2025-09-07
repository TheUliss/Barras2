// ===================================
// 3. CODIGOSLISTVIEW.swift - CON LÓGICA PARA COMPARTIR POR DÍA
// ===================================

import SwiftUI

struct CodigosListView: View {
    @EnvironmentObject var dataManager: DataManager
        // Accedemos al nuevo manager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedCodigo: CodigoBarras?
    @State private var showingDetail = false
    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteDateAlert = false
    @State private var selectedDateToDelete: Date?
    @State private var refreshID = UUID()

    // NUEVO: Estados para manejar la funcionalidad de compartir
    @State private var showingShareSheet = false
    @State private var showingDatePickerSheet = false
    @State private var showingActionSheet = false
    @State private var shareText = ""
    
    @State private var activityItems: [Any] = [] // Puede contener texto o datos de PDF
    @State private var selectedDateForAction: Date?

    var groupedCodigos: [Date: [CodigoBarras]] {
        let groupedByDate = Dictionary(grouping: dataManager.codigos) { codigo in
            Calendar.current.startOfDay(for: codigo.fechaCreacion)
        }
        return groupedByDate.mapValues { $0.sorted { $0.codigo < $1.codigo } }
    }

    var sortedGroupedKeys: [Date] {
        groupedCodigos.keys.sorted(by: >)
    }

    var duplicatedCodigos: Set<String> {
        let counts = dataManager.codigos.reduce(into: [String: Int]()) { $0[$1.codigo, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedGroupedKeys, id: \.self) { date in
                    DisclosureGroup(
                        content: {
                            ForEach(groupedCodigos[date]!) { codigo in
                                CodigoRowView(
                                    codigo: codigo,
                                    isDuplicate: duplicatedCodigos.contains(codigo.codigo)
                                )
                                .onTapGesture {
                                    selectedCodigo = codigo
                                    showingDetail = true
                                }
                                .onLongPressGesture {
                                    UIPasteboard.general.string = codigo.codigo
                                }
                            }
                            .onDelete { offsets in
                                deleteCodigos(at: offsets, for: groupedCodigos[date]!)
                            }
                        },
                        label: {
                            HStack {
                                Text(date, style: .date)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("(\(groupedCodigos[date]?.count ?? 0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    selectedDateToDelete = date
                                    showingDeleteDateAlert = true
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    )
                }
            }
            .id(refreshID)
            .navigationTitle("Códigos (\(dataManager.codigos.count))")
            .toolbar {
                // MODIFICADO: Se añade el botón para compartir
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Eliminar Todo") {
                        showingDeleteAllAlert = true
                    }
                    .foregroundColor(.red)
                    .disabled(dataManager.codigos.isEmpty)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                                    Button {
                                        // MODIFICADO: Esto ahora abre el selector de fechas
                                        showingActionSheet = true
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .disabled(dataManager.codigos.isEmpty)

                                    EditButton()
                }
            }
            .sheet(isPresented: $showingDetail) {
                CodigoDetailViewWrapper(
                    codigo: selectedCodigo,
                    isNew: false,
                    onSave: { updatedCodigo in
                        dataManager.updateCodigo(updatedCodigo)
                        refreshID = UUID()
                    }
                )
            }
            // NUEVO: Hoja para presentar el ActivityView (compartir)
            .sheet(isPresented: $showingShareSheet) {
                            ActivityView(activityItems: activityItems)
                        }
            // MODIFICADO: Este diálogo ahora te permite elegir la fecha
                        .confirmationDialog("Seleccionar Fecha para Reporte", isPresented: $showingActionSheet, titleVisibility: .visible) {
                            ForEach(sortedGroupedKeys, id: \.self) { date in
                                Button(date.formatted(date: .long, time: .omitted)) {
                                    selectedDateForAction = date
                                    // Aquí podríamos abrir otro menú o realizar una acción directa
                                    // Para este ejemplo, vamos a generar ambos y que el usuario elija
                                    // en el siguiente paso. Por simplicidad, lo haremos directo.
                                    // Lo ideal es presentar un segundo menú aquí.
                                }
                            }
                            Button("Cancelar", role: .cancel) {}
                        }
                                    // NUEVO: Un segundo confirmationDialog para elegir el tipo de reporte
                                    .confirmationDialog("¿Qué tipo de reporte deseas generar?", isPresented: .constant(selectedDateForAction != nil), titleVisibility: .visible) {
                                        Button("Resumen Rápido (Texto)") {
                                            generateShareText(for: selectedDateForAction!)
                                            selectedDateForAction = nil // Reset
                                        }
                                        Button("Reporte Completo (PDF)") {
                                            generatePDFReport(for: selectedDateForAction!)
                                            selectedDateForAction = nil // Reset
                                        }
                                        Button("Cancelar", role: .cancel) {
                                            selectedDateForAction = nil // Reset
                                        }
                                    }
            .alert("Eliminar Todos los Códigos", isPresented: $showingDeleteAllAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar Todo", role: .destructive) {
                    dataManager.codigos.removeAll()
                }
            } message: {
                Text("¿Estás seguro de que quieres eliminar todos los códigos?")
            }
            .alert("Eliminar Códigos de Fecha", isPresented: $showingDeleteDateAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    if let dateToDelete = selectedDateToDelete {
                        deleteCodigosForDate(dateToDelete)
                    }
                }
            } message: {
                if let dateToDelete = selectedDateToDelete {
                    let count = groupedCodigos[dateToDelete]?.count ?? 0
                    Text("¿Estás seguro de que quieres eliminar todos los \(count) códigos del \(dateToDelete, style: .date)?")
                } else {
                    Text("¿Estás seguro de que quieres eliminar todos los códigos de esta fecha?")
                }
            }
        }
    }
    
    @MainActor
        private func generatePDFReport(for date: Date) {
            guard let codigosDelDia = groupedCodigos[date] else { return }
            
            // MODIFICADO: Pasamos los datos del settingsManager al generador
            if let pdfData = PDFGenerator.render(
                codigos: codigosDelDia,
                date: date,
                settings: settingsManager // Pasamos el manager completo
            ) {
                let fileName = "Reporte-\(date.formatted(.iso8601.year().month().day())).pdf"
                let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try? pdfData.write(to: temporaryURL)
                
                self.activityItems = [temporaryURL]
                self.showingShareSheet = true
            }
        }
    
    // NUEVO: Función para generar el texto del reporte diario
    private func generateShareText(for date: Date) {
        guard let codigosDelDia = groupedCodigos[date] else {
            shareText = "No hay códigos para la fecha seleccionada."
            showingShareSheet = true
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.locale = Locale(identifier: "es_MX")
        let fechaTitulo = dateFormatter.string(from: date)
        
        var text = "RESUMEN TURNO - \(fechaTitulo.uppercased()) 📊\n"
       // text += "Total de Códigos: \(codigosDelDia.count)\n\n"
        
        // --- 1. EMPACADOS (con detalle de códigos) ---
        let empacados = codigosDelDia.filter { $0.currentOperacionLog?.operacion == .empaque }
        if !empacados.isEmpty {
            text += "✅ EMPACADO (\(empacados.count)):\n"
            for codigo in empacados {
                text += "_\(codigo.codigo)_\n"
            }
            text += "\n"
        }
        
        // --- 2. AUDITADOS (con detalle de códigos y puntas) ---
        let auditados = codigosDelDia.filter { $0.auditado && $0.currentOperacionLog?.operacion != .empaque }
        if !auditados.isEmpty {
            text += "🅰️ AUDITADO (\(auditados.count)):\n"
            for codigo in auditados {
                // MODIFICADO: Se añade el conteo de puntas al lado del código
                text += "- \(codigo.codigo)"
                if let puntasContadas = codigo.cantidadPuntas,
                   let puntasEsperadas = codigo.articulo?.cantidadPuntasEsperadas {
                    text += "  *\(puntasContadas)/\(puntasEsperadas)*\n"
                } else {
                    text += "\n"
                }
            }
            text += "\n"
        }
        
        // --- 3. EN PROCESO (solo sumatoria) ---
        let enProceso = codigosDelDia.filter { !$0.auditado && $0.currentOperacionLog?.operacion != .empaque }
        if !enProceso.isEmpty {
            text += "🔄 EN PROCESO (\(enProceso.count)):\n"
            let groupedByOperation = Dictionary(grouping: enProceso) { $0.currentOperacionLog?.operacion }
            
            // Ordenar para una presentación lógica
            let sortedOperations = groupedByOperation.keys.compactMap { $0 }.sorted(by: { $0.hashValue < $1.hashValue })
            
            for operacion in sortedOperations {
                if let count = groupedByOperation[operacion]?.count {
                    text += "_\(operacion.rawValue): \(count)\n"
                }
            }
            text += "\n"
        }
        
        text += "---\nGenerado el \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        self.activityItems = [text] // `text` es el String que generaste
        self.shareText = text
        self.showingShareSheet = true
    }
    
    private func deleteCodigos(at offsets: IndexSet, for group: [CodigoBarras]) {
        offsets.forEach { index in
            dataManager.deleteCodigo(group[index])
        }
    }
    
    private func deleteCodigosForDate(_ date: Date) {
        guard let codigosToDelete = groupedCodigos[date] else { return }
        
        codigosToDelete.forEach { codigo in
            dataManager.deleteCodigo(codigo)
        }
        
        selectedDateToDelete = nil
    }
}

// MARK: - Codigo Row View SIMPLIFICADO
struct CodigoRowView: View {
    let codigo: CodigoBarras
    let isDuplicate: Bool
    
    private var timeFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(codigo.codigo)
                    .fontWeight(.bold)
                Spacer()
                
                if let currentLog = codigo.currentOperacionLog,
                   currentLog.operacion.rawValue.lowercased() == "empaque" {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else if codigo.auditado {
                    Image(systemName: "a.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
            
            if let articulo = codigo.articulo {
                Text("Artículo: \(articulo.nombre)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let currentLog = codigo.currentOperacionLog {
                HStack {
                    Text("Actual:")
                        .fontWeight(.semibold)
                        .font(.caption)
                    Text("\(currentLog.operacion.rawValue) (\(currentLog.timestamp, style: .time))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let previousLog = codigo.previousOperacionLog {
                    HStack {
                        Text("Anterior:")
                            .fontWeight(.semibold)
                            .font(.caption)
                        Text("\(previousLog.operacion.rawValue) (\(previousLog.timestamp, style: .time))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    let interval = currentLog.timestamp.timeIntervalSince(previousLog.timestamp)
                    if let timeString = timeFormatter.string(from: interval) {
                        Text("Tiempo Transcurrido: \(timeString)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }
                }
            } else {
                Text("Sin operación asignada")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if let cantidadPuntas = codigo.cantidadPuntas {
                Text("Puntas: \(cantidadPuntas)")
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
        }
        .padding(.vertical, 4)
        .background(
            Group {
                if let currentLog = codigo.currentOperacionLog,
                   currentLog.operacion.rawValue.lowercased() == "empaque" {
                    Color.blue.opacity(0.2)
                } else if isDuplicate {
                    Color.yellow.opacity(0.3)
                } else {
                    Color.clear
                }
            }
        )
        .cornerRadius(5)
    }
}

// ===================================
// 4. WRAPPER UNIFICADO
// ===================================

struct CodigoDetailViewWrapper: View {
    let codigo: CodigoBarras?
    let isNew: Bool
    let onSave: (CodigoBarras) -> Void
    
    // CORRECCIÓN: Se eliminan 'scannerActive' y su binding. No son necesarios aquí.
    init(codigo: CodigoBarras?, isNew: Bool = false, onSave: @escaping (CodigoBarras) -> Void) {
        self.codigo = codigo
        self.isNew = isNew
        self.onSave = onSave
    }
    
    var body: some View {
        if let codigo = codigo {
            // CORRECCIÓN: La llamada ahora es correcta y no tiene argumentos extra.
            CodigoDetailView(
                codigo: codigo,
                isNew: isNew,
                onSave: onSave
            )
        } else {
            Text("No se pudo cargar el detalle")
                .foregroundColor(.secondary)
        }
    }
}
