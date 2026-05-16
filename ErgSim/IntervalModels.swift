import Foundation
import SwiftData

@Model
final class IntervalStep {
    var order: Int
    var workDuration: TimeInterval
    var workSendData: Bool
    var restDuration: TimeInterval
    var restSendData: Bool
    var repeatCount: Int
    var shouldLoop: Bool

    @Relationship(inverse: \IntervalConfig.steps)
    var config: IntervalConfig?

    init(order: Int = 0,
         workDuration: TimeInterval = 120,
         workSendData: Bool = true,
         restDuration: TimeInterval = 0,
         restSendData: Bool = false,
         repeatCount: Int = 1,
         shouldLoop: Bool = false) {
        self.order = order
        self.workDuration = workDuration
        self.workSendData = workSendData
        self.restDuration = restDuration
        self.restSendData = restSendData
        self.repeatCount = repeatCount
        self.shouldLoop = shouldLoop
    }
}

@Model
final class IntervalConfig {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var steps: [IntervalStep]

    var sortedSteps: [IntervalStep] {
        steps.sorted { $0.order < $1.order }
    }

    init(name: String = "New Config", steps: [IntervalStep] = []) {
        self.name = name
        self.createdAt = Date()
        self.steps = steps
    }
}
