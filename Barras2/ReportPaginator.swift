import Foundation
import SwiftUI

struct ReportPageData {
    // Info de la página
    let pageNumber: Int
    let totalPages: Int
    let date: Date
    let isFirstPage: Bool
    let logoImageData: Data?
    let nombreRealizador: String
    let turno: String

    // Datos específicos de ESTA página
    let codigosEmpacadosDeLaPagina: [CodigoBarras]
    let codigosEnProcesoDeLaPagina: [CodigoBarras]

    // Datos de RESUMEN para todo el día (se usan en la página 1)
    let totalCodigosDelDia: Int
    let totalAuditadosDelDia: Int
    let totalEmpacadosDelDia: Int
    let operationsDataDelDia: [(operacion: String, count: Int)]
}

struct ReportPaginator {
    static func paginate(empacados: [CodigoBarras], auditados: [CodigoBarras], otros: [CodigoBarras], date: Date, settings: SettingsManager) -> [ReportPageData] {
        
        let codesInProcess = (auditados + otros).sorted { $0.codigo < $1.codigo }
        
        // Capacidades más realistas basadas en espacio disponible
        let firstPageAvailableLines = 50  // Líneas disponibles en primera página
        let subsequentPageAvailableLines = 55  // Líneas disponibles en páginas siguientes
        
        var pages: [ReportPageData] = []
        var remainingPackaged = empacados
        var remainingProcess = codesInProcess
        
        var currentPage = 1
        
        // Calcular datos de resumen una sola vez
        let totalCodigosDelDia = empacados.count + codesInProcess.count
        let operationOrder: [Operacion] = [.ribonizado, .ensamble, .pulido, .limpGeo, .armado, .etiquetas, .polaridad, .prueba, .limpieza]
        let allInProcessForGraph = (auditados + otros).filter { $0.currentOperacionLog?.operacion != .empaque && $0.currentOperacionLog?.operacion != nil }
        let groupedByOperationForGraph = Dictionary(grouping: allInProcessForGraph, by: { $0.currentOperacionLog!.operacion })
        let operationsData = operationOrder.map { (operacion: $0.rawValue, count: groupedByOperationForGraph[$0]?.count ?? 0) }
        
        while !remainingPackaged.isEmpty || !remainingProcess.isEmpty {
            var pagePackaged: [CodigoBarras] = []
            var pageProcess: [CodigoBarras] = []
            
            let availableLines = currentPage == 1 ? firstPageAvailableLines : subsequentPageAvailableLines
            var usedLines = 0
            
            // Espacio para sección de empacados (si es primera página, reservar espacio para header)
            let headerLines = currentPage == 1 ? 15 : 5
            
            // Primero agregar códigos empacados
            if !remainingPackaged.isEmpty {
                let packagedGrouped = Dictionary(grouping: remainingPackaged) { $0.articulo?.nombre ?? "Sin Artículo" }
                var packagedLinesUsed = 0
                
                for articleName in packagedGrouped.keys.sorted() {
                    let codes = packagedGrouped[articleName]!
                    let linesForArticle = 2 + codes.count  // 1 línea para título + 1 para subtotal + 1 por código
                    
                    if usedLines + linesForArticle + headerLines <= availableLines {
                        pagePackaged.append(contentsOf: codes)
                        packagedLinesUsed += linesForArticle
                        usedLines += linesForArticle
                    } else {
                        break
                    }
                }
                
                // Remover los códigos que se agregaron a esta página
                remainingPackaged.removeAll { code in
                    pagePackaged.contains(where: { $0.id == code.id })
                }
            }
            
            // Luego agregar códigos en proceso si todavía hay espacio
            if !remainingProcess.isEmpty && usedLines + headerLines < availableLines {
                let processGroupedByOperation = Dictionary(grouping: remainingProcess) {
                    $0.currentOperacionLog?.operacion ?? .limpieza
                }
                
                var processLinesUsed = 0
                
                for operacion in operationOrder {
                    guard let codesForOperation = processGroupedByOperation[operacion], !codesForOperation.isEmpty else {
                        continue
                    }
                    
                    let operationGroupedByArticle = Dictionary(grouping: codesForOperation) {
                        $0.articulo?.nombre ?? "Sin Artículo"
                    }
                    
                    let linesForOperationHeader = 2  // Título de operación + línea divisoria
                    
                    if usedLines + linesForOperationHeader + headerLines > availableLines {
                        break
                    }
                    
                    usedLines += linesForOperationHeader
                    processLinesUsed += linesForOperationHeader
                    
                    for articleName in operationGroupedByArticle.keys.sorted() {
                        let codesForArticle = operationGroupedByArticle[articleName]!
                        let linesForArticle = 3 + codesForArticle.count  // 2 líneas para artículo + 1 para subtotal + 1 por código
                        
                        if usedLines + linesForArticle <= availableLines {
                            pageProcess.append(contentsOf: codesForArticle)
                            usedLines += linesForArticle
                            processLinesUsed += linesForArticle
                        } else {
                            break
                        }
                    }
                }
                
                // Remover los códigos que se agregaron a esta página
                remainingProcess.removeAll { code in
                    pageProcess.contains(where: { $0.id == code.id })
                }
            }
            
            // Crear la página solo si tiene contenido
            if !pagePackaged.isEmpty || !pageProcess.isEmpty {
                let pageData = ReportPageData(
                    pageNumber: currentPage,
                    totalPages: 0, // Se actualizará al final
                    date: date,
                    isFirstPage: currentPage == 1,
                    logoImageData: settings.logoImageData,
                    nombreRealizador: settings.nombreRealizador,
                    turno: settings.turnoSeleccionado,
                    codigosEmpacadosDeLaPagina: pagePackaged,
                    codigosEnProcesoDeLaPagina: pageProcess,
                    totalCodigosDelDia: totalCodigosDelDia,
                    totalAuditadosDelDia: auditados.count,
                    totalEmpacadosDelDia: empacados.count,
                    operationsDataDelDia: operationsData
                )
                pages.append(pageData)
                currentPage += 1
            }
        }
        
        // Actualizar el total de páginas
        let totalPages = pages.count
        for i in 0..<pages.count {
            pages[i] = ReportPageData(
                pageNumber: pages[i].pageNumber,
                totalPages: totalPages,
                date: pages[i].date,
                isFirstPage: pages[i].isFirstPage,
                logoImageData: pages[i].logoImageData,
                nombreRealizador: pages[i].nombreRealizador,
                turno: pages[i].turno,
                codigosEmpacadosDeLaPagina: pages[i].codigosEmpacadosDeLaPagina,
                codigosEnProcesoDeLaPagina: pages[i].codigosEnProcesoDeLaPagina,
                totalCodigosDelDia: pages[i].totalCodigosDelDia,
                totalAuditadosDelDia: pages[i].totalAuditadosDelDia,
                totalEmpacadosDelDia: pages[i].totalEmpacadosDelDia,
                operationsDataDelDia: pages[i].operationsDataDelDia
            )
        }
        
        // Si no hay páginas, crear una vacía
        if pages.isEmpty {
            pages.append(ReportPageData(
                pageNumber: 1,
                totalPages: 1,
                date: date,
                isFirstPage: true,
                logoImageData: settings.logoImageData,
                nombreRealizador: settings.nombreRealizador,
                turno: settings.turnoSeleccionado,
                codigosEmpacadosDeLaPagina: [],
                codigosEnProcesoDeLaPagina: [],
                totalCodigosDelDia: totalCodigosDelDia,
                totalAuditadosDelDia: auditados.count,
                totalEmpacadosDelDia: empacados.count,
                operationsDataDelDia: operationsData
            ))
        }
        
        return pages
    }
}
