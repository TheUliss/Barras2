//
//  ReportPageData.swift
//  Barras2
//
//  Created by Ulises Islas on 05/09/25.
//


// ReportPaginator.swift
import Foundation

// Estructura para contener los datos de una sola página
struct ReportPageData {
    let pageNumber: Int
    let totalPages: Int
    let date: Date
    let codigos: [CodigoBarras]
    let isFirstPage: Bool // Para saber si mostrar el encabezado completo
}

struct ReportPaginator {
    static func paginate(codigos: [CodigoBarras], date: Date) -> [ReportPageData] {
        // --- Estimaciones de Altura (ajusta estos valores según tus pruebas) ---
        let topSectionHeight: Int = 450 // Altura estimada para encabezado, KPIs, gráficos, etc.
        let codeRowHeight: Int = 15      // Altura estimada por cada fila de código
        let pageHeight: Int = 780        // Altura útil de la página (A4 menos márgenes)
        // ---------------------------------------------------------------------

        // Ordenamos los códigos para que el llenado sea consistente
        let sortedCodigos = codigos.sorted { $0.codigo < $1.codigo }
        
        guard !sortedCodigos.isEmpty else {
            // Si no hay códigos, crea una sola página vacía
            return [ReportPageData(pageNumber: 1, totalPages: 1, date: date, codigos: [], isFirstPage: true)]
        }

        var pages: [[CodigoBarras]] = []
        var currentPageCodigos: [CodigoBarras] = []
        
        // Calcular cuántos códigos caben en la primera página
        let firstPageCapacity = (pageHeight - topSectionHeight) / codeRowHeight
        
        // Calcular cuántos códigos caben en las páginas siguientes (sin el encabezado grande)
        let subsequentPageCapacity = pageHeight / codeRowHeight
        
        var currentIndex = 0
        
        // Llenar la primera página
        let firstPageCount = min(sortedCodigos.count, firstPageCapacity)
        currentPageCodigos.append(contentsOf: sortedCodigos.prefix(firstPageCount))
        pages.append(currentPageCodigos)
        currentIndex += firstPageCount
        
        // Llenar las páginas siguientes si es necesario
        while currentIndex < sortedCodigos.count {
            currentPageCodigos = []
            let remainingCount = sortedCodigos.count - currentIndex
            let pageCount = min(remainingCount, subsequentPageCapacity)
            
            let pageEndIndex = currentIndex + pageCount
            currentPageCodigos.append(contentsOf: sortedCodigos[currentIndex..<pageEndIndex])
            pages.append(currentPageCodigos)
            currentIndex += pageCount
        }
        
        // Mapear los arreglos de códigos a nuestra estructura ReportPageData
        return pages.enumerated().map { (index, pageCodigos) in
            ReportPageData(
                pageNumber: index + 1,
                totalPages: pages.count,
                date: date,
                codigos: pageCodigos,
                isFirstPage: index == 0
            )
        }
    }
}