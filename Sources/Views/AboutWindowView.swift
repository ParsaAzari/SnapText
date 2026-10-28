import SwiftUI
import AppKit

public struct AppConstants {
    public static let appName = "SnapText"
    public static let developerName = "Parsa Azari"
    public static let githubProfileURL = URL(string: "https://github.com/ParsaAzari")!
    public static let websiteURL = URL(string: "https://parsaazari.com")!
    public static let repositoryURL = URL(string: "https://github.com/ParsaAzari/SnapText.git")!
    
    public static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (Build \(build))"
    }
}

// MARK: - Reusable About Content (Flexible, Compact, Never Overflows)
public struct AboutContent: View {
    private var appIcon: NSImage? {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        return NSApp.applicationIconImage
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // App Icon
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 68, height: 68)
                    .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
            } else {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 46))
                    .foregroundColor(Color.accentColor)
            }
            
            // App Title & Version
            VStack(spacing: 2) {
                Text(AppConstants.appName)
                    .font(.system(size: 18, weight: .bold))
                
                Text("Version \(AppConstants.appVersion)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text("Fast, private and offline OCR tool for macOS.\nEngineered with advanced Persian BiDi reconstruction and Apple Vision intelligence.")
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.horizontal, 8)
            
            // Badges
            HStack(spacing: 6) {
                BadgeLabel(title: "Apple Silicon & Intel")
                BadgeLabel(title: "Offline OCR")
                BadgeLabel(title: "SQLite 3")
            }
            
            Divider()
                .opacity(0.3)
                .padding(.horizontal, 24)
                .padding(.vertical, 2)
            
            // Credits
            VStack(spacing: 2) {
                Text("Core Engines & Typography")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text("Apple Vision • Tesseract OCR • Vazirmatn Font")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            
            // Actions (GitHub Profile & Website)
            HStack(spacing: 10) {
                Button(action: {
                    NSWorkspace.shared.open(AppConstants.githubProfileURL)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 11))
                        Text("GitHub Profile")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    NSWorkspace.shared.open(AppConstants.websiteURL)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                        Text("parsaazari.com")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)
            
            Text("© 2026 Parsa Azari. All rights reserved.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

public struct AboutView: View {
    public init() {}
    
    public var body: some View {
        AboutContent()
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .frame(width: 350, height: 390)
    }
}

struct BadgeLabel: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(4)
    }
}

// MARK: - Dedicated Window Manager for Standalone About Window
public class AboutWindowManager {
    public static let shared = AboutWindowManager()
    
    private var window: NSWindow?
    private var windowController: NSWindowController?
    
    private init() {}
    
    public func show() {
        DispatchQueue.main.async {
            if let win = self.window {
                win.orderFrontRegardless()
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            let contentView = AboutView()
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 390),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "About SnapText"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            self.window = window
            self.windowController = NSWindowController(window: window)
        }
    }
}
