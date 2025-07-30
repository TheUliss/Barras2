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
    @State private var showingShareSheet = false
    
    // NUEVO: Estado para controlar la hoja de selección de fecha
    @State private var showingDatePickerSheet = false

    @State private var shareText = ""
    @State private var isGeneratingShareText = false

    var codigosOrdenados: [CodigoBarras] {
        dataManager.codigos.sorted { $0.codigo < $1.codigo }
    }

    var codigosAuditadosOrdenados: [CodigoBarras] {
        dataManager.codigos.filter { $0.auditado }.sorted { $0.codigo < $1.codigo }
    }

    // 1. Agrupa los códigos por día (igual que en CodigosListView)
    private var groupedCodigos: [Date: [CodigoBarras]] {
        let sorted = dataManager.codigos.sorted { $0.fechaCreacion > $1.fechaCreacion }
        return Dictionary(grouping: sorted) { codigo in
            // Normaliza la fecha para agrupar por día
            Calendar.current.startOfDay(for: codigo.fechaCreacion)
        }
    }

    // 2. Ordena las fechas de los grupos para que el más reciente aparezca primero
    private var sortedGroupedKeys: [Date] {
        groupedCodigos.keys.sorted(by: >)
    }

    // 3. Agrupa códigos auditados por día
    private var groupedCodigosAuditados: [Date: [CodigoBarras]] {
        let auditados = dataManager.codigos.filter { $0.auditado }.sorted { $0.fechaCreacion > $1.fechaCreacion }
        return Dictionary(grouping: auditados) { codigo in
            Calendar.current.startOfDay(for: codigo.fechaCreacion)
        }
    }

    // 4. Ordena las fechas de códigos auditados
    private var sortedGroupedKeysAuditados: [Date] {
        groupedCodigosAuditados.keys.sorted(by: >)
    }

    // NUEVO: Orden específico de operaciones según el flujo de trabajo
    private let operacionOrder: [Operacion] = [
        .ribonizado,
        .ensamble,
        .pulido,
        .limpGeo,
        .armado,
        .etiquetas,
        .polaridad,
        .prueba,
        .limpieza,
        .empaque
    ]
    
    // MODIFICADO: Usar el orden específico de operaciones
    var codigosPorOperacionOrdenados: [(Operacion, Int)] {
        let codigosPorOperacion = dataManager.codigosPorOperacion()
        let operacionDict = Dictionary(uniqueKeysWithValues: codigosPorOperacion)
        
        // Crear lista ordenada según operacionOrder
        return operacionOrder.map { operacion in
            let count = operacionDict[operacion] ?? 0
            return (operacion, count)
        }
    }

    var codigosPorArticuloOrdenados: [(String, Int)] {
        dataManager.codigosPorArticulo().sorted { $0.0 < $1.0 }
    }

    // New computed property to identify duplicates across all codes
    var duplicatedCodigos: Set<String> {
        let counts = dataManager.codigos.reduce(into: [String: Int]()) { counts, codigo in
            counts[codigo.codigo, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }
    
    var body: some View {
            NavigationView {
                List {
                    operationsSection
                    articlesSection
                    summarySection
                }
                .navigationTitle("Resumen")
                .navigationBarItems(trailing: shareButton)
                .confirmationDialog("Seleccionar Fecha para Compartir", isPresented: $showingDatePickerSheet, titleVisibility: .visible) {
                    ForEach(sortedGroupedKeys, id: \.self) { date in
                        // 👇 ESTA ES LA LÍNEA CORREGIDA FINAL
                        Button(date.formatted(date: .long, time: .omitted)) {
                            shareContent(for: date)
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                }
            .sheet(isPresented: $showingCodigosList) {
                FilteredCodigosView(
                    operacion: selectedOperacion,
                    articulo: selectedArticulo,
                    duplicatedCodigos: duplicatedCodigos
                )
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingAllCodigos) {
                NavigationView {
                    List {
                        ForEach(sortedGroupedKeys, id: \.self) { date in
                            DisclosureGroup(
                                content: {
                                    ForEach(groupedCodigos[date]!) { codigo in
                                        CodigoRowView(codigo: codigo, isDuplicate: duplicatedCodigos.contains(codigo.codigo))
                                    }
                                },
                                label: {
                                    Text(date, style: .date)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            )
                        }
                    }
                    .navigationTitle("Todos los códigos")
                    .navigationBarItems(
                        trailing: Button("Cerrar") {
                            showingAllCodigos = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingAuditedCodigos) {
                NavigationView {
                    List {
                        ForEach(sortedGroupedKeysAuditados, id: \.self) { date in
                            DisclosureGroup(
                                content: {
                                    ForEach(groupedCodigosAuditados[date]!) { codigo in
                                        CodigoRowView(codigo: codigo, isDuplicate: duplicatedCodigos.contains(codigo.codigo))
                                    }
                                },
                                label: {
                                    Text(date, style: .date)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            )
                        }
                    }
                    .navigationTitle("Códigos auditados")
                    .navigationBarItems(
                        trailing: Button("Cerrar") {
                            showingAuditedCodigos = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [shareText])
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
    
    // NUEVO: Función para asignar colores a las operaciones según su estado en el flujo
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
    
    // NUEVO: Calcular porcentaje de progreso basado en códigos en empaque
    private var progressPercentage: String {
        let totalCodigos = dataManager.codigos.count
        guard totalCodigos > 0 else { return "0%" }
        
        let codigosEnEmpaque = dataManager.codigos.filter { codigo in
            codigo.currentOperacionLog?.operacion == .empaque
        }.count
        
        let percentage = (Double(codigosEnEmpaque) / Double(totalCodigos)) * 100
        return String(format: "%.1f%%", percentage)
    }
    
    // NUEVO: Valor numérico del progreso para la barra
    private var progressValue: Double {
        let totalCodigos = dataManager.codigos.count
        guard totalCodigos > 0 else { return 0.0 }
        
        let codigosEnEmpaque = dataManager.codigos.filter { codigo in
            codigo.currentOperacionLog?.operacion == .empaque
        }.count
        
        return Double(codigosEnEmpaque) / Double(totalCodigos)
    }
    
    // MODIFICADO: Función generateShareText usando el orden específico
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
          text += "Auditados: \(codigosDelDia.filter { $0.auditado }.count)\n\n"
          
          // 3. Listar el detalle de los códigos de esa fecha
          text += "# DETALLE DE CÓDIGOS:\n"
          for codigo in codigosDelDia.sorted(by: { $0.codigo < $1.codigo }) { // Ordenar por código
              text += "- *\(codigo.codigo)*\n"
              if let operacion = codigo.currentOperacionLog?.operacion {
                  if operacion == .empaque {
                      text += "  ✅ Empaque"
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
                  text += " | *\(puntas)* puntas"
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
 /*   private func generateShareText() {
        print("🔄 Iniciando generación de texto para compartir...")
        
        guard !dataManager.codigos.isEmpty else {
            print("❌ No hay códigos para generar texto")
            shareText = ""
            return
        }
        
        var text = "= RESUMEN JOBS =\n\n"
        
        text += "Total Jobs: \(dataManager.codigos.count)\n"
        text += "Auditados: \(dataManager.codigos.filter { $0.auditado }.count)\n"
        text += "Progreso: \(progressPercentage)\n\n"
        
        // Por operación con orden específico
        text += "# POR OPERACIÓN (FLUJO DE TRABAJO):\n"
        for (index, (operacion, cantidad)) in codigosPorOperacionOrdenados.enumerated() {
            text += "\(index + 1). \(operacion.rawValue): \(cantidad)\n"
        }
        text += "\n"
        
        // Por artículo
        text += "# ARTÍCULOS:\n"
        for (articulo, cantidad) in codigosPorArticuloOrdenados {
            text += "\(articulo): \(cantidad)\n"
        }
        text += "\n"
    
        // Listado detallado de códigos
        text += "# DETALLE DE CÓDIGOS:\n"
        for codigo in codigosOrdenados {
            text += "- *\(codigo.codigo)*\n"
            if let operacion = codigo.currentOperacionLog?.operacion {
                if operacion == .empaque {
                    text += "  ✅Empaque"
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
                text += " | Puntas: *\(puntas)*"
            }
            
            if let articulo = codigo.articulo?.nombre {
                text += " | \(articulo)"
            }
            
            text += "\n"
        }
        
        // Información adicional
        text += "\n---\n"
        let fechaFormateada = DateFormatter.shortDateTime.string(from: Date())
        text += "Generado: \(fechaFormateada)\n"

        shareText = text
        
        print("✅ Texto generado. Longitud: \(text.count) caracteres")
        print("📝 Primeros 100 caracteres: \(String(text.prefix(100)))")
    }
}*/

// MARK: - Extension para DateFormatter (SIN CAMBIOS)
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Activity View (SIN CAMBIOS)
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}

// MARK: - Filtered Codigos View (SIN CAMBIOS)
struct FilteredCodigosView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    let operacion: Operacion?
    let articulo: String?
    let duplicatedCodigos: Set<String>

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
