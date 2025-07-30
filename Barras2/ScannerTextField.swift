//
//  ScannerTextField.swift
//  Barras2
//
//  Created by Ulises Islas on 18/07/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Scanner TextField (Corregido)
struct ScannerTextField: UIViewRepresentable {
    @Binding var text: String
    var onScan: (String) -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = "Escanea código de barras..."
        textField.borderStyle = .roundedRect
        
        // Usar DispatchQueue para asegurar que el teclado aparezca de forma fiable.
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // 1. Actualiza el coordinator con la última versión del closure `onScan`.
        // Esto es crucial para evitar el bug de estado viejo.
        context.coordinator.onScan = onScan
        
        // 2. Sincroniza el texto si se modifica desde fuera.
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        // El coordinator se inicializa con los valores iniciales.
        // `updateUIView` se encargará de mantenerlo actualizado.
        Coordinator(text: $text, onScan: onScan)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onScan: (String) -> Void
        
        init(text: Binding<String>, onScan: @escaping (String) -> Void) {
            self._text = text
            self.onScan = onScan
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Un escáner de hardware suele enviar un carácter de tabulación ('\t') o nueva línea ('\n').
            if string == "\t" || string == "\n" {
                if let currentText = textField.text, !currentText.isEmpty {
                    // Usa el closure `onScan` almacenado y actualizado para procesar el código.
                    self.onScan(currentText)
                    
                    // Limpia el campo y el binding para el siguiente escaneo.
                    textField.text = ""
                    self.text = ""
                }
                // Evita que el carácter de tabulación/nueva línea se escriba en el campo.
                return false
            }
            
            // Para escritura manual
            let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
            self.text = newText
            return true
        }
    }
}

// MARK: - Estructuras adicionales para modo Batch
struct BatchCodigo: Identifiable {
    let id = UUID()
    let codigo: String
    var articulo: Articulo?
    let fechaEscaneo: Date
    
    init(codigo: String) {
        self.codigo = codigo
        self.fechaEscaneo = Date()
    }
}

