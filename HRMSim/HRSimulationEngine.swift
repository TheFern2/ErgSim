import Foundation

@Observable
final class HRSimulationEngine {
    enum Profile: String, CaseIterable, Identifiable {
        case resting = "Resting"
        case warmup = "Warmup"
        case steady = "Steady"
        case intense = "Intense"

        var id: String { rawValue }

        var targetRange: ClosedRange<Int> {
            switch self {
            case .resting: 60...72
            case .warmup: 100...120
            case .steady: 140...160
            case .intense: 170...185
            }
        }
    }

    private(set) var currentHeartRate: Int = 65
    var selectedProfile: Profile = .resting

    private var timer: Timer?
    private let tickInterval: TimeInterval = 0.25

    func start() {
        let range = selectedProfile.targetRange
        currentHeartRate = Int.random(in: range)
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let range = selectedProfile.targetRange
        let targetMid = (range.lowerBound + range.upperBound) / 2
        let jitter = Int.random(in: -1...1)
        let target = targetMid + jitter

        let maxDelta = 1
        let delta = target - currentHeartRate
        let clamped = min(max(delta, -maxDelta), maxDelta)
        currentHeartRate += clamped
    }
}
