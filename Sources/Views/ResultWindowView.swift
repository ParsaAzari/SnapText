import SwiftUI
import AppKit

// Custom NSTextView with keyCode-based (layout-independent) keyboard shortcuts and responder chain support
class EditableDocumentTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard f.contains(.command), !f.contains(.option), !f.contains(.control) else {
            return super.performKeyEquivalent(with: event)
        }
        let shift = f.contains(.shift)
        switch event.keyCode {
        case 0 where !shift:  selectAll(nil); return true      // A
        case 8 where !shift:
            copy(nil)
            HUDNotificationManager.shared.show(message: "Copied\nSuccessfully", icon: "checkmark")
            return true      // C
        case 9 where !shift:  paste(nil); return true          // V
        case 7 where !shift:  cut(nil); return true            // X
        case 6:                                                // Z / Shift+Z
            if shift { undoManager?.redo() } else { undoManager?.undo() }
            return true
        default: return super.performKeyEquivalent(with: event)
        }
    }
}

// Native NSTextView wrapper with natural BiDi writing direction and smart substitutions disabled
struct NSTextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var isWhitePaper: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let contentSize = scrollView.contentSize
        
        let textView = EditableDocumentTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 18, height: 18)
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = font
        textView.string = text
        
        // BUG 4 settings: Right-aligned & RTL for Persian text, Natural for other languages
        let hasPersian = text.unicodeScalars.contains { scalar in
            (scalar.value >= 0x0600 && scalar.value <= 0x06FF) ||
            (scalar.value >= 0xFB50 && scalar.value <= 0xFDFF) ||
            (scalar.value >= 0xFE70 && scalar.value <= 0xFEFF)
        }
        if hasPersian {
            textView.baseWritingDirection = .rightToLeft
            textView.alignment = .right
        } else {
            textView.baseWritingDirection = .natural
            textView.alignment = .natural
        }
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Colors: Clean White Paper Canvas
        if isWhitePaper {
            textView.backgroundColor = .white
            textView.textColor = .black
            textView.insertionPointColor = .black
            scrollView.backgroundColor = .white
        } else {
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .textColor
            textView.insertionPointColor = .textColor
            scrollView.backgroundColor = .textBackgroundColor
        }
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            let hasPersian = text.unicodeScalars.contains { scalar in
                (scalar.value >= 0x0600 && scalar.value <= 0x06FF) ||
                (scalar.value >= 0xFB50 && scalar.value <= 0xFDFF) ||
                (scalar.value >= 0xFE70 && scalar.value <= 0xFEFF)
            }
            if hasPersian {
                textView.baseWritingDirection = .rightToLeft
                textView.alignment = .right
            } else {
                textView.baseWritingDirection = .natural
                textView.alignment = .natural
            }
        }
        textView.font = font
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NSTextViewWrapper
        
        init(_ parent: NSTextViewWrapper) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

public class ResultViewModel: ObservableObject {
    @Published public var text: String
    
    public init(text: String = "") {
        self.text = text
    }
}

public struct CapturedTextView: View {
    @ObservedObject var viewModel: ResultViewModel
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false
    @State private var isStrikethrough: Bool = false
    @State private var selectedFont: String = "Vazirmatn"
    @State private var selectedWeight: String = "Regular"
    @State private var fontSize: Double = 16
    @State private var copiedNotice: Bool = false
    
