import Foundation
import AppKit

public class CaptureService {
    public static let shared = CaptureService()
    
    private init() {}
    
    public func captureInteractive(completion: @escaping (NSImage?) -> Void) {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("snaptext_capture_\(UUID().uuidString).png")
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        // -i: interactive select
        // -s: only allows mouse selection of a rectangle
        // -x: do not play sound (we control sound in app)
        task.arguments = ["-i", "-s", "-x", tempUrl.path]
        
        task.terminationHandler = { proc in
            DispatchQueue.main.async {
                if FileManager.default.fileExists(atPath: tempUrl.path) {
                    if let image = NSImage(contentsOf: tempUrl) {
                        try? FileManager.default.removeItem(at: tempUrl)
                        completion(image)
                        return
                    }
                }
                // Cancelled or empty
                try? FileManager.default.removeItem(at: tempUrl)
                completion(nil)
            }
        }
        
        do {
            try task.run()
        } catch {
            print("[CaptureService] Failed to run screencapture: \(error)")
            completion(nil)
        }
    }
}
