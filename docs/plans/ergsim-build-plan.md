# ErgSim Build Plan

## Goal

Build a BLE peripheral simulator (iPadOS + macOS) that emits realistic rowing data over Bluetooth. It must support Concept2 PM5 and FTMS protocols today, be architected so adding a new protocol is a self-contained task, and let the user load simulation profiles that control how workout data evolves over time.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      ErgSim App                         │
│                                                         │
│  ┌──────────────┐   ┌──────────────┐   ┌─────────────┐ │
│  │   Profile     │   │  Simulation  │   │     UI      │ │
│  │   Manager     │──>│  Engine      │──>│  (SwiftUI)  │ │
│  │              │   │              │   │             │ │
│  │  Load/Save   │   │  Tick loop   │   │  Protocol   │ │
│  │  Edit        │   │  Physics     │   │  picker     │ │
│  │  Presets     │   │  Randomness  │   │  Profile    │ │
│  └──────────────┘   └──────┬───────┘   │  selector   │ │
│                            │           │  Live data   │ │
│                            v           │  Controls    │ │
│                     ┌──────────────┐   └─────────────┘ │
│                     │  Protocol    │                    │
│                     │  Abstraction │                    │
│                     │              │                    │
│                     │  ┌────────┐  │                    │
│                     │  │  C2    │  │                    │
│                     │  ├────────┤  │                    │
│                     │  │  FTMS  │  │                    │
│                     │  ├────────┤  │                    │
│                     │  │ Future │  │                    │
│                     │  └────────┘  │                    │
│                     └──────┬───────┘                    │
│                            │                            │
│                     ┌──────────────┐                    │
│                     │  BLE         │                    │
│                     │  Peripheral  │                    │
│                     │  Manager     │                    │
│                     └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

## Phase 1: Protocol Abstraction Layer

Establish the protocol-agnostic foundation so that C2, FTMS, and any future protocol are plug-in modules.

### Core Types

**`RowingSnapshot`** — a flat struct holding the superset of all fields any protocol could produce. This is what the simulation engine outputs each tick. Fields not relevant to a given protocol are ignored by that protocol's encoder.

```
struct RowingSnapshot {
    elapsedTime: TimeInterval
    distance: Double              // meters
    strokeRate: Int               // SPM
    strokeCount: Int
    pace: TimeInterval            // seconds per 500m
    averagePace: TimeInterval
    speed: Double                 // m/s
    power: Int                    // watts
    averagePower: Int
    heartRate: Int                // bpm
    calories: Int                 // total kcal
    caloriesPerHour: Int
    dragFactor: Int
    driveLength: Double           // meters
    driveTime: TimeInterval
    recoveryTime: TimeInterval
    strokeDistance: Double         // meters per stroke
    peakDriveForce: Double        // lbs
    avgDriveForce: Double         // lbs
    workPerStroke: Double         // joules
    workoutState: WorkoutState
    rowingState: RowingState
    strokeState: StrokeState
    resistanceLevel: Int
}
```

**`SimulatedProtocol`** — the protocol (Swift protocol) each BLE protocol conforms to:

```swift
protocol SimulatedProtocol {
    var id: String { get }
    var displayName: String { get }

    /// BLE service UUIDs this protocol advertises
    var serviceUUIDs: [CBUUID] { get }

    /// Build the CBMutableService(s) with characteristics
    func buildServices() -> [CBMutableService]

    /// Encode a RowingSnapshot into characteristic updates
    /// Returns [(characteristic, data)] pairs to notify
    func encode(snapshot: RowingSnapshot) -> [(CBMutableCharacteristic, Data)]

    /// Handle a write from a central (e.g., C2 sample rate control)
    func handleWrite(to characteristic: CBCharacteristic, value: Data)
}
```

### Protocol Implementations

**`C2Protocol`** — encodes RowingSnapshot into the four C2 characteristics (0x0031, 0x0032, 0x0035, 0x0036) using the exact byte layouts from the spec. Handles the 0x0034 sample rate write.

**`FTMSProtocol`** — encodes RowingSnapshot into a single 0x2AD1 Rower Data characteristic with the flags-based variable layout.

### Adding a Future Protocol

A developer creates a new struct conforming to `SimulatedProtocol`, registers it in a `ProtocolRegistry` (a simple dictionary keyed by `id`), and it appears in the UI picker. No other code changes needed.

## Phase 2: Simulation Engine and Profiles

