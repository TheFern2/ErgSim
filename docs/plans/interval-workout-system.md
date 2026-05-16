# Interval Workout System for ErgSim

## Context

ErgSim currently runs a free-form workout that starts and runs indefinitely until stopped. For testing the companion rowing app, we need structured interval workouts (e.g., 2min work / 1.5min rest) with control over BLE data publishing per phase. This lets us simulate realistic interval sessions and test how the app handles gaps in data, transitions, and looping patterns.

## Summary of Changes

1. **Pause/Resume** on running workouts
2. **SwiftData models** for interval configs (named presets with ordered steps)
3. **IntervalCoordinator** to manage work/rest phase transitions
4. **Rest phase behavior**: engine keeps ticking with zeroed rowing metrics, HR drifts toward resting
5. **Single profile** for all steps (existing profile picker applies to entire workout)
6. **Interval editor UI** (sheet) for CRUD on saved configs
7. **Inline progress display** during interval workouts

## New Files

### `ErgSim/IntervalModels.swift`

Two SwiftData `@Model` classes:

**IntervalStep**:
- `order: Int` (position in sequence)
- `workDuration: TimeInterval` (seconds)
- `workSendData: Bool` (publish BLE during work)
- `restDuration: TimeInterval?` (nil = no rest phase)
- `restSendData: Bool` (publish BLE during rest)
- `repeatCount: Int` (how many times to repeat this step before advancing, default 1)
- `shouldLoop: Bool` (marks this step as the loop-back target)
- `@Relationship(inverse:) var config: IntervalConfig?`

**IntervalConfig**:
- `name: String`
- `createdAt: Date`
- `@Relationship(deleteRule: .cascade) var steps: [IntervalStep]`
- Computed `sortedSteps` property (sorted by `order`)

**Loop logic**: When all steps complete, find the first step where `shouldLoop == true`. If one exists, restart from that step (steps before it act as a warmup and only execute once). If no step has `shouldLoop`, the workout ends.

### `ErgSim/IntervalCoordinator.swift`

`@Observable` class managing interval execution:

- `Phase` enum: `.idle`, `.work`, `.rest`, `.completed`
- Tracks: `currentPhase`, `currentStepIndex`, `currentRepeat`, `phaseElapsedTime`, `phaseTotalDuration`
- Publishes `shouldPublishBLE: Bool` (derived from current phase's send-data flag)
- `tick(tickInterval:)` called by engine every 0.25s; handles phase transitions
- `start(with:)`, `stop()`, `reset()`
- Step advancement: after a step's work+rest completes, increment `currentRepeat`. If `currentRepeat < repeatCount`, replay that step. Otherwise advance to next step.
- When all steps complete: find first step with `shouldLoop == true`. If found, restart from that step. Otherwise set phase to `.completed`.

### `ErgSim/IntervalEditorView.swift`

Sheet with:
- Left sidebar: list of saved configs with add/delete buttons
- Right panel: edit selected config (name, loop toggle, ordered list of steps)
- Each step row: work duration field, send-data toggle, optional rest duration, rest send-data toggle
- Add/remove/reorder step controls

## Modified Files

### `ErgSim/SimulationEngine.swift`

- Add `isPaused: Bool` property
- Add `isRestPhase: Bool` (set externally by view based on coordinator state)
- Add `pause()`: invalidates timer, sets `isPaused = true`
- Add `resume()`: recreates timer, sets `isPaused = false`
- Modify `tick()`: when `isRestPhase`, zero out SPM/power/pace/speed, skip stroke logic, call `updateHeartRateTowardResting()` instead
- Add `updateHeartRateTowardResting()`: drift HR toward resting range (similar to existing `updateHeartRate` but targeting rest mid)
- Still calls `buildSnapshot()` during rest so elapsed time keeps updating

### `ErgSim/ContentView.swift`

- Add `.paused` case to `SimState` enum
- Add state: `@State private var intervalCoordinator = IntervalCoordinator()`
- Add state: `@State private var selectedIntervalConfig: IntervalConfig?`
- Add state: `@State private var showIntervalEditor = false`
- Add `@Query` for saved configs
- Add `@Environment(\.modelContext)` for passing to editor
- Controls section: add interval config picker (Menu or Picker) + "Edit" button to open sheet
- Start/Stop section: add Pause button (`.running` state), Resume button (`.paused` state)
- `onChange(of: engine.latestSnapshot)`: gate BLE publishing on `intervalCoordinator.shouldPublishBLE` (or always publish when no interval config active)
- New `onChange(of: engine.elapsedTime)` or integrate into tick: advance coordinator, sync `engine.isRestPhase`, handle `.completed`
- Add interval progress GroupBox (visible when coordinator is active): step N of M, phase, time remaining, loop indicator
- `startWorkout()`: if config selected, start coordinator with it
- `stop()`: also stop coordinator
- `.sheet(isPresented: $showIntervalEditor)` for IntervalEditorView

### `ErgSim/ErgSimApp.swift`

- Replace `Item.self` in schema with `IntervalConfig.self, IntervalStep.self`

### `ErgSim/Item.swift`

- Delete (replaced by IntervalModels)

## Implementation Order

1. Create `IntervalModels.swift` + update `ErgSimApp.swift` schema + delete `Item.swift`
2. Add pause/resume + `isRestPhase` to `SimulationEngine`
3. Create `IntervalCoordinator.swift`
4. Create `IntervalEditorView.swift`
5. Wire everything together in `ContentView.swift`

## Verification

- Build the project in Xcode (or `xcodebuild`)
- Launch the app: verify existing free-run workflow still works (broadcast -> start workout -> stop)
- Test pause/resume: start workout, pause, verify data stops, resume, verify data continues
- Create an interval config via editor: e.g., "Test 10s/5s" with 10s work, 5s rest
- Start workout with interval config: verify work phase produces data, rest phase zeros metrics
- Test "send data" toggles: uncheck work send-data, verify BLE stops during work
- Test loop: with loop on, verify intervals restart after completing all steps
- Test completion: with loop off, verify workout stops after all intervals complete
