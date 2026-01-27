import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// SmartDocumentScanner
/// محرك معالجة الصور لتحويلها إلى هيئة مستندات ماسوحة ضوئياً (Scanned Documents).
/// يتميز بالسرعة والأداء العالي في الخلفية.
final class SmartDocumentScanner: @unchecked Sendable {
    
    static let shared = SmartDocumentScanner()
    
    // سياق عمل موحد لـ CoreImage لتحسين الأداء
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let maxDimension: CGFloat = 1240
    
    private init() {}
    
    /// معالجة الصورة في خيط منفصل لتحويلها لمستند
    func processImage(_ originalImage: UIImage) async -> Data? {
        return await Task.detached(priority: .userInitiated) {
            // استخدام autoreleasepool لضمان تفريغ الذاكرة فوراً بعد معالجة الصور الكبيرة
            return autoreleasepool {
                guard let fixedImage = self.fixOrientation(img: originalImage) else { return nil }
                
                let resizedImage = self.resizeImage(image: fixedImage, maxDimension: self.maxDimension)
                
                // تطبيق فلتر تحسين المستندات (Contrast + Grayscale)
                let documentImage = self.applyDocumentFilter(to: resizedImage) ?? resizedImage
                
                return documentImage.jpegData(compressionQuality: 0.75)
            }
        }.value
    }
    
    nonisolated private func resizeImage(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension { return image }
        
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    nonisolated private func applyDocumentFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // استخدام فلتر تحسين التباين لزيادة وضوح النص وتبييض الخلفية
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = 1.1 // زيادة التباين
        filter.saturation = 0.0 // تحويل لرمادي (Grayscale)
        filter.brightness = 0.05 // زيادة طفيفة في السطوع
        
        guard let outputImage = filter.outputImage,
              let cgImage = self.context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    nonisolated private func fixOrientation(img: UIImage) -> UIImage? {
        if img.imageOrientation == .up { return img }
        
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        img.draw(in: CGRect(origin: .zero, size: img.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}
