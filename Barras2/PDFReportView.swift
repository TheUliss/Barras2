// PDFReportView.swift
import SwiftUI
import Charts // Asegúrate de importar Charts

struct PDFReportView: View {
    let date: Date
    let codigosDelDia: [CodigoBarras]
    
    // Propiedades computadas para facilitar el acceso a los datos
    private var empacados: [CodigoBarras] { codigosDelDia.filter { $0.currentOperacionLog?.operacion == .empaque } }
    private var auditados: [CodigoBarras] { codigosDelDia.filter { $0.auditado && $0.currentOperacionLog?.operacion != .empaque } }
    private var enProceso: [CodigoBarras] { codigosDelDia.filter { !$0.auditado && $0.currentOperacionLog?.operacion != .empaque } }
    
    // Datos para el gráfico de operaciones
    private var operationsData: [(operacion: String, count: Int)] {
        let grouped = Dictionary(grouping: codigosDelDia) { $0.currentOperacionLog?.operacion.rawValue ?? "Sin Asignar" }
        return grouped.map { (operacion: $0.key, count: $0.value.count) }.sorted { $0.operacion < $1.operacion }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Encabezado
            headerView
            
            Divider()
            
            // MARK: - Métricas Clave (KPIs)
            kpiView
            
            // MARK: - Gráfico de Operaciones
            operationsChartView
            
            // MARK: - Tabla de Auditoría
            auditSummaryView
            
            // MARK: - Listado General
            fullCodeListView
            
            Spacer() // Empuja el pie de página hacia abajo
            
            // MARK: - Pie de Página
            footerView
        }
        .padding(40) // Márgenes del documento
        .frame(width: 595.2, height: 841.8) // Tamaño A4
        .background(Color.white)
        .foregroundColor(.black)
    }

    // MARK: - Subvistas del Reporte
    
    private var headerView: some View {
        HStack {
            // Descomenta y agrega tu logo a los Assets
            // Image("logo_empresa")
            //     .resizable()
            //     .scaledToFit()
            //     .frame(width: 100)
            
            VStack(alignment: .leading) {
                Text("Resumen de Producción Diario")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var kpiView: some View {
        VStack(alignment: .leading) {
            Text("Métricas Clave")
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                KPIBox(title: "Total Códigos", value: "\(codigosDelDia.count)", color: .blue)
                KPIBox(title: "Auditados", value: "\(auditados.count)", color: .green)
                KPIBox(title: "Empacados", value: "\(empacados.count)", color: .purple)
                KPIBox(title: "En Proceso", value: "\(enProceso.count)", color: .orange)
            }
        }
    }
    
    private var operationsChartView: some View {
        VStack(alignment: .leading) {
            Text("Distribución por Operación")
                .font(.title)
                .fontWeight(.semibold)
            
            // Gráfico de Barras
            Chart(operationsData, id: \.operacion) { data in
                BarMark(
                    x: .value("Operación", data.operacion),
                    y: .value("Cantidad", data.count)
                )
                .foregroundStyle(by: .value("Operación", data.operacion))
                .annotation(position: .top) {
                    Text("\(data.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 150)
        }
    }
    
    private var auditSummaryView: some View {
        // Solo mostrar si hay códigos auditados
        if !auditados.isEmpty {
            VStack(alignment: .leading) {
                Text("Resumen de Auditoría")
                    .font(.title)
                    .fontWeight(.semibold)
                
                // Encabezados de la tabla
                HStack {
                    Text("Código").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Artículo").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Esperadas").fontWeight(.bold).frame(width: 80)
                    Text("Contadas").fontWeight(.bold).frame(width: 80)
                    Text("Estado").fontWeight(.bold).frame(width: 80)
                }
                .font(.caption)
                .padding(.bottom, 5)
                
                Divider()
                
                // Filas de la tabla
                ForEach(auditados) { codigo in
                    AuditRow(codigo: codigo)
                }
            }
        } else {
            EmptyView()
        }
    }
    
    private var fullCodeListView: some View {
        VStack(alignment: .leading) {
            Text("Listado de Códigos del Día")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            // Usar LazyVGrid para crear columnas
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                ForEach(codigosDelDia.sorted(by: { $0.codigo < $1.codigo })) { codigo in
                    Text(codigo.codigo)
                        .font(.system(size: 9, design: .monospaced))
                }
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Text("Reporte generado por Barras2 App")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Página 1 de 1")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Componentes Auxiliares para el PDF

struct KPIBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct AuditRow: View {
    let codigo: CodigoBarras
    
    var body: some View {
        VStack {
            HStack {
                Text(codigo.codigo)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(codigo.articulo?.nombre ?? "N/A")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\(codigo.articulo?.cantidadPuntasEsperadas ?? 0)")
                    .font(.system(size: 10))
                    .frame(width: 80)
                
                Text("\(codigo.cantidadPuntas ?? 0)")
                    .font(.system(size: 10))
                    .frame(width: 80)
                
                auditStatusView
                    .frame(width: 80)
            }
            Divider()
        }
    }
    
    // Lógica para mostrar el estado de la auditoría
    @ViewBuilder
    private var auditStatusView: some View {
        let esperadas = codigo.articulo?.cantidadPuntasEsperadas ?? 0
        let contadas = codigo.cantidadPuntas ?? 0
        
        if esperadas == 0 {
            Text("-")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
        } else if contadas == esperadas {
            Text("OK")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
        } else if contadas < esperadas {
            Text("Faltan \(esperadas - contadas)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
        } else {
            Text("Exceso \(contadas - esperadas)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
        }
    }
}