    public init(viewModel: ResultViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    public init(text: String) {
        self._viewModel = ObservedObject(wrappedValue: ResultViewModel(text: text))
    }
    
    let fontFamilies = ["Vazirmatn", "Geeza Pro", "Tahoma", "San Francisco", "Helvetica", "Arial", "Courier"]
    let fontWeights = ["Regular", "Bold", "Light", "Medium"]
    let fontSizes: [Double] = [12, 14, 16, 18, 20, 24, 28, 32]
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Toolbar
            HStack(spacing: 8) {
                // Formatting buttons (B I U S)
                HStack(spacing: 4) {
                    StyleButton(title: "B", isBold: true, isSelected: isBold) { isBold.toggle() }
                    StyleButton(title: "I", isItalic: true, isSelected: isItalic) { isItalic.toggle() }
                    StyleButton(title: "U", isUnderline: true, isSelected: isUnderline) { isUnderline.toggle() }
                    StyleButton(title: "S", isStrikethrough: true, isSelected: isStrikethrough) { isStrikethrough.toggle() }
                }
                
                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 4)
                    .opacity(0.3)
                
                // Font Family Dropdown
                Picker("", selection: $selectedFont) {
                    ForEach(fontFamilies, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .frame(width: 135)
                
                // Font Weight Dropdown
                Picker("", selection: $selectedWeight) {
                    ForEach(fontWeights, id: \.self) { weight in
                        Text(weight).tag(weight)
                    }
                }
                .frame(width: 105)
                
                // Font Size Dropdown
                Picker("", selection: $fontSize) {
                    ForEach(fontSizes, id: \.self) { size in
                        Text("\(Int(size))").tag(size)
                    }
                }
                .frame(width: 70)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider().opacity(0.3)
            
            // MARK: - Document Canvas
            NSTextViewWrapper(text: $viewModel.text, font: getNSFont(), isWhitePaper: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            
            Divider().opacity(0.3)
            
            // MARK: - Bottom Action Bar
            HStack(spacing: 18) {
                // Share
                Button(action: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Share text")
                
                // Copy with feedback
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedNotice ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 15))
                            .foregroundColor(copiedNotice ? .green : .secondary)
                        if copiedNotice {
                            Text("Copied!").font(.caption).foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
                
                // Remove line breaks
                Button(action: removeLineBreaks) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove line breaks / Merge into single line")
                
                Spacer()
                
                Text("\(viewModel.text.count) characters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 520, minHeight: 480)
    }
    
    private func getNSFont() -> NSFont {
        var traits: NSFontDescriptor.SymbolicTraits = []
        let isBoldFont = isBold || selectedWeight == "Bold"
        if isBoldFont { traits.insert(.bold) }
        if isItalic { traits.insert(.italic) }
        
        if selectedFont == "Vazirmatn" {
            let fontName = isBoldFont ? "Vazirmatn-Bold" : (selectedWeight == "Medium" ? "Vazirmatn-Medium" : (selectedWeight == "Light" ? "Vazirmatn-Light" : "Vazirmatn-Regular"))
            if let customFont = NSFont(name: fontName, size: CGFloat(fontSize)) {
                return customFont
            }
            if let customFont = NSFont(name: "Vazirmatn", size: CGFloat(fontSize)) {
                return customFont
            }
        }
        
        let baseName = (selectedFont == "San Francisco") ? ".AppleSystemUIFont" : selectedFont
        let descriptor = NSFontDescriptor(fontAttributes: [.family: baseName])
            .withSymbolicTraits(traits)
        
        return NSFont(descriptor: descriptor, size: CGFloat(fontSize)) ?? NSFont.systemFont(ofSize: CGFloat(fontSize))
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.text, forType: .string)
        HUDNotificationManager.shared.show(message: "Copied\nSuccessfully", icon: "checkmark")
        copiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedNotice = false
        }
    }
    
    private func removeLineBreaks() {
        viewModel.text = viewModel.text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
    
    private func shareText() {
        let picker = NSSharingServicePicker(items: [viewModel.text])
        if let currentWindow = NSApplication.shared.keyWindow {
            picker.show(relativeTo: .zero, of: currentWindow.contentView!, preferredEdge: .minY)
        }
    }
}

struct StyleButton: View {
    let title: String
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isBold ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color(red: 0.18, green: 0.52, blue: 0.98) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}

public class ResultWindowManager {
    public static let shared = ResultWindowManager()
    private var windowController: NSWindowController?
    private var window: NSWindow?
    public let viewModel = ResultViewModel()
    
    private init() {}
    
    public func show(text: String, image: NSImage? = nil) {
        DispatchQueue.main.async {
            // Inject newly captured text into the persistent view model
            self.viewModel.text = text
            
            if let existingWindow = self.window {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            let contentView = CapturedTextView(viewModel: self.viewModel)
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Captured Text"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            self.window = window
            self.windowController = NSWindowController(window: window)
        }
    }
}
