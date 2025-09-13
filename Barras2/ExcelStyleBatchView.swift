import SwiftUI


struct ExcelStyleBatchView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var rows: [BatchRow] = [BatchRow()]
    @State private var showingConfirmation = false
    @FocusState private var focusedField: FieldType?
    
    // ✅ MEJORA: El enum de foco no necesita ser público
    enum FieldType: Hashable {
        case codigo(Int)
        case operacion(Int)
        case articulo(Int)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                tableHeaderView
                
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            BatchRowView(
                                row: $rows[index],
                                index: index,
                                dataManager: dataManager,
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
            // ✅ MEJORA: Evita el uso del NavigationView anidado si esta vista es presentada modalmente.
            // Si esta vista se presenta con .sheet() o .fullScreenCover(), el NavigationView aquí es correcto.
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
    
    // MARK: - Vistas Componentes
    
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
            
            Text("Escanea o escribe un código y presiona Enter para avanzar.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var tableHeaderView: some View {
        HStack(spacing: 1) {
            Group {
                Text("Código")
                Text("Operación")
                Text("Artículo")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(UIColor.systemGray5))
            .multilineTextAlignment(.center)
            
            Text("🗑️")
                .font(.system(size: 14))
                .frame(width: 44, height: 44)
                .background(Color(UIColor.systemGray5))
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // 💡 MEJORA: La acción ahora está en una función dedicada que también mueve el foco.
                Button(action: addRowAndFocus) {
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
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
  /*  // ✅ CORREGIDO: Lógica para habilitar el botón "Guardar Todo".
    // Ahora una fila es válida si solo tiene un código de 3 o más caracteres.
    private var validRows: [BatchRow] {
        rows.filter { $0.codigo.count >= 3 }
    }*/
    
    private var validRows: [BatchRow] {
        rows.filter { !$0.codigo.isEmpty && $0.operacion != nil && $0.articulo != nil }
    }
    
    // MARK: - Lógica y Funciones
    
    private func addRowAndFocus() {
        let newIndex = rows.count
        rows.append(BatchRow())
        
        // Mover foco a la nueva fila cuando se agrega manualmente
        DispatchQueue.main.async {
            focusedField = .codigo(newIndex)
        }
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

    // ✅ CORREGIDO: Lógica de manejo de foco simplificada y más robusta.
    private func handleCodigoSubmit(at index: Int, codigo: String) {
        guard codigo.count >= 3 else {
            print("⚠️ Código muy corto rechazado: '\(codigo)'")
            return
        }
        
        print("✅ Código aceptado en fila \(index): '\(codigo)'")
        
        // Asegurarse de que el modelo esté actualizado
        if rows.indices.contains(index) {
            rows[index].codigo = codigo
        }
        
        // Si es la última fila, agregar una nueva.
        if index == rows.count - 1 {
            rows.append(BatchRow())
        }

        // Mover el foco a la siguiente fila de manera asíncrona
        // para asegurar que la nueva fila exista en la UI antes de enfocarla.
        DispatchQueue.main.async {
            focusedField = .codigo(index + 1)
            print("🎯 Focus movido a fila \(index + 1)")
        }
    }

    private func deleteRow(at index: Int) {
        guard rows.count > 1 else { return }
        
        // Lógica inteligente para mover el foco
        if let currentFocus = focusedField {
            switch currentFocus {
            case .codigo(let focusedIndex) where focusedIndex == index:
                let newFocusIndex = index > 0 ? index - 1 : 0
                focusedField = .codigo(newFocusIndex)
            default:
                 // Si el foco está en otra fila, ajustar índices si es necesario
                if case .codigo(let focusedIndex) = currentFocus, focusedIndex > index {
                    focusedField = .codigo(focusedIndex - 1)
                }
            }
        }
        
        rows.remove(at: index)
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
    // Este ya no dará error gracias al cambio anterior
    var focusedField: FocusState<ExcelStyleBatchView.FieldType?>.Binding
    let onCodigoSubmit: (String) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 1) {
            
            CodigoTextField(
                text: $row.codigo,
                onSubmit: { codigo in
                    onCodigoSubmit(codigo)
                },
                // ✅ CORREGIDO: Se usa el nombre completo del tipo para dar contexto
                isFocused: focusedField.wrappedValue == ExcelStyleBatchView.FieldType.codigo(index)
            )
            // ✅ CORREGIDO: Se usa el nombre completo del tipo aquí también
            .focused(focusedField, equals: ExcelStyleBatchView.FieldType.codigo(index))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(UIColor.systemBackground))
            
            // Picker de operación
            Menu {
                Button("Sin operación") { row.operacion = nil }
                ForEach(Operacion.allCases, id: \.self) { operacion in
                    Button(operacion.rawValue) { row.operacion = operacion }
                }
            } label: {
                Text(row.operacion?.rawValue ?? "Seleccionar")
                    // ✅ CORREGIDO: Cambia el color del texto basado en la selección.
                    .foregroundColor(row.operacion == nil ? .yellow : .primary)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle()) // Asegura que toda el área sea tappable
            }
            .background(Color(UIColor.systemBackground))

            // Picker de artículo
            Menu {
                Button("Sin artículo") { row.articulo = nil }
                ForEach(dataManager.articulos, id: \.id) { articulo in
                    Button(articulo.nombre) { row.articulo = articulo }
                }
            } label: {
                Text(row.articulo?.nombre ?? "Seleccionar")
                    // ✅ CORREGIDO: Cambia el color del texto basado en la selección.
                    .foregroundColor(row.articulo == nil ? .yellow : .primary)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .background(Color(UIColor.systemBackground))
            
            // Botón delete
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
            }
            .background(Color(UIColor.systemBackground))
        }
        .frame(height: 44) // Altura uniforme para toda la fila
        .background(Color(UIColor.separator)) // Línea de separación
    }
}
    
// MARK: - TextField especializado para códigos (UIViewRepresentable)
struct CodigoTextField: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: (String) -> Void
    let isFocused: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = "Escanear..."
        textField.borderStyle = .none
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.keyboardType = .asciiCapable
        textField.returnKeyType = .next
        // Previene que aparezcan sugerencias de autocompletado sobre el teclado
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        
        // Manejo del foco
        if isFocused && !uiView.isFirstResponder {
            // Usar async para evitar modificar el estado de la vista durante una actualización
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
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
            // Sincronizar el binding si el texto cambia
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let currentText = textField.text, !currentText.isEmpty {
                onSubmit(currentText)
            }
            return false // Evita que se inserte un salto de línea
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            // Opcional: Si quieres procesar el código también cuando se pierde el foco
            // if let currentText = textField.text, !currentText.isEmpty {
            //     onSubmit(currentText)
            // }
        }
    }
}


