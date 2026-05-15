import Foundation

struct SimulationProfile: Identifiable, Hashable {
    let id: String
    let name: String
    var spmMin: Int
    var spmMax: Int
    var powerMin: Int
    var powerMax: Int
    var paceMin: TimeInterval
    var paceMax: TimeInterval
    var hrRestingMin: Int
    var hrRestingMax: Int
    var hrActiveMin: Int
    var hrActiveMax: Int

    static let presets: [SimulationProfile] = [
        SimulationProfile(
            id: "easy",
            name: "Easy Steady",
            spmMin: 20, spmMax: 24,
            powerMin: 100, powerMax: 140,
            paceMin: 130, paceMax: 145,
            hrRestingMin: 60, hrRestingMax: 70,
            hrActiveMin: 120, hrActiveMax: 140
        ),
        SimulationProfile(
            id: "steady",
            name: "Steady State",
            spmMin: 24, spmMax: 28,
            powerMin: 150, powerMax: 190,
            paceMin: 115, paceMax: 130,
            hrRestingMin: 62, hrRestingMax: 72,
            hrActiveMin: 140, hrActiveMax: 160
        ),
        SimulationProfile(
            id: "race",
            name: "Race Pace",
            spmMin: 30, spmMax: 34,
            powerMin: 230, powerMax: 280,
            paceMin: 100, paceMax: 110,
            hrRestingMin: 65, hrRestingMax: 75,
            hrActiveMin: 160, hrActiveMax: 178
        ),
        SimulationProfile(
            id: "sprint",
            name: "Sprint",
            spmMin: 34, spmMax: 40,
            powerMin: 320, powerMax: 400,
            paceMin: 88, paceMax: 98,
            hrRestingMin: 65, hrRestingMax: 75,
            hrActiveMin: 170, hrActiveMax: 185
        ),
    ]

    static let `default` = presets[1]

    func randomSPM() -> Int {
        Int.random(in: spmMin...spmMax)
    }

    func randomPower() -> Int {
        Int.random(in: powerMin...powerMax)
    }

    func randomPace() -> TimeInterval {
        TimeInterval.random(in: paceMin...paceMax)
    }
}
