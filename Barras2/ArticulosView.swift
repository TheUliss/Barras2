//
//  ArticulosView.swift
//  Barras2
//
//  Created by Ulises Islas on 18/07/25.
//
import SwiftUI
import AVFoundation
import Combine
import PhotosUI

// MARK: - Articulos View Mejorada
struct ArticulosView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddArticulo = false
    @State private var showingEditArticulo = false
    @State private var editingArticulo: Articulo?
    @State private var nuevoArticuloNombre = ""
    @State private var nuevoArticuloDescripcion = ""
    @State private var showingDeleteAlert = false
    @State private var articuloToDelete: Articulo?
    @State private var showingDataManagement = false
    
    var body: some View {
        NavigationView {
            Form {
            // NUEVA SECCIÓN: Configuración de Reportes
            Section(header: Text("Configuración de Reportes")) {
                ReportSettingsView() // Extraemos la nueva UI a su propia vista
            }

            // SECCIÓN EXISTENTE: Lista de Artículos
            Section(header: Text("Artículos")) {
                // La lista ahora va dentro de la sección del Form
                ForEach(dataManager.articulos) { articulo in
                    ArticuloRow(
                        articulo: articulo,
                        onEdit: { editArticulo(articulo) },
                        onDelete: {
                            articuloToDelete = articulo
                            showingDeleteAlert = true
                        }
                    )
                }
                .onDelete(perform: deleteArticulos)
            }
            }
            .navigationTitle("Artículos y Config.")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !dataManager.articulos.isEmpty {
                        Button("Gestión") {
                            showingDataManagement = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        resetForm()
                        showingAddArticulo = true
                    }) {
                        Image(systemName: "plus") // Usar un ícono es más estándar
                    }
                }
            }
            .sheet(isPresented: $showingAddArticulo) {
                addArticuloSheet
            }
            .sheet(isPresented: $showingEditArticulo) {
                editArticuloSheet
            }
            .sheet(isPresented: $showingDataManagement) {
                DataManagementView()
                    .environmentObject(dataManager)
            }
            .alert("Eliminar Artículo", isPresented: $showingDeleteAlert) {
                deleteAlert
            } message: {
                deleteAlertMessage
            }
        }
    }
    
    // MARK: - Subvistas
  /*  private var estadisticasView: some View {
        HStack {
            VStack {
                Text("\(dataManager.articulos.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Artículos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Text("\(dataManager.codigos.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Códigos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // CORRECCIÓN: Se elimina el botón redundante de "Gestión" para no duplicar
            // la funcionalidad de la barra de navegación.
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var articulosListView: some View {
        List {
            ForEach(dataManager.articulos) { articulo in
                ArticuloRow(
                    articulo: articulo,
                    onEdit: {
                        editArticulo(articulo)
                    },
                    onDelete: {
                        articuloToDelete = articulo
                        showingDeleteAlert = true
                    }
                )
            }
            .onDelete(perform: deleteArticulos)
        }
        .listStyle(PlainListStyle())
    }*/
    
    // NUEVA VISTA: Contiene la UI para la configuración
    struct ReportSettingsView: View {
        // Accedemos al SettingsManager desde el entorno
        @EnvironmentObject var settingsManager: SettingsManager
        
        @State private var selectedPhoto: PhotosPickerItem?
        
        var body: some View {
            HStack {
                // Selector de Logo
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    VStack {
                        if let logoImage = settingsManager.getLogoImage() {
                            logoImage
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .frame(width: 60, height: 60)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text("Logo")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhoto) {_, newItem in
                    Task {
                        // Convertir la foto seleccionada a Data y guardarla
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            settingsManager.logoImageData = data
                        }
                    }
                }

                Divider().padding(.horizontal, 5)

                // Campos de Turno y Realizador
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Realizado por...", text: $settingsManager.nombreRealizador)
                        .textFieldStyle(.roundedBorder)

                    Picker("Turno:", selection: $settingsManager.turnoSeleccionado) {
                        ForEach(settingsManager.turnos, id: \.self) { turno in
                            Text(turno).tag(turno)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var addArticuloSheet: some View {
        ArticuloFormViewWithPuntas(
            titulo: "Agregar Artículo",
            nombre: $nuevoArticuloNombre,
            descripcion: $nuevoArticuloDescripcion,
            onSave: { cantidadPuntas in
                let articulo = Articulo(
                    nombre: nuevoArticuloNombre,
                    descripcion: nuevoArticuloDescripcion.isEmpty ? nil : nuevoArticuloDescripcion,
                    cantidadPuntasEsperadas: cantidadPuntas
                )
                dataManager.addArticulo(articulo)
                showingAddArticulo = false
            },
            onCancel: {
                showingAddArticulo = false
            }
        )
    }
    
    private var editArticuloSheet: some View {
        ArticuloFormViewWithPuntas(
            titulo: "Editar Artículo",
            nombre: $nuevoArticuloNombre,
            descripcion: $nuevoArticuloDescripcion,
            articuloExistente: editingArticulo,
            onSave: { cantidadPuntas in
                saveEditedArticuloWithPuntas(cantidadPuntas: cantidadPuntas)
            },
            onCancel: {
                cancelEdit()
            }
        )
    }
    
    @ViewBuilder
    private var deleteAlert: some View {
        Button("Cancelar", role: .cancel) {
            articuloToDelete = nil
        }
        Button("Eliminar", role: .destructive) {
            if let articulo = articuloToDelete {
                dataManager.deleteArticulo(articulo)
            }
            articuloToDelete = nil
        }
    }
    
    @ViewBuilder
    private var deleteAlertMessage: some View {
        if let articulo = articuloToDelete {
            Text("¿Estás seguro de que deseas eliminar '\(articulo.nombre)'? Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Funciones auxiliares
    private func resetForm() {
        nuevoArticuloNombre = ""
        nuevoArticuloDescripcion = ""
        editingArticulo = nil
    }
    
    private func editArticulo(_ articulo: Articulo) {
        editingArticulo = articulo
        nuevoArticuloNombre = articulo.nombre
        nuevoArticuloDescripcion = articulo.descripcion ?? ""
        showingEditArticulo = true
    }
    
    private func saveEditedArticuloWithPuntas(cantidadPuntas: Int?) {
        if let articulo = editingArticulo {
            var updatedArticulo = articulo // Crear una copia mutable ya que Articulo es una struct
            updatedArticulo.nombre = nuevoArticuloNombre
            updatedArticulo.descripcion = nuevoArticuloDescripcion.isEmpty ? nil : nuevoArticuloDescripcion
            updatedArticulo.cantidadPuntasEsperadas = cantidadPuntas
            dataManager.updateArticulo(updatedArticulo)
        }
        cancelEdit()
    }
    
    private func cancelEdit() {
        showingEditArticulo = false
        editingArticulo = nil
    }
    
    private func deleteArticulos(at offsets: IndexSet) {
        for index in offsets {
            let articulo = dataManager.articulos[index]
            dataManager.deleteArticulo(articulo)
        }
    }
}

// MARK: - Fila de Artículo
struct ArticuloRow: View {
    let articulo: Articulo
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var dataManager: DataManager
    
    // NOTA: Esta propiedad computada puede ser ineficiente si la lista de códigos es muy grande.
    // Para esta app, probablemente está bien.
    private var codigosConEsteArticulo: Int {
        dataManager.codigos.filter { $0.articulo?.id == articulo.id }.count
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(articulo.nombre)
                    .fontWeight(.semibold)
                
                if let descripcion = articulo.descripcion, !descripcion.isEmpty {
                    Text(descripcion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if codigosConEsteArticulo > 0 {
                        Text("\(codigosConEsteArticulo) códigos")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if let puntasEsperadas = articulo.cantidadPuntasEsperadas {
                        Text("\(puntasEsperadas) puntas")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) { // Aumentar espaciado para mejor toque
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formulario de Artículo con Puntas
struct ArticuloFormViewWithPuntas: View {
    let titulo: String
    @Binding var nombre: String
    @Binding var descripcion: String
    let articuloExistente: Articulo?
    let onSave: (Int?) -> Void
    let onCancel: () -> Void
    
    @State private var cantidadPuntasEsperadas: String
    @State private var usarCantidadPuntas: Bool
    @FocusState private var isNombreFocused: Bool
    
    init(titulo: String, nombre: Binding<String>, descripcion: Binding<String>, articuloExistente: Articulo? = nil, onSave: @escaping (Int?) -> Void, onCancel: @escaping () -> Void) {
        self.titulo = titulo
        self._nombre = nombre
        self._descripcion = descripcion
        self.articuloExistente = articuloExistente
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Inicializar el estado local a partir del artículo existente
        _usarCantidadPuntas = State(initialValue: articuloExistente?.cantidadPuntasEsperadas != nil)
        _cantidadPuntasEsperadas = State(initialValue: articuloExistente?.cantidadPuntasEsperadas?.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información del Artículo")) {
                    TextField("Nombre", text: $nombre)
                        .focused($isNombreFocused)
                    
                    TextField("Descripción (opcional)", text: $descripcion, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Control de Puntas")) {
                    Toggle("Especificar cantidad de puntas", isOn: $usarCantidadPuntas.animation())
                    
                    if usarCantidadPuntas {
                        HStack {
                            Text("Cantidad de puntas:")
                            Spacer()
                            TextField("0", text: $cantidadPuntasEsperadas)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
            }
            .navigationTitle(titulo)
            // CORRECCIÓN: Se usa .toolbar en lugar del obsoleto .navigationBarItems
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        onSaveWithPuntas()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNombreFocused = true
            }
        }
    }
    
    private func onSaveWithPuntas() {
        // CORRECCIÓN: Se asegura que si el Toggle está apagado o el texto es inválido, se envíe nil.
        let cantidadPuntas: Int?
        if usarCantidadPuntas {
            cantidadPuntas = Int(cantidadPuntasEsperadas)
        } else {
            cantidadPuntas = nil
        }
        onSave(cantidadPuntas)
    }
}

// CORRECCIÓN: Se eliminó el bloque de código duplicado de 'ArticuloFormViewWithPuntas' que estaba aquí.

// MARK: - Vista de Gestión de Datos
struct DataManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    // CORRECCIÓN: Se usa @Environment(\.dismiss) en lugar del obsoleto .presentationMode
    @Environment(\.dismiss) var dismiss
    @State private var showingClearDataAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Estadísticas")) {
                    HStack {
                        Text("Artículos guardados:")
                        Spacer()
                        Text("\(dataManager.articulos.count)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Códigos guardados:")
                        Spacer()
                        Text("\(dataManager.codigos.count)")
                            .fontWeight(.semibold)
                    }
                }
                
                Section(header: Text("Acciones de Datos")) {
                    Button("Limpiar Todos los Datos") {
                        showingClearDataAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                Section(footer: Text("Los datos se guardan automáticamente en el dispositivo.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Gestión de Datos")
            // CORRECCIÓN: Se usa .toolbar en lugar del obsoleto .navigationBarItems
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss() // Se llama a dismiss() para cerrar la vista
                    }
                }
            }
            .alert("Limpiar Todos los Datos", isPresented: $showingClearDataAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Limpiar Todo", role: .destructive) {
                    dataManager.limpiarTodosLosDatos()
                    dismiss()
                }
            } message: {
                Text("Esta acción eliminará todos los artículos y códigos guardados. No se puede deshacer.")
            }
        }
    }
}