/*
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
            Group {
                Text("Código")
                Text("Operación")
                Text("Artículo")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 44) // Altura uniforme
            .background(Color(UIColor.systemGray5))
            .multilineTextAlignment(.center)
            
            // Columna eliminar - mejor alineada
            Text("🗑️")
                .font(.system(size: 14))
                .frame(width: 44, height: 44)
                .background(Color(UIColor.systemGray5))
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
            
            CodigoTextField(
                text: $row.codigo,
                scannerManager: scannerManager,
                onSubmit: { codigo in
                    onCodigoSubmit(codigo)
                    
                },
                isFocused: focusedField.wrappedValue == .codigo(index)
            )
            .focused(focusedField, equals: .codigo(index))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                focusedField.wrappedValue == .codigo(index) ?
                Color.blue.opacity(0.1) : Color(UIColor.systemBackground)
            )
            
            // Picker de operación - solo manual
            Menu {
                Button("Sin operación") {
                    row.operacion = nil
                }
                ForEach(Operacion.allCases, id: \.self) { operacion in
                    Button(operacion.rawValue) {
                        row.operacion = operacion
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
            
            // Picker de artículo - solo manual
            Menu {
                Button("Sin artículo") {
                    row.articulo = nil
                }
                ForEach(dataManager.articulos, id: \.id) { articulo in
                    Button(articulo.nombre) {
                        row.articulo = articulo
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
                    .font(.system(size: 16))
                    .frame(width: 32, height: 44)
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
    
}
    
 

// MARK: - TextField especializado para códigos con manejo de scanner MEJORADO
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
        textField.keyboardType = .asciiCapable
        textField.returnKeyType = .next
        
        // Configuración mejorada para scanners
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.onSubmit = onSubmit
        context.coordinator.scannerManager = scannerManager
        
        if !context.coordinator.isProcessingScan &&
           !context.coordinator.isReceivingInput &&
           uiView.text != text {
            uiView.text = text
        }
        
        // Manejo de focus mejorado
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                context.coordinator.prepareForNewInput()
            }
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, scannerManager: scannerManager)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onSubmit: (String) -> Void
        var scannerManager: DebugScannerManager
        
        // ✅ Estados mejorados para seguimiento
        private var scanBuffer = ""
        private var lastInputTime = Date()
        private var scannerTimer: Timer?
        var isProcessingScan = false
        var isReceivingInput = false  // Nuevo: para detectar entrada activa
        private var inputStartTime = Date()
        
        // ✅ Configuración mejorada de timing
        private let scannerTimeout: TimeInterval = 0.4  // Aumentado a 400ms
        private let fastInputThreshold: TimeInterval = 0.15  // Más permisivo: 150ms
        private let maxInputDuration: TimeInterval = 2.0  // Máximo 2 segundos para completar entrada
        
        init(text: Binding<String>, onSubmit: @escaping (String) -> Void, scannerManager: DebugScannerManager) {
            self._text = text
            self.onSubmit = onSubmit
            self.scannerManager = scannerManager
        }
        
        func prepareForNewInput() {
            cleanup()
            isReceivingInput = false
            isProcessingScan = false
        }
        
        func cleanup() {
            scannerTimer?.invalidate()
            scanBuffer = ""
            isProcessingScan = false
            isReceivingInput = false
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            
            // ✅ 1. Detectar terminadores de scanner (más completa)
            let terminators: [String] = ["\t", "\n", "\r", "\u{0003}", "\u{0004}", "\u{001A}", "\u{001B}"]
            
            if terminators.contains(string) {
                let currentText = (textField.text ?? "") + scanBuffer
                if !currentText.isEmpty {
                    processCompleteCode(currentText, textField: textField)
                }
                return false
            }
            
            // ✅ 2. Si es entrada vacía (delete), permitir pero marcar como no-scanner
            if string.isEmpty {
                isReceivingInput = false
                return true
            }
            
            // ✅ 3. Detectar inicio de nueva entrada
            let currentTime = Date()
            let timeSinceLastInput = currentTime.timeIntervalSince(lastInputTime)
            
            if !isReceivingInput {
                inputStartTime = currentTime
                isReceivingInput = true
            }
            
            lastInputTime = currentTime
            
            // ✅ 4. Detectar si es entrada de scanner (criterios mejorados)
            let isFastInput = timeSinceLastInput < fastInputThreshold
            let isMultiCharInput = string.count > 1
            let inputDuration = currentTime.timeIntervalSince(inputStartTime)
            let isWithinScanWindow = inputDuration < maxInputDuration
            
            // Si parece ser del scanner
            if (isFastInput || isMultiCharInput) && isWithinScanWindow {
                // Marcar que estamos recibiendo datos del scanner
                isReceivingInput = true
                
                // Agregar al buffer
                scanBuffer += string
                
                // Cancelar timer anterior si existe
                scannerTimer?.invalidate()
                
                // ✅ Programar timer con timeout más largo
                scannerTimer = Timer.scheduledTimer(withTimeInterval: scannerTimeout, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        let currentFieldText = textField.text ?? ""
                        let completeCode = currentFieldText + self.scanBuffer
                        
                        if !completeCode.isEmpty {
                            self.processCompleteCode(completeCode, textField: textField)
                        } else {
                            self.cleanup()
                        }
                    }
                }
                
                // ✅ NO actualizar el campo de texto directamente durante el buffer
                // Esto evita conflictos con el binding
                return false
            }
            
            // ✅ 5. Entrada manual normal
            isReceivingInput = true
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            
            // Solo actualizar binding si no hay conflicto
            if !isProcessingScan {
                text = newText
            }
            
            return true
        }
        
        private func processCompleteCode(_ code: String, textField: UITextField) {
            // ✅ Prevenir procesamiento múltiple
            guard !isProcessingScan else { return }
            isProcessingScan = true
            isReceivingInput = false
            
            // Limpiar recursos
            scannerTimer?.invalidate()
            
            let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🔍 Scanner procesando código completo: '\(cleanCode)' (longitud: \(cleanCode.count))")
            
            if cleanCode.count >= 3 { // Validación mínima
                
                textField.text = cleanCode
                
                DispatchQueue.main.async {
                    self.text = cleanCode
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.onSubmit(cleanCode)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if textField.isFirstResponder {
                                textField.text = ""
                                self.text = ""
                            }
                            self.scanBuffer = ""
                            self.isProcessingScan = false
                            self.isReceivingInput = false
                        }
                    }
                }
            } else {
                // Código muy corto, probablemente incompleto
                print("⚠️ Código demasiado corto: '\(cleanCode)'")
                cleanup()
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let fieldText = textField.text, !fieldText.isEmpty {
                let completeText = fieldText + scanBuffer
                processCompleteCode(completeText, textField: textField)
            }
            return false
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            // ✅ Procesar cualquier entrada pendiente antes de salir
            if !scanBuffer.isEmpty || !(textField.text?.isEmpty ?? true) {
                let completeText = (textField.text ?? "") + scanBuffer
                if !completeText.isEmpty {
                    processCompleteCode(completeText, textField: textField)
                }
            } else {
                cleanup()
            }
        }
        
        // ✅ Nuevo: Manejar cuando el campo pierde foco abruptamente
        func textFieldDidBeginEditing(_ textField: UITextField) {
            prepareForNewInput()
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension ExcelStyleBatchView {
    private func handleCodigoSubmit(at index: Int, codigo: String) {
        // Validar que el código tenga al menos 3 caracteres
        guard codigo.count >= 3 else {
            print("⚠️ Código muy corto rechazado: '\(codigo)'")
            return
        }
        
        print("✅ Código aceptado en fila \(index): '\(codigo)'")
        
        rows[index].codigo = codigo
        
        let shouldAddNewRow = (index == rows.count - 1)
        if shouldAddNewRow {
            addNewRow()
        }
        
        let nextRowIndex = index + 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Asegurarse de que la siguiente fila existe antes de mover el focus
            if nextRowIndex < rows.count {
                focusedField = .codigo(nextRowIndex)
                print("🎯 Focus movido a fila \(nextRowIndex)")
            } else {
 
                focusedField = .codigo(max(0, rows.count - 1))
                print("🎯 Focus movido a última fila disponible: \(max(0, rows.count - 1))")
            }
        }
    }
}

extension ExcelStyleBatchView {
    private func deleteRow(at index: Int) {
        guard rows.count > 1 else { return }
        
        // ✅ Si estamos eliminando la fila enfocada, mover el focus inteligentemente
        if let currentFocus = focusedField {
            switch currentFocus {
            case .codigo(let focusedIndex) where focusedIndex == index:
                // Si eliminamos la fila actual, mover a la fila anterior o siguiente
                let newFocusIndex = index > 0 ? index - 1 : 0
                focusedField = .codigo(newFocusIndex)
                
            case .operacion(let focusedIndex) where focusedIndex == index:
                let newFocusIndex = index > 0 ? index - 1 : 0
                focusedField = .codigo(newFocusIndex) // Siempre volver al código
                
            case .articulo(let focusedIndex) where focusedIndex == index:
                let newFocusIndex = index > 0 ? index - 1 : 0
                focusedField = .codigo(newFocusIndex) // Siempre volver al código
                
            default:
                // Si el focus está en otra fila, ajustar índices si es necesario
                switch currentFocus {
                case .codigo(let focusedIndex) where focusedIndex > index:
                    focusedField = .codigo(focusedIndex - 1)
                case .operacion(let focusedIndex) where focusedIndex > index:
                    focusedField = .operacion(focusedIndex - 1)
                case .articulo(let focusedIndex) where focusedIndex > index:
                    focusedField = .articulo(focusedIndex - 1)
                default:
                    break
                }
            }
        }
        
        rows.remove(at: index)
    }
}

// MARK: - Botón mejorado para agregar fila manualmente
extension ExcelStyleBatchView {
    private func addNewRow() {
        let newIndex = rows.count
        rows.append(BatchRow())
        
        print("➕ Nueva fila agregada en índice \(newIndex)")
    }
    
    // Función separada para agregar fila manualmente con focus
    private func addNewRowManually() {
        let newIndex = rows.count
        addNewRow()
        
        // Mover focus a la nueva fila cuando se agrega manualmente
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .codigo(newIndex)
        }
    }
}

// MARK: - Footer actualizado para usar la función manual
extension ExcelStyleBatchView {
    private var footerViewUpdated: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: addNewRowManually) { // ✅ CAMBIADO: usar función manual
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
}
*/
