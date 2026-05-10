import Foundation
import RowingProtocols

@Observable
final class SimulationEngine {
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var distance: Double = 0
    private(set) var strokeCount: Int = 0
    private(set) var currentSPM: Int = 0
    private(set) var currentPower: Int = 0
    private(set) var currentPace: TimeInterval = 0
    private(set) var currentSpeed: Double = 0
    private(set) var driveTime: TimeInterval = 0
    private(set) var recoveryTime: TimeInterval = 0
    private(set) var latestSnapshot: RowingSnapshot?

    var profile: SimulationProfile = .default

    private var tickInterval: TimeInterval = 0.25
    private var timeSinceLastStroke: TimeInterval = 0
    private var strokeInterval: TimeInterval = 2.0
    private var timer: Timer?

    func start() {
        reset()
        rollStrokeValues()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        stop()
        elapsedTime = 0
        distance = 0
        strokeCount = 0
        currentSPM = 0
        currentPower = 0
        currentPace = 0
        currentSpeed = 0
        driveTime = 0
        recoveryTime = 0
        timeSinceLastStroke = 0
        latestSnapshot = nil
    }

    private func tick() {
        elapsedTime += tickInterval
        let metersPerSecond = currentPace > 0 ? 500.0 / currentPace : 0
        distance += metersPerSecond * tickInterval
        currentSpeed = metersPerSecond

        timeSinceLastStroke += tickInterval
        if timeSinceLastStroke >= strokeInterval {
            completeStroke()
        }

        buildSnapshot()
    }

    private func completeStroke() {
        strokeCount += 1
        timeSinceLastStroke = 0
        rollStrokeValues()
    }

    private func rollStrokeValues() {
        currentSPM = profile.randomSPM()
        currentPower = profile.randomPower()
        currentPace = profile.randomPace()

        strokeInterval = currentSPM > 0 ? 60.0 / Double(currentSPM) : 2.0
        // ~40% drive, ~60% recovery
        driveTime = strokeInterval * 0.4
        recoveryTime = strokeInterval * 0.6
    }

    private func buildSnapshot() {
        let snapshot = RowingSnapshot(
            elapsedTime: elapsedTime,
            distance: distance,
            strokeRate: currentSPM,
            strokeCount: strokeCount,
            pace: currentPace,
            speed: currentSpeed,
            power: currentPower,
            driveTime: driveTime,
            recoveryTime: recoveryTime,
            workoutState: .rowing,
            rowingState: .active,
            strokeState: timeSinceLastStroke < driveTime ? .driving : .recovery
        )
        latestSnapshot = snapshot
    }
}
