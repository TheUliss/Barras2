//
//  PDFReportView.swift
//  Barras2
//
//  Created by Ulises Islas on 29/08/25.
//


import SwiftUI
import Charts

struct PDFReportView: View {
    let pageData: ReportPageData
    
    private var groupedEmpacados: [String: [CodigoBarras]] {
        Dictionary(grouping: pageData.codigosEmpacadosDeLaPagina) { $0.articulo?.nombre ?? "Sin Artículo" }
    }
    
    private let operationOrder: [Operacion] = [
        .ribonizado, .ensamble, .pulido, .limpGeo, .armado,
        .etiquetas, .polaridad, .prueba, .limpieza
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Reducir espaciado
            // Secciones de la primera página
            if pageData.isFirstPage {
                headerView
                Divider()
                kpiView
                    .padding(.bottom, 6)
                operationsChartView
                    .padding(.bottom, 8)
            } else {
                continuationHeaderView
                    .padding(.bottom, 6)
            }
            
            // Secciones de contenido con espaciado controlado
            if !pageData.codigosEmpacadosDeLaPagina.isEmpty {
                packagedCodesSection
                    .padding(.bottom, pageData.isFirstPage ? 6 : 8)
            }
            
            if !pageData.codigosEnProcesoDeLaPagina.isEmpty {
                inProcessCodesSection
            }
            
            Spacer(minLength: 20) // Espacio mínimo antes del footer
            footerView
        }
        .padding(25) // Reducir padding
        .frame(width: 595.2, height: 841.8, alignment: .topLeading)
        .background(Color.white)
        .foregroundColor(.black)
    }

    // MARK: - Subvistas con fuentes más pequeñas
    private var headerView: some View {
        VStack(spacing: 0) {
            // Banda superior azul
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 4)
            
            // Contenido del header
            HStack(alignment: .top, spacing: 20) {
                // Logo con marco elegante
                if let imageData = pageData.logoImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.05))
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Información principal
                VStack(alignment: .leading, spacing: 6) {
                    Text("RESUMEN DE TURNO")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge")
                            .foregroundColor(.blue)
                        Text("Turno: \(pageData.turno)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Información de fecha y realizador
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Text(pageData.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    if !pageData.nombreRealizador.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("Realizó: \(pageData.nombreRealizador)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 25)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.gray.opacity(0.02))
            )
        }
    }
    
    private var continuationHeaderView: some View {
        HStack {
            Text("(Continuacion..)")
                .font(.subheadline) // Reducir tamaño
               // .fontWeight(.bold)
            Spacer()
            Text(pageData.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var kpiView: some View {
        VStack(alignment: .leading) {
            Text("Métricas del Día")
                .font(.headline) // Reducir tamaño
                .fontWeight(.semibold)
                .padding(.bottom, 4)
            HStack(spacing: 15) {
                KPIBox(title: "Total Códigos", value: "\(pageData.totalCodigosDelDia)", color: .blue)
                KPIBox(title: "Auditados", value: "\(pageData.totalAuditadosDelDia)", color: .green)
                KPIBox(title: "Empacados", value: "\(pageData.totalEmpacadosDelDia)", color: .purple)
            }
        }
    }
 
    //---->

    private var operationsChartView: some View {
        VStack(alignment: .leading) {
Text("Distribución por Operación")
.font(.headline)
.padding(.bottom, 4)
            
Chart(pageData.operationsDataDelDia, id: \.operacion) { data in
BarMark(
x: .value("Operación", data.operacion),
y: .value("Cantidad", data.count)
)
.foregroundStyle(by: .value("Operación", data.operacion))
.annotation(position: .top) {
Text("\(data.count)")
.font(.system(size: 8))
.foregroundColor(.secondary)
}
}
.chartXAxis {
AxisMarks(values: pageData.operationsDataDelDia.map { $0.operacion }) { value in
AxisValueLabel() {
if let op = value.as(String.self) {
Text(op)
.font(.system(size: 7))
}
}
AxisTick()
}
}
.chartLegend(.hidden)
.frame(height: 120)
}
}
    
    //<----
    
    
     @ViewBuilder
     private var packagedCodesSection: some View {
         if !pageData.codigosEmpacadosDeLaPagina.isEmpty {
             VStack(alignment: .leading, spacing: 0) {
                 // Header de sección
                 HStack {
                     Text("Cables Empacados")
                         .font(.headline)
                     //   .padding(.bottom, 2)
                     Spacer()
                     Image(systemName: "sum")
                         //.foregroundColor(.green)
                         .font(.system(size: 12))
                     Text("Total Empacados:")
                         .font(.system(size: 14, weight: .medium))
                     Text("\(pageData.codigosEmpacadosDeLaPagina.count)")
                         .font(.system(size: 14, weight: .bold))
                         //.foregroundColor(.green)
                 }
                 
                 VStack(spacing: 0) {
                     createColumnsView()
                         .padding(.horizontal, 15)
                         .padding(.vertical, 8)
                 }
                 .background(Color.gray.opacity(0.02))
             }
             .padding(.bottom, 8)
         }
     }
     

    @ViewBuilder
    private func createColumnsView() -> some View {
        let sortedArticles = groupedEmpacados.keys.sorted()
        let totalCodes = pageData.codigosEmpacadosDeLaPagina.count
        let codesPerColumn = 15
        let numberOfColumns = min(3, max(1, (totalCodes + codesPerColumn - 1) / codesPerColumn))
        
        // Distribuir artículos por columnas basándose en la cantidad de códigos
        let columnData = distributeArticlesByColumns(articles: sortedArticles, numberOfColumns: numberOfColumns)
        
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<numberOfColumns, id: \.self) { columnIndex in
                if columnIndex < columnData.count {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(columnData[columnIndex], id: \.self) { articleName in
                            createArticleView(articleName: articleName)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func createArticleView(articleName: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack{
                Text(articleName)
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 4)
            Text("Subtotal: \((groupedEmpacados[articleName] ?? []).count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 1)
                }
            ForEach(Array((groupedEmpacados[articleName] ?? []).sorted(by: { $0.codigo < $1.codigo }).enumerated()), id: \.element.id) { index, codigo in
                Text("\(index + 1). \(codigo.codigo)")
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .padding(.bottom, 3)
    }

    // Función para distribuir artículos por columnas de manera equilibrada
    private func distributeArticlesByColumns(articles: [String], numberOfColumns: Int) -> [[String]] {
        var columns: [[String]] = Array(repeating: [], count: numberOfColumns)
        var columnCounts: [Int] = Array(repeating: 0, count: numberOfColumns)
        
        // Ordenar artículos por cantidad de códigos (descendente) para mejor distribución
        let articlesWithCounts = articles.map { article in
            (article: article, count: groupedEmpacados[article]?.count ?? 0)
        }.sorted { $0.count > $1.count }
        
        // Asignar cada artículo a la columna con menos códigos
        for articleData in articlesWithCounts {
            let minColumnIndex = columnCounts.enumerated().min { $0.element < $1.element }?.offset ?? 0
            columns[minColumnIndex].append(articleData.article)
            columnCounts[minColumnIndex] += articleData.count
        }
        
        return columns
    }
    
    
     @ViewBuilder
     private var inProcessCodesSection: some View {
         let codesInProcessOnPage = pageData.codigosEnProcesoDeLaPagina
         
         if !codesInProcessOnPage.isEmpty {
             VStack(alignment: .leading, spacing: 0) {
             Text("Cables en Proceso")
                 .font(.headline)
                 .padding(.top, pageData.isFirstPage && !pageData.codigosEmpacadosDeLaPagina.isEmpty ? 8 : 0)
                 .padding(.bottom, 3)
                 
                 VStack(spacing: 0) {
                     let groupedByOperation = Dictionary(grouping: codesInProcessOnPage) {
                         $0.currentOperacionLog?.operacion ?? .limpieza
                     }
                     
                     ForEach(operationOrder, id: \.self) { operacion in
                         if let codesForOperation = groupedByOperation[operacion], !codesForOperation.isEmpty {
                             operationSectionView(operacion: operacion, codes: codesForOperation)
                         }
                     }
                 }
                 .background(Color.gray.opacity(0.02))
             }
         }
     }
     
  private func operationSectionView(operacion: Operacion, codes: [CodigoBarras]) -> some View {
      VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 8) {
              Circle()
               //   .fill(getOperationColor(operacion))
                  .frame(width: 8, height: 8)
              Text(operacion.rawValue)
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(.primary)
              Spacer()
              Text("\(codes.count) cable\(codes.count == 1 ? "" : "s")")
                  .font(.system(size: 10, weight: .medium))
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
               //   .background(getOperationColor(operacion.rawValue).opacity(0.2))
                  .cornerRadius(6)
          }
          
          let groupedByArticle = Dictionary(grouping: codes) { $0.articulo?.nombre ?? "Sin Cable" }
          
          ForEach(groupedByArticle.keys.sorted(), id: \.self) { articleName in
              articleProcessView(articleName: articleName, codes: groupedByArticle[articleName]!)
          }
      }
      .padding(.horizontal, 25)
      .padding(.vertical, 10)
      .background(Color.white)
      .overlay(
          Rectangle()
              .fill(Color.gray.opacity(0.2))
              .frame(height: 1),
          alignment: .bottom
      )
  }
     
    private func articleProcessView(articleName: String, codes: [CodigoBarras]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            
            let count = codes.count
            let auditedCount = codes.filter { $0.auditado }.count

            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                
                Text(articleName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack {
                    subtotalBadge(label: "Total", value: "\(count)", color: .gray)
                    if auditedCount > 0 {
                        subtotalBadge(label: "Auditados", value: "\(auditedCount)", color: .blue)
                    }
                }
                .padding(.leading, 30)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2), spacing: 4) {
                ForEach(codes.sorted(by: { $0.codigo < $1.codigo })) { codigo in
                    codeRowView(codigo: codigo)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(8)
    }
    
    private func codeRowView(codigo: CodigoBarras) -> some View {
        HStack(spacing: 6) {
            Text("• \(codigo.codigo)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
            
            // --- LÓGICA MODIFICADA ---
            if codigo.auditado {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    
                    // Se obtienen las puntas reales y esperadas para este código específico.
                    let puntasReales = codigo.cantidadPuntas ?? 0
                    let puntasEsperadas = codigo.articulo?.cantidadPuntasEsperadas ?? 0
                    
                    // Se muestra la badge solo si hay puntas esperadas.
                    if puntasEsperadas > 0 {
                        Text("\(puntasReales)/\(puntasEsperadas)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            // Mejora: El color es verde si coinciden, naranja si no.
                            .background(puntasReales == puntasEsperadas ? Color.green : Color.orange)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func subtotalBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(size: 9, weight: .medium))
            Text(value)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
  /*  @ViewBuilder
    private var inProcessCodesSection: some View {
        let codesInProcessOnPage = pageData.codigosEnProcesoDeLaPagina
        
        if !codesInProcessOnPage.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Códigos en Proceso")
                    .font(.headline)
                    .padding(.top, pageData.isFirstPage && !pageData.codigosEmpacadosDeLaPagina.isEmpty ? 8 : 0)
                    .padding(.bottom, 3)
                
                let groupedByOperation = Dictionary(grouping: codesInProcessOnPage) {
                    $0.currentOperacionLog?.operacion ?? .limpieza
                }

                ForEach(operationOrder, id: \.self) { operacion in
                    if let codesForOperation = groupedByOperation[operacion], !codesForOperation.isEmpty {
                      HStack(alignment: .top, spacing: 4) {
                          Text(operacion.rawValue)
                          .font(.system(size: 12, design: .rounded)) // Fuente diferente: rounded
                          //.foregroundColor(.gray)
                          .padding(.horizontal, 4)
                          .padding(.vertical, 2)
                          .background(Color.gray.opacity(0.1))
                          .cornerRadius(4)
                          
                        }
                        
                        
                        let groupedByArticle = Dictionary(grouping: codesForOperation) { $0.articulo?.nombre ?? "Sin Artículo" }
                        
                        ForEach(groupedByArticle.keys.sorted(), id: \.self) { articleName in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(articleName)")
                                    .font(.system(size: 11, weight: .semibold))
                                
                                let codesForArticle = groupedByArticle[articleName]!
                                
                                ForEach(codesForArticle.sorted(by: { $0.codigo < $1.codigo })) { codigo in
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("  - \(codigo.codigo)")
                                            .font(.system(size: 10, design: .monospaced))
                                        
                                        if codigo.auditado {
                                            HStack(spacing: 4) {
                                                Text("(Auditado)")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.green)
                                                
                                                // Mostrar cantidad de puntas solo para códigos auditados
                                                if let puntas = codigo.cantidadPuntas, puntas > 0 {
                                                    Text("\(puntas) pts")
                                                        .font(.system(size: 10, design: .rounded)) // Fuente diferente: rounded
                                                        .foregroundColor(.blue)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.1))
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                let count = codesForArticle.count
                                let totalPuntasEsperadas = codesForArticle.reduce(0) { $0 + ($1.articulo?.cantidadPuntasEsperadas ?? 0) }
                                let totalPuntasReales = codesForArticle
                                    .filter { $0.auditado }
                                    .reduce(0) { $0 + ($1.cantidadPuntas ?? 0) }
                                let auditedCount = codesForArticle.filter { $0.auditado }.count
                                
                                // Subtotales mejorados con información de puntas
                                //VStack(alignment: .leading, spacing: 1) {
                                    HStack{
                                    Text("  Subtotal: \(count) cable\(count == 1 ? "" : "s") [\(auditedCount) auditado\(auditedCount == 1 ? "" : "s")]")
                                    .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    if auditedCount > 0 {
                                        Text(" | Auditadas: \(totalPuntasReales) / \(totalPuntasEsperadas)")
                                            .font(.system(size: 10, design: .rounded)) // Fuente diferente
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.top, 1)
                            }
                            .padding(.bottom, 3)
                        }
                        Divider()
                    }
                }
            }
        }
    }*/
    
    private var footerView: some View {
        HStack {
            Text("Reporte....")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            Spacer()
            Text("Página \(pageData.pageNumber) de \(pageData.totalPages)")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Componentes Auxiliares con fuentes más pequeñas
struct KPIBox: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack {
            Text(value)
                .font(.title3.weight(.bold)) // Reducir de largeTitle a title3
            Text(title)
                .font(.system(size: 10)) // Fuente más pequeña
        }
        .frame(maxWidth: .infinity)
        .padding(6) // Reducir padding
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

/*

//
//  PDFReportView.swift
//  Barras2
//
//  Created by Ulises Islas on 29/08/25.
//  Enhanced Professional Version


struct PDFReportView: View {
    let pageData: ReportPageData
    
    private var groupedEmpacados: [String: [CodigoBarras]] {
        Dictionary(grouping: pageData.codigosEmpacadosDeLaPagina) { $0.articulo?.nombre ?? "Sin Artículo" }
    }
    
    private let operationOrder: [Operacion] = [
        .ribonizado, .ensamble, .pulido, .limpGeo, .armado,
        .etiquetas, .polaridad, .prueba, .limpieza
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header principal con diseño profesional
            if pageData.isFirstPage {
                professionalHeaderView
                modernKPISection
                operationsChartSection
            } else {
                continuationHeaderView
                    .padding(.bottom, 15)
            }
            
            // Contenido principal con separadores elegantes
            if !pageData.codigosEmpacadosDeLaPagina.isEmpty {
                packagedCodesSection
            }
            
            if !pageData.codigosEnProcesoDeLaPagina.isEmpty {
                inProcessCodesSection
            }
            
            Spacer(minLength: 20)
            professionalFooterView
        }
        .padding(30)
        .frame(width: 595.2, height: 841.8, alignment: .topLeading)
        .background(Color.white)
        .foregroundColor(.black)
    }

    // MARK: - Header Profesional
    
    private var professionalHeaderView: some View {
        VStack(spacing: 0) {
            // Banda superior azul
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 4)
            
            // Contenido del header
            HStack(alignment: .top, spacing: 20) {
                // Logo con marco elegante
                if let imageData = pageData.logoImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.05))
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Información principal
                VStack(alignment: .leading, spacing: 6) {
                    Text("RESUMEN DE TURNO")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge")
                            .foregroundColor(.blue)
                        Text("Turno: \(pageData.turno)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Información de fecha y realizador
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Text(pageData.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    if !pageData.nombreRealizador.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("Realizó: \(pageData.nombreRealizador)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 25)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.gray.opacity(0.02))
            )
            
            // Línea separadora elegante
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
        }
    }
    
    private var continuationHeaderView: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continuación...")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(pageData.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 25)
            .background(Color.gray.opacity(0.02))
    }
    
    // MARK: - KPI Section Modernizada (con mayor reducción)
    private var modernKPISection: some View {
        // CAMBIO: Espaciado principal reducido de 15 a 12
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("MÉTRICAS DEL TURNO")
                    // CAMBIO: Tamaño de fuente del título reducido de 16 a 14
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 25)
            // CAMBIO: Padding superior reducido de 20 a 15
            .padding(.top, 10)
            
            // CAMBIO: Espaciado entre tarjetas reducido de 15 a 12
            HStack(spacing: 12) {
                ModernKPIBox(
                    title: "Total Códigos",
                    value: "\(pageData.totalCodigosDelDia)",
                    icon: "qrcode",
                    color: .blue,
                    gradient: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]
                )
                
                ModernKPIBox(
                    title: "Auditados",
                    value: "\(pageData.totalAuditadosDelDia)",
                    icon: "checkmark.seal.fill",
                    color: .green,
                    gradient: [Color.green.opacity(0.8), Color.green.opacity(0.6)]
                )
                
                ModernKPIBox(
                    title: "Empacados",
                    value: "\(pageData.totalEmpacadosDelDia)",
                    icon: "shippingbox.fill",
                    color: .purple,
                    gradient: [Color.purple.opacity(0.8), Color.purple.opacity(0.6)]
                )
            }
            .padding(.horizontal, 20)
        }
        // CAMBIO: Padding inferior reducido de 25 a 20
        .padding(.bottom, 20)
    }

    // MARK: - Componente KPI Modernizado (CON MAYOR REDUCCIÓN)

    struct ModernKPIBox: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        let gradient: [Color]
        
        var body: some View {
            // CAMBIO MÁS AGRESIVO: Reducido el espaciado principal de 5 a 4
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        // CAMBIO MÁS AGRESIVO: Reducido el tamaño del ícono de 15 a 13
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    VStack(spacing: 1) {
                        Text(value)
                            // CAMBIO MÁS AGRESIVO: Reducido el tamaño de la fuente del valor de 18 a 16
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(title)
                            // CAMBIO MÁS AGRESIVO: Reducido el tamaño de la fuente del título de 11 a 10
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // CAMBIO MÁS AGRESIVO: Reducido el espaciado entre valor y título de 2 a 1
                
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            // CAMBIO MÁS AGRESIVO: Reducido el padding vertical de 8 a 6
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // CAMBIO ESTÉTICO: Reducido el radio de las esquinas para un look más compacto
            .cornerRadius(10)
            .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    
    // MARK: - Gráfico de Operaciones Mejorado
    
    private var operationsChartSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.orange)
                Text("DISTRIBUCIÓN POR OPERACIÓN")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 25)
            
            Chart(pageData.operationsDataDelDia, id: \.operacion) { data in
                BarMark(
                    x: .value("Operación", data.operacion),
                    y: .value("Cantidad", data.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [getOperationColor(data.operacion).opacity(0.8), getOperationColor(data.operacion)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text("\(data.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .chartXAxis {
                AxisMarks(values: pageData.operationsDataDelDia.map { $0.operacion }) { value in
                    AxisValueLabel() {
                        if let op = value.as(String.self) {
                            Text(op)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisTick().foregroundStyle(.clear)
                    AxisValueLabel()
                        .font(.system(size: 9))
                      //  .foregroundColor(.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 120)
            .padding(.horizontal, 25)
        }
        .padding(.bottom, 15)
    }
    
    // MARK: - Sección de Códigos Empacados Mejorada
    
    @ViewBuilder
    private var packagedCodesSection: some View {
        if !pageData.codigosEmpacadosDeLaPagina.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header de sección
                sectionHeader(
                    title: "CÓDIGOS EMPACADOS",
                    subtitle: "Productos finalizados",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                // Contenido
                VStack(spacing: 0) {
                    createColumnsView()
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                    
                    // Total con diseño elegante
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "sum")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("Total Empacados:")
                                .font(.system(size: 12, weight: .medium))
                            Text("\(pageData.codigosEmpacadosDeLaPagina.count)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 10)
                }
                .background(Color.gray.opacity(0.02))
            }
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Sección de Códigos en Proceso Mejorada
    
    @ViewBuilder
    private var inProcessCodesSection: some View {
        let codesInProcessOnPage = pageData.codigosEnProcesoDeLaPagina
        
        if !codesInProcessOnPage.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(
                    title: "CÓDIGOS EN PROCESO",
                    subtitle: "Estado actual de producción",
                    icon: "gearshape.2.fill",
                    color: .orange
                )
                
                VStack(spacing: 0) {
                    let groupedByOperation = Dictionary(grouping: codesInProcessOnPage) {
                        $0.currentOperacionLog?.operacion ?? .limpieza
                    }
                    
                    ForEach(operationOrder, id: \.self) { operacion in
                        if let codesForOperation = groupedByOperation[operacion], !codesForOperation.isEmpty {
                            operationSectionView(operacion: operacion, codes: codesForOperation)
                        }
                    }
                }
                .background(Color.gray.opacity(0.02))
            }
        }
    }
    
 private func operationSectionView(operacion: Operacion, codes: [CodigoBarras]) -> some View {
     VStack(alignment: .leading, spacing: 12) {
         HStack(spacing: 8) {
             Circle()
              //   .fill(getOperationColor(operacion))
                 .frame(width: 8, height: 8)
             Text(operacion.rawValue)
                 .font(.system(size: 12, weight: .bold))
                 .foregroundColor(.primary)
             Spacer()
             Text("\(codes.count) código\(codes.count == 1 ? "" : "s")")
                 .font(.system(size: 10, weight: .medium))
                 .padding(.horizontal, 8)
                 .padding(.vertical, 4)
                 .background(getOperationColor(operacion.rawValue).opacity(0.2))
                 .cornerRadius(6)
         }
         
         let groupedByArticle = Dictionary(grouping: codes) { $0.articulo?.nombre ?? "Sin Artículo" }
         
         ForEach(groupedByArticle.keys.sorted(), id: \.self) { articleName in
             articleProcessView(articleName: articleName, codes: groupedByArticle[articleName]!)
         }
     }
     .padding(.horizontal, 25)
     .padding(.vertical, 10)
     .background(Color.white)
     .overlay(
         Rectangle()
             .fill(Color.gray.opacity(0.2))
             .frame(height: 1),
         alignment: .bottom
     )
 }
 
 
    // MARK: - Helpers para Secciones
    
    private func sectionHeader(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.1), color.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 2)
        }
    }
    
    
    
    private func articleProcessView(articleName: String, codes: [CodigoBarras]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text(articleName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2), spacing: 4) {
                ForEach(codes.sorted(by: { $0.codigo < $1.codigo })) { codigo in
                    codeRowView(codigo: codigo)
                }
            }
            
            // Subtotales mejorados
            let count = codes.count
            let auditedCount = codes.filter { $0.auditado }.count
            let totalPuntasEsperadas = codes.reduce(0) { $0 + ($1.articulo?.cantidadPuntasEsperadas ?? 0) }
            let totalPuntasReales = codes.filter { $0.auditado }.reduce(0) { $0 + ($1.cantidadPuntas ?? 0) }
            
            HStack {
                subtotalBadge(label: "Total", value: "\(count)", color: .gray)
                subtotalBadge(label: "Auditados", value: "\(auditedCount)", color: .green)
                if auditedCount > 0 {
                    subtotalBadge(label: "Puntas", value: "\(totalPuntasReales)/\(totalPuntasEsperadas)", color: .orange)
                }
                Spacer()
            }
        }
        .padding(.leading, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(8)
    }
    
    private func codeRowView(codigo: CodigoBarras) -> some View {
        HStack(spacing: 6) {
            Text("• \(codigo.codigo)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
            
            if codigo.auditado {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 8))
                    
                    if let puntas = codigo.cantidadPuntas, puntas > 0 {
                        Text("\(puntas)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func subtotalBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(size: 9, weight: .medium))
            Text(value)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Distribución de Columnas Mejorada
    
    @ViewBuilder
    private func createColumnsView() -> some View {
        let sortedArticles = groupedEmpacados.keys.sorted()
        let totalCodes = pageData.codigosEmpacadosDeLaPagina.count
        let codesPerColumn = 15
        let numberOfColumns = min(3, max(1, (totalCodes + codesPerColumn - 1) / codesPerColumn))
        
        let columnData = distributeArticlesByColumns(articles: sortedArticles, numberOfColumns: numberOfColumns)
        
        HStack(alignment: .top, spacing: 20) {
            ForEach(0..<numberOfColumns, id: \.self) { columnIndex in
                if columnIndex < columnData.count {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(columnData[columnIndex], id: \.self) { articleName in
                            modernArticleView(articleName: articleName)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.03))
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func modernArticleView(articleName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text(articleName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text("Subtotal: \((groupedEmpacados[articleName] ?? []).count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
            
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading)], spacing: 2) {
                ForEach(Array((groupedEmpacados[articleName] ?? []).sorted(by: { $0.codigo < $1.codigo }).enumerated()), id: \.element.id) { index, codigo in
                    HStack(spacing: 4) {
                        Text("\(index + 1).")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 15, alignment: .trailing)
                        Text(codigo.codigo)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 8)
            
          /*  HStack {
                Spacer()
                Text("Subtotal: \((groupedEmpacados[articleName] ?? []).count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                Spacer()
            }*/
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Footer Profesional
    
    private var professionalFooterView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 10))
                    Text("Reporte Generado Automáticamente")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge")
                        .foregroundColor(.blue)
                        .font(.system(size: 10))
                    Text("Página \(pageData.pageNumber) de \(pageData.totalPages)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Funciones Helper
    
    private func getOperationColor(_ operation: String) -> Color {
        switch operation {
        case "ribonizado": return .red
        case "ensamble": return .orange
        case "pulido": return .yellow
        case "limpGeo": return .green
        case "armado": return .blue
        case "etiquetas": return .indigo
        case "polaridad": return .purple
        case "prueba": return .pink
        case "limpieza": return .mint
        default: return .gray
        }
    }
    
    private func distributeArticlesByColumns(articles: [String], numberOfColumns: Int) -> [[String]] {
        var columns: [[String]] = Array(repeating: [], count: numberOfColumns)
        var columnCounts: [Int] = Array(repeating: 0, count: numberOfColumns)
        
        let articlesWithCounts = articles.map { article in
            (article: article, count: groupedEmpacados[article]?.count ?? 0)
        }.sorted { $0.count > $1.count }
        
        for articleData in articlesWithCounts {
            let minColumnIndex = columnCounts.enumerated().min { $0.element < $1.element }?.offset ?? 0
            columns[minColumnIndex].append(articleData.article)
            columnCounts[minColumnIndex] += articleData.count
        }
        
        return columns
    }
}
*/