The engine produces a stream of `RowingSnapshot` values at a configurable tick rate. A profile controls the shape of the data over time.

### Profile Model

A profile is a JSON-serializable document describing a workout scenario:

```
SimulationProfile {
    id: UUID
    name: String
    description: String
    segments: [Segment]
    defaults: BaselineConfig
}

Segment {
    type: .warmup | .steady | .interval | .rest | .cooldown | .sprint
    duration: TimeInterval            // seconds
    targetPace: ClosedRange<Double>   // sec/500m — engine interpolates within range
    targetSPM: ClosedRange<Int>
    targetPower: ClosedRange<Int>     // watts
    heartRateRange: ClosedRange<Int>
    dragFactor: Int
    rampCurve: .linear | .easeIn | .easeOut | .easeInOut
}

BaselineConfig {
    heartRateResting: Int
    weight: Double                    // kg — affects calorie calc
    noiseLevel: Double               // 0.0–1.0, how much random jitter
    strokeMechanicsVariance: Double  // how much drive length/force vary stroke to stroke
}
```

### How Segments Work

Each segment defines a target range for the key metrics. The engine:

1. Transitions from the previous segment's ending values to the new segment's target using the specified ramp curve.
2. During steady portions, values fluctuate within the target range with noise controlled by `noiseLevel`.
3. Derived values are computed from physics (e.g., distance accumulates from pace, calories from power via standard rowing formulas, speed from pace).
4. Stroke mechanics (drive length, drive time, recovery time, forces) are derived from pace and SPM using realistic biomechanical relationships, then jittered by `strokeMechanicsVariance`.

### Built-in Presets

Ship with 3-4 presets that cover common testing scenarios:

| Preset | Description | Segments |
|--------|-------------|----------|
| **Steady State 30min** | Consistent 2:05-2:10 pace, 22-24 SPM | warmup(3min) -> steady(24min) -> cooldown(3min) |
| **Interval 8x500m** | Hard/easy alternation | warmup(3min) -> 8x[sprint(~1:45, 30spm, 90sec) + rest(60sec)] -> cooldown(3min) |
| **Easy Recovery** | Light paddle, low rate | warmup(2min) -> steady(2:20-2:30, 18-20 SPM, 20min) -> cooldown(2min) |
| **Race Simulation 2K** | Aggressive start, settle, sprint finish | sprint(30sec, 1:35) -> steady(5.5min, 1:45) -> sprint(1min, 1:38) |

### Tick Loop

The engine runs on a `DispatchSourceTimer` (or `AsyncTimerSequence`) at the configured tick rate (default 500ms to match C2 default). Each tick:

1. Advance elapsed time.
2. Determine current segment and position within it.
3. Compute target values using the ramp curve.
4. Apply noise/jitter.
5. Derive dependent values (distance, calories, stroke mechanics).
6. Produce a `RowingSnapshot`.
7. Publish snapshot to the BLE layer and UI via `@Observable` or Combine.

### Stroke State Machine

Simulate realistic stroke state transitions. At the configured SPM, cycle through:
- Recovery (duration = 60/SPM - driveTime)
- Driving (duration = driveTime, typically 0.7-1.0s depending on pace)

This drives the `strokeState` field in the snapshot (C2 characteristic 0x0031 byte 10).

## Phase 3: BLE Peripheral Manager

A `BLEPeripheralManager` class wrapping `CBPeripheralManager`.

### Responsibilities

- Initialize `CBPeripheralManager` and wait for `.poweredOn`.
- When the user starts a simulation: add services from the selected `SimulatedProtocol`, start advertising with the protocol's service UUIDs and a configurable local name (e.g., "PM5 XXXXXXX" for C2, "FTMS Rower" for FTMS).
- On each tick, receive the encoded characteristic data from the protocol layer and call `updateValue(_:for:onSubscribedCentrals:)`.
- Handle central subscription/unsubscription.
- Handle writes (forward to `SimulatedProtocol.handleWrite`).
- On stop: remove services, stop advertising.

### Advertising Details

**C2 mode:** Advertise with the C2 rowing service UUID (`CE060030-...`). Set the local name to "PM5 " followed by a random 7-digit serial to mimic real PM5 discovery. Include the Device Information Service (0x180A) with manufacturer "Concept2".

**FTMS mode:** Advertise with service UUID `0x1826`. Include the Fitness Machine Feature characteristic (0x2ACC) indicating rower support.

