import Foundation
import SwiftData

@Model
final class StoryBook {
    @Attribute(.unique) var id: UUID
    var title: String
    @Attribute(.externalStorage) var coverImageData: Data?
    var audioFileName: String?
    var creationDate: Date

    @Relationship(deleteRule: .cascade, inverse: \TimedWord.book)
    var timedWords: [TimedWord]

    var audioRecordingURL: URL? {
        guard let audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(audioFileName)
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        coverImageData: Data? = nil,
        audioFileName: String? = nil,
        creationDate: Date = .now
    ) {
        self.id = id
        self.title = title
        self.coverImageData = coverImageData
        self.audioFileName = audioFileName
        self.creationDate = creationDate
        self.timedWords = []
    }
}
