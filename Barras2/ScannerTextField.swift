//
//  ScannerTextField.swift
//  Barras2 - Versión Mejorada
//
//  Solución definitiva para el problema del teclado/scanner
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Scanner Mode Manager
class DebugScannerManager: ObservableObject {
    @Published var isHardwareScannerActive: Bool = true
    @Published var keyboardMode: KeyboardMode = .scanner
    @Published var debugMode: Bool = false
    @Published var lastScanDebugInfo: ScanDebugInfo?
    
    enum KeyboardMode {
        case scanner
        case manual
        case hybrid
    }
    
    struct ScanDebugInfo {
        let timestamp: Date
        let rawInput: String
        let processedInput: String
        let inputLength: Int
        let terminatorFound: String?
        let processingTime: TimeInterval
    }
    
    func switchToManualMode() {
        keyboardMode = .manual
        isHardwareScannerActive = false
    }
    
    func switchToScannerMode() {
        keyboardMode = .scanner
        isHardwareScannerActive = true
    }
    
    func switchToHybridMode() {
        keyboardMode = .hybrid
        isHardwareScannerActive = true
    }
    
    func logScanAttempt(raw: String, processed: String, terminator: String?, time: TimeInterval) {
        lastScanDebugInfo = ScanDebugInfo(
            timestamp: Date(),
            rawInput: raw,
            processedInput: processed,
            inputLength: processed.count,
            terminatorFound: terminator,
            processingTime: time
        )
    }
}

// MARK: - Enhanced Scanner TextField with Debug
struct DebugScannerTextField: UIViewRepresentable {
    @Binding var text: String
    var onScan: (String) -> Void
    var placeholder: String
    var isActive: Bool
    @ObservedObject var scannerManager: DebugScannerManager
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.textAlignment = .center
        
        // Configuración específica para capturar todo el input
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .default
        textField.returnKeyType = .done
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.onScan = onScan
        context.coordinator.scannerManager = scannerManager
        
        if uiView.text != text {
            uiView.text = text
        }
        
