import SwiftUI
import AppKit
import Carbon

public struct SettingsView: View {
    @ObservedObject var prefs = AppPreferences.shared
    @State private var selectedTab: Int = 0
    
    let sounds = ["Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    public static let targetControlWidth: CGFloat = 175
    public static let windowSize = NSSize(width: 480, height: 430)
    
    public var body: some View {
        VStack(spacing: 0) {
            // Segmented Icon Toolbar (General, Text, Image, About)
            HStack(spacing: 32) {
                SettingsTabButton(title: "General", systemImage: "gearshape", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                SettingsTabButton(title: "Text", systemImage: "text.viewfinder", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                SettingsTabButton(title: "Image", systemImage: "camera", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                SettingsTabButton(title: "About", systemImage: "info.circle", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            
            Divider()
                .opacity(0.35)
            
            // Tab Contents
            VStack(alignment: .leading, spacing: 0) {
                if selectedTab == 0 {
                    GeneralTab(prefs: prefs, sounds: sounds)
                } else if selectedTab == 1 {
                    TextTab(prefs: prefs)
                } else if selectedTab == 2 {
                    ImageTab(prefs: prefs)
                } else {
                    AboutContent()
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: SettingsView.windowSize.width, height: SettingsView.windowSize.height)
    }
}

// Custom Tab Button styling with 100% full-box clickable hit area
struct SettingsTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(isSelected ? Color(red: 0.18, green: 0.52, blue: 0.98) : Color.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color(red: 0.18, green: 0.52, blue: 0.98) : Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.primary.opacity(0.18) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle()) // Ensures the entire bounding box is instantly clickable
        }
        .buttonStyle(.plain)
        .frame(width: 66, height: 56)
    }
}

// MARK: - General Tab
struct GeneralTab: View {
    @ObservedObject var prefs: AppPreferences
    let sounds: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                Text("Launch Initiater at startup:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("", isOn: $prefs.launchAtStartup)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.gray.opacity(0.5)))
            }
            
            Divider().opacity(0.25)
            
            HStack(alignment: .center) {
                Text("Show Success Notification:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("", isOn: $prefs.showSuccessNotification)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.gray.opacity(0.5)))
            }
            
            HStack(alignment: .center) {
                Text("Play sound when capture:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("", isOn: $prefs.playSound)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.gray.opacity(0.5)))
            }
            
            // Sound Picker using native MacPopUpButton for exact pixel right-alignment
            HStack {
                Spacer()
                MacPopUpButton(items: sounds, selectedItem: $prefs.soundName) { newSound in
                    NSSound(named: newSound)?.play()
                }
                .frame(width: SettingsView.targetControlWidth, height: 26)
                .disabled(!prefs.playSound)
            }
            
            Divider().opacity(0.25)
            
            HStack(alignment: .center) {
                Text("Set Capture Shortcut:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                ShortcutRecorderButton(prefs: prefs)
                    .frame(width: SettingsView.targetControlWidth)
            }
        }
    }
}

// MARK: - Shortcut Recorder Button
struct ShortcutRecorderButton: View {
    @ObservedObject var prefs: AppPreferences
    @State private var isRecording: Bool = false
    @State private var monitor: Any?
    
    var body: some View {
        Button(action: startRecording) {
            Text(isRecording ? "Type shortcut..." : prefs.shortcutDisplay)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, maxHeight: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func startRecording() {
        if isRecording {
            stopRecording()
            return
        }
        isRecording = true
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            if flags.contains(.command) || flags.contains(.option) || flags.contains(.control) || flags.contains(.shift) {
                var carbonModifiers: UInt32 = 0
                var display = ""
                
                if flags.contains(.control) { carbonModifiers |= UInt32(controlKey); display += "⌃" }
                if flags.contains(.option) { carbonModifiers |= UInt32(optionKey); display += "⌥" }
                if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey); display += "⇧" }
                if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey); display += "⌘" }
                
                let chars = event.charactersIgnoringModifiers?.uppercased() ?? ""
                if !chars.isEmpty {
                    display += chars
                    prefs.shortcutKeyCode = UInt32(event.keyCode)
                    prefs.shortcutModifiers = carbonModifiers
                    prefs.shortcutDisplay = display
                    
                    NotificationCenter.default.post(name: NSNotification.Name("UpdateHotKey"), object: nil)
                    stopRecording()
                    return nil
                }
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let mon = monitor {
            NSEvent.removeMonitor(mon)
            monitor = nil
        }
    }
}

// MARK: - Text Tab
struct TextTab: View {
    @ObservedObject var prefs: AppPreferences
    
    let languageNames = OCRService.supportedLanguages.map { $0.name }
    let qualityLevels = ["Normal", "Best"]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                Text("Recognize Text:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("", isOn: $prefs.recognizeText)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.gray.opacity(0.5)))
            }
            
            Divider().opacity(0.25)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recognition Language:")
                        .font(.system(size: 13, weight: .medium))
                    Text("Default Text Recognition Language.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                MacPopUpButton(items: languageNames, selectedItem: $prefs.recognitionLanguage)
                    .frame(width: SettingsView.targetControlWidth, height: 26)
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recognition Quality:")
                        .font(.system(size: 13, weight: .medium))
                    Text("Normal - High Speed but Lower Accuracy\nBest - Good Result but Slower Speed")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                MacPopUpButton(items: qualityLevels, selectedItem: $prefs.recognitionQuality)
                    .frame(width: SettingsView.targetControlWidth, height: 26)
            }
            
            Divider().opacity(0.25)
            
            HStack(alignment: .top) {
                Text("After Recognition:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Copy to Clipboard", isOn: $prefs.copyToClipboard)
                    Toggle("Show Text in Window", isOn: $prefs.showTextInWindow)
                    Toggle("Save Text to Notes", isOn: $prefs.saveTextToNotes)
                }
                .font(.system(size: 13))
                .frame(width: SettingsView.targetControlWidth, alignment: .leading)
            }
        }
    }
}

// MARK: - Image Tab
struct ImageTab: View {
    @ObservedObject var prefs: AppPreferences
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center) {
                Text("Capture Image:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("", isOn: $prefs.captureImage)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.gray.opacity(0.5)))
            }
            
            Divider().opacity(0.25)
            
            HStack(alignment: .top) {
                Text("After Capture:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Image in Window", isOn: $prefs.showImageInWindow)
                    Toggle("Save to Folder", isOn: $prefs.saveToFolder)
                    
                    HStack(spacing: 8) {
                        Text(prefs.saveFolderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: chooseFolder) {
                            Image(systemName: "folder")
                                .font(.system(size: 13))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .opacity(prefs.saveToFolder ? 1.0 : 0.0)
                    .disabled(!prefs.saveToFolder)
                }
                .font(.system(size: 13))
                .frame(width: SettingsView.targetControlWidth, alignment: .leading)
            }
        }
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            prefs.saveFolderPath = url.path
        }
    }
}

// MARK: - About Tab (Clean Open Source Project Page)
struct AboutTab: View {
    private var appIconImage: NSImage? {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        return NSApp.applicationIconImage
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if let icon = appIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
            } else {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 46))
                    .foregroundColor(Color(red: 0.18, green: 0.52, blue: 0.98))
            }
            
            Text("SnapText")
                .font(.system(size: 17, weight: .bold))
            
            Text("Version 1.0.0 (Native Apple Silicon & Intel)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Text("Open Source, ultra-lightweight Menu Bar OCR tool for macOS.\nEngineered with full Persian & Multilingual support and robust offline OCR capabilities.")
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 2)
            
            Divider().opacity(0.25).padding(.vertical, 4)
            
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://github.com") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                        Text("GitHub Repository")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
