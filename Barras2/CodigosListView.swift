// ===================================
// 3. CODIGOSLISTVIEW.swift - CON ELIMINACIÓN POR FECHA
// ===================================

import SwiftUI

struct CodigosListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedCodigo: CodigoBarras?
    @State private var showingDetail = false
    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteDateAlert = false
    @State private var selectedDateToDelete: Date?
    @State private var refreshID = UUID()

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
            // MEJORA: Se usa .toolbar en lugar del obsoleto .navigationBarItems
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Eliminar Todo") {
                        showingDeleteAllAlert = true
                    }
                    .foregroundColor(.red)
                    .disabled(dataManager.codigos.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingDetail) {
                // Se llama a la versión corregida del Wrapper
                CodigoDetailViewWrapper(
                    codigo: selectedCodigo,
                    isNew: false,
                    onSave: { updatedCodigo in
                        dataManager.updateCodigo(updatedCodigo)
                        refreshID = UUID()
                    }
                )
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