        handleFocusManagement(uiView)
        configureTextField(uiView, for: scannerManager.keyboardMode)
    }
    
    private func configureTextField(_ textField: UITextField, for mode: DebugScannerManager.KeyboardMode) {
        switch mode {
        case .scanner:
            textField.isUserInteractionEnabled = true
            textField.keyboardType = .default
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            
        case .manual:
            textField.isUserInteractionEnabled = true
            textField.keyboardType = .namePhonePad
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .allCharacters
            
        case .hybrid:
            textField.isUserInteractionEnabled = true
            textField.keyboardType = .default
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        }
    }
    
    private func handleFocusManagement(_ textField: UITextField) {
        switch (isActive, scannerManager.keyboardMode) {
        case (true, .scanner):
            if !textField.isFirstResponder {
                textField.becomeFirstResponder()
            }
            // En modo scanner, mantener focus pero minimizar interferencia del teclado virtual
            
        case (true, .manual):
            if !textField.isFirstResponder {
                DispatchQueue.main.async {
                    textField.becomeFirstResponder()
                }
            }
            
        case (true, .hybrid):
            if !textField.isFirstResponder {
                textField.becomeFirstResponder()
            }
            
        case (false, _):
            if textField.isFirstResponder {
                textField.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onScan: onScan, scannerManager: scannerManager)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onScan: (String) -> Void
        var scannerManager: DebugScannerManager
        
        // Buffer para acumular caracteres del scanner
        private var scanBuffer = ""
        private var lastInputTime = Date()
        private var scannerInputTimer: Timer?
        
        init(text: Binding<String>, onScan: @escaping (String) -> Void, scannerManager: DebugScannerManager) {
            self._text = text
            self.onScan = onScan
            self.scannerManager = scannerManager
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let startTime = Date()
            
            // SOLUCIÓN 1: Detectar terminadores múltiples
            let allTerminators = ["\t", "\n", "\r", "\u{0003}", "\u{000D}", "\u{000A}"] // TAB, LF, CR, ETX
            
            if allTerminators.contains(string) {
                let finalText = textField.text ?? ""
                
                // Log para debug
                if scannerManager.debugMode {
                    let processingTime = Date().timeIntervalSince(startTime)
                    scannerManager.logScanAttempt(
                        raw: finalText + " + [\\(getTerminatorName(string))]",
                        processed: finalText,
                        terminator: getTerminatorName(string),
                        time: processingTime
                    )
                }
                
                if !finalText.isEmpty {
                    onScan(finalText)
                    
                    // Limpiar después del escaneo
                    DispatchQueue.main.async {
                        textField.text = ""
                        self.text = ""
                        self.scanBuffer = ""
                    }
                }
                return false
            }
            
            // SOLUCIÓN 2: Detectar entrada rápida de scanner (múltiples caracteres)
            let isLikelyFromScanner = string.count > 1
            let timeSinceLastInput = Date().timeIntervalSince(lastInputTime)
            
            // SOLUCIÓN 3: Detectar patrones de scanner
            let isFastInput = timeSinceLastInput < 0.05 // Menos de 50ms entre caracteres
            
            // Actualizar tiempo de último input
            lastInputTime = Date()
            
            // Procesar input normal
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            
            // SOLUCIÓN 4: Usar buffer para scanners que envían caracteres uno por uno muy rápido
            if scannerManager.keyboardMode == .scanner || scannerManager.keyboardMode == .hybrid {
                
                // Si es entrada rápida, usar buffer
                if isFastInput || isLikelyFromScanner {
                    scanBuffer += string
                    
                    // Cancelar timer anterior
                    scannerInputTimer?.invalidate()
                    
                    // Crear nuevo timer para procesar después de que termine la entrada rápida
                    scannerInputTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                        DispatchQueue.main.async {
                            if !self.scanBuffer.isEmpty {
                                let completeCode = (textField.text ?? "") + self.scanBuffer
                                
                                if self.scannerManager.debugMode {
                                    let processingTime = Date().timeIntervalSince(startTime)
                                    self.scannerManager.logScanAttempt(
                                        raw: "Buffer: " + self.scanBuffer,
                                        processed: completeCode,
                                        terminator: "Timer",
                                        time: processingTime
                                    )
                                }
                                
                                self.onScan(completeCode)
                                textField.text = ""
                                self.text = ""
                                self.scanBuffer = ""
                            }
                        }
                    }
                }
                
                // En modo híbrido, detectar automáticamente si viene del scanner
                if scannerManager.keyboardMode == .hybrid && (isLikelyFromScanner || isFastInput) {
                    // Si parece ser del scanner, procesarlo después de un breve delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if textField.text == newText && !newText.isEmpty && self.scanBuffer.isEmpty {
                            if self.scannerManager.debugMode {
                                let processingTime = Date().timeIntervalSince(startTime)
                                self.scannerManager.logScanAttempt(
                                    raw: newText,
                                    processed: newText,
                                    terminator: "Auto-detect",
                                    time: processingTime
                                )
                            }
                            
                            self.onScan(newText)
                            textField.text = ""
                            self.text = ""
                        }
                    }
                }
            }
            
            // Actualizar binding
            text = newText
            return true
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let text = textField.text, !text.isEmpty {
                onScan(text)
                textField.text = ""
                self.text = ""
                scanBuffer = ""
            }
            return false
        }
        
        // SOLUCIÓN 5: Manejar cuando el campo pierde focus (algunos scanners causan esto)
        func textFieldDidEndEditing(_ textField: UITextField) {
            if let text = textField.text, !text.isEmpty, scannerManager.keyboardMode == .scanner {
                // Si hay texto cuando pierde focus, probablemente fue un escaneo
                onScan(text)
                textField.text = ""
                self.text = ""
                scanBuffer = ""
            }
        }
        
        private func getTerminatorName(_ terminator: String) -> String {
            switch terminator {
            case "\t": return "TAB"
            case "\n": return "LF"
            case "\r": return "CR"
            case "\u{0003}": return "ETX"
         //   case "\u{000D}": return "CR2"
         //   case "\u{000A}": return "LF2"
            default: return "UNKNOWN"
            }
        }
    }
}

