//
//  StatisticsView.swift
//  Barras2
//
//  Created by Ulises Islas on 18/07/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Statistics View
struct StatisticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedOperacion: Operacion?
    @State private var selectedArticulo: String?
    @State private var showingCodigosList = false
    @State private var showingAllCodigos = false
    @State private var showingAuditedCodigos = false
    @State private var showingPackagedCodigos = false // NUEVO: Para códigos empacados
    @State private var showingShareSheet = false
    
    // Estados para la hoja de selección de fecha y compartir
    @State private var showingDatePickerSheet = false
    @State private var shareText = ""
    @State private var isGeneratingShareText = false

    // MODIFICADO: Estados para manejar la edición de códigos con mejor gestión de sheets
    @State private var selectedCodigo: CodigoBarras?
    @State private var showingDetail = false
    @State private var showingChangeDateSheet = false
    @State private var codigoToChangeDate: CodigoBarras?
    @State private var newDateForCodigo = Date()
    @State private var refreshID = UUID()

    var codigosOrdenados: [CodigoBarras] { dataManager.codigos.sorted { $0.codigo < $1.codigo } }
    var codigosAuditadosOrdenados: [CodigoBarras] { dataManager.codigos.filter { $0.auditado }.sorted { $0.codigo < $1.codigo } }
    // NUEVO: Códigos empacados
    var codigosEmpacadosOrdenados: [CodigoBarras] {
        dataManager.codigos.filter { codigo in
            codigo.currentOperacionLog?.operacion == .empaque
        }.sorted { $0.codigo < $1.codigo }
    }
    
    private var groupedCodigos: [Date: [CodigoBarras]] { Dictionary(grouping: dataManager.codigos.sorted { $0.fechaCreacion > $1.fechaCreacion }) { Calendar.current.startOfDay(for: $0.fechaCreacion) } }
    private var sortedGroupedKeys: [Date] { groupedCodigos.keys.sorted(by: >) }
    private var groupedCodigosAuditados: [Date: [CodigoBarras]] { Dictionary(grouping: dataManager.codigos.filter { $0.auditado }.sorted { $0.fechaCreacion > $1.fechaCreacion }) { Calendar.current.startOfDay(for: $0.fechaCreacion) } }
    private var sortedGroupedKeysAuditados: [Date] { groupedCodigosAuditados.keys.sorted(by: >) }
    // NUEVO: Agrupación de códigos empacados por fecha
    private var groupedCodigosEmpacados: [Date: [CodigoBarras]] {
        Dictionary(grouping: codigosEmpacadosOrdenados.sorted { $0.fechaCreacion > $1.fechaCreacion }) {
            Calendar.current.startOfDay(for: $0.fechaCreacion)
        }
    }
    private var sortedGroupedKeysEmpacados: [Date] { groupedCodigosEmpacados.keys.sorted(by: >) }
    
    private let operacionOrder: [Operacion] = [.ribonizado, .ensamble, .pulido, .limpGeo, .armado, .etiquetas, .polaridad, .prueba, .limpieza, .empaque]
    var codigosPorOperacionOrdenados: [(Operacion, Int)] {
        let codigosPorOperacion = dataManager.codigosPorOperacion()
        let operacionDict = Dictionary(uniqueKeysWithValues: codigosPorOperacion)
        return operacionOrder.map { ($0, operacionDict[$0] ?? 0) }
    }
    var codigosPorArticuloOrdenados: [(String, Int)] { dataManager.codigosPorArticulo().sorted { $0.0 < $1.0 } }
    var duplicatedCodigos: Set<String> {
        let counts = dataManager.codigos.reduce(into: [:]) { $0[$1.codigo, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }
    
    var body: some View {
        NavigationView {
            List {
                operationsSection
                articlesSection
                summarySection
            }
            .id(refreshID)
            .navigationTitle("Resumen")
            .navigationBarItems(trailing: shareButton)
            .confirmationDialog("Seleccionar Fecha para Compartir", isPresented: $showingDatePickerSheet, titleVisibility: .visible) {
                ForEach(sortedGroupedKeys, id: \.self) { date in
                    Button(date.formatted(date: .long, time: .omitted)) {
                        shareContent(for: date)
                    }
                }
                Button("Cancelar", role: .cancel) {}
            }
            // MODIFICADO: Sheet para códigos filtrados con capacidad de edición
            .sheet(isPresented: $showingCodigosList) {
                FilteredCodigosView(
                    operacion: selectedOperacion,
                    articulo: selectedArticulo,
                    duplicatedCodigos: duplicatedCodigos,
                    onCodigoTapped: { codigo in
                        selectedCodigo = codigo
                        showingCodigosList = false // Cerrar el sheet actual primero
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDetail = true // Abrir el sheet de detalle
                        }
                    },
                    onCodigoDeleted: { codigo in
                        dataManager.deleteCodigo(codigo)
                        refreshID = UUID()
                    },
                    onCodigoDateChanged: { codigo in
                        codigoToChangeDate = codigo
                        newDateForCodigo = codigo.fechaCreacion
                        showingCodigosList = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingChangeDateSheet = true
                        }
                    }
                )
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingAllCodigos) {
                CodigosListSheetView(
                    title: "Todos los códigos",
                    groupedCodigos: groupedCodigos,
                    sortedKeys: sortedGroupedKeys,
                    duplicatedCodigos: duplicatedCodigos,
                    onClose: { showingAllCodigos = false },
                    onCodigoTapped: { codigo in
                        selectedCodigo = codigo
                        showingAllCodigos = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDetail = true
                        }
                    },
                    onCodigoDeleted: { codigo in
                        dataManager.deleteCodigo(codigo)
                        refreshID = UUID()
                    },
                    onCodigoDateChanged: { codigo in
                        codigoToChangeDate = codigo
                        newDateForCodigo = codigo.fechaCreacion
                        showingAllCodigos = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingChangeDateSheet = true
                        }
                    }
                )
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingAuditedCodigos) {
                CodigosListSheetView(
                    title: "Códigos auditados",
                    groupedCodigos: groupedCodigosAuditados,
                    sortedKeys: sortedGroupedKeysAuditados,
                    duplicatedCodigos: duplicatedCodigos,
                    onClose: { showingAuditedCodigos = false },
                    onCodigoTapped: { codigo in
                        selectedCodigo = codigo
                        showingAuditedCodigos = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDetail = true
                        }
                    },
                    onCodigoDeleted: { codigo in
                        dataManager.deleteCodigo(codigo)
                        refreshID = UUID()
                    },
                    onCodigoDateChanged: { codigo in
                        codigoToChangeDate = codigo
                        newDateForCodigo = codigo.fechaCreacion
                        showingAuditedCodigos = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingChangeDateSheet = true
                        }
                    }
                )
                .environmentObject(dataManager)
            }
            // NUEVO: Sheet para códigos empacados
            .sheet(isPresented: $showingPackagedCodigos) {
                CodigosListSheetView(
                    title: "Códigos empacados",
                    groupedCodigos: groupedCodigosEmpacados,
                    sortedKeys: sortedGroupedKeysEmpacados,
                    duplicatedCodigos: duplicatedCodigos,
                    onClose: { showingPackagedCodigos = false },
                    onCodigoTapped: { codigo in
                        selectedCodigo = codigo
                        showingPackagedCodigos = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDetail = true
                        }
                    },
                    onCodigoDeleted: { codigo in
                        dataManager.deleteCodigo(codigo)
                        refreshID = UUID()
                    },
                    onCodigoDateChanged: { codigo in
                        codigoToChangeDate = codigo
                        newDateForCodigo = codigo.fechaCreacion
                        showingPackagedCodigos = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingChangeDateSheet = true
                        }
                    }
                )
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [shareText])
            }
            .sheet(isPresented: $showingDetail) {
                CodigoDetailViewWrapper(
                    codigo: selectedCodigo,
                    onSave: { updatedCodigo in
                        dataManager.updateCodigo(updatedCodigo)
                        refreshID = UUID()
                    }
                )
            }
            .sheet(isPresented: $showingChangeDateSheet) {
                changeDateSheetView
            }
        }
    }
    
    // MARK: - Subvistas extraídas
        
    /// **Sección para "Códigos por Operación"**
    private var operationsSection: some View {
        Section(header: Text("Códigos por Operación (Flujo de Trabajo)")) {
            ForEach(codigosPorOperacionOrdenados, id: \.0) { operacion, cantidad in
                HStack {
                    Text("\(operacionOrder.firstIndex(of: operacion)! + 1).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)
                    
                    Text(operacion.rawValue)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(cantidad)")
                            .fontWeight(.bold)
                            .foregroundColor(cantidad > 0 ? .primary : .secondary)
                        
                        if cantidad > 0 {
                            Circle()
                                .fill(colorForOperacion(operacion))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .opacity(cantidad > 0 ? 1.0 : 0.6)
                .onTapGesture {
                    if cantidad > 0 {
                        selectedOperacion = operacion
                        selectedArticulo = nil
                        showingCodigosList = true
                    }
                }
            }
        }
    }
    
    /// **Sección para "Códigos por Artículo"**
    private var articlesSection: some View {
        Section(header: Text("Códigos por Artículo")) {
            ForEach(codigosPorArticuloOrdenados, id: \.0) { articulo, cantidad in
                HStack {
                    Text(articulo)
                    Spacer()
                    Text("\(cantidad)")
                        .fontWeight(.bold)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .onTapGesture {
                    selectedArticulo = articulo
                    selectedOperacion = nil
                    showingCodigosList = true
                }
            }
        }
    }
    
    /// **Sección de "Resumen"**
    private var summarySection: some View {
        Section(header: Text("Resumen")) {
            HStack {
                Text("Total de códigos")
                Spacer()
                Text("\(dataManager.codigos.count)")
                    .fontWeight(.bold)
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .onTapGesture {
                showingAllCodigos = true
            }
            
            HStack {
                Text("Códigos auditados")
                Spacer()
                Text("\(dataManager.codigos.filter { $0.auditado }.count)")
                    .fontWeight(.bold)
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .onTapGesture {
                showingAuditedCodigos = true
            }
            
            // NUEVO: Códigos empacados
            HStack {
                Text("Códigos empacados")
                Spacer()
                Text("\(codigosEmpacadosOrdenados.count)")
                    .fontWeight(.bold)
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .onTapGesture {
                showingPackagedCodigos = true
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progreso del Flujo")
                    Spacer()
                    Text(progressPercentage)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: progressValue, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }
        }
    }
    
    // MARK: - Componentes y Lógica
    
    /// **Botón para compartir**
    private var shareButton: some View {
        Button(action: {
            guard !dataManager.codigos.isEmpty else {
                print("No hay códigos para compartir")
                return
            }
            showingDatePickerSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(dataManager.codigos.isEmpty)
    }

    // Vista para el sheet de cambio de fecha
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

    // Función para cambiar la fecha
    private func changeDateForCodigo() {
        guard let codigo = codigoToChangeDate else { return }
        
        let updatedCodigo = CodigoBarras(
            id: codigo.id, codigo: codigo.codigo,
            fechaCreacion: Calendar.current.startOfDay(for: newDateForCodigo),
            articulo: codigo.articulo, auditado: codigo.auditado,
            cantidadPuntas: codigo.cantidadPuntas, fechaEmbarque: codigo.fechaEmbarque,
            fechaModificacion: Date(), operacionHistory: codigo.operacionHistory
        )
        dataManager.updateCodigo(updatedCodigo)
        refreshID = UUID()
        showingChangeDateSheet = false
    }
    
    /// **Función para manejar la acción de compartir**
    private func shareContent(for date: Date) {
        isGeneratingShareText = true
        generateShareText(for: date)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isGeneratingShareText = false
            if !shareText.isEmpty {
                showingShareSheet = true
            }
        }
    }

    // Función para asignar colores a las operaciones según su estado en el flujo
    private func colorForOperacion(_ operacion: Operacion) -> Color {
        switch operacion {
        case .ribonizado:
            return .red
        case .ensamble:
            return .orange
        case .pulido:
            return .yellow
        case .limpGeo:
            return .green
        case .armado:
            return .mint
        case .etiquetas:
            return .teal
        case .polaridad:
            return .cyan
        case .prueba:
            return .blue
        case .limpieza:
            return .indigo
        case .empaque:
            return .purple
        }
    }
    
    // Calcular porcentaje de progreso basado en códigos en empaque
    private var progressPercentage: String {
        let totalCodigos = dataManager.codigos.count
        guard totalCodigos > 0 else { return "0%" }
        
        let codigosEnEmpaque = dataManager.codigos.filter { codigo in
            codigo.currentOperacionLog?.operacion == .empaque
        }.count
        
        let percentage = (Double(codigosEnEmpaque) / Double(totalCodigos)) * 100
        return String(format: "%.1f%%", percentage)
    }
    
    // Valor numérico del progreso para la barra
    private var progressValue: Double {
        let totalCodigos = dataManager.codigos.count
        guard totalCodigos > 0 else { return 0.0 }
        
        let codigosEnEmpaque = dataManager.codigos.filter { codigo in
            codigo.currentOperacionLog?.operacion == .empaque
        }.count
        
        return Double(codigosEnEmpaque) / Double(totalCodigos)
    }
    
    // Función generateShareText usando el orden específico
    private func generateShareText(for date: Date) {
        // 1. Obtener solo los códigos de la fecha seleccionada
        guard let codigosDelDia = groupedCodigos[date] else {
            print("❌ No se encontraron códigos para la fecha seleccionada.")
            shareText = ""
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let fechaTitulo = dateFormatter.string(from: date)

        var text = "= RESUMEN JOBS - \(fechaTitulo.uppercased()) =\n\n"
        
        // 2. Calcular el resumen solo para esa fecha
        text += "Total del día: \(codigosDelDia.count)\n"
        text += "Auditados: \(codigosDelDia.filter { $0.auditado }.count)\n"
        text += "Empacados: \(codigosDelDia.filter { $0.currentOperacionLog?.operacion == .empaque }.count)\n\n"
        
        // 3. Listar el detalle de los códigos de esa fecha
        text += "# DETALLE DE CÓDIGOS:\n"
        for codigo in codigosDelDia.sorted(by: { $0.codigo < $1.codigo }) {
            text += "- *\(codigo.codigo)*"
            if let operacion = codigo.currentOperacionLog?.operacion {
                if operacion == .empaque {
                    text += " | ✅ Empaque"
                } else {
                    text += "  _\(operacion.rawValue)_"
                }
            } else {
                text += "  Sin operación"
            }

            if codigo.auditado {
                text += " | 🅰️uditado"
            }
            
            if let puntas = codigo.cantidadPuntas {
                text += " | *\(puntas)* pts"
            }
                        
            text += "\n"
        }
        
        // 4. Información adicional
        text += "\n---\n"
        let fechaFormateada = DateFormatter.shortDateTime.string(from: Date())
        text += "Generado: \(fechaFormateada)\n"

        shareText = text
    }
}

// MARK: - NUEVO: Vista reutilizable para sheets de listas de códigos
struct CodigosListSheetView: View {
    @EnvironmentObject var dataManager: DataManager
    
    let title: String
    let groupedCodigos: [Date: [CodigoBarras]]
    let sortedKeys: [Date]
    let duplicatedCodigos: Set<String>
    let onClose: () -> Void
    let onCodigoTapped: (CodigoBarras) -> Void
    let onCodigoDeleted: (CodigoBarras) -> Void
    let onCodigoDateChanged: (CodigoBarras) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedKeys, id: \.self) { date in
                    DisclosureGroup(
                        content: {
                            ForEach(groupedCodigos[date]!) { codigo in
                                CodigoRowView(codigo: codigo, isDuplicate: duplicatedCodigos.contains(codigo.codigo))
                                    .onTapGesture {
                                        onCodigoTapped(codigo)
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            onCodigoTapped(codigo)
                                        }) {
                                            Label("Ver Detalles", systemImage: "info.circle")
                                        }
                                        
                                        Button(action: {
                                            UIPasteboard.general.string = codigo.codigo
                                        }) {
                                            Label("Copiar Código", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button(action: {
                                            onCodigoDateChanged(codigo)
                                        }) {
                                            Label("Cambiar Fecha", systemImage: "calendar")
                                        }
                                    }
                            }
                            .onDelete { offsets in
                                offsets.forEach { index in
                                    onCodigoDeleted(groupedCodigos[date]![index])
                                }
                            }
                        },
                        label: {
                            Text(date, style: .date).font(.headline).fontWeight(.bold)
                        }
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarItems(trailing: Button("Cerrar") { onClose() })
        }
    }
}

// MARK: - Extension para DateFormatter
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Activity View
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}

// MARK: - MODIFICADO: Filtered Codigos View con capacidades de edición
struct FilteredCodigosView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    let operacion: Operacion?
    let articulo: String?
    let duplicatedCodigos: Set<String>
    let onCodigoTapped: (CodigoBarras) -> Void
    let onCodigoDeleted: (CodigoBarras) -> Void
    let onCodigoDateChanged: (CodigoBarras) -> Void

    var filteredCodigos: [CodigoBarras] {
        let codigos: [CodigoBarras]

        if let operacion = operacion {
            codigos = dataManager.codigosPorOperacion(operacion)
        } else if let articulo = articulo {
            codigos = dataManager.codigosPorArticulo(articulo)
        } else {
            codigos = []
        }

        return codigos.sorted { $0.codigo < $1.codigo }
    }

    var titleText: String {
        if let operacion = operacion {
            return operacion.rawValue
        } else if let articulo = articulo {
            return articulo
        }
        return "Códigos"
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredCodigos) { codigo in
                    CodigoRowView(codigo: codigo, isDuplicate: duplicatedCodigos.contains(codigo.codigo))
                        .onTapGesture {
                            onCodigoTapped(codigo)
                        }
                        .contextMenu {
                            Button(action: {
                                onCodigoTapped(codigo)
                            }) {
                                Label("Ver Detalles", systemImage: "info.circle")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = codigo.codigo
                            }) {
                                Label("Copiar Código", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                onCodigoDateChanged(codigo)
                            }) {
                                Label("Cambiar Fecha", systemImage: "calendar")
                            }
                        }
                }
                .onDelete { offsets in
                    offsets.forEach { index in
                        onCodigoDeleted(filteredCodigos[index])
                    }
                }
            }
            .navigationTitle(titleText)
            .navigationBarItems(
                trailing: Button("Cerrar") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
