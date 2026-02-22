import Foundation
import SwiftData

@Model
final class TimedWord {
    var word: String
    var startTime: TimeInterval
    var duration: TimeInterval
    var index: Int

    var book: StoryBook?

    init(
        word: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        index: Int
    ) {
        self.word = word
        self.startTime = startTime
        self.duration = duration
        self.index = index
    }
}
