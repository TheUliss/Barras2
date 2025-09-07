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
        HStack(alignment: .top) {
            if let imageData = pageData.logoImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60) // Reducir tamaño logo
            }
            VStack(alignment: .leading) {
                Text("Resumen de Turno")
                    .font(.title2) // Reducir de largeTitle a title2
                    .fontWeight(.bold)
                Text("Turno: \(pageData.turno)")
                    .font(.headline) // Reducir de title2 a headline
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(pageData.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline) // Reducir tamaño
                if !pageData.nombreRealizador.isEmpty {
                    Text("Realizó: \(pageData.nombreRealizador)")
                        .font(.caption2) // Fuente más pequeña
                }
            }
        }
    }
    
    private var continuationHeaderView: some View {
        VStack(alignment: .leading) {
            Text("Resumen de Turno (Cont..)")
                .font(.title3) // Reducir tamaño
                .fontWeight(.bold)
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
                                .font(.system(size: 7)) // Tamaño pequeño para las etiquetas
                        }
                    }
                    AxisTick()
                }
            }
            .chartLegend(.hidden)
            .frame(height: 140) // Un poco más de altura para que no se encimen los textos
        }
    }

    
    @ViewBuilder
    private var packagedCodesSection: some View {
        if !pageData.codigosEmpacadosDeLaPagina.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Códigos Empacados (Finalizados)")
                    .font(.headline)
                    .padding(.bottom, 2)
                Divider()
                
                // Crear las columnas dinámicamente
                createColumnsView()
                
                Divider()
                HStack {
                    Spacer()
                    Text("Total Empacados: \(pageData.codigosEmpacadosDeLaPagina.count)")
                        .font(.system(size: 9, weight: .bold))
                }
            }
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
            Text(articleName)
                .font(.system(size: 10, weight: .bold))
                .padding(.top, 4)
            
            ForEach(Array((groupedEmpacados[articleName] ?? []).sorted(by: { $0.codigo < $1.codigo }).enumerated()), id: \.element.id) { index, codigo in
                Text("\(index + 1). \(codigo.codigo)")
                    .font(.system(size: 8, design: .monospaced))
            }
            
            Text("Subtotal: \((groupedEmpacados[articleName] ?? []).count)")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 1)
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
                        Text(operacion.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.bottom, 1)
                            
                        let groupedByArticle = Dictionary(grouping: codesForOperation) { $0.articulo?.nombre ?? "Sin Artículo" }
                        
                        ForEach(groupedByArticle.keys.sorted(), id: \.self) { articleName in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(articleName)")
                                    .font(.system(size: 9, weight: .semibold))
                                
                                let codesForArticle = groupedByArticle[articleName]!
                                
                                ForEach(codesForArticle.sorted(by: { $0.codigo < $1.codigo })) { codigo in
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("  - \(codigo.codigo)")
                                            .font(.system(size: 8, design: .monospaced))
                                        
                                        if codigo.auditado {
                                            HStack(spacing: 4) {
                                                Text("(Auditado)")
                                                    .font(.system(size: 7, weight: .bold))
                                                    .foregroundColor(.green)
                                                
                                                // Mostrar cantidad de puntas solo para códigos auditados
                                                if let puntas = codigo.cantidadPuntas, puntas > 0 {
                                                    Text("\(puntas) pts")
                                                        .font(.system(size: 7, design: .rounded)) // Fuente diferente: rounded
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
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("  Subtotal: \(count) código(s) [\(auditedCount) auditados]")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    if auditedCount > 0 {
                                        Text("  Auditadas: \(totalPuntasReales) / Totales: \(totalPuntasEsperadas)")
                                            .font(.system(size: 7, design: .rounded)) // Fuente diferente
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
