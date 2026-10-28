import SwiftUI
import AppKit

public struct CapturedTextsView: View {
    @ObservedObject var store = HistoryStore.shared
    @State private var selectedIds: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var showClearAllAlert: Bool = false
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
    
    var filteredNotes: [CapturedNote] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return store.notes
        }
        return store.notes.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header / Section Bar
            HStack {
                Text("Texts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("(\(store.notes.count))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Spacer()
                
                if !filteredNotes.isEmpty {
                    Button(action: toggleSelectAll) {
                        Text(selectedIds.count == filteredNotes.count ? "Deselect All" : "Select All")
                            .font(.system(size: 11.5))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search captured texts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider().opacity(0.3)
            
            // MARK: - Notes List
            if filteredNotes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchText.isEmpty ? "No captured texts yet" : "No matching texts found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Text("Capture text with ⌘E or click 'Add Clipboard to Notes'")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredNotes) { note in
                            NoteRowView(
                                note: note,
                                isSelected: selectedIds.contains(note.id),
                                dateString: dateFormatter.string(from: note.createdAt),
                                onToggleSelect: {
                                    toggleSelection(for: note.id)
                                },
                                onDoubleClick: {
                                    openInEditor(note: note)
                                }
                            )
                            .contextMenu {
                                Button("Copy to Clipboard") {
                                    copyNote(note: note)
                                }
                                Button("Open in Editor") {
                                    openInEditor(note: note)
                                }
                                Divider()
                                Button("Delete Note", role: .destructive) {
                                    store.deleteNote(id: note.id)
                                    selectedIds.remove(note.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            }
            
            Divider().opacity(0.3)
            
            // MARK: - Bottom Action Toolbar (Matching Screenshot)
            HStack(spacing: 10) {
                // Delete Note (Single or Batch)
                Button(action: deleteSelected) {
                    HStack(spacing: 4) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                        Text(selectedIds.count > 1 ? "Delete (\(selectedIds.count))" : "Delete Note")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedIds.isEmpty ? Color.primary.opacity(0.04) : Color.red.opacity(0.12))
                    )
                    .foregroundColor(selectedIds.isEmpty ? .secondary : .red)
                }
                .buttonStyle(.plain)
                .disabled(selectedIds.isEmpty)
                .help("Delete selected notes (Single or Batch)")
                
                // Add Clipboard to Notes
                Button(action: addClipboard) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12))
                        Text("Add Clipboard to Notes")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Add current clipboard content into database")
                
                Spacer()
                
                // Clear Database (Batch wipe)
                if !store.notes.isEmpty {
                    Button(action: { showClearAllAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .help("Clear entire database history")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 460, idealHeight: 560)
        .alert("Clear All History?", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                store.clearAll()
                selectedIds.removeAll()
                HUDNotificationManager.shared.show(message: "Database\nCleared", icon: "trash")
            }
        } message: {
            Text("Are you sure you want to delete all \(store.notes.count) saved notes? This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    private func toggleSelection(for id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
    
    private func toggleSelectAll() {
        if selectedIds.count == filteredNotes.count {
            selectedIds.removeAll()
        } else {
            selectedIds = Set(filteredNotes.map { $0.id })
        }
    }
    
    private func deleteSelected() {
        guard !selectedIds.isEmpty else { return }
        let count = selectedIds.count
        store.deleteNotes(ids: selectedIds)
        selectedIds.removeAll()
        HUDNotificationManager.shared.show(message: "\(count) Note\(count > 1 ? "s" : "")\nDeleted", icon: "trash")
    }
    
    private func addClipboard() {
        if let str = NSPasteboard.general.string(forType: .string), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.addNote(text: str)
            HUDNotificationManager.shared.show(message: "Added to\nNotes", icon: "doc.badge.plus")
        }
    }
    
    private func copyNote(note: CapturedNote) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
        HUDNotificationManager.shared.show(message: "Copied\nSuccessfully", icon: "checkmark")
    }
    
    private func openInEditor(note: CapturedNote) {
        ResultWindowManager.shared.show(text: note.text)
    }
}

// MARK: - Individual Note Row
struct NoteRowView: View {
    let note: CapturedNote
    let isSelected: Bool
    let dateString: String
    let onToggleSelect: () -> Void
    let onDoubleClick: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Checkbox indicator for batch selection
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            
            // Text & Info
            VStack(alignment: .leading, spacing: 5) {
                Text(note.text)
                    .font(resolveNoteFont())
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Text(dateString)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("\(note.text.count) characters")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelect()
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onDoubleClick()
            }
        )
    }
    
    private func resolveNoteFont() -> Font {
        if NSFont(name: "Vazirmatn-Regular", size: 12.5) != nil || NSFont(name: "Vazirmatn", size: 12.5) != nil {
            return Font.custom("Vazirmatn", size: 12.5)
        }
        return Font.system(size: 12.5)
    }
}

// MARK: - Window Manager for Captured Texts
public class CapturedTextsWindowManager {
    public static let shared = CapturedTextsWindowManager()
    
    private var windowController: NSWindowController?
    private var window: NSWindow?
    
    private init() {}
    
    public func show() {
        DispatchQueue.main.async {
            if let existingWindow = self.window {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            let contentView = CapturedTextsView()
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Captured Texts"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            self.window = window
            self.windowController = NSWindowController(window: window)
        }
    }
}
