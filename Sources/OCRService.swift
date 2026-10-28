import Foundation
import Vision
import AppKit

public class OCRService {
    public static let shared = OCRService()
    
    public static let supportedLanguages: [(name: String, codes: [String])] = [
        ("Persian (پارسی)", ["fas", "eng"]),
        ("English", ["en-US"]),
        ("Chinese Simplified", ["zh-Hans", "en-US"]),
        ("Chinese Traditional", ["zh-Hant", "en-US"]),
        ("French", ["fr-FR", "en-US"]),
        ("German", ["de-DE", "en-US"]),
        ("Italian", ["it-IT", "en-US"]),
        ("Spanish", ["es-ES", "en-US"]),
        ("Portuguese", ["pt-BR", "en-US"]),
        ("Cantonese Simplified", ["yue-Hans", "en-US"]),
        ("Cantonese Traditional", ["yue-Hant", "en-US"]),
        ("Korean", ["ko-KR", "en-US"]),
        ("Japanese", ["ja-JP", "en-US"]),
        ("Russian", ["ru-RU", "en-US"]),
        ("Ukrainian", ["uk-UA", "en-US"]),
        ("Thai", ["th-TH", "en-US"]),
        ("Vietnamese", ["vi-VT", "en-US"])
    ]
    
    private init() {}
    
    public func recognizeText(from image: NSImage,
                              languageChoice: String,
                              qualityChoice: String,
                              completion: @escaping (Result<String, Error>) -> Void) {
        
        if languageChoice.contains("Persian") || languageChoice.contains("پارسی") || languageChoice.contains("فارسی") {
            performPersianOCR(from: image, completion: completion)
            return
        }
        
        performVisionOCR(from: image, languageChoice: languageChoice, qualityChoice: qualityChoice, completion: completion)
    }
    
