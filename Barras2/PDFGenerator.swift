// PDFGenerator.swift
/*import SwiftUI
import PDFKit

struct PDFPageView: UIViewRepresentable {
    let pageData: ReportPageData
    
    func makeUIView(context: Context) -> UIView {
        let hostingController = UIHostingController(rootView: PDFReportView(pageData: pageData))
        return hostingController.view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}


@MainActor
class PDFGenerator {
    static func render(codigos: [CodigoBarras], date: Date, settings: SettingsManager) -> Data? {
        // 1. Separar los códigos por estado
        let empacados = codigos.filter { $0.currentOperacionLog?.operacion == .empaque }.sorted { $0.codigo < $1.codigo }
        let auditados = codigos.filter { $0.auditado && $0.currentOperacionLog?.operacion != .empaque }.sorted { $0.codigo < $1.codigo }
        let enProceso = codigos.filter { !$0.auditado && $0.currentOperacionLog?.operacion != .empaque }
        
        // 2. Paginar los datos ya separados
        let pagesData = ReportPaginator.paginate(empacados: empacados, auditados: auditados, otros: enProceso, date: date, settings: settings)
        
        // 3. Configurar el tamaño de página A4 con márgenes
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 en puntos (72 dpi)
        let margin: CGFloat = 30 // Márgenes de 30 puntos (aprox. 1 cm)
        let contentRect = pageRect.insetBy(dx: margin, dy: margin)
        
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
                      let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {  //Errror: Cannot pass immutable value as inout argument: 'pageRect' is a 'let' constant
                    return nil
                }
        
        for pageData in pagesData {
                    let pdfPageView = PDFPageView(pageData: pageData)
                    let controller = UIHostingController(rootView: pdfPageView)
                    let view = controller.view
                    
                    view?.bounds = CGRect(origin: .zero, size: pageRect.size)
                    view?.backgroundColor = .white
                    
                    pdfContext.beginPDFPage(nil) //Errror: 'nil' requires a contextual type
                    
                    // Renderizar la vista en el contexto PDF
                    if let view = view {
                        view.drawHierarchy(in: pageRect, afterScreenUpdates: true)
                    }
                    
                    pdfContext.endPDFPage()
                }
                
                pdfContext.closePDF()
                return data as Data
    }
}*/
/*
// PDFGenerator.swift
import SwiftUI
import PDFKit

@MainActor
class PDFGenerator {
    static func render(codigos: [CodigoBarras], date: Date, settings: SettingsManager) -> Data? {
        // 1. Separar los códigos por estado
        let empacados = codigos.filter { $0.currentOperacionLog?.operacion == .empaque }.sorted { $0.codigo < $1.codigo }
        let auditados = codigos.filter { $0.auditado && $0.currentOperacionLog?.operacion != .empaque }.sorted { $0.codigo < $1.codigo }
        let enProceso = codigos.filter { !$0.auditado && $0.currentOperacionLog?.operacion != .empaque }
        
        // 2. Paginar los datos ya separados
        let pagesData = ReportPaginator.paginate(empacados: empacados, auditados: auditados, otros: enProceso, date: date, settings: settings)
        
        // 3. Crear PDF document
        let pdfDocument = PDFDocument()
        
        for pageData in pagesData {
            // Crear la vista SwiftUI
            let view = PDFReportView(pageData: pageData)
            
            // Usar ImageRenderer de SwiftUI
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0 // Alta resolución
            
            if let image = renderer.uiImage {
                // Asegurar tamaño A4 exacto
                UIGraphicsBeginImageContextWithOptions(CGSize(width: 595.2, height: 841.8), false, 2.0)
                image.draw(in: CGRect(origin: .zero, size: CGSize(width: 595.2, height: 841.8)))
                let sizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let sizedImage = sizedImage, let pdfPage = PDFPage(image: sizedImage) {
                    pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                }
            }
        }
        
        return pdfDocument.dataRepresentation()
    }
}*/

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
