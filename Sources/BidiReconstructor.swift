import Foundation

public struct TSVWordBox {
    public var text: String
    public var left: Int
    public var top: Int
    public var width: Int
    public var height: Int
    public var conf: Float
    
    public var right: Int { left + width }
    public var bottom: Int { top + height }
    public var centerY: Double { Double(top) + Double(height) / 2.0 }
    
    public init(text: String, left: Int, top: Int, width: Int, height: Int, conf: Float) {
        self.text = text
        self.left = left
        self.top = top
        self.width = width
        self.height = height
        self.conf = conf
    }
}

public struct BidiReconstructor {
    /// Flag determined by acceptance tests in Step 5: whether bracket characters from Tesseract
    /// were recognized as visual glyph shapes on an RTL line and need mirroring.
    public static var MIRROR_BRACKETS_FROM_GLYPH: Bool = true
    
    public enum ScriptDirection {
        case R   // Persian / Arabic
        case L   // Latin
        case EN  // Digits
        case N   // Neutrals (punctuation, spaces, brackets, symbols)
    }
    
    public struct PseudoToken {
        public var text: String
        public var dir: ScriptDirection
        public var isBracket: Bool
        public var attachLeadingToNext: Bool
        public var attachTrailingToPrev: Bool
        public var level: Int = 0
    }
    
    private static let bracketsPair: [Character: Character] = [
        "(": ")", ")": "(",
        "[": "]", "]": "[",
        "{": "}", "}": "{",
        "«": "»", "»": "«",
        "⟨": "⟩", "⟩": "⟨",
        "<": ">", ">": "<"
    ]
    
    private static let openBrackets: Set<Character> = ["(", "[", "{", "«", "⟨", "<"]
    private static let closeBracketsOrPunct: Set<Character> = [
        ")", "]", "}", "»", "⟩", ">",
        ".", ":", "،", ",", ";", "؛", "!", "?", "؟"
    ]
    
    // MARK: - Visual Line Clustering
    public static func clusterLines(words: [TSVWordBox]) -> [[TSVWordBox]] {
        guard !words.isEmpty else { return [] }
        
        let heights = words.map { $0.height }.sorted()
        let medianHeight = heights.isEmpty ? 30.0 : Double(heights[heights.count / 2])
        let threshold = max(10.0, 0.5 * medianHeight)
        
        // Sort words vertically
        let sortedWords = words.sorted { $0.centerY < $1.centerY }
        
        var lines: [[TSVWordBox]] = []
        var lineCenters: [Double] = []
        
        for w in sortedWords {
            var bestIdx = -1
            var bestDist = Double.greatestFiniteMagnitude
            
            for (idx, center) in lineCenters.enumerated() {
                let dist = abs(w.centerY - center)
                if dist <= threshold && dist < bestDist {
                    bestDist = dist
                    bestIdx = idx
                }
            }
            
            if bestIdx != -1 {
                lines[bestIdx].append(w)
                let sumY = lines[bestIdx].reduce(0.0) { $0 + $1.centerY }
                lineCenters[bestIdx] = sumY / Double(lines[bestIdx].count)
            } else {
                lines.append([w])
                lineCenters.append(w.centerY)
            }
        }
        
        // Sort lines from top to bottom
        let sortedIndices = lineCenters.indices.sorted { lineCenters[$0] < lineCenters[$1] }
        return sortedIndices.map { lines[$0] }
    }
    
