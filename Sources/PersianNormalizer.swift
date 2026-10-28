import Foundation

public struct PersianNormalizer {
    
    // Standard Persian character mappings
    private static let safeReplacements: [(String, String)] = [
        ("ي", "ی"),
        ("ك", "ک"),
        ("ى", "ی")
    ]
    
    // Arabic-Indic digits to Persian digits
    private static let arabicIndicDigits: [(String, String)] = [
        ("\u{0660}", "\u{06F0}"),
        ("\u{0661}", "\u{06F1}"),
        ("\u{0662}", "\u{06F2}"),
        ("\u{0663}", "\u{06F3}"),
        ("\u{0664}", "\u{06F4}"),
        ("\u{0665}", "\u{06F5}"),
        ("\u{0666}", "\u{06F6}"),
        ("\u{0667}", "\u{06F7}"),
        ("\u{0668}", "\u{06F8}"),
        ("\u{0669}", "\u{06F9}")
    ]
    
    /// Process OCR text:
    /// Strips U+200E/U+200F, trims, skips empty lines, calls normalizePersian(line), joins with "\n".
    /// Note: Ordering is handled by BidiReconstructor from bounding box coordinates.
    public static func processTesseractPersianOutput(_ rawText: String) -> String {
        let lines = rawText.components(separatedBy: .newlines)
        var processedLines: [String] = []
        
        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "\u{200E}", with: "")
                                .replacingOccurrences(of: "\u{200F}", with: "")
                                .trimmingCharacters(in: .whitespaces)
            guard !cleanLine.isEmpty else { continue }
            
            processedLines.append(normalizePersian(cleanLine))
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    public static func normalizePersian(_ input: String) -> String {
        // Normalize redundant whitespace
        var text = cleanWhitespace(input)
        
        // Tokenize by space to ensure digit and char mappings are ONLY applied to RTL tokens
        let rawTokens = text.components(separatedBy: " ")
        var normalizedTokens: [String] = []
        
        for token in rawTokens {
            if isPureLatinOrNumber(token) {
                // Preserve Latin tokens and numbers unchanged
                normalizedTokens.append(token)
            } else {
                var tok = token
                // Decompose Arabic Presentation Forms
                tok = decomposePresentationForms(tok)
                
                // Unify Arabic-Indic digits and Persian letter variations
                for (src, dst) in safeReplacements {
                    tok = tok.replacingOccurrences(of: src, with: dst, options: .literal)
                }
                for (src, dst) in arabicIndicDigits {
                    tok = tok.replacingOccurrences(of: src, with: dst, options: .literal)
                }
                normalizedTokens.append(tok)
            }
        }
        
        text = normalizedTokens.joined(separator: " ")
        
        // Remove Tatweel / Kashida (U+0640)
        text = text.replacingOccurrences(of: "\u{0640}", with: "")
        
        // Punctuation normalization (, ; ? -> ، ؛ ؟)
        text = normalizePunctuation(text)
        
        // Contextual Half-Space (ZWNJ) for Persian affixes
        text = applySafeZWNJ(text)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func isPureLatinOrNumber(_ token: String) -> Bool {
        var hasLatin = false
        var hasRTL = false
        for scalar in token.unicodeScalars {
            if (scalar.value >= 0x0600 && scalar.value <= 0x06FF) ||
               (scalar.value >= 0xFB50 && scalar.value <= 0xFDFF) ||
               (scalar.value >= 0xFE70 && scalar.value <= 0xFEFF) {
                hasRTL = true
            } else if (scalar.value >= 0x0041 && scalar.value <= 0x005A) ||
                      (scalar.value >= 0x0061 && scalar.value <= 0x007A) {
                hasLatin = true
            }
        }
        return hasLatin && !hasRTL
    }
    
    private static func decomposePresentationForms(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if (scalar.value >= 0xFB50 && scalar.value <= 0xFDFF) ||
               (scalar.value >= 0xFE70 && scalar.value <= 0xFEFF) {
                result.append(String(scalar).decomposedStringWithCanonicalMapping)
            } else {
                result.append(String(scalar))
            }
        }
        return result
    }
    
    private static func normalizePunctuation(_ text: String) -> String {
        var res = text
        let rules: [(String, String)] = [
            ("([\\u0600-\\u06FF]),", "$1،"),
            ("([\\u0600-\\u06FF]);", "$1؛"),
            ("([\\u0600-\\u06FF])\\?", "$1؟")
        ]
        for rule in rules {
            if let regex = try? NSRegularExpression(pattern: rule.0, options: []) {
                res = regex.stringByReplacingMatches(in: res, options: [], range: NSRange(location: 0, length: res.utf16.count), withTemplate: rule.1)
            }
        }
        return res
    }
    
    private static func cleanWhitespace(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        for line in lines {
            let merged = line.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            cleanedLines.append(merged.trimmingCharacters(in: .whitespaces))
        }
        return cleanedLines.joined(separator: "\n")
    }
    
    private static func applySafeZWNJ(_ text: String) -> String {
        var res = text
        let zwnj = "\u{200C}"
        let rules: [(String, String)] = [
            ("(^|[\\s])می\\s+([\\u0600-\\u06FF])", "$1می\(zwnj)$2"),
            ("(^|[\\s])نمی\\s+([\\u0600-\\u06FF])", "$1نمی\(zwnj)$2"),
            ("([\\u0600-\\u06FF]{2,})\\s+ها([\\s\\.,:!؛؟«»\\)\\]]|$)", "$1\(zwnj)ها$2"),
            ("([\\u0600-\\u06FF]{2,})\\s+های([\\s\\.,:!؛؟«»\\)\\]]|$)", "$1\(zwnj)های$2"),
            ("([\\u0600-\\u06FF]{2,})\\s+تر([\\s\\.,:!؛؟«»\\)\\]]|$)", "$1\(zwnj)تر$2"),
            ("([\\u0600-\\u06FF]{2,})\\s+ترین([\\s\\.,:!؛؟«»\\)\\]]|$)", "$1\(zwnj)ترین$2")
        ]
        for rule in rules {
            if let regex = try? NSRegularExpression(pattern: rule.0, options: []) {
                res = regex.stringByReplacingMatches(in: res, options: [], range: NSRange(location: 0, length: res.utf16.count), withTemplate: rule.1)
            }
        }
        return res
    }
}
