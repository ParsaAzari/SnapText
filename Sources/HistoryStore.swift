import Foundation
import AppKit
import SQLite3

public struct CapturedNote: Identifiable, Codable, Equatable {
    public let id: UUID
    public var text: String
    public let createdAt: Date
    
    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

public class HistoryStore: ObservableObject {
    public static let shared = HistoryStore()
    
    @Published public var notes: [CapturedNote] = []
    
    private var db: OpaquePointer?
    private let dbURL: URL
    private let legacyJsonURL: URL
    private let queue = DispatchQueue(label: "com.parsa.SnapText.HistoryStore", qos: .utility)
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SnapText", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        self.dbURL = dir.appendingPathComponent("captured_notes.sqlite")
        self.legacyJsonURL = dir.appendingPathComponent("captured_notes.json")
        
        initDatabase()
        migrateLegacyJsonIfNeeded()
        reloadNotes()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    // MARK: - SQLite Setup
    private func initDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            NSLog("HistoryStore: Failed to open SQLite database at \(dbURL.path)")
            return
        }
        
        // Performance optimizations for high load & crash resilience
        sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
        
        // Create table and indexes if not exists
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY NOT NULL,
            text TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at DESC);
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errMsg = String(cString: sqlite3_errmsg(db))
            NSLog("HistoryStore: Failed to create table: \(errMsg)")
        }
    }
    
    // MARK: - Migration from Legacy JSON
    private func migrateLegacyJsonIfNeeded() {
        guard FileManager.default.fileExists(atPath: legacyJsonURL.path),
              let data = try? Data(contentsOf: legacyJsonURL) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let legacyNotes = try? decoder.decode([CapturedNote].self, from: data), !legacyNotes.isEmpty {
            for note in legacyNotes {
                insertRow(note: note)
            }
            // Archive legacy JSON file to avoid repeated migrations
            let backupURL = legacyJsonURL.deletingPathExtension().appendingPathExtension("json.bak")
            try? FileManager.default.moveItem(at: legacyJsonURL, to: backupURL)
            NSLog("HistoryStore: Migrated \(legacyNotes.count) notes from JSON to SQLite")
        }
    }
    
    // MARK: - DB Helpers
    private func reloadNotes() {
        var fetched: [CapturedNote] = []
        let selectSQL = "SELECT id, text, created_at FROM notes ORDER BY created_at DESC;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCString = sqlite3_column_text(stmt, 0),
                   let textCString = sqlite3_column_text(stmt, 1) {
                    let idStr = String(cString: idCString)
                    let text = String(cString: textCString)
                    let timestamp = sqlite3_column_double(stmt, 2)
                    
                    if let uuid = UUID(uuidString: idStr) {
                        let note = CapturedNote(id: uuid, text: text, createdAt: Date(timeIntervalSince1970: timestamp))
                        fetched.append(note)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        performOnMain {
            self.notes = fetched
        }
    }
    
    private func insertRow(note: CapturedNote) {
        let insertSQL = "INSERT OR REPLACE INTO notes (id, text, created_at) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            let idStr = note.id.uuidString
            let text = note.text
            let timestamp = note.createdAt.timeIntervalSince1970
            
            sqlite3_bind_text(stmt, 1, (idStr as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (text as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, timestamp)
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                let errMsg = String(cString: sqlite3_errmsg(db))
                NSLog("HistoryStore: Insert error: \(errMsg)")
            }
            sqlite3_finalize(stmt)
        }
    }
    
    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    // MARK: - CRUD Operations
    @discardableResult
    public func addNote(text: String) -> CapturedNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Prevent accidental rapid duplicate entries
        if let first = notes.first, first.text == trimmed, abs(first.createdAt.timeIntervalSinceNow) < 3.0 {
            return first
        }
        
        let note = CapturedNote(text: trimmed)
        
        performOnMain {
            self.notes.insert(note, at: 0)
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.insertRow(note: note)
        }
        
        return note
    }
    
    public func addFromClipboard() {
        if let clipText = NSPasteboard.general.string(forType: .string) {
            addNote(text: clipText)
        }
    }
    
    public func deleteNote(id: UUID) {
        performOnMain {
            self.notes.removeAll { $0.id == id }
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = "DELETE FROM notes WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }
    
    public func deleteNotes(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        
        performOnMain {
            self.notes.removeAll { ids.contains($0.id) }
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
            let sql = "DELETE FROM notes WHERE id IN (\(placeholders));"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                for (index, id) in ids.enumerated() {
                    sqlite3_bind_text(stmt, Int32(index + 1), (id.uuidString as NSString).utf8String, -1, nil)
                }
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }
    
    public func clearAll() {
        performOnMain {
            self.notes.removeAll()
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = "DELETE FROM notes; VACUUM;"
            sqlite3_exec(self.db, sql, nil, nil, nil)
        }
    }
}
