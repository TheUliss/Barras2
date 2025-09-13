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
                
                Chart(pageData.operationsDataDelDia) { data in
                    // 1. Barra para el TOTAL de códigos (AZUL MARINO)
                    BarMark(
                        x: .value("Operación", data.operacion),
                        y: .value("Total", data.totalCount)
                    )
                    .foregroundStyle(Color.navyBlue) // Color azul marino personalizado
                    .annotation(position: .top) {
                        if data.totalCount > 0 {
                            Text("\(data.totalCount)")
                                .font(.system(size: 9, weight: .bold)) // Texto un poco más grande
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 2. Círculo (PointMark) para los AUDITADOS (NARANJA O DORADO para contraste)
                    if data.auditedCount > 0 {
                        PointMark(
                            x: .value("Operación", data.operacion),
                            y: .value("Auditados", data.auditedCount)
                        )
                        .foregroundStyle(Color.orangeYellow) // Color naranja/amarillo para contraste
                        .symbolSize(CGSize(width: 25, height: 25)) // Círculo más grande
                        .annotation(position: .overlay) {
                             Text("\(data.auditedCount)")
                                 .font(.system(size: 10, weight: .bold)) // Texto más grande dentro del círculo
                                 .foregroundColor(.white) // Sigue siendo blanco para contraste
                        }
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
                .chartLegend(position: .top, alignment: .trailing) {
                    HStack {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.navyBlue) // Color de la leyenda
                                .frame(width: 12, height: 12)
                            Text("Total")
                                .font(.system(size: 10))
                        }
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orangeYellow) // Color de la leyenda
                                .frame(width: 8, height: 8)
                            Text("Auditado")
                                .font(.system(size: 10))
                        }
                    }
                    .padding(.bottom, 4)
                }
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

extension Color {
    static let navyBlue = Color(red: 0.1, green: 0.2, blue: 0.45) // Un azul marino
    static let orangeYellow = Color(red: 1.0, green: 0.7, blue: 0.0) // Un naranja tirando a amarillo
}

