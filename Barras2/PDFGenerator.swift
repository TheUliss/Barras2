// PDFGenerator.swift
import SwiftUI
import PDFKit

@MainActor
class PDFGenerator {
    // Función que toma una vista de SwiftUI y la convierte en datos PDF
    static func render<V: View>(view: V) -> Data? {
        // 1. Define el tamaño de la página (A4)
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        
        // 2. Crea un ImageRenderer que renderizará nuestra vista de SwiftUI
        let renderer = ImageRenderer(content: view)
        
        let data = NSMutableData()
        
        // 3. Inicia el contexto del PDF
        guard let consumer = CGDataConsumer(data: data),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }
        
        // 4. Renderiza la vista página por página si es necesario (para contenido largo)
        renderer.render { size, context in
            var mediaBox = pageRect
            
            // Inicia la página PDF
            pdfContext.beginPDFPage(mediaBox: &mediaBox)
            
            // Dibuja la vista de SwiftUI en el contexto del PDF
            context(pdfContext)
            
            // Cierra la página
            pdfContext.endPDFPage()
        }
        
        // 5. Cierra el documento PDF
        pdfContext.closePDF()
        
        return data as Data
    }
}