    // MARK: - Logical Order Reconstruction
    public static func reconstruct(words: [TSVWordBox], overrideBaseDirection: ScriptDirection? = nil) -> String {
        guard !words.isEmpty else { return "" }
        
        // 1. Sort words by left ascending (visual left-to-right)
        let sortedWords = words.sorted { $0.left < $1.left }
        
        // 2. Split each word into core + edge neutrals as separate pseudo-tokens
        var visualTokens: [PseudoToken] = []
        for w in sortedWords {
            let split = splitWord(w.text)
            visualTokens.append(contentsOf: split)
        }
        
        guard !visualTokens.isEmpty else { return "" }
        
        // 4. Base direction: RTL if Persian letters >= Latin letters in the line, else LTR
        var isBaseRTL: Bool
        if let overrideBase = overrideBaseDirection {
            isBaseRTL = (overrideBase == .R)
        } else {
            var persianLetters = 0
            var latinLetters = 0
            for t in visualTokens {
                for s in t.text.unicodeScalars {
                    if isRTLChar(s) { persianLetters += 1 }
                    else if isLatinChar(s) { latinLetters += 1 }
                }
            }
            if persianLetters >= latinLetters {
                isBaseRTL = true
            } else {
                // If Latin letters dominate due to long URLs/emails/filenames in Persian sentence:
                // Check if rightmost word is RTL and leftmost word has RTL characters
                let nonNeutrals = visualTokens.filter { $0.dir != .N }
                if let last = nonNeutrals.last, last.dir == .R,
                   let first = nonNeutrals.first, first.dir == .R {
                    isBaseRTL = true
                } else {
                    isBaseRTL = false
                }
            }
        }
        let baseDir: ScriptDirection = isBaseRTL ? .R : .L
        
        // 5. Assign embedding levels on visual sequence
        let count = visualTokens.count
        var resolvedDirs = [ScriptDirection](repeating: .N, count: count)
        
        for i in 0..<count {
            if visualTokens[i].dir != .N {
                resolvedDirs[i] = visualTokens[i].dir
            } else {
                var leftDir = baseDir
                for j in stride(from: i - 1, through: 0, by: -1) {
                    if visualTokens[j].dir != .N {
                        leftDir = visualTokens[j].dir
                        break
                    }
                }
                var rightDir = baseDir
                for j in (i + 1)..<count {
                    if visualTokens[j].dir != .N {
                        rightDir = visualTokens[j].dir
                        break
                    }
                }
                
                let leftType = (leftDir == .EN) ? ScriptDirection.L : leftDir
                let rightType = (rightDir == .EN) ? ScriptDirection.L : rightDir
                if leftType == rightType {
                    resolvedDirs[i] = leftType
                } else {
                    resolvedDirs[i] = baseDir
                }
            }
        }
        
        for i in 0..<count {
            let d = resolvedDirs[i]
            if isBaseRTL {
                visualTokens[i].level = (d == .R) ? 1 : 2
            } else {
                visualTokens[i].level = (d == .R) ? 1 : 0
            }
        }
        
        // 6. Convert visual -> logical with L2 reversal procedure
        var maxLevel = 0
        var minOddLevel = Int.max
        for t in visualTokens {
            if t.level > maxLevel { maxLevel = t.level }
            if t.level % 2 != 0 && t.level < minOddLevel { minOddLevel = t.level }
        }
        
        if minOddLevel <= maxLevel {
            for l in stride(from: maxLevel, through: minOddLevel, by: -1) {
                var start = 0
                while start < count {
                    if visualTokens[start].level >= l {
                        var end = start
                        while end + 1 < count && visualTokens[end + 1].level >= l {
                            end += 1
                        }
                        visualTokens[start...end].reverse()
                        start = end + 1
                    } else {
                        start += 1
                    }
                }
            }
        }
        
        // 7. Mirroring: swap brackets if MIRROR_BRACKETS_FROM_GLYPH is true and resolved level is odd
        if MIRROR_BRACKETS_FROM_GLYPH {
            for i in 0..<visualTokens.count {
                if visualTokens[i].isBracket && (visualTokens[i].level % 2 != 0) {
                    var mirrored = ""
                    for ch in visualTokens[i].text {
                        mirrored.append(bracketsPair[ch] ?? ch)
                    }
                    visualTokens[i].text = mirrored
                }
            }
        }
        
        // Update attachment flags based on final logical bracket / punctuation orientation
        for i in 0..<visualTokens.count {
            if visualTokens[i].text.count == 1, let ch = visualTokens[i].text.first {
                if openBrackets.contains(ch) {
                    visualTokens[i].attachLeadingToNext = true
                    visualTokens[i].attachTrailingToPrev = false
                } else if closeBracketsOrPunct.contains(ch) {
                    visualTokens[i].attachLeadingToNext = false
                    visualTokens[i].attachTrailingToPrev = true
                }
            }
        }
        
        // 8. Join tokens with single space, except between bracket/punct and core word
        var result = ""
        for i in 0..<visualTokens.count {
            let t = visualTokens[i]
            if i > 0 {
                let prev = visualTokens[i - 1]
                let noSpace = prev.attachLeadingToNext || t.attachTrailingToPrev
                if !noSpace {
                    result.append(" ")
                }
            }
            result.append(t.text)
        }
        
        return result
    }
    
    private static func splitWord(_ raw: String) -> [PseudoToken] {
        let clean = raw.replacingOccurrences(of: "\u{200E}", with: "")
                       .replacingOccurrences(of: "\u{200F}", with: "")
                       .trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return [] }
        
        let scalars = Array(clean.unicodeScalars)
        var firstCore = -1
        var lastCore = -1
        
        for i in 0..<scalars.count {
            if !isNeutralChar(scalars[i]) {
                if firstCore == -1 { firstCore = i }
                lastCore = i
            }
        }
        
