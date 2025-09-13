

import SwiftUI
import PDFKit

@MainActor
class PDFGenerator {
    static func render(codigos: [CodigoBarras], date: Date, settings: SettingsManager) -> Data? {
        let empacados = codigos.filter { $0.currentOperacionLog?.operacion == .empaque }.sorted { $0.codigo < $1.codigo }
        let auditados = codigos.filter { $0.auditado && $0.currentOperacionLog?.operacion != .empaque }.sorted { $0.codigo < $1.codigo }
        let enProceso = codigos.filter { !$0.auditado && $0.currentOperacionLog?.operacion != .empaque }
        
        let pagesData = ReportPaginator.paginate(empacados: empacados, auditados: auditados, otros: enProceso, date: date, settings: settings)

        
        let pdfDocument = PDFDocument()
        
        for pageData in pagesData {
            let view = PDFReportView(pageData: pageData)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3.0 // Alta resolución para mejor calidad
            
            if let image = renderer.uiImage {
                // Asegurar que la imagen tenga el tamaño exacto A4
                UIGraphicsBeginImageContextWithOptions(CGSize(width: 595.2, height: 841.8), false, 3.0)
                defer { UIGraphicsEndImageContext() }
                
                image.draw(in: CGRect(origin: .zero, size: CGSize(width: 595.2, height: 841.8)))
                
                if let sizedImage = UIGraphicsGetImageFromCurrentImageContext(),
                   let pdfPage = PDFPage(image: sizedImage) {
                    pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                }
            }
        }
        
        return pdfDocument.dataRepresentation()
    }
}
