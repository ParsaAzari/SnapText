import Foundation
import Carbon

public class AppPreferences: ObservableObject {
    public static let shared = AppPreferences()
    
    private let defaults = UserDefaults.standard
    
    // General
    @Published public var launchAtStartup: Bool {
        didSet { defaults.set(launchAtStartup, forKey: "launchAtStartup") }
    }
    
    @Published public var showSuccessNotification: Bool {
        didSet { defaults.set(showSuccessNotification, forKey: "showSuccessNotification") }
    }
    
    @Published public var playSound: Bool {
        didSet { defaults.set(playSound, forKey: "playSound") }
    }
    
    @Published public var soundName: String {
        didSet { defaults.set(soundName, forKey: "soundName") }
    }
    
    // Shortcut
    @Published public var shortcutKeyCode: UInt32 {
        didSet { defaults.set(shortcutKeyCode, forKey: "shortcutKeyCode") }
    }
    @Published public var shortcutModifiers: UInt32 {
        didSet { defaults.set(shortcutModifiers, forKey: "shortcutModifiers") }
    }
    @Published public var shortcutDisplay: String {
        didSet { defaults.set(shortcutDisplay, forKey: "shortcutDisplay") }
    }
    
    // Text / OCR
    @Published public var recognizeText: Bool {
        didSet { defaults.set(recognizeText, forKey: "recognizeText") }
    }
    
    @Published public var recognitionLanguage: String {
        didSet { defaults.set(recognitionLanguage, forKey: "recognitionLanguage") }
    }
    
    @Published public var recognitionQuality: String {
        didSet { defaults.set(recognitionQuality, forKey: "recognitionQuality") }
    }
    
    @Published public var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: "copyToClipboard") }
    }
    
    @Published public var showTextInWindow: Bool {
        didSet { defaults.set(showTextInWindow, forKey: "showTextInWindow") }
    }
    
    @Published public var saveTextToNotes: Bool {
        didSet { defaults.set(saveTextToNotes, forKey: "saveTextToNotes") }
    }
    
    @Published public var keepLineBreak: Bool {
        didSet { defaults.set(keepLineBreak, forKey: "keepLineBreak") }
    }
    
    @Published public var captureMode: String { // "text", "image"
        didSet { defaults.set(captureMode, forKey: "captureMode") }
    }
    
    // Image
    @Published public var captureImage: Bool {
        didSet { defaults.set(captureImage, forKey: "captureImage") }
    }
    
    @Published public var showImageInWindow: Bool {
        didSet { defaults.set(showImageInWindow, forKey: "showImageInWindow") }
    }
    
    @Published public var saveToFolder: Bool {
        didSet { defaults.set(saveToFolder, forKey: "saveToFolder") }
    }
    
    @Published public var saveFolderPath: String {
        didSet { defaults.set(saveFolderPath, forKey: "saveFolderPath") }
    }
    
    private init() {
        self.launchAtStartup = defaults.object(forKey: "launchAtStartup") as? Bool ?? false
        self.showSuccessNotification = defaults.object(forKey: "showSuccessNotification") as? Bool ?? false
        self.playSound = defaults.object(forKey: "playSound") as? Bool ?? false
        self.soundName = defaults.string(forKey: "soundName") ?? "Blow"
        
        self.shortcutKeyCode = defaults.object(forKey: "shortcutKeyCode") as? UInt32 ?? 14 // 14 = 'E'
        self.shortcutModifiers = defaults.object(forKey: "shortcutModifiers") as? UInt32 ?? UInt32(cmdKey)
        self.shortcutDisplay = defaults.string(forKey: "shortcutDisplay") ?? "⌘E"
        
        self.recognizeText = defaults.object(forKey: "recognizeText") as? Bool ?? true
        let savedLang = defaults.string(forKey: "recognitionLanguage") ?? "Persian (پارسی)"
        self.recognitionLanguage = (savedLang == "Persian (فارسی)") ? "Persian (پارسی)" : savedLang
        self.recognitionQuality = defaults.string(forKey: "recognitionQuality") ?? "Normal"
        self.copyToClipboard = defaults.object(forKey: "copyToClipboard") as? Bool ?? true
        self.showTextInWindow = defaults.object(forKey: "showTextInWindow") as? Bool ?? true
        self.saveTextToNotes = defaults.object(forKey: "saveTextToNotes") as? Bool ?? true
        
        self.keepLineBreak = defaults.object(forKey: "keepLineBreak") as? Bool ?? true
        self.captureMode = defaults.string(forKey: "captureMode") ?? "text"
        
        self.captureImage = defaults.object(forKey: "captureImage") as? Bool ?? false
        self.showImageInWindow = defaults.object(forKey: "showImageInWindow") as? Bool ?? false
        self.saveToFolder = defaults.object(forKey: "saveToFolder") as? Bool ?? false
        
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?.path ?? ""
        self.saveFolderPath = defaults.string(forKey: "saveFolderPath") ?? pictures
    }
}