        // All neutrals
        if firstCore == -1 {
            let isBrack = scalars.allSatisfy { isBracketChar($0) }
            let isLeading = scalars.allSatisfy { openBrackets.contains(Character($0)) }
            let isTrailing = scalars.allSatisfy { closeBracketsOrPunct.contains(Character($0)) }
            return [PseudoToken(text: clean, dir: .N, isBracket: isBrack, attachLeadingToNext: isLeading, attachTrailingToPrev: isTrailing)]
        }
        
        let leadingStr = (firstCore > 0) ? String(String.UnicodeScalarView(scalars[0..<firstCore])) : ""
        let coreStr = String(String.UnicodeScalarView(scalars[firstCore...lastCore]))
        let trailingStr = (lastCore + 1 < scalars.count) ? String(String.UnicodeScalarView(scalars[(lastCore + 1)..<scalars.count])) : ""
        
        let coreDir: ScriptDirection = hasRTL(coreStr) ? .R : (hasLatin(coreStr) ? .L : (hasDigit(coreStr) ? .EN : .N))
        
        var tokens: [PseudoToken] = []
        
        if coreDir == .R {
            // RTL-core word: leading neutrals sit on visual right, trailing on visual left.
            // Visual left-to-right: trailing comes first, then core, then leading.
            if !trailingStr.isEmpty {
                let isBrack = trailingStr.unicodeScalars.allSatisfy { isBracketChar($0) }
                tokens.append(PseudoToken(text: trailingStr, dir: .N, isBracket: isBrack, attachLeadingToNext: false, attachTrailingToPrev: true))
            }
            tokens.append(PseudoToken(text: coreStr, dir: coreDir, isBracket: false, attachLeadingToNext: false, attachTrailingToPrev: false))
            if !leadingStr.isEmpty {
                let isBrack = leadingStr.unicodeScalars.allSatisfy { isBracketChar($0) }
                tokens.append(PseudoToken(text: leadingStr, dir: .N, isBracket: isBrack, attachLeadingToNext: true, attachTrailingToPrev: false))
            }
        } else {
            // LTR-core word: leading neutrals sit on visual left, trailing on visual right.
            if !leadingStr.isEmpty {
                let isBrack = leadingStr.unicodeScalars.allSatisfy { isBracketChar($0) }
                tokens.append(PseudoToken(text: leadingStr, dir: .N, isBracket: isBrack, attachLeadingToNext: true, attachTrailingToPrev: false))
            }
            tokens.append(PseudoToken(text: coreStr, dir: coreDir, isBracket: false, attachLeadingToNext: false, attachTrailingToPrev: false))
            if !trailingStr.isEmpty {
                let isBrack = trailingStr.unicodeScalars.allSatisfy { isBracketChar($0) }
                tokens.append(PseudoToken(text: trailingStr, dir: .N, isBracket: isBrack, attachLeadingToNext: false, attachTrailingToPrev: true))
            }
        }
        
        return tokens
    }
    
    public static func isRTLChar(_ scalar: UnicodeScalar) -> Bool {
        if isDigitChar(scalar) { return false }
        return (scalar.value >= 0x0600 && scalar.value <= 0x06FF) ||
               (scalar.value >= 0xFB50 && scalar.value <= 0xFDFF) ||
               (scalar.value >= 0xFE70 && scalar.value <= 0xFEFF)
    }
    public static func isLatinChar(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 0x0041 && scalar.value <= 0x005A) ||
        (scalar.value >= 0x0061 && scalar.value <= 0x007A)
    }
    public static func isDigitChar(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 0x0030 && scalar.value <= 0x0039) ||
        (scalar.value >= 0x0660 && scalar.value <= 0x0669) ||
        (scalar.value >= 0x06F0 && scalar.value <= 0x06F9)
    }
    public static func isNeutralChar(_ scalar: UnicodeScalar) -> Bool {
        !isRTLChar(scalar) && !isLatinChar(scalar) && !isDigitChar(scalar)
    }
    public static func isBracketChar(_ scalar: UnicodeScalar) -> Bool {
        let brackets: Set<Character> = ["(", ")", "[", "]", "{", "}", "«", "»", "⟨", "⟩", "<", ">"]
        return brackets.contains(Character(scalar))
    }
    public static func hasRTL(_ s: String) -> Bool {
        s.unicodeScalars.contains { isRTLChar($0) }
    }
    public static func hasLatin(_ s: String) -> Bool {
        s.unicodeScalars.contains { isLatinChar($0) }
    }
    public static func hasDigit(_ s: String) -> Bool {
        s.unicodeScalars.contains { isDigitChar($0) }
    }
}