// MARK: - Debug Panel View
struct ScannerDebugPanel: View {
    @ObservedObject var scannerManager: DebugScannerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🐛 Debug Panel")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Toggle("Debug", isOn: $scannerManager.debugMode)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            
            if scannerManager.debugMode {
                if let debugInfo = scannerManager.lastScanDebugInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Último Escaneo:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        DebugInfoRow(title: "Hora", value: debugInfo.timestamp.formatted(date: .omitted, time: .standard))
                        DebugInfoRow(title: "Input Raw", value: debugInfo.rawInput)
                        DebugInfoRow(title: "Procesado", value: debugInfo.processedInput)
                        DebugInfoRow(title: "Longitud", value: "\(debugInfo.inputLength) caracteres")
                        DebugInfoRow(title: "Terminador", value: debugInfo.terminatorFound ?? "N/A")
                        DebugInfoRow(title: "Tiempo", value: String(format: "%.3f ms", debugInfo.processingTime * 1000))
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Sin información de debug disponible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Consejos de troubleshooting
               // troubleshootingTips
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var troubleshootingTips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Consejos de Troubleshooting:")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Si los códigos están incompletos, verifica la configuración del escáner")
                Text("• Asegúrate de que el terminador sea TAB (\\t)")
                Text("• Algunos escáneres necesitan un delay post-scan")
                Text("• Verifica que no haya caracteres especiales extra")
                Text("• En modo híbrido, el sistema detecta automáticamente")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct DebugInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

// MARK: - Scanner View con Debug
struct DebugScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var scannerManager = DebugScannerManager()
    @Environment(\.colorScheme) var colorScheme
    
    @State private var scannedText = ""
    @State private var manualEntry = ""
    @State private var showingDetail = false
    @State private var currentCodigo: CodigoBarras?
    