    // MARK: - Persian High Accuracy OCR Engine (tessdata_best + TSV + BidiReconstructor + Word Recheck)
    private func performPersianOCR(from image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        let preparedImage = ImagePreProcessor.prepareForOCR(image: image)
        
        guard let tiffData = preparedImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            completion(.failure(NSError(domain: "SnapText", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"])))
            return
        }
        
        // Original CGImage for Step 3 word-level cropping
        let originalCGImage: CGImage? = {
            if let tiff = image.tiffRepresentation,
               let r = NSBitmapImageRep(data: tiff) {
                return r.cgImage
            }
            return rep.cgImage
        }()
        
        // Locate tessdata directory inside App Bundle or fallback to project resource
        var tessdataDir = "/Applications/SnapText.app/Contents/Resources/tessdata"
        if let bundleTessdata = Bundle.main.path(forResource: "tessdata", ofType: nil) {
            tessdataDir = bundleTessdata
        } else if let resourcePath = Bundle.main.resourcePath {
            let candidate = (resourcePath as NSString).appendingPathComponent("tessdata")
            if FileManager.default.fileExists(atPath: candidate) {
                tessdataDir = candidate
            }
        }
        
        // Find tesseract binary (Apple Silicon /opt/homebrew or Intel /usr/local)
        let tesseractPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/tesseract")
            ? "/opt/homebrew/bin/tesseract"
            : (FileManager.default.fileExists(atPath: "/usr/local/bin/tesseract") ? "/usr/local/bin/tesseract" : "/opt/homebrew/bin/tesseract")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // In-memory processing with thread-safe execution
            guard let tsv1 = self.runTesseractInMemory(imageData: pngData, tesseractPath: tesseractPath, tessdataDir: tessdataDir, extraArgs: ["-l", "fas+eng", "--oem", "1", "--psm", "6", "-c", "tessedit_create_tsv=1"]) else {
                completion(.failure(NSError(domain: "SnapText", code: -2, userInfo: [NSLocalizedDescriptionKey: "No Persian text detected"])))
                return
            }
            
            var wordBoxes = self.parseTSV(tsv1)
            guard !wordBoxes.isEmpty else {
                completion(.failure(NSError(domain: "SnapText", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text tokens detected"])))
                return
            }
            
            // Normalize scale before recognition for optimal LSTM character classification
            let heights = wordBoxes.map { Double($0.height) }.sorted()
            let medianH = heights[heights.count / 2]
            let targetH = 80.0
            let scaleFactor = max(0.5, min(3.0, targetH / max(10.0, medianH)))
            
            if abs(scaleFactor - 1.0) > 0.25, let cg = rep.cgImage {
                let w = Int(Double(cg.width) * scaleFactor)
                let h = Int(Double(cg.height) * scaleFactor)
                if let colorSpace = cg.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
                   let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
                    ctx.interpolationQuality = .high
                    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                    if let scaledCG = ctx.makeImage(),
                       let scaledPng = NSBitmapImageRep(cgImage: scaledCG).representation(using: .png, properties: [:]) {
                        if let tsv2 = self.runTesseractInMemory(imageData: scaledPng, tesseractPath: tesseractPath, tessdataDir: tessdataDir, extraArgs: ["-l", "fas+eng", "--oem", "1", "--psm", "6", "-c", "tessedit_create_tsv=1"]) {
                            let scaledBoxes = self.parseTSV(tsv2)
                            if !scaledBoxes.isEmpty {
                                wordBoxes = scaledBoxes.map { b in
                                    TSVWordBox(
                                        text: b.text,
                                        left: Int(Double(b.left) / scaleFactor),
                                        top: Int(Double(b.top) / scaleFactor),
                                        width: Int(Double(b.width) / scaleFactor),
                                        height: Int(Double(b.height) / scaleFactor),
                                        conf: b.conf
                                    )
                                }
                            }
                        }
                    }
                }
            }
            
            // Word-level confidence validation
            if let origCG = originalCGImage {
                wordBoxes = self.recheckWords(wordBoxes, originalCG: origCG, tesseractPath: tesseractPath, tessdataDir: tessdataDir)
            }
            
            // Regroup tokens into visual lines by vertical overlap
            let clusteredLines = BidiReconstructor.clusterLines(words: wordBoxes)
            
            // Rebuild logical reading order from geometric coordinates
            var reconstructedLines: [String] = []
            for lineWords in clusteredLines {
                let logicalLine = BidiReconstructor.reconstruct(words: lineWords)
                let normalizedLine = PersianNormalizer.normalizePersian(logicalLine)
                if !normalizedLine.isEmpty {
                    reconstructedLines.append(normalizedLine)
                }
            }
            
            let finalText = reconstructedLines.joined(separator: "\n")
            completion(.success(finalText))
        }
    }
    
    // MARK: - TSV Parser
    private func parseTSV(_ tsv: String) -> [TSVWordBox] {
        var boxes: [TSVWordBox] = []
        let rows = tsv.components(separatedBy: .newlines)
        
        for row in rows {
            let cols = row.components(separatedBy: "\t")
            guard cols.count >= 12 else { continue }
            guard cols[0] == "5" else { continue } // level 5 is word
            
            let text = cols[11].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            
            let left = Int(cols[6]) ?? 0
            let top = Int(cols[7]) ?? 0
            let width = Int(cols[8]) ?? 0
            let height = Int(cols[9]) ?? 0
            let conf = Float(cols[10]) ?? 0.0
            
            boxes.append(TSVWordBox(text: text, left: left, top: top, width: width, height: height, conf: conf))
        }
        return boxes
    }
    
    // MARK: - In-Memory Tesseract Execution (Zero Disk I/O, Deterministic)
    private func runTesseractInMemory(imageData: Data, tesseractPath: String, tessdataDir: String, extraArgs: [String]) -> String? {
        let task = Process()
        task.launchPath = tesseractPath
        
        var env = ProcessInfo.processInfo.environment
        env["OMP_THREAD_LIMIT"] = "1"
        task.environment = env
        
        var args = [
            "stdin",
            "stdout",
            "--tessdata-dir", tessdataDir
        ]
        args.append(contentsOf: extraArgs)
        task.arguments = args
        
        let inPipe = Pipe()
        let outPipe = Pipe()
        task.standardInput = inPipe
        task.standardOutput = outPipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            inPipe.fileHandleForWriting.write(imageData)
            inPipe.fileHandleForWriting.closeFile()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    // MARK: - Word-Level Re-recognition
    private func recheckWords(_ words: [TSVWordBox], originalCG: CGImage, tesseractPath: String, tessdataDir: String) -> [TSVWordBox] {
        var updated = words
        let imgW = originalCG.width
        let imgH = originalCG.height
        
        for i in 0..<updated.count {
            let b = updated[i]
            let isLatinOrMixed = BidiReconstructor.hasLatin(b.text) || (BidiReconstructor.hasDigit(b.text) && !BidiReconstructor.hasRTL(b.text))
            let needsRecheck = b.conf < 85.0 || isLatinOrMixed
            
            guard needsRecheck else { continue }
            
            // Crop box with 8px padding on the original image (ImagePreProcessor adds 20px padding)
            let pad = 8
            let origX = max(0, b.left - 20)
            let origY = max(0, b.top - 20)
            let x0 = max(0, origX - pad)
            let y0 = max(0, origY - pad)
            let w = min(imgW - x0, b.width + pad * 2)
            let h = min(imgH - y0, b.height + pad * 2)
            guard w > 4 && h > 4 else { continue }
            
            guard let crop = originalCG.cropping(to: CGRect(x: x0, y: y0, width: w, height: h)) else { continue }
            
            // Upscale so height is ~48px if smaller
            let upscaledCrop = upscaleCGImage(crop, targetHeight: 48)
            
            if isLatinOrMixed {
                // Try Vision (.accurate, en-US) on Latin crops
                var bestText = b.text
                var bestConf = b.conf
                
                if let vResult = recognizeWordVision(cgCrop: upscaledCrop) {
                    let hasNewLatin = BidiReconstructor.hasLatin(vResult.text) && !BidiReconstructor.hasLatin(bestText)
                    if vResult.conf >= bestConf || hasNewLatin {
                        bestText = vResult.text
                        bestConf = vResult.conf
                    }
                }
                
                // Also try Tesseract -l eng --psm 7
                if let tResult = recognizeWordTesseract(cgCrop: upscaledCrop, lang: "eng", tesseractPath: tesseractPath, tessdataDir: tessdataDir) {
                    let hasNewLatin = BidiReconstructor.hasLatin(tResult.text) && !BidiReconstructor.hasLatin(bestText)
                    if (tResult.conf > bestConf || hasNewLatin) && (BidiReconstructor.hasLatin(tResult.text) || BidiReconstructor.hasDigit(tResult.text)) {
                        bestText = tResult.text
                        bestConf = tResult.conf
                    }
                }
                
                updated[i].text = bestText
                updated[i].conf = bestConf
            } else if b.conf < 45.0 && BidiReconstructor.hasRTL(b.text) {
                // Try Tesseract -l fas --psm 7 for very low-confidence Persian tokens
                if let fResult = recognizeWordTesseract(cgCrop: upscaledCrop, lang: "fas", tesseractPath: tesseractPath, tessdataDir: tessdataDir) {
                    if fResult.conf > b.conf && BidiReconstructor.hasRTL(fResult.text) {
                        updated[i].text = fResult.text
                        updated[i].conf = fResult.conf
                    }
                }
            }
        }
        
        return updated
    }
    
    private func upscaleCGImage(_ cgImage: CGImage, targetHeight: Int) -> CGImage {
        let currentH = cgImage.height
        if currentH >= targetHeight { return cgImage }
        
        let scale = CGFloat(targetHeight) / CGFloat(currentH)
        let targetW = Int(CGFloat(cgImage.width) * scale)
        
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil,
                                  width: targetW,
                                  height: targetHeight,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return cgImage
        }
        
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetW, height: targetHeight))
        return ctx.makeImage() ?? cgImage
    }
    
    private func recognizeWordVision(cgCrop: CGImage) -> (text: String, conf: Float)? {
        let req = VNRecognizeTextRequest()
        req.recognitionLanguages = ["en-US"]
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cgImage: cgCrop, options: [:])
        do {
            try handler.perform([req])
            if let obs = req.results?.first, let cand = obs.topCandidates(1).first {
                let trimmed = cand.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return (trimmed, cand.confidence * 100.0)
                }
            }
        } catch {}
        return nil
    }
    
    private func recognizeWordTesseract(cgCrop: CGImage, lang: String, tesseractPath: String, tessdataDir: String) -> (text: String, conf: Float)? {
        let rep = NSBitmapImageRep(cgImage: cgCrop)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        if let out = runTesseractInMemory(imageData: png, tesseractPath: tesseractPath, tessdataDir: tessdataDir, extraArgs: ["-l", lang, "--psm", "7"])?.trimmingCharacters(in: .whitespacesAndNewlines), !out.isEmpty {
            return (out, 85.0)
        }
        return nil
    }
    
    // MARK: - Vision Engine for English & Multilingual
    private func performVisionOCR(from image: NSImage,
                                  languageChoice: String,
                                  qualityChoice: String,
                                  completion: @escaping (Result<String, Error>) -> Void) {
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            completion(.failure(NSError(domain: "SnapText", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
            return
        }
        
        let langCodes = OCRService.supportedLanguages.first(where: { $0.name == languageChoice })?.codes ?? ["en-US"]
        
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(NSError(domain: "SnapText", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text found"])))
                return
            }
            
            let sortedObs = observations.sorted { (obs1, obs2) -> Bool in
                let y1 = obs1.boundingBox.origin.y
                let y2 = obs2.boundingBox.origin.y
                if abs(y1 - y2) > 0.03 {
                    return y1 > y2
                }
                return obs1.boundingBox.origin.x < obs2.boundingBox.origin.x
            }
            
            var recognizedStrings: [String] = []
            for observation in sortedObs {
                if let candidate = observation.topCandidates(1).first {
                    recognizedStrings.append(candidate.string)
                }
            }
            
            let fullText = recognizedStrings.joined(separator: "\n")
            completion(.success(fullText))
        }
        
        request.recognitionLanguages = langCodes
        if #available(macOS 15.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        } else {
            request.revision = VNRecognizeTextRequestRevision2
        }
        request.recognitionLevel = (qualityChoice == "Best") ? .accurate : .fast
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
}
