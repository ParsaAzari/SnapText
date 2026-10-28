import SwiftUI
import AppKit

// A rock-solid AppKit NSPopUpButton wrapper with explicit geometry
struct MacPopUpButton: NSViewRepresentable {
    let items: [String]
    @Binding var selectedItem: String
    var onChange: ((String) -> Void)? = nil
    
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }
    
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        if button.itemTitles != items {
            button.removeAllItems()
            button.addItems(withTitles: items)
        }
        if button.titleOfSelectedItem != selectedItem {
            button.selectItem(withTitle: selectedItem)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: MacPopUpButton
        init(_ parent: MacPopUpButton) { self.parent = parent }
        
        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let title = sender.titleOfSelectedItem {
                parent.selectedItem = title
                parent.onChange?(title)
            }
        }
    }
}