## Phase 4: UI

SwiftUI, multiplatform (iPadOS + macOS). Minimal but functional.

### Screens

**Main Screen — Simulator Control**

- Protocol picker (segmented control or dropdown): C2 PM5 | FTMS | (future entries auto-populated from registry)
- Profile picker: dropdown listing saved and preset profiles
- Start / Stop button
- Status indicator: Idle | Advertising | Connected | Simulating

**Live Data Panel** (visible when simulating)

- Current segment name and progress bar
- Key metrics in a grid: elapsed time, distance, pace, SPM, power, heart rate, stroke count, calories
- Stroke state indicator (driving / recovery)

**Profile Editor** (sheet or navigation push)

- Profile name and description
- List of segments, each editable:
  - Segment type picker
  - Duration stepper
  - Target pace range (min/max sliders or text fields)
  - Target SPM range
  - Ramp curve picker
- Baseline config: resting HR, weight, noise level, stroke variance
- Save / Save As / Delete
- Import/Export JSON (for sharing profiles between devices)

**Settings**

- BLE device name override
- Default tick rate

### Persistence

- Profiles stored as JSON files in the app's documents directory (not SwiftData — profiles are portable and should be easily shared/exported).
- Remove the current SwiftData/Item boilerplate.

## Phase 5: Testing and Validation

### Unit Tests

- Protocol encoders: given a known `RowingSnapshot`, assert the output bytes match the spec exactly. Test edge cases (zero values, max values, boundary conditions).
- Simulation engine: given a profile, run the engine for N ticks and verify values stay within expected ranges, distances accumulate correctly, segment transitions happen at the right times.
- Profile serialization: round-trip encode/decode.

### Integration Testing

- Run ErgSim on one device, connect RowUp on another. Verify RowUp correctly discovers, connects, and displays the simulated data.
- Test both C2 and FTMS modes.
- Test profile transitions (verify RowUp handles pace/SPM changes smoothly).

### Validation Checklist

- [ ] C2 byte layouts match PM5 BLE Interface spec exactly
- [ ] FTMS flags and field order match GATT Rower Data spec
- [ ] Simulated values are physiologically plausible (no 0:30 pace at 15 SPM)
- [ ] Distance accumulation is monotonic and consistent with pace
- [ ] Calorie computation uses standard rowing formula
- [ ] Stroke state transitions happen at correct timing relative to SPM
- [ ] BLE advertising name and services match what a real erg presents
- [ ] Profiles serialize/deserialize without data loss

## File Organization

```
ErgSim/
├── App/
│   └── ErgSimApp.swift
├── Protocols/
│   ├── SimulatedProtocol.swift        // protocol + RowingSnapshot
│   ├── ProtocolRegistry.swift         // discovery/registration
│   ├── C2Protocol.swift               // Concept2 PM5 encoder
│   └── FTMSProtocol.swift             // FTMS encoder
├── Simulation/
│   ├── SimulationEngine.swift         // tick loop, snapshot production
│   ├── SimulationProfile.swift        // profile model, segment, baseline
│   ├── StrokeStateMachine.swift       // drive/recovery cycling
│   ├── PhysicsHelpers.swift           // pace<->speed, calorie formulas
│   └── RampCurve.swift                // interpolation curves
├── BLE/
│   └── BLEPeripheralManager.swift     // CBPeripheralManager wrapper
├── Profiles/
│   ├── ProfileManager.swift           // load, save, list, presets
│   └── Presets/
│       ├── steady-state-30min.json
│       ├── interval-8x500m.json
│       ├── easy-recovery.json
│       └── race-sim-2k.json
├── Views/
│   ├── SimulatorControlView.swift
│   ├── LiveDataPanel.swift
│   ├── ProfileEditorView.swift
│   ├── ProfileListView.swift
│   └── SettingsView.swift
└── Utilities/
    └── ByteEncoding.swift             // little-endian helpers, uint24, etc.
```

## Implementation Order

1. **Phase 1** first — the protocol abstraction is the backbone everything else plugs into.
2. **Phase 2** next — the engine can be tested in isolation (write unit tests) without BLE.
3. **Phase 3** — wire BLE to the engine. At this point you can test with RowUp.
4. **Phase 4** — build the UI around the working engine + BLE stack.
5. **Phase 5** — formalize tests and validate against the specs.

Phases 1 and 2 can be developed in parallel if needed since they share only the `RowingSnapshot` type.
