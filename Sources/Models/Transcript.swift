import Foundation
import SwiftData

/// A single dictation result, persisted locally.
@Model
final class Transcript {
    var id: UUID
    var text: String
    var createdAt: Date
    var durationSeconds: Double?
    var inputDeviceName: String?

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        durationSeconds: Double? = nil,
        inputDeviceName: String? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.inputDeviceName = inputDeviceName
    }
}
