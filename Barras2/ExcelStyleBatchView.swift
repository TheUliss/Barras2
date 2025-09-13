// MARK: - NUEVA VISTA TIPO EXCEL PARA CAPTURA MASIVA

import SwiftUI

struct ExcelStyleBatchView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var scannerManager = DebugScannerManager()
    
    @State private var rows: [BatchRow] = [BatchRow()]
    @State private var currentEditingIndex: Int = 0
    @State private var showingConfirmation = false
    @FocusState private var focusedField: FieldType?
    
    enum FieldType: Hashable {
        case codigo(Int)
        case operacion(Int)
        case articulo(Int)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Table Header
                tableHeaderView
                
                // Scrollable content
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            BatchRowView(
                                row: $rows[index],
                                index: index,
                                dataManager: dataManager,
                                scannerManager: scannerManager,
                                focusedField: $focusedField,
                                onCodigoSubmit: { codigoText in
                                    handleCodigoSubmit(at: index, codigo: codigoText)
                                },
                                onDelete: {
                                    deleteRow(at: index)
                                }
                            )
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Footer with actions
                footerView
            }
            .navigationTitle("Captura Masiva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar Todo") {
                        showingConfirmation = true
                    }
                    .disabled(validRows.isEmpty)
                }
            }
        }
        .alert("Confirmar Guardado", isPresented: $showingConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Guardar \(validRows.count) códigos") {
                saveAllRows()
            }
        } message: {
            Text("¿Deseas guardar \(validRows.count) códigos válidos?")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Captura tipo Excel")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(validRows.count) válidos")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text("Escanea códigos y se moverá automáticamente al siguiente campo")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var tableHeaderView: some View {
        HStack(spacing: 1) {
            Text("Código")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray5))
            
            Text("Operación")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray5))
            
            Text("Artículo")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray5))
            
            // Columna para botón delete
            Rectangle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 44)
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: addNewRow) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Agregar Fila")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button(action: clearAllRows) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Limpiar Todo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(rows.allSatisfy { $0.codigo.isEmpty })
            }
            
            if !validRows.isEmpty {
                Text("Filas válidas: \(validRows.count) de \(rows.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var validRows: [BatchRow] {
        rows.filter { !$0.codigo.isEmpty && $0.operacion != nil && $0.articulo != nil }
    }
    
    private func handleCodigoSubmit(at index: Int, codigo: String) {
        // Asegurar que el código se guardó
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            rows[index].codigo = codigo
            
            // Mover focus a operación
            focusedField = .operacion(index)
            
            // Si es la última fila y tiene código, agregar nueva fila
            if index == rows.count - 1 && !codigo.isEmpty {
                addNewRow()
            }
        }
    }
    
    private func addNewRow() {
        rows.append(BatchRow())
    }
    
    private func deleteRow(at index: Int) {
        guard rows.count > 1 else { return }
        rows.remove(at: index)
    }
    
    private func clearAllRows() {
        rows = [BatchRow()]
        focusedField = .codigo(0)
    }
    
    private func saveAllRows() {
        for row in validRows {
            var nuevoCodigo = CodigoBarras(codigo: row.codigo)
            nuevoCodigo.articulo = row.articulo
            
            if let operacion = row.operacion {
                let operacionLog = OperacionLog(operacion: operacion, timestamp: Date())
                nuevoCodigo.operacionHistory.append(operacionLog)
            }
            
            dataManager.addCodigo(nuevoCodigo)
        }
        
        dismiss()
    }
}

// MARK: - Modelo para las filas del batch
struct BatchRow: Identifiable {
    let id = UUID()
    var codigo: String = ""
    var operacion: Operacion?
    var articulo: Articulo?
}