// MARK: - ScannerView Modificado (reemplazar el existente)
struct ScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var scannedText = ""
    @State private var showingDetail = false
    @State private var currentCodigo: CodigoBarras?
    @State private var manualEntry = ""
    @FocusState private var isScannerTextFieldFocused: Bool
    @FocusState private var isManualTextFieldFocused: Bool
    @State private var scannerActive = true

    // Nuevos estados para modo Batch
    @State private var batchMode = false
    @State private var selectedBatchOperacion: Operacion?
    @State private var batchCodigos: [BatchCodigo] = []
    @State private var showingBatchList = false
    @State private var batchScannedText = ""
    @FocusState private var isBatchScannerFocused: Bool
    

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Picker("Modo", selection: $batchMode.animation()) {
                    Text("Individual").tag(false)
                    Text("Batch").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if batchMode {
                    batchModeView
                } else {
                    individualModeView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scanner")
            // MEJORA: Se usa .toolbar en lugar del obsoleto .navigationBarItems
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ArticulosView()) {
                        Image(systemName: "list.bullet.rectangle")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                CodigoDetailViewWrapper(
                    codigo: currentCodigo,
                    isNew: true,
                    onSave: { updatedCodigo in
                        dataManager.addCodigo(updatedCodigo)
                    }
                )
            }
            .sheet(isPresented: $showingBatchList) {
                BatchListView(
                    batchCodigos: $batchCodigos,
                    selectedOperacion: selectedBatchOperacion!,
                    dataManager: dataManager
                ) {
                    batchCodigos.removeAll()
                    selectedBatchOperacion = nil
                    batchMode = false
                }
            }
            .onAppear {
                if !batchMode {
                    isScannerTextFieldFocused = scannerActive
                }
            }
            .onChange(of: batchMode) { _, newValue in
                if !newValue {
                    batchCodigos.removeAll()
                    selectedBatchOperacion = nil
                    isScannerTextFieldFocused = scannerActive
                }
            }
        }
    }
    
    // MARK: - Vista del modo Individual
    private var individualModeView: some View {
        VStack(spacing: 20) {
            // Toggle for Scanner/Manual Mode
            Button(action: {
                scannerActive.toggle()
                if scannerActive {
                    isScannerTextFieldFocused = true
                    isManualTextFieldFocused = false
                    manualEntry = ""
                } else {
                    isManualTextFieldFocused = true
                    isScannerTextFieldFocused = false
                    scannedText = ""
                }
            }) {
                Label(
                    scannerActive ? "Desactivar escáner" : "Activar escáner",
                    systemImage: scannerActive ? "barcode.viewfinder" : "keyboard"
                )
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Text("Escáner de Códigos")
                .font(.title)
                .fontWeight(.bold)
            
            // Scanner automático
            VStack(spacing: 10) {
                Text("Escáner Automático")
                    .font(.headline)
                
                if scannerActive {
                    ScannerTextField(text: $scannedText) { codigo in
                        procesarCodigo(codigo)
                    }
                    .frame(height: 44)
                    .padding(.horizontal)
                    .focused($isScannerTextFieldFocused)
                } else {
                    TextField("Escáner inactivo", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                        .frame(height: 44)
                        .padding(.horizontal)
                }
                
                Text(scannerActive ? "Mantén el cursor en el campo y escanea el código" : "Activa el escáner para usarlo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Manual Entry Section
            VStack(spacing: 10) {
                Text("Captura Manual")
                    .font(.headline)

                if !scannerActive {
                    HStack {
                        TextField("Ingresa código manualmente", text: $manualEntry)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isManualTextFieldFocused)
                            .keyboardType(.asciiCapable)
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                        Button("+") {
                            if !manualEntry.isEmpty {
                                procesarCodigo(manualEntry)
                                manualEntry = ""
                            }
                        }
                        .disabled(manualEntry.isEmpty)
                    }
                    .padding(.horizontal)
                } else {
                    TextField("Captura manual inactiva", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Vista del modo Batch
    private var batchModeView: some View {
        VStack(spacing: 20) {
            Text("Modo Batch")
                .font(.title)
                .fontWeight(.bold)
            
            // Selector de operación para batch
            VStack(spacing: 10) {
                Text("Selecciona la Operación")
                    .font(.headline)
                
                Picker("Operación", selection: $selectedBatchOperacion) {
                    Text("Seleccionar operación").tag(nil as Operacion?)
                    ForEach(Operacion.allCases, id: \.self) { operacion in
                        Text(operacion.rawValue).tag(operacion as Operacion?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            if selectedBatchOperacion != nil {
                // Scanner para batch
                VStack(spacing: 10) {
                    Text("Escanear Códigos")
                        .font(.headline)
                    
                    ScannerTextField(text: $batchScannedText) { codigo in
                        procesarBatchCodigo(codigo)
                    }
                    .frame(height: 44)
                    .padding(.horizontal)
                    .focused($isBatchScannerFocused)
                    
                    Text("Códigos escaneados: \(batchCodigos.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Botones de acción
                HStack(spacing: 20) {
                    Button("Ver Lista (\(batchCodigos.count))") {
                        showingBatchList = true
                    }
                    .disabled(batchCodigos.isEmpty)
                    
                    Button("Limpiar") {
                        batchCodigos.removeAll()
                    }
                    .disabled(batchCodigos.isEmpty)
                    .foregroundColor(.red)
                }
                .buttonStyle(.borderedProminent)
                
                // Lista resumida de códigos escaneados
                if !batchCodigos.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(batchCodigos.suffix(10)) { batchCodigo in
                                HStack {
                                    Text(batchCodigo.codigo)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text(batchCodigo.fechaEscaneo, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(4)
                            }
                            
                            if batchCodigos.count > 5 {
                                Text("... y \(batchCodigos.count - 5) más")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
            } else {
                Text("Selecciona una operación para comenzar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .onAppear {
            if selectedBatchOperacion != nil {
                isBatchScannerFocused = true
            }
        }
        .onChange(of: selectedBatchOperacion) { _, newValue in
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isBatchScannerFocused = true
                }
            }
        }
    }
    
    private func procesarCodigo(_ codigo: String) {
            let nuevoCodigo = CodigoBarras(codigo: codigo)
            currentCodigo = nuevoCodigo
            showingDetail = true
        }
        
        private func procesarBatchCodigo(_ codigo: String) {
            if !batchCodigos.contains(where: { $0.codigo == codigo }) {
                let batchCodigo = BatchCodigo(codigo: codigo)
                batchCodigos.append(batchCodigo)
            }
            batchScannedText = ""
        }
}

// MARK: - Vista de lista de códigos en batch
struct BatchListView: View {
    @Binding var batchCodigos: [BatchCodigo]
    let selectedOperacion: Operacion
    let dataManager: DataManager
    let onFinish: () -> Void
    
    // MEJORA: Se usa @Environment(\.dismiss) en lugar del obsoleto .presentationMode
    @Environment(\.dismiss) var dismiss
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                if batchCodigos.isEmpty {
                    Text("No hay códigos escaneados")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach($batchCodigos) { $batchCodigo in
                            BatchCodigoRow(
                                batchCodigo: $batchCodigo,
                                dataManager: dataManager
                            )
                        }
                        .onDelete(perform: deleteCodigos)
                    }
                }
                
                if !batchCodigos.isEmpty {
                    Button("Guardar Todos") {
                        showingConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Códigos - \(selectedOperacion.rawValue)")
            // MEJORA: Se usa .toolbar en lugar del obsoleto .navigationBarItems
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .alert("Confirmar Guardado", isPresented: $showingConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Guardar") {
                    guardarTodosLosCodigos()
                }
            } message: {
                Text("¿Deseas guardar todos los códigos con la operación \(selectedOperacion.rawValue)?")
            }
        }
    }
    
    private func deleteCodigos(offsets: IndexSet) {
        batchCodigos.remove(atOffsets: offsets)
    }
    
    private func guardarTodosLosCodigos() {
        // MEJORA: Se podría crear una función en DataManager para procesar en lote
        // y optimizar el rendimiento, pero la lógica actual es funcional.
        for batchCodigo in batchCodigos {
            var nuevoCodigo = CodigoBarras(codigo: batchCodigo.codigo)
            nuevoCodigo.articulo = batchCodigo.articulo
            let operacionLog = OperacionLog(operacion: selectedOperacion, timestamp: Date())
            nuevoCodigo.operacionHistory.append(operacionLog)
            dataManager.addCodigo(nuevoCodigo)
        }
        
        dismiss()
        onFinish()
    }
}

// MARK: - Fila para cada código en batch
struct BatchCodigoRow: View {
    @Binding var batchCodigo: BatchCodigo
    let dataManager: DataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(batchCodigo.codigo)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                Text(batchCodigo.fechaEscaneo, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Picker("Artículo", selection: $batchCodigo.articulo) {
                Text("Sin artículo").tag(nil as Articulo?)
                ForEach(dataManager.articulos) { articulo in
                    Text(articulo.nombre).tag(articulo as Articulo?)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Codigo Detail View
struct CodigoDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    var onSave: ((CodigoBarras) -> Void)?
      
    @State var codigo: CodigoBarras
    let isNew: Bool

    @State private var selectedArticulo: Articulo?
    @State private var selectedOperacion: Operacion?
    @State private var auditado = false
    @State private var cantidadPuntas = ""
    @State private var fechaEmbarque = Date()
    @State private var usarFechaEmbarque = false
    @FocusState private var isPuntasTextFieldFocused: Bool

    init(codigo: CodigoBarras, isNew: Bool = false, onSave: ((CodigoBarras) -> Void)? = nil) {
        self._codigo = State(initialValue: codigo)
        self.isNew = isNew
        self.onSave = onSave
          
        self._selectedArticulo = State(initialValue: codigo.articulo)
        self._selectedOperacion = State(initialValue: codigo.currentOperacionLog?.operacion)
        self._auditado = State(initialValue: codigo.auditado)
        self._cantidadPuntas = State(initialValue: codigo.cantidadPuntas?.description ?? "")
        self._fechaEmbarque = State(initialValue: codigo.fechaEmbarque ?? Date())
        self._usarFechaEmbarque = State(initialValue: codigo.fechaEmbarque != nil)
    }
      
    var body: some View {
        NavigationView {
            Form {
                CodigoInfoSection(codigo: codigo)
                  
                // CORRECCIÓN: Se llama a CodigoDetailsSection en lugar de a CodigoDetailView.
                // Esto elimina la recursividad infinita que causaba el error.
                CodigoDetailsSection(
                    dataManager: dataManager,
                    codigo: codigo,
                    isNew: isNew,
                    selectedArticulo: $selectedArticulo,
                    selectedOperacion: $selectedOperacion,
                    auditado: $auditado,
                    cantidadPuntas: $cantidadPuntas,
                    fechaEmbarque: $fechaEmbarque,
                    usarFechaEmbarque: $usarFechaEmbarque,
                    isPuntasTextFieldFocused: $isPuntasTextFieldFocused,
                    scannerActive: .constant(false)
                )
                  
                if let articulo = selectedArticulo, auditado {
                    ResumenEstadoPuntas(
                        articulo: articulo,
                        cantidadPuntas: cantidadPuntas
                    )
                }
            }
            .navigationTitle(isNew ? "Nuevo Código" : "Editar Código")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") { saveChanges() }
                }
            }
        }
    }
      
    private func saveChanges() {
        var updatedCodigo = codigo
        updatedCodigo.articulo = selectedArticulo
        updatedCodigo.auditado = auditado
        updatedCodigo.cantidadPuntas = auditado ? Int(cantidadPuntas) : nil
        updatedCodigo.fechaEmbarque = usarFechaEmbarque ? fechaEmbarque : nil
          
        if let newOperation = selectedOperacion {
            if newOperation != updatedCodigo.currentOperacionLog?.operacion {
                let newLogEntry = OperacionLog(operacion: newOperation, timestamp: Date())
                updatedCodigo.operacionHistory.append(newLogEntry)
            }
        }
          
        onSave?(updatedCodigo)
        dismiss()
    }
}

// MARK: - Vistas de Secciones y Resumen
struct CodigoInfoSection: View {
    let codigo: CodigoBarras
    
    var body: some View {
        Section(header: Text("Información del Código")) {
            HStack {
                Text("Código:")
                Spacer()
                Text(codigo.codigo)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("Fecha de Creación:")
                Spacer()
                Text(codigo.fechaCreacion, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

  // MARK: - Resumen de estado de puntas
  struct ResumenEstadoPuntas: View {
      let articulo: Articulo
      let cantidadPuntas: String
      
      private var puntasContadas: Int {
          Int(cantidadPuntas) ?? 0
      }
      
      private var estadoCompleto: (icono: String, texto: String, color: Color) {
          guard let esperadas = articulo.cantidadPuntasEsperadas else {
              return ("questionmark.circle", "Sin referencia", .orange)
          }
          
          if puntasContadas == esperadas {
              return ("checkmark.circle.fill", "Cantidad completa", .green)
          } else if puntasContadas < esperadas {
              let faltantes = esperadas - puntasContadas
              return ("exclamationmark.triangle.fill", "Faltan \(faltantes)", .orange)
          } else {
              let exceso = puntasContadas - esperadas
              return ("xmark.circle.fill", "Exceso de \(exceso)", .red)
          }
      }
      
      var body: some View {
          Section(header: Text("Resumen de Auditoría")) {
              HStack(spacing: 12) {
                  Image(systemName: estadoCompleto.icono)
                      .foregroundColor(estadoCompleto.color)
                      .font(.title)
                  
                  VStack(alignment: .leading, spacing: 2) {
                      Text(estadoCompleto.texto)
                          .fontWeight(.semibold)
                          .foregroundColor(estadoCompleto.color)
                      
                      if let esperadas = articulo.cantidadPuntasEsperadas {
                          Text("Contadas: \(puntasContadas) de \(esperadas)")
                              .font(.caption)
                              .foregroundColor(.secondary)
                      }
                  }
                  Spacer()
              }
              .padding(.vertical, 4)
          }
      }
  }


  // MARK: - Vista mejorada de cantidad de puntas con progreso
  struct CantidadPuntasViewWithProgress: View {
      @Binding var cantidadPuntas: String
      var isPuntasTextFieldFocused: FocusState<Bool>.Binding
      @Binding var scannerActive: Bool
      let articuloSeleccionado: Articulo?
      
      private var puntasEsperadas: Int? {
          articuloSeleccionado?.cantidadPuntasEsperadas
      }
      
      private var puntasActuales: Int {
          Int(cantidadPuntas) ?? 0
      }
      
      private var progreso: Double {
          guard let esperadas = puntasEsperadas, esperadas > 0 else { return 0 }
          return min(1.0, Double(puntasActuales) / Double(esperadas))
      }
      
      private var colorProgreso: Color {
          guard let esperadas = puntasEsperadas else { return .secondary }
          if esperadas == 0 { return .secondary }
          
          if puntasActuales == esperadas {
              return .green
          } else if puntasActuales > esperadas {
              return .red
          } else {
              return .orange
          }
      }
      
      var body: some View {
          VStack(spacing: 8) {
              if let esperadas = puntasEsperadas {
                  VStack(spacing: 4) {
                      ProgressView(value: progreso)
                          .tint(colorProgreso)
                      
                      HStack {
                          Text(estadoTexto)
                              .font(.caption)
                              .foregroundColor(colorProgreso)
                          Spacer()
                          Text("\(puntasActuales) / \(esperadas)")
                              .font(.caption)
                              .foregroundColor(.secondary)
                      }
                  }
              }
              
              HStack {
                  Button(action: { adjustPuntas(by: -1) }) {
                      Image(systemName: "minus.circle.fill")
                  }
                  .foregroundColor(.red)
                  
                  TextField("Puntas", text: $cantidadPuntas)
                      .keyboardType(.numberPad)
                      .multilineTextAlignment(.center)
                      .padding(8)
                      .background(Color.secondary.opacity(0.1))
                      .cornerRadius(8)
                      .focused(isPuntasTextFieldFocused)
                  
                  Button(action: { adjustPuntas(by: 1) }) {
                      Image(systemName: "plus.circle.fill")
                  }
                  .foregroundColor(.green)
              }
              .font(.title2)
              .buttonStyle(PlainButtonStyle())
          }
          .padding(.vertical, 8)
      }
      
      private var estadoTexto: String {
          guard let esperadas = puntasEsperadas else { return "Sin referencia" }
          if esperadas == 0 { return "No se esperan puntas" }
          
          if puntasActuales == esperadas {
              return "Cantidad correcta"
          } else if puntasActuales < esperadas {
              return "Cantidad incompleta"
          } else {
              return "Exceso de puntas"
          }
      }
      
      private func adjustPuntas(by value: Int) {
          let newValue = max(0, puntasActuales + value)
          cantidadPuntas = "\(newValue)"
      }
  }

// MARK: - Sección de información del código
/*struct CodigoInfoSection: View {
    let codigo: CodigoBarras
    
    var body: some View {
        Section(header: Text("Información del Código")) {
            HStack {
                Text("Código:")
                Spacer()
                Text(codigo.codigo)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("Fecha de Creación:")
                Spacer()
                Text(codigo.fechaCreacion, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}*/

// MARK: - Sección de detalles del código (Mejorada)
struct CodigoDetailsSection: View {
    let dataManager: DataManager
    let codigo: CodigoBarras
    let isNew: Bool
    
    @Binding var selectedArticulo: Articulo?
    @Binding var selectedOperacion: Operacion?
    @Binding var auditado: Bool
    @Binding var cantidadPuntas: String
    @Binding var fechaEmbarque: Date
    @Binding var usarFechaEmbarque: Bool
    
    // CORRECCIÓN: La sintaxis correcta para recibir el binding de un @FocusState.
    var isPuntasTextFieldFocused: FocusState<Bool>.Binding
    @Binding var scannerActive: Bool
    
    private var isAuditadoToggleDisabled: Bool {
        return selectedOperacion == .empaque
    }
    
    var body: some View {
        // CORRECCIÓN: Se usa un Group para que el body devuelva una sola vista raíz.
        Group {
            Section(header: Text("Detalles")) {
                ArticuloPicker(dataManager: dataManager, selectedArticulo: $selectedArticulo)
                OperacionPicker(selectedOperacion: $selectedOperacion)
                
                if !isNew, let previousLog = codigo.currentOperacionLog {
                    OperacionAnteriorView(previousLog: previousLog)
                }
                
                Toggle("Auditado", isOn: $auditado)
                    .disabled(isAuditadoToggleDisabled)
                
                if auditado {
                    // MEJORA: Se utiliza la vista con progreso y se elimina la versión simple.
                    CantidadPuntasViewWithProgress(
                        cantidadPuntas: $cantidadPuntas,
                        isPuntasTextFieldFocused: isPuntasTextFieldFocused,
                        scannerActive: $scannerActive,
                        articuloSeleccionado: selectedArticulo
                    )
                }
                
                FechaEmbarqueView(usarFechaEmbarque: $usarFechaEmbarque, fechaEmbarque: $fechaEmbarque)
            }
            .onChange(of: selectedOperacion) { _, newOperation in
                if newOperation == .empaque {
                    auditado = false
                }
            }

            if isAuditadoToggleDisabled {
                Text("Auditado no aplica para la operación de 'Empaque'.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Picker de artículo
struct ArticuloPicker: View {
    let dataManager: DataManager
    @Binding var selectedArticulo: Articulo?
    
    var body: some View {
        Picker("Artículo", selection: $selectedArticulo) {
            Text("Seleccionar artículo").tag(nil as Articulo?)
            ForEach(dataManager.articulos) { articulo in
                Text(articulo.nombre).tag(articulo as Articulo?)
            }
        }
    }
}

// MARK: - Picker de operación
struct OperacionPicker: View {
    @Binding var selectedOperacion: Operacion?
    
    var body: some View {
        Picker("Operación Actual", selection: $selectedOperacion) {
            Text("Seleccionar operación").tag(nil as Operacion?)
            ForEach(Operacion.allCases, id: \.self) { op in
                Text(op.rawValue).tag(op as Operacion?)
            }
        }
    }
}

// MARK: - Vista de operación anterior
struct OperacionAnteriorView: View {
    let previousLog: OperacionLog
    
    var body: some View {
        HStack {
            Text("Operación Anterior:")
            Spacer()
            Text("\(previousLog.operacion.rawValue) a las \(previousLog.timestamp, style: .time)")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

/*// MARK: - Vista de cantidad de puntas
struct CantidadPuntasView: View {
    @Binding var cantidadPuntas: String
    @FocusState.Binding var isPuntasTextFieldFocused: Bool
    @Binding var scannerActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cantidad de Puntas")
                .font(.headline)
            
            HStack {
                // Botón rápido -10
                Button(action: { adjustPuntas(by: -10) }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                
                // Botón -1
                Button(action: { adjustPuntas(by: -1) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                // Campo editable
                TextField("0", text: $cantidadPuntas)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
                    .focused($isPuntasTextFieldFocused)
                
                // Botón +1
                Button(action: { adjustPuntas(by: 1) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                
                // Botón rápido +10
                Button(action: { adjustPuntas(by: 10) }) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onChange(of: isPuntasTextFieldFocused) { _, isFocused in
            if scannerActive != true {
                scannerActive = !isFocused
            }
        }
    }
    
    private func adjustPuntas(by value: Int) {
        let currentValue = Int(cantidadPuntas) ?? 0
        let newValue = max(0, currentValue + value)
        cantidadPuntas = "\(newValue)"
    }
}*/

// MARK: - Vista de fecha de embarque
struct FechaEmbarqueView: View {
    @Binding var usarFechaEmbarque: Bool
    @Binding var fechaEmbarque: Date
    
    var body: some View {
        Toggle("Usar Fecha de Embarque", isOn: $usarFechaEmbarque)
        
        if usarFechaEmbarque {
            DatePicker("Fecha de Embarque", selection: $fechaEmbarque, displayedComponents: .date)
        }
    }
}

