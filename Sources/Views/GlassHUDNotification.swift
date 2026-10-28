import SwiftUI
import AppKit

public struct HUDNotificationView: View {
    let message: String
    let icon: String
    
    @State private var scale: CGFloat = 0.65
    @State private var opacity: Double = 0.0
    
    public init(message: String = "Captured\nSuccessfully", icon: String = "checkmark") {
        self.message = message
        self.icon = icon
    }
    
    public var body: some View {
        ZStack {
            // Dark Frosted Glass Card
            VStack(spacing: 12) {
                // White badge with dark icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 42, height: 42)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.black)
                }
                
                // Notification Text
                Text(message)
                    .font(resolveFont())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .frame(width: 155, height: 145)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(white: 0.12).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .frame(width: 240, height: 230)
        .background(Color.clear)
        .onAppear {
            // Zoom In Animation
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Zoom Out & Fade Animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.easeIn(duration: 0.22)) {
                    scale = 0.75
                    opacity = 0.0
                }
            }
        }
    }
    
    private func resolveFont() -> Font {
        if NSFont(name: "Vazirmatn-SemiBold", size: 13.5) != nil || NSFont(name: "Vazirmatn", size: 13.5) != nil {
            return Font.custom("Vazirmatn", size: 13.5).weight(.semibold)
        }
        return Font.system(size: 13.5, weight: .semibold, design: .default)
    }
}

public class HUDNotificationManager {
    public static let shared = HUDNotificationManager()
    
    private var hudWindow: NSWindow?
    private var dismissTimer: Timer?
    
    private init() {}
    
    public func show(message: String = "Captured\nSuccessfully", icon: String = "checkmark") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            
            let screen = NSScreen.main ?? NSScreen.screens.first
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            
            // Transparent host window frame with generous padding around the card to prevent any shadow clipping
            let windowWidth: CGFloat = 240
            let windowHeight: CGFloat = 230
            let origin = NSPoint(
                x: screenFrame.midX - (windowWidth / 2.0),
                y: screenFrame.midY - (windowHeight / 2.0)
            )
            
            let hudView = HUDNotificationView(message: message, icon: icon)
            let hosting = NSHostingView(rootView: hudView)
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
            
            if let window = self.hudWindow {
                window.contentView = hosting
                window.setFrame(NSRect(origin: origin, size: NSSize(width: windowWidth, height: windowHeight)), display: true)
                window.alphaValue = 1.0
                window.orderFrontRegardless()
            } else {
                let window = NSWindow(
                    contentRect: NSRect(origin: origin, size: NSSize(width: windowWidth, height: windowHeight)),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.level = .floating
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
                window.contentView = hosting
                window.orderFrontRegardless()
                self.hudWindow = window
            }
            
            // Auto hide window after animation completes (0.85s delay + 0.22s zoom-out)
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.15, repeats: false) { [weak self] _ in
                self?.hudWindow?.orderOut(nil)
            }
        }
    }
}
