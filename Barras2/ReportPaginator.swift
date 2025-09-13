

import Foundation
import SwiftUI

// NUEVA ESTRUCTURA DE DATOS para el gráfico.
struct AggregatedOperationData: Identifiable {
    let id = UUID()
    let operacion: String
    let totalCount: Int
    let auditedCount: Int
}

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
    // Se usa la nueva estructura de datos.
    let operationsDataDelDia: [AggregatedOperationData]
}

struct ReportPaginator {
    // Ajusta el valor según sea necesario para evitar el desperdicio de espacio.
    static let firstPageAvailableLines = 65
    
    static func paginate(empacados: [CodigoBarras], auditados: [CodigoBarras], otros: [CodigoBarras], date: Date, settings: SettingsManager) -> [ReportPageData] {
        
        let codesInProcess = (auditados + otros).sorted { $0.codigo < $1.codigo }
        
        let subsequentPageAvailableLines = 50
        
        var pages: [ReportPageData] = []
        var remainingPackaged = empacados
        var remainingProcess = codesInProcess
        
        var currentPage = 1
        
        // --- INICIO DE LA LÓGICA MODIFICADA PARA EL GRÁFICO ---
        let totalCodigosDelDia = empacados.count + codesInProcess.count
        let operationOrder: [Operacion] = [.ribonizado, .ensamble, .pulido, .limpGeo, .armado, .etiquetas, .polaridad, .prueba, .limpieza]
        let allInProcessForGraph = auditados + otros
        
        var operationsData: [AggregatedOperationData] = []
        
        let groupedByOperation = Dictionary(grouping: allInProcessForGraph) { $0.currentOperacionLog?.operacion ?? .limpieza }

        for operacion in operationOrder {
            if let codes = groupedByOperation[operacion], !codes.isEmpty {
                let total = codes.count
                let auditadosEnOperacion = codes.filter { $0.auditado }.count
                
                operationsData.append(AggregatedOperationData(operacion: operacion.rawValue, totalCount: total, auditedCount: auditadosEnOperacion))
            } else {
                // Opcional: Añadir operaciones sin códigos para que aparezcan en el eje X.
                operationsData.append(AggregatedOperationData(operacion: operacion.rawValue, totalCount: 0, auditedCount: 0))
            }
        }
        // --- FIN DE LA LÓGICA MODIFICADA ---
   
        while !remainingPackaged.isEmpty || !remainingProcess.isEmpty {
            // ... (El resto de la lógica de paginación que corregimos anteriormente no cambia) ...
            var pagePackaged: [CodigoBarras] = []
            var pageProcess: [CodigoBarras] = []
            
            let totalPageLines = currentPage == 1 ? firstPageAvailableLines : subsequentPageAvailableLines
            let headerLines = currentPage == 1 ? 15 : 5
            let contentBudget = totalPageLines - headerLines
            var usedContentLines = 0

            if !remainingPackaged.isEmpty {
                let packagedGrouped = Dictionary(grouping: remainingPackaged) { $0.articulo?.nombre ?? "Sin Artículo" }
                for articleName in packagedGrouped.keys.sorted() {
                    guard let codes = packagedGrouped[articleName] else { continue }
                    let linesForArticle = 2 + codes.count
                    if usedContentLines + linesForArticle <= contentBudget {
                        pagePackaged.append(contentsOf: codes)
                        usedContentLines += linesForArticle
                    } else {
                        break
                    }
                }
                remainingPackaged.removeAll { code in pagePackaged.contains { $0.id == code.id } }
            }
            
            if !remainingProcess.isEmpty && usedContentLines < contentBudget {
                let processGroupedByOperation = Dictionary(grouping: remainingProcess) { $0.currentOperacionLog?.operacion ?? .limpieza }
                for operacion in operationOrder {
                    guard let codesForOperation = processGroupedByOperation[operacion], !codesForOperation.isEmpty else { continue }
                    let operationGroupedByArticle = Dictionary(grouping: codesForOperation) { $0.articulo?.nombre ?? "Sin Artículo" }
                    let linesForOperationHeader = 2
                    if usedContentLines + linesForOperationHeader > contentBudget { break }
                    var addedCodesInThisOperation = false
                    for articleName in operationGroupedByArticle.keys.sorted() {
                        guard let codesForArticle = operationGroupedByArticle[articleName] else { continue }
                        let linesForArticle = 3 + codesForArticle.count
                        if usedContentLines + (addedCodesInThisOperation ? 0 : linesForOperationHeader) + linesForArticle <= contentBudget {
                            if !addedCodesInThisOperation {
                                usedContentLines += linesForOperationHeader
                                addedCodesInThisOperation = true
                            }
                            pageProcess.append(contentsOf: codesForArticle)
                            usedContentLines += linesForArticle
                        } else {
                            break
                        }
                    }
                }
                remainingProcess.removeAll { code in pageProcess.contains { $0.id == code.id } }
            }
            
            if !pagePackaged.isEmpty || !pageProcess.isEmpty {
                let pageData = ReportPageData(
                    pageNumber: currentPage, totalPages: 0, date: date, isFirstPage: currentPage == 1,
                    logoImageData: settings.logoImageData, nombreRealizador: settings.nombreRealizador, turno: settings.turnoSeleccionado,
                    codigosEmpacadosDeLaPagina: pagePackaged, codigosEnProcesoDeLaPagina: pageProcess,
                    totalCodigosDelDia: totalCodigosDelDia, totalAuditadosDelDia: auditados.count,
                    totalEmpacadosDelDia: empacados.count, operationsDataDelDia: operationsData
                )
                pages.append(pageData)
                currentPage += 1
            } else {
                break
            }
        }
        
        let totalPages = pages.count
        for i in 0..<pages.count {
            let oldPage = pages[i]
            pages[i] = ReportPageData(
                pageNumber: oldPage.pageNumber, totalPages: totalPages, date: oldPage.date, isFirstPage: oldPage.isFirstPage,
                logoImageData: oldPage.logoImageData, nombreRealizador: oldPage.nombreRealizador, turno: oldPage.turno,
                codigosEmpacadosDeLaPagina: oldPage.codigosEmpacadosDeLaPagina,
                codigosEnProcesoDeLaPagina: oldPage.codigosEnProcesoDeLaPagina,
                totalCodigosDelDia: oldPage.totalCodigosDelDia, totalAuditadosDelDia: oldPage.totalAuditadosDelDia,
                totalEmpacadosDelDia: oldPage.totalEmpacadosDelDia, operationsDataDelDia: oldPage.operationsDataDelDia
            )
        }
        
        if pages.isEmpty {
            pages.append(ReportPageData(
                pageNumber: 1, totalPages: 1, date: date, isFirstPage: true,
                logoImageData: settings.logoImageData, nombreRealizador: settings.nombreRealizador, turno: settings.turnoSeleccionado,
                codigosEmpacadosDeLaPagina: [], codigosEnProcesoDeLaPagina: [],
                totalCodigosDelDia: totalCodigosDelDia, totalAuditadosDelDia: auditados.count,
                totalEmpacadosDelDia: empacados.count, operationsDataDelDia: operationsData
            ))
        }
        
        return pages
    }
}
