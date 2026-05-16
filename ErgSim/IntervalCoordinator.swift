import Foundation

@Observable
final class IntervalCoordinator {
    enum Phase { case idle, work, rest, completed }

    private(set) var currentPhase: Phase = .idle
    private(set) var currentStepIndex: Int = 0
    private(set) var currentRepeat: Int = 0
    private(set) var phaseElapsedTime: TimeInterval = 0
    private(set) var phaseTotalDuration: TimeInterval = 0
    private(set) var shouldPublishBLE: Bool = true

    private var steps: [IntervalStep] = []

    var isActive: Bool { currentPhase == .work || currentPhase == .rest }

    var totalSteps: Int { steps.count }

    var phaseTimeRemaining: TimeInterval {
        max(0, phaseTotalDuration - phaseElapsedTime)
    }

    var currentStepRepeatCount: Int {
        guard currentStepIndex < steps.count else { return 1 }
        return steps[currentStepIndex].repeatCount
    }

    func start(with config: IntervalConfig) {
        steps = config.sortedSteps
        guard !steps.isEmpty else { return }
        currentStepIndex = 0
        currentRepeat = 0
        beginWorkPhase()
    }

    func stop() {
        currentPhase = .idle
        phaseElapsedTime = 0
        phaseTotalDuration = 0
        currentStepIndex = 0
        currentRepeat = 0
        shouldPublishBLE = true
        steps = []
    }

    func tick(tickInterval: TimeInterval) {
        guard isActive else { return }

        phaseElapsedTime += tickInterval

        if phaseElapsedTime >= phaseTotalDuration {
            advancePhase()
        }
    }

    private func advancePhase() {
        switch currentPhase {
        case .work:
            let step = steps[currentStepIndex]
            if step.restDuration > 0 {
                beginRestPhase()
            } else {
                advanceStep()
            }
        case .rest:
            advanceStep()
        default:
            break
        }
    }

    private func advanceStep() {
        currentRepeat += 1
        let step = steps[currentStepIndex]

        if currentRepeat < step.repeatCount {
            beginWorkPhase()
            return
        }

        currentRepeat = 0
        currentStepIndex += 1

        if currentStepIndex >= steps.count {
            handleSequenceComplete()
        } else {
            beginWorkPhase()
        }
    }

    private func handleSequenceComplete() {
        if let loopIndex = steps.firstIndex(where: { $0.shouldLoop }) {
            currentStepIndex = loopIndex
            currentRepeat = 0
            beginWorkPhase()
        } else {
            currentPhase = .completed
            shouldPublishBLE = true
        }
    }

    private func beginWorkPhase() {
        let step = steps[currentStepIndex]
        currentPhase = .work
        phaseElapsedTime = 0
        phaseTotalDuration = step.workDuration
        shouldPublishBLE = step.workSendData
    }

    private func beginRestPhase() {
        let step = steps[currentStepIndex]
        currentPhase = .rest
        phaseElapsedTime = 0
        phaseTotalDuration = step.restDuration
        shouldPublishBLE = step.restSendData
    }
}
