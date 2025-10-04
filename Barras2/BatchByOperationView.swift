//
//  BatchByOperationView.swift
//  Vista de captura masiva por operación con menú lateral
//

import SwiftUI

// MARK: - Vista Principal con Menú Lateral

struct BatchByOperationView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    // Datos capturados por operación
    @State private var capturedData: [Operacion: [BatchRow]] = [:]
    @State private var selectedOperation: Operacion? = Operacion.allCases.first
    
    // Calcula si hay datos válidos para activar el botón de guardar
    private var hasValidData: Bool {
        capturedData.values.flatMap { $0 }.contains {
            !$0.codigo.isEmpty && $0.articulo != nil
        }
    }
    
    // Contador total de códigos válidos
    private var totalValidCodes: Int {
        capturedData.values.flatMap { $0 }.filter {
            !$0.codigo.isEmpty && $0.articulo != nil
        }.count
    }
    
    var body: some View {
        NavigationSplitView {
            // SIDEBAR - Lista de operaciones
            sidebarView
        } detail: {
            // DETAIL - Vista de captura
            if let selectedOperation {
                OperationCaptureView(
                    operation: selectedOperation,
                    rows: binding(for: selectedOperation)
                )
                .environmentObject(dataManager)
            } else {
                emptyDetailView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: saveAllData) {
                    Label("Guardar Todo (\(totalValidCodes))", systemImage: "checkmark.circle.fill")
                }
                .disabled(!hasValidData)
            }
        }
        .alert("Datos Guardados", isPresented: .constant(false)) {
            Button("OK") { dismiss() }
        }
    }
    
    // MARK: - Subvistas
    
    private var sidebarView: some View {
        List(Operacion.allCases, id: \.self, selection: $selectedOperation) { operacion in
            HStack {
                // Icono de operación
                Image(systemName: iconForOperation(operacion))
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(operacion.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    // Mostrar conteo si hay datos
                    let count = capturedData[operacion]?.filter {
                        !$0.codigo.isEmpty && $0.articulo != nil
                    }.count ?? 0
                    
                    if count > 0 {
                        Text("\(count) códigos capturados")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Badge con contador
                if let count = capturedData[operacion]?.filter({
                    !$0.codigo.isEmpty && $0.articulo != nil
                }).count, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .tag(operacion)
            .padding(.vertical, 4)
        }
        .navigationTitle("Operaciones")
        .listStyle(.sidebar)
    }
    
    private var emptyDetailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Selecciona una operación")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Elige una operación del menú lateral para comenzar a capturar códigos")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Funciones de Ayuda
    
    private func binding(for operation: Operacion) -> Binding<[BatchRow]> {
        Binding(
            get: {
                self.capturedData[operation] ?? [BatchRow()]
            },
            set: {
                self.capturedData[operation] = $0
            }
        )
    }
    
    private func iconForOperation(_ operacion: Operacion) -> String {
        switch operacion {
        case .ribonizado: return "scissors"
        case .ensamble: return "gearshape.2"
        case .pulido: return "sparkles"
        case .limpGeo: return "drop.fill"
        case .armado: return "wrench.and.screwdriver"
        case .etiquetas: return "tag.fill"
        case .polaridad: return "bolt.fill"
        case .prueba: return "checkmark.seal.fill"
        case .limpieza: return "sparkle"
        case .empaque: return "shippingbox.fill"
        }
    }
    
    private func saveAllData() {
        var savedCount = 0
        
        for (operation, rows) in capturedData {
            let validRows = rows.filter {
                !$0.codigo.isEmpty && $0.articulo != nil
            }
            
            guard !validRows.isEmpty else { continue }
            
            for row in validRows {
                var nuevoCodigo = CodigoBarras(codigo: row.codigo)
                nuevoCodigo.articulo = row.articulo
                
                let operacionLog = OperacionLog(operacion: operation, timestamp: Date())
                nuevoCodigo.operacionHistory.append(operacionLog)
                
                dataManager.addCodigo(nuevoCodigo)
                savedCount += 1
            }
        }
        
        print("✅ Guardados \(savedCount) códigos en total")
        dismiss()
    }
}

// MARK: - Vista de Captura por Operación

fileprivate struct OperationCaptureView: View {
    let operation: Operacion
    @Binding var rows: [BatchRow]
    @EnvironmentObject var dataManager: DataManager
    
    @FocusState private var focusedField: UUID?
    
    private var validRows: [BatchRow] {
        rows.filter { !$0.codigo.isEmpty && $0.articulo != nil }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con información
            headerView
            
            // Encabezados de tabla
            tableHeaderView
            
            // Lista de filas
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach($rows) { $row in
                        BatchRowView(
                            row: $row,
                            focusedField: $focusedField,
                            onCodigoSubmit: {
                                handleCodigoSubmit(for: row.id)
                            },
                            onDelete: {
                                deleteRow(id: row.id)
                            }
                        )
                        .environmentObject(dataManager)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Footer con botones
            footerView
        }
        .navigationTitle(operation.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-focus en la primera fila vacía
            if let firstRow = rows.first, firstRow.codigo.isEmpty {
                focusedField = firstRow.id
            }
        }
    }
    
    // MARK: - Subvistas
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Captura de Códigos")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Escanea o escribe códigos y presiona Enter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Contador de códigos válidos
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(validRows.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("válidos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
    
    private var tableHeaderView: some View {
        HStack(spacing: 1) {
            Text("Código")
                .frame(maxWidth: .infinity)
            
            Text("Artículo")
                .frame(maxWidth: .infinity)
            
            Text("🗑️")
                .frame(width: 44)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .frame(height: 44)
        .background(Color(UIColor.systemGray5))
        .multilineTextAlignment(.center)
    }
    
    private var footerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Botón para agregar fila
                Button(action: addRowAndFocus) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Agregar Fila")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Botón para limpiar todo
                Button(action: clearAllRows) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Limpiar")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(rows.allSatisfy { $0.codigo.isEmpty })
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: -1)
    }
    
    // MARK: - Funciones
    
    private func addRowAndFocus() {
        let newRow = BatchRow()
        rows.append(newRow)
        
        DispatchQueue.main.async {
            focusedField = newRow.id
        }
    }
    
    private func clearAllRows() {
        rows = [BatchRow()]
        focusedField = rows.first?.id
    }
    
    private func deleteRow(id: UUID) {
        guard rows.count > 1 else {
            clearAllRows()
            return
        }
        
        rows.removeAll { $0.id == id }
        
        if rows.isEmpty {
            rows.append(BatchRow())
        }
    }
    
    private func handleCodigoSubmit(for id: UUID) {
        guard let currentIndex = rows.firstIndex(where: { $0.id == id }) else { return }
        
        // Si es la última fila, agregar una nueva
        if currentIndex == rows.count - 1 {
            let newRow = BatchRow()
            rows.append(newRow)
            
            DispatchQueue.main.async {
                focusedField = newRow.id
            }
        } else {
            // Mover al siguiente campo
            let nextRow = rows[currentIndex + 1]
            focusedField = nextRow.id
        }
    }
}

// MARK: - Vista de Fila Individual

fileprivate struct BatchRowView: View {
    @Binding var row: BatchRow
    @EnvironmentObject var dataManager: DataManager
    var focusedField: FocusState<UUID?>.Binding
    let onCodigoSubmit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 1) {
            // Campo de código
            CodigoTextField(
                text: $row.codigo,
                onSubmit: { _ in onCodigoSubmit() },
                isFocused: focusedField.wrappedValue == row.id
            )
            .focused(focusedField, equals: row.id)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(UIColor.systemBackground))
            
            // Menú de selección de artículo
            Menu {
                Button("Sin artículo") {
                    row.articulo = nil
                }
                
                Divider()
                
                ForEach(dataManager.articulos) { articulo in
                    Button(action: {
                        row.articulo = articulo
                    }) {
                        HStack {
                            Text(articulo.nombre)
                            if row.articulo?.id == articulo.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(row.articulo?.nombre ?? "Seleccionar")
                        .foregroundColor(row.articulo == nil ? .orange : .primary)
                        .font(.system(size: 14))
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(UIColor.systemBackground))
            
            // Botón de eliminar
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .frame(width: 44, height: 44)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Modelo de Fila (solo para UI)

fileprivate struct BatchRow: Identifiable {
    let id = UUID()
    var codigo: String = ""
    var articulo: Articulo?
}

// MARK: - TextField Personalizado para Códigos

fileprivate struct CodigoTextField: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: (String) -> Void
    let isFocused: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = "Escanear código..."
        textField.borderStyle = .none
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        textField.keyboardType = .asciiCapable
        textField.returnKeyType = .next
        
        // Deshabilitar barra de sugerencias
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onSubmit: (String) -> Void
        
        init(text: Binding<String>, onSubmit: @escaping (String) -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let currentText = textField.text, !currentText.isEmpty {
                onSubmit(currentText)
            }
            return false
        }
    }
}
