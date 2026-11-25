import Foundation
import SQLite3

/// Where Yap keeps its transcript history.
///
/// `ModelContainer(for:)` with no configuration writes to
/// `~/Library/Application Support/default.store`. Yap isn't sandboxed, so that
/// path is shared with every other unsandboxed app that also takes SwiftData's
/// default, including Apple's own `icloudmailagent`. When another process opens
/// that file with its own schema, Yap's table disappears, every save fails, and
/// SwiftData's autosave keeps retrying the unsaved rows on the main thread,
/// which stalls the shortcut and the recording HUD. A file of our own avoids
/// all of it.
enum HistoryLocation {
    static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.frigade.Yap", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("History.store")
    }

    private static var legacyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("default.store")
    }

    /// Copies history from the old shared location the first time this build
    /// runs, but only if that file still holds Yap's transcripts. The old file is
    /// left in place: it may belong to another app now.
    static func migrateLegacyStoreIfNeeded() {
        let fileManager = FileManager.default
        let destination = storeURL
        guard !fileManager.fileExists(atPath: destination.path),
              fileManager.fileExists(atPath: legacyURL.path),
              containsTranscripts(legacyURL) else { return }

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            let target = URL(fileURLWithPath: destination.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            do {
                try fileManager.copyItem(at: source, to: target)
            } catch {
                NSLog("Yap: could not copy history from \(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    private static func containsTranscripts(_ url: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return false
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let query = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ZTRANSCRIPT'"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }
}