    // Estados para modo Batch
    @State private var batchMode = false
    @State private var selectedBatchOperacion: Operacion?
    @State private var batchCodigos: [BatchCodigo] = []
    @State private var showingBatchList = false
    @State private var batchScannedText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.1),
                        Color.purple.opacity(colorScheme == .dark ? 0.1 : 0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        // Debug Panel (siempre visible para troubleshooting)
                        ScannerDebugPanel(scannerManager: scannerManager)
                        
                        modeToggleSection
                        
                        if batchMode {
                            batchModeSection
                        } else {
                            individualModeSection
                        }
                        
                        statisticsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ArticulosView()) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
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
        }
    }
    
    // MARK: - Resto de las vistas (similar al código anterior pero usando DebugScannerTextField)
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanner")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Sistema avanzado de Captura")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                                
                HStack(spacing: 12) {
                    // Botón sutil para ArticulosView
                    NavigationLink(destination: ArticulosView()) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title3)
                            .foregroundColor(.blue.opacity(0.7))
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    modeIndicator
                }
            }
        }
    }
    
    private var modeIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: currentModeIcon)
                .font(.caption)
            Text(currentModeText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(currentModeColor.opacity(0.2))
        .foregroundColor(currentModeColor)
        .clipShape(Capsule())
    }
    
    private var currentModeIcon: String {
        switch scannerManager.keyboardMode {
        case .scanner: return "barcode.viewfinder"
        case .manual: return "keyboard"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }
    
    private var currentModeText: String {
        switch scannerManager.keyboardMode {
        case .scanner: return "Scanner"
        case .manual: return "Teclado"
        case .hybrid: return "Híbrido"
        }
    }
    
    private var currentModeColor: Color {
        switch scannerManager.keyboardMode {
        case .scanner: return .blue
        case .manual: return .green
        case .hybrid: return .purple
        }
    }
    
    private var modeToggleSection: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { isBatch in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        batchMode = isBatch
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isBatch ? "square.stack.3d.up.fill" : "viewfinder")
                            .font(.system(size: 16, weight: .medium))
                        Text(isBatch ? "Batch" : "Individual")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        batchMode == isBatch ?
                        Color.blue : Color(UIColor.systemGray5)
                    )
                    .foregroundColor(
                        batchMode == isBatch ? .white : .primary
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var individualModeSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                inputModeSelector
                scannerInputSection
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 2)
        }
    }
    
    private var inputModeSelector: some View {
        HStack(spacing: 12) {
            Button("Scanner") {
                scannerManager.switchToScannerMode()
            }
            .foregroundColor(scannerManager.keyboardMode == .scanner ? .white : .blue)
            .padding()
            .background(scannerManager.keyboardMode == .scanner ? Color.blue : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button("Manual") {
                scannerManager.switchToManualMode()
            }
            .foregroundColor(scannerManager.keyboardMode == .manual ? .white : .green)
            .padding()
            .background(scannerManager.keyboardMode == .manual ? Color.green : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button("Híbrido") {
                scannerManager.switchToHybridMode()
            }
            .foregroundColor(scannerManager.keyboardMode == .hybrid ? .white : .purple)
            .padding()
            .background(scannerManager.keyboardMode == .hybrid ? Color.purple : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var scannerInputSection: some View {
            VStack(spacing: 12) {
                HStack {
                    Text("Campo de Captura")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Botón para ocultar teclado en modo manual e híbrido
                    if scannerManager.keyboardMode == .manual || scannerManager.keyboardMode == .hybrid {
                        Button(action: {
                            hideKeyboard()
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DebugScannerTextField(
                    text: $scannedText,
                    onScan: procesarCodigo,
                    placeholder: "Escanea o escribe el código...",
                    isActive: true,
                    scannerManager: scannerManager
                )
                .frame(height: 50)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(colorScheme == .dark ? 0.6 : 0.3), lineWidth: 2)
                )
            }
        }
    
       
       // MARK: - Manual Input Section
       private var manualInputSection: some View {
           VStack(spacing: 12) {
               if scannerManager.keyboardMode == .manual || scannerManager.keyboardMode == .hybrid {
                   VStack(spacing: 8) {
                       HStack {
                           Image(systemName: "keyboard")
                               .foregroundColor(.green)
                           Text("Entrada Manual")
                               .font(.subheadline)
                               .fontWeight(.medium)
                           Spacer()
                       }
                       
                       HStack(spacing: 12) {
                           TextField("Escribe el código manualmente", text: $manualEntry)
                               .textFieldStyle(PlainTextFieldStyle())
                               .padding(.horizontal, 16)
                               .padding(.vertical, 14)
                               .background(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.05))
                               .clipShape(RoundedRectangle(cornerRadius: 12))
                               .overlay(
                                   RoundedRectangle(cornerRadius: 12)
                                       .stroke(Color.green.opacity(colorScheme == .dark ? 0.6 : 0.3), lineWidth: 2)
                               )
                           
                           Button(action: {
                               if !manualEntry.isEmpty {
                                   procesarCodigo(manualEntry)
                                   manualEntry = ""
                               }
                           }) {
                               Image(systemName: "plus.circle.fill")
                                   .font(.title2)
                                   .foregroundColor(.white)
                                   .frame(width: 50, height: 50)
                                   .background(Color.green)
                                   .clipShape(Circle())
                           }
                           .disabled(manualEntry.isEmpty)
                       }
                   }
               }
           }
       }
    
    // MARK: - Batch Mode Section
      private var batchModeSection: some View {
          VStack(spacing: 20) {
              // Batch Header
              VStack(spacing: 12) {
                  Text("Modo Batch")
                      .font(.title2)
                      .fontWeight(.bold)
                  
                  Text("Escanea múltiples códigos para una operación")
                      .font(.subheadline)
                      .foregroundColor(.secondary)
                      .multilineTextAlignment(.center)
              }
              
              // Operation Selector
              VStack(spacing: 12) {
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
                  .background(Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.1))
                  .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .padding(20)
              .background(Color(UIColor.systemBackground))
              .clipShape(RoundedRectangle(cornerRadius: 16))
              .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 2)
              
              // Batch Scanner Section
              if selectedBatchOperacion != nil {
                  batchScannerSection
                  batchActionsSection
                  batchCodigosList
              }
          }
      }
      
      // MARK: - Batch Scanner Section
      private var batchScannerSection: some View {
          VStack(spacing: 16) {
              HStack {
                  Image(systemName: "barcode.viewfinder")
                      .foregroundColor(.purple)
                  Text("Scanner Batch")
                      .font(.headline)
                  Spacer()
                  Text("\(batchCodigos.count)")
                      .font(.title2)
                      .fontWeight(.bold)
                      .foregroundColor(.purple)
              }
              
              DebugScannerTextField(
                  text: $batchScannedText,
                  onScan: procesarBatchCodigo,
                  placeholder: "Escanea códigos para el batch...",
                  isActive: true,
                  scannerManager: scannerManager
              )
              .frame(height: 50)
              .padding(.horizontal, 16)
              .background(Color.purple.opacity(colorScheme == .dark ? 0.2 : 0.05))
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .overlay(
                  RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.purple.opacity(colorScheme == .dark ? 0.6 : 0.3), lineWidth: 2)
              )
          }
          .padding(20)
          .background(Color(UIColor.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 2)
      }
      
      // MARK: - Batch Actions Section
      private var batchActionsSection: some View {
          HStack(spacing: 16) {
              Button(action: { showingBatchList = true }) {
                  HStack {
                      Image(systemName: "list.bullet")
                      Text("Ver Lista")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.blue)
                  .foregroundColor(.white)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .disabled(batchCodigos.isEmpty)
              
              Button(action: { batchCodigos.removeAll() }) {
                  HStack {
                      Image(systemName: "trash")
                      Text("Limpiar")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.red.opacity(colorScheme == .dark ? 0.3 : 0.1))
                  .foregroundColor(.red)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .disabled(batchCodigos.isEmpty)
          }
      }
      
      // MARK: - Batch Códigos List
      private var batchCodigosList: some View {
          VStack(alignment: .leading, spacing: 12) {
              if !batchCodigos.isEmpty {
                  Text("Últimos códigos escaneados")
                      .font(.headline)
                  
                  ScrollView {
                      LazyVStack(spacing: 8) {
                          ForEach(batchCodigos.suffix(5).reversed()) { batchCodigo in
                              HStack {
                                  Text(batchCodigo.codigo)
                                      .font(.system(.body, design: .monospaced))
                                      .fontWeight(.medium)
                                  Spacer()
                                  Text(batchCodigo.fechaEscaneo, style: .time)
                                      .font(.caption)
                                      .foregroundColor(.secondary)
                              }
                              .padding(.horizontal, 12)
                              .padding(.vertical, 8)
                              .background(Color(UIColor.systemGray6))
                              .clipShape(RoundedRectangle(cornerRadius: 8))
                          }
                          
                          if batchCodigos.count > 5 {
                              Text("... y \(batchCodigos.count - 5) más")
                                  .font(.caption)
                                  .foregroundColor(.secondary)
                          }
                      }
                  }
                  .frame(maxHeight: 200)
              }
          }
          .padding(20)
          .background(Color(UIColor.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 2)
      }
      
      // MARK: - Statistics Card
      private var statisticsCard: some View {
          VStack(spacing: 16) {
              Text("Estadísticas de Hoy")
                  .font(.headline)
                  .fontWeight(.semibold)
              
              HStack(spacing: 20) {
                  StatisticItem(
                      title: "Códigos",
                      value: "\(dataManager.codigos.count)",
                      icon: "barcode",
                      color: .blue
                  )
                  
                  StatisticItem(
                      title: "Artículos",
                      value: "\(dataManager.articulos.count)",
                      icon: "cube.box",
                      color: .green
                  )
                  
                  StatisticItem(
                      title: "Batch",
                      value: "\(batchCodigos.count)",
                      icon: "square.stack.3d.up",
                      color: .purple
                  )
              }
          }
          .padding(20)
          .background(Color(UIColor.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 2)
      }
      
      // MARK: - Helper Functions
      private func procesarCodigo(_ codigo: String) {
          let nuevoCodigo = CodigoBarras(codigo: codigo)
          currentCodigo = nuevoCodigo
          showingDetail = true
          
          // Limpiar campos
          scannedText = ""
          manualEntry = ""
      }
      
      private func procesarBatchCodigo(_ codigo: String) {
          if !batchCodigos.contains(where: { $0.codigo == codigo }) {
              let batchCodigo = BatchCodigo(codigo: codigo)
              withAnimation(.spring()) {
                  batchCodigos.append(batchCodigo)
              }
          }
          batchScannedText = ""
      }

    private func hideKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
  }

  // MARK: - Statistic Item Component
  struct StatisticItem: View {
      let title: String
      let value: String
      let icon: String
      let color: Color
      
      var body: some View {
          VStack(spacing: 8) {
              Image(systemName: icon)
                  .font(.title2)
                  .foregroundColor(color)
              
              Text(value)
                  .font(.title2)
                  .fontWeight(.bold)
                  .foregroundColor(.primary)
              
              Text(title)
                  .font(.caption)
                  .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
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
              return ("exclamationmark.triangle.fill", "Auditadas OK \(faltantes)", .orange)
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

// Nueva vista para mostrar las puntas faltantes
struct PuntasFaltantesView: View {
    let articulo: Articulo
    let puntasAuditadas: Int
    
    private var puntasFaltantes: Int? {
        guard let esperadas = articulo.cantidadPuntasEsperadas else { return nil }
        return esperadas - puntasAuditadas
    }

    var body: some View {
        if let faltantes = puntasFaltantes {
            HStack {
                if faltantes <= 0 {
                    Label("Auditoría Completa", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Puntas Faltantes: \(faltantes)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
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
              
              HStack(spacing: 16) {
                              Button(action: { adjustPuntas(by: -10) }) { Image(systemName: "gobackward.10") }
                              Button(action: { adjustPuntas(by: -1) }) { Image(systemName: "minus.circle.fill") }
                                  .foregroundColor(.red)
                              
                              TextField("Puntas", text: $cantidadPuntas)
                                  .keyboardType(.numberPad)
                                  .multilineTextAlignment(.center)
                                  .focused(isPuntasTextFieldFocused)
                              
                              Button(action: { adjustPuntas(by: 1) }) { Image(systemName: "plus.circle.fill") }
                                  .foregroundColor(.green)
                              Button(action: { adjustPuntas(by: 10) }) { Image(systemName: "goforward.10") }
                          }
                          .font(.title2)
                          .buttonStyle(PlainButtonStyle())
                          
                          // MEJORA: Botones de acción rápida
                          if let esperadas = puntasEsperadas {
                              HStack {
                                  Button("Completar (\(esperadas))") { cantidadPuntas = "\(esperadas)" }
                                  Spacer()
                                  Button("Limpiar") { cantidadPuntas = "0" }.foregroundColor(.red)
                              }
                              .font(.caption)
                              .buttonStyle(.bordered)
                              .padding(.top, 4)
                          }
                      }
                  }
      
      private var estadoTexto: String {
          guard let esperadas = puntasEsperadas else { return "Sin referencia" }
          if esperadas == 0 { return "No se esperan puntas" }
          
          if puntasActuales == esperadas {
              return "Cantidad correcta"
          } else if puntasActuales < esperadas {
              return "Cantidad faltante"
          } else {
              return "Exceso de puntas"
          }
      }
      
      private func adjustPuntas(by value: Int) {
          let newValue = max(0, puntasActuales + value)
          cantidadPuntas = "\(newValue)"
      }
  }


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
