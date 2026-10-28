import Cocoa
import SwiftUI
import UserNotifications
import Carbon

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var lastCapturedText: String = ""
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        registerCustomFonts()
        setupMainMenu()
        setupMenuBar()
        setupHotKey()
        requestNotificationPermission()
        _ = HistoryStore.shared
        
        NotificationCenter.default.addObserver(self, selector: #selector(rebindHotKey), name: NSNotification.Name("UpdateHotKey"), object: nil)
    }
    
    private func registerCustomFonts() {
        if let fontsURL = Bundle.main.url(forResource: "Fonts", withExtension: nil) {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(fontsURL as CFURL, .process, &error)
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App item (required empty or placeholder for first menu item in macOS)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        
        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenu.addItem(undoItem)
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(cutItem)
        editMenu.addItem(copyItem)
        editMenu.addItem(pasteItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(selectAllItem)
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func rebindHotKey() {
        setupHotKey()
        setupMenuBar()
    }
    
    private func setupHotKey() {
        let prefs = AppPreferences.shared
        HotKeyManager.shared.register(keyCode: prefs.shortcutKeyCode, modifiers: prefs.shortcutModifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.triggerCapture()
            }
        }
    }
    
    public func setupMenuBar() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "SnapText")
            }
        }
        
        let prefs = AppPreferences.shared
        let menu = NSMenu()
        
        // 1. Capture Text (One-click direct OCR action)
        let captureTextItem = NSMenuItem(title: "Capture Text", action: #selector(triggerTextCapture), keyEquivalent: "e")
        captureTextItem.keyEquivalentModifierMask = [.command]
        menu.addItem(captureTextItem)
        
        // 2. Capture Image (One-click direct screenshot action)
        let captureImageItem = NSMenuItem(title: "Capture Image", action: #selector(triggerImageCapture), keyEquivalent: "e")
        captureImageItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(captureImageItem)
        
        // 3. Capture Text from File
        let fileItem = NSMenuItem(title: "Capture Text From File...", action: #selector(captureFromFile), keyEquivalent: "3")
        fileItem.keyEquivalentModifierMask = [.command]
        menu.addItem(fileItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Keep Line Break toggle
        let lineBreakItem = NSMenuItem(title: "Keep Line Break", action: #selector(toggleKeepLineBreak), keyEquivalent: "")
        lineBreakItem.state = prefs.keepLineBreak ? .on : .off
        menu.addItem(lineBreakItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. History / Captured Texts
        let historyItem = NSMenuItem(title: "History / Captured Texts", action: #selector(openCapturedTexts), keyEquivalent: "h")
        historyItem.keyEquivalentModifierMask = [.command]
        menu.addItem(historyItem)
        
        // 6. Preferences
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem(title: "About SnapText", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // 7. Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func toggleKeepLineBreak() {
        AppPreferences.shared.keepLineBreak.toggle()
        setupMenuBar()
    }
    
    @objc private func openCapturedTexts() {
        CapturedTextsWindowManager.shared.show()
    }
    
    @objc private func captureFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            processImage(image, asText: true)
        }
    }
    
    @objc public func triggerCapture() {
        triggerTextCapture()
    }
    
    @objc public func triggerTextCapture() {
        CaptureService.shared.captureInteractive { [weak self] capturedImage in
            guard let image = capturedImage else { return }
            self?.processImage(image, asText: true)
        }
    }
    
    @objc public func triggerImageCapture() {
        CaptureService.shared.captureInteractive { [weak self] capturedImage in
            guard let image = capturedImage else { return }
            self?.processImage(image, asText: false)
        }
    }
    
    private func processImage(_ image: NSImage, asText: Bool = true) {
        let prefs = AppPreferences.shared
        
        if prefs.playSound {
            NSSound(named: prefs.soundName)?.play()
        }
        
        if !asText {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
            HUDNotificationManager.shared.show(message: "Image Copied\nSuccessfully", icon: "photo")
            if prefs.showSuccessNotification {
                showNotification(title: "SnapText", body: "Image copied to clipboard!")
            }
            return
        }
        
        OCRService.shared.recognizeText(
            from: image,
            languageChoice: prefs.recognitionLanguage,
            qualityChoice: prefs.recognitionQuality
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(var text):
                    if !prefs.keepLineBreak {
                        text = text.replacingOccurrences(of: "\n", with: " ")
                    }
                    
                    self?.lastCapturedText = text
                    
                    if prefs.copyToClipboard {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        HUDNotificationManager.shared.show(message: "Captured\nSuccessfully", icon: "checkmark")
                    }
                    
                    if prefs.saveTextToNotes {
                        HistoryStore.shared.addNote(text: text)
                    }
                    
                    if prefs.showSuccessNotification {
                        self?.showNotification(title: "SnapText Copied!", body: text)
                    }
                    
                    // Show Rich Text Editor Window if enabled
                    if prefs.showTextInWindow {
                        ResultWindowManager.shared.show(text: text, image: image)
                    }
                    
                case .failure(let error):
                    print("[AppDelegate] OCR error: \(error)")
                }
            }
        }
    }
    
    @objc public func openPreferences() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: SettingsView.windowSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SnapText Preferences"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc public func openAbout() {
        AboutWindowManager.shared.show()
    }
    
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body.count > 100 ? String(body.prefix(100)) + "..." : body
        content.sound = nil
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { _, _ in }
    }
    
    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
