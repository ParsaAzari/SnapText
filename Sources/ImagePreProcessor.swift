import Foundation
import AppKit
import CoreImage

public class ImagePreProcessor {
    
    /// Professional pre-processing following Section 4.1 guidelines:
    /// - Checks resolution (avoid over-scaling Retina screenshots)
    /// - Handles dark mode inversion if dark background detected
    /// - Adds 20px quiet border padding (crucial for Tesseract page segmentation)
    /// - Preserves delicate Persian diacritic dots (Dot-Survival)
    public static func prepareForOCR(image: NSImage) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let cgImage = rep.cgImage else {
            return image
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // 1. Detect Dark Mode (Sample border pixels)
        let isDarkMode = detectDarkBackground(cgImage: cgImage)
        
        // 2. CIImage pipeline
        var ciImage = CIImage(cgImage: cgImage)
        
        // If dark mode, invert colors to black-text-on-white (Tesseract standard)
        if isDarkMode {
            if let invertFilter = CIFilter(name: "CIColorInvert") {
                invertFilter.setValue(ciImage, forKey: kCIInputImageKey)
                if let inverted = invertFilter.outputImage {
                    ciImage = inverted
                }
            }
        }
        
        // 3. Grayscale conversion with natural contrast to preserve delicate Persian dots (Dot-Survival)
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls?.setValue(0.0, forKey: kCIInputSaturationKey) // Grayscale
        colorControls?.setValue(1.0, forKey: kCIInputContrastKey)   // Natural contrast (prevents dot & ligature erosion)
        
        if let enhancedCI = colorControls?.outputImage {
            ciImage = enhancedCI
        }
        
        let context = CIContext(options: nil)
        guard let processedCG = context.createCGImage(ciImage, from: ciImage.extent) else {
            return image
        }
        
        // 4. Add 20px padding around the image (Rule 6 in Section 4.1)
        let pad: CGFloat = 20.0
        let paddedWidth = CGFloat(width) + (pad * 2)
        let paddedHeight = CGFloat(height) + (pad * 2)
        
        guard let colorSpace = cgImage.colorSpace,
              let bitmapContext = CGContext(
                data: nil,
                width: Int(paddedWidth),
                height: Int(paddedHeight),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            return image
        }
        
        // Fill pure white background
        bitmapContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        bitmapContext.fill(CGRect(x: 0, y: 0, width: paddedWidth, height: paddedHeight))
        
        // Draw processed text in center
        bitmapContext.draw(processedCG, in: CGRect(x: pad, y: pad, width: CGFloat(width), height: CGFloat(height)))
        
        if let finalCG = bitmapContext.makeImage() {
            return NSImage(cgImage: finalCG, size: NSSize(width: paddedWidth, height: paddedHeight))
        }
        
        return image
    }
    
    private static func detectDarkBackground(cgImage: CGImage) -> Bool {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        
        // Sample corners (top-left, top-right, bottom-left, bottom-right)
        var totalLuminance: Double = 0.0
        var samples = 0
        
        let samplePoints = [
            (2, 2), (width - 3, 2),
            (2, height - 3), (width - 3, height - 3),
            (width / 2, 2), (width / 2, height - 3)
        ]
        
        for (x, y) in samplePoints {
            if x >= 0 && x < width && y >= 0 && y < height {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Double(bytes[offset])
                let g = Double(bytes[offset + 1])
                let b = Double(bytes[offset + 2])
                let lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                totalLuminance += lum
                samples += 1
            }
        }
        
        let avgLum = samples > 0 ? (totalLuminance / Double(samples)) : 1.0
        return avgLum < 0.45 // Dark mode detected if average corner luminance is dark
    }
}