// MARK: - Vista para cada fila del batch
struct BatchRowView: View {
    @Binding var row: BatchRow
    let index: Int
    let dataManager: DataManager
    @ObservedObject var scannerManager: DebugScannerManager
    var focusedField: FocusState<ExcelStyleBatchView.FieldType?>.Binding
    let onCodigoSubmit: (String) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 1) {
            // Campo de código con scanner especial
            CodigoTextField(
                text: $row.codigo,
                scannerManager: scannerManager,
                onSubmit: onCodigoSubmit,
                isFocused: focusedField.wrappedValue == .codigo(index)
            )
            .focused(focusedField, equals: .codigo(index))
            .frame(maxWidth: .infinity)
            
            // Picker de operación
            Menu {
                Button("Sin operación") {
                    row.operacion = nil
                    moveFocusToNextField()
                }
                ForEach(Operacion.allCases, id: \.self) { operacion in
                    Button(operacion.rawValue) {
                        row.operacion = operacion
                        moveFocusToNextField()
                    }
                }
            } label: {
                Text(row.operacion?.rawValue ?? "Seleccionar")
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        focusedField.wrappedValue == .operacion(index) ?
                        Color.blue.opacity(0.1) : Color(UIColor.systemBackground)
                    )
            }
            .onTapGesture {
                focusedField.wrappedValue = .operacion(index)
            }
            
            // Picker de artículo
            Menu {
                Button("Sin artículo") {
                    row.articulo = nil
                    moveFocusToNextRow()
                }
                ForEach(dataManager.articulos, id: \.id) { articulo in
                    Button(articulo.nombre) {
                        row.articulo = articulo
                        moveFocusToNextRow()
                    }
                }
            } label: {
                Text(row.articulo?.nombre ?? "Seleccionar")
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        focusedField.wrappedValue == .articulo(index) ?
                        Color.blue.opacity(0.1) : Color(UIColor.systemBackground)
                    )
            }
            .onTapGesture {
                focusedField.wrappedValue = .articulo(index)
            }
            
            // Botón delete
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }
    
    private func moveFocusToNextField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if focusedField.wrappedValue == .operacion(index) {
                focusedField.wrappedValue = .articulo(index)
            } else {
                moveFocusToNextRow()
            }
        }
    }
    
    private func moveFocusToNextRow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField.wrappedValue = .codigo(index + 1)
        }
    }
}

// MARK: - TextField especializado para códigos con manejo de scanner
struct CodigoTextField: UIViewRepresentable {
    @Binding var text: String
    @ObservedObject var scannerManager: DebugScannerManager
    let onSubmit: (String) -> Void
    let isFocused: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = "Código..."
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        textField.keyboardType = .default
        textField.returnKeyType = .next
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.onSubmit = onSubmit
        
        if uiView.text != text {
            uiView.text = text
        }
        
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
        
        private var scanBuffer = ""
        private var lastInputTime = Date()
        private var scannerTimer: Timer?
        
        init(text: Binding<String>, onSubmit: @escaping (String) -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Detectar terminadores de scanner
            let terminators = ["\t", "\n", "\r", "\u{0003}", "\u{000D}", "\u{000A}"]
            
            if terminators.contains(string) {
                let finalText = textField.text ?? ""
                if !finalText.isEmpty {
                    onSubmit(finalText)
                    return false // No insertar el terminador
                }
                return false
            }
            
            // Procesar texto normal
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            
            // Detectar entrada rápida de scanner
            let timeSinceLastInput = Date().timeIntervalSince(lastInputTime)
            let isLikelyFromScanner = string.count > 1 || timeSinceLastInput < 0.05
            
            lastInputTime = Date()
            
            if isLikelyFromScanner {
                scanBuffer += string
                scannerTimer?.invalidate()
                
                scannerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                    DispatchQueue.main.async {
                        if !self.scanBuffer.isEmpty {
                            let completeCode = (textField.text ?? "") + self.scanBuffer
                            textField.text = completeCode
                            self.text = completeCode
                            self.onSubmit(completeCode)
                            self.scanBuffer = ""
                        }
                    }
                }
            }
            
            text = newText
            return true
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let text = textField.text, !text.isEmpty {
                onSubmit(text)
            }
            return false
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            scannerTimer?.invalidate()
        }
    }
}

// MARK: - CORRECCIÓN 2: Agregar NavigationLink en el header de DebugScannerView
// En la sección headerView de DebugScannerView, reemplazar el NavigationLink existente por:

NavigationLink(destination: ExcelStyleBatchView()) {
    Image(systemName: "tablecells")
        .font(.title3)
        .foregroundColor(.green.opacity(0.7))
        .padding(8)
        .background(Color.green.opacity(0.1))
        .clipShape(Circle())
}