# RowingKit Swift Package

## Purpose

Reusable library for any rowing app. Two modules in one package:

- **RowingProtocols** — pure Swift, no platform imports. Data types, enums, UUIDs, byte encode/decode. Usable anywhere including server-side Swift or data analysis tools.
- **RowingBLE** — imports CoreBluetooth, depends on RowingProtocols. Provides ready-to-use central (connect to ergs) and peripheral (simulate an erg) managers. A new app imports this module and gets BLE rowing connectivity without touching CoreBluetooth directly.

No UI in either module.

## Repository

Standalone repo (e.g., `RowingKit`). Apps add it via SPM:

```swift
.package(url: "https://github.com/<org>/RowingKit.git", from: "0.1.0")

// In target dependencies, pick what you need:
.product(name: "RowingProtocols", package: "RowingKit"),  // just data
.product(name: "RowingBLE", package: "RowingKit"),        // full BLE stack
```

## Package.swift Skeleton

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RowingKit",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(name: "RowingProtocols", targets: ["RowingProtocols"]),
        .library(name: "RowingBLE", targets: ["RowingBLE"]),
    ],
    targets: [
        .target(name: "RowingProtocols"),
        .target(name: "RowingBLE", dependencies: ["RowingProtocols"]),
        .testTarget(name: "RowingProtocolsTests", dependencies: ["RowingProtocols"]),
        .testTarget(name: "RowingBLETests", dependencies: ["RowingBLE"]),
    ]
)
```

## Package Structure

```
RowingKit/
├── Package.swift
├── Sources/
│   ├── RowingProtocols/
│   │   ├── Core/
│   │   │   ├── RowingSnapshot.swift
│   │   │   ├── RowingDataProvider.swift
│   │   │   └── RowingEnums.swift
│   │   ├── UUIDs/
│   │   │   ├── C2UUIDs.swift
│   │   │   ├── FTMSUUIDs.swift
│   │   │   └── CommonUUIDs.swift
│   │   ├── ByteCoding/
│   │   │   ├── ByteReader.swift
│   │   │   ├── ByteWriter.swift
│   │   │   └── ByteConstants.swift
│   │   ├── C2/
│   │   │   ├── C2GeneralStatus.swift
│   │   │   ├── C2AdditionalStatus1.swift
│   │   │   ├── C2StrokeData.swift
│   │   │   ├── C2AdditionalStrokeData.swift
│   │   │   └── C2SampleRate.swift
│   │   └── FTMS/
│   │       └── FTMSRowerData.swift
│   └── RowingBLE/
│       ├── Central/
│       │   ├── RowingCentral.swift
│       │   ├── ProtocolDetector.swift
│       │   ├── C2CentralSession.swift
│       │   ├── FTMSCentralSession.swift
│       │   └── DiscoveredRower.swift
│       ├── Peripheral/
│       │   ├── RowingPeripheral.swift
│       │   ├── C2PeripheralSession.swift
│       │   └── FTMSPeripheralSession.swift
│       └── Shared/
│           ├── BLEState.swift
│           └── BLEConfiguration.swift
└── Tests/
    ├── RowingProtocolsTests/
    │   ├── ByteCodingTests.swift
    │   ├── C2RoundTripTests.swift
    │   └── FTMSRoundTripTests.swift
    └── RowingBLETests/
        ├── ProtocolDetectorTests.swift
        └── SessionTests.swift
```

## Module 1: RowingProtocols

### RowingSnapshot

The canonical representation of rowing state at a point in time. Every field is optional — not all protocols populate all fields.

```swift
public struct RowingSnapshot: Sendable, Equatable {
    public var elapsedTime: TimeInterval?
    public var distance: Double?               // meters
    public var strokeRate: Int?                 // SPM
    public var strokeCount: Int?
    public var pace: TimeInterval?             // sec per 500m
    public var averagePace: TimeInterval?
    public var speed: Double?                  // m/s
    public var power: Int?                     // watts
    public var averagePower: Int?
    public var heartRate: Int?                 // bpm, nil or 255 = invalid
    public var calories: Int?                  // total kcal
    public var caloriesPerHour: Int?
    public var caloriesPerMinute: Int?
    public var dragFactor: Int?
    public var driveLength: Double?            // meters
    public var driveTime: TimeInterval?
    public var recoveryTime: TimeInterval?
    public var strokeDistance: Double?          // meters per stroke
    public var peakDriveForce: Double?         // lbs
    public var avgDriveForce: Double?          // lbs
    public var workPerStroke: Double?          // joules
    public var workoutState: WorkoutState?
    public var rowingState: RowingState?
    public var strokeState: StrokeState?
    public var workoutType: WorkoutType?
    public var ergMachineType: ErgMachineType?
    public var resistanceLevel: Int?
    public var metabolicEquivalent: Double?    // METs
    public var remainingTime: TimeInterval?
    public var projectedWorkTime: TimeInterval?
    public var projectedWorkDistance: Double?
}
```

ErgSim's simulation engine produces a fully-populated snapshot, hands it to the encoder which picks the relevant fields. RowUp's decoders produce sparse snapshots (only what the erg sent).

### RowingDataProvider

Consumer-side protocol. Any app that connects to an erg gets data through this.

```swift
public protocol RowingDataProvider: AnyObject, Observable {
    var id: String { get }
    var displayName: String { get }
    var protocolType: RowingProtocolType { get }
    var connectionState: ConnectionState { get }
    var latestSnapshot: RowingSnapshot? { get }
    var snapshotStream: AsyncStream<RowingSnapshot> { get }
}

public enum RowingProtocolType: String, Sendable {
    case concept2
    case ftms
    case watchCoreMotion
}

public enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}
```

### Enums

```swift
public enum WorkoutState: UInt8, Sendable, Codable {
    case waitToBegin = 0
    case rowing = 1
    case intervalRest = 3
    case end = 10
    case terminate = 11
}

public enum RowingState: UInt8, Sendable, Codable {
    case inactive = 0
    case active = 1
}

public enum StrokeState: UInt8, Sendable, Codable {
    case waitingMinSpeed = 0
    case waitingAccel = 1
    case driving = 2
    case dwelling = 3
    case recovery = 4
}

public enum WorkoutType: UInt8, Sendable, Codable {
    case justRow = 0
    case fixedDistance = 2
    case fixedTime = 4
    case timeInterval = 6
    case distanceInterval = 7
}

public enum ErgMachineType: UInt8, Sendable, Codable {
    case staticD = 0
    case staticE = 5
    case ski = 128
    case bike = 192
}
```

### ByteReader and ByteWriter

Symmetric APIs so encode/decode logic mirrors each other.

```swift
public struct ByteReader {
    private let data: Data
    private(set) var offset: Int

    public init(_ data: Data)

    public mutating func readUInt8() -> UInt8
    public mutating func readUInt16LE() -> UInt16
    public mutating func readUInt24LE() -> UInt32
    public mutating func readInt16LE() -> Int16
    public mutating func skip(_ count: Int)
    public var remaining: Int { get }
}

public struct ByteWriter {
    private(set) var data: Data

    public init(capacity: Int)

    public mutating func writeUInt8(_ value: UInt8)
    public mutating func writeUInt16LE(_ value: UInt16)
    public mutating func writeUInt24LE(_ value: UInt32)
    public mutating func writeInt16LE(_ value: Int16)
    public mutating func pad(_ count: Int)
}
```

### Per-Characteristic Encode/Decode

Each characteristic exposes a symmetric pair:

```swift
public enum C2GeneralStatus {
    public static func encode(_ snapshot: RowingSnapshot) -> Data
    public static func decode(_ data: Data) -> RowingSnapshot
}
```

- `encode` builds the BLE notification payload (used by RowingBLE peripheral side).
- `decode` parses incoming notifications (used by RowingBLE central side).
- Both use ByteWriter/ByteReader — the byte layout is defined exactly once.

FTMS follows the same pattern but `FTMSRowerData.encode` also constructs the flags bitfield based on which snapshot fields are non-nil.

## Module 2: RowingBLE

### Central Side (connecting to ergs)

The central API a rowing app uses:

```swift
@Observable
public final class RowingCentral {
    public var state: CBManagerState { get }
    public var discoveredRowers: [DiscoveredRower] { get }
    public var connectedProviders: [any RowingDataProvider] { get }

    public init(configuration: BLEConfiguration = .default)

    public func startScanning()
    public func stopScanning()
    public func connect(_ rower: DiscoveredRower) async throws -> any RowingDataProvider
    public func disconnect(_ provider: any RowingDataProvider)
}

public struct DiscoveredRower: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let protocolType: RowingProtocolType
    public let rssi: Int
    public let peripheral: CBPeripheral
}
```

Internally, `RowingCentral` uses `ProtocolDetector` to inspect advertised service UUIDs and determine whether a discovered peripheral is C2 or FTMS. On connect, it creates the appropriate session (`C2CentralSession` or `FTMSCentralSession`) which subscribes to the relevant characteristics, decodes notifications using RowingProtocols, and publishes snapshots through the `RowingDataProvider` interface.

### Peripheral Side (simulating an erg)

The peripheral API ErgSim (or any test harness) uses:

```swift
@Observable
public final class RowingPeripheral {
    public var state: CBManagerState { get }
    public var isAdvertising: Bool { get }
    public var subscribedCentrals: Int { get }

    public init(protocolType: RowingProtocolType, configuration: BLEConfiguration = .default)

    public func startAdvertising(name: String)
    public func stopAdvertising()
    public func publish(snapshot: RowingSnapshot)
}
```

Internally, `RowingPeripheral` creates the appropriate session (`C2PeripheralSession` or `FTMSPeripheralSession`) which builds CBMutableServices, encodes snapshots using RowingProtocols, and calls `updateValue` on subscribed characteristics.

### BLEConfiguration

```swift
public struct BLEConfiguration: Sendable {
    public var restoreIdentifier: String?
    public var scanDuplicates: Bool
    public var connectionTimeout: TimeInterval
    public var c2SampleRate: C2SampleRate

    public static let `default` = BLEConfiguration(
        restoreIdentifier: nil,
        scanDuplicates: false,
        connectionTimeout: 10.0,
        c2SampleRate: .ms500
    )
}

public enum C2SampleRate: UInt8, Sendable {
    case sec1 = 0
    case ms500 = 1
    case ms250 = 2
    case ms100 = 3
}
```

### How a New App Uses RowingBLE

Minimal integration — connect to whatever erg is nearby:

```swift
import RowingBLE

@Observable class WorkoutManager {
    let central = RowingCentral()
    var provider: (any RowingDataProvider)?

    func start() {
        central.startScanning()
    }

    func connectToFirst() async throws {
        guard let rower = central.discoveredRowers.first else { return }
        provider = try await central.connect(rower)
        for await snapshot in provider!.snapshotStream {
            // use snapshot.pace, snapshot.power, etc.
        }
    }
}
```

The app never imports CoreBluetooth, never parses bytes, never thinks about C2 vs FTMS differences.

## Adding a Future Protocol

### In RowingProtocols

1. Add a new directory (e.g., `Sources/RowingProtocols/WaterRowerS4/`)
2. Add encode/decode files for the protocol's characteristics using ByteReader/ByteWriter
3. Add a UUIDs file
4. Add round-trip tests
5. Add a case to `RowingProtocolType`

### In RowingBLE

1. Add the new service UUID to `ProtocolDetector`
2. Create a `<Protocol>CentralSession` conforming to internal session protocol
3. Create a `<Protocol>PeripheralSession` if simulator support is desired
4. Both sessions use the encode/decode from RowingProtocols

No changes to the public API (`RowingCentral`, `RowingPeripheral`, `RowingDataProvider`). The new protocol just works.

## Testing Strategy

### RowingProtocols Tests

The primary test is the **round-trip**: encode a snapshot, decode the resulting bytes, assert decoded matches original within the protocol's resolution limits.

```swift
func testC2GeneralStatusRoundTrip() {
    let original = RowingSnapshot(
        elapsedTime: 125.50,
        distance: 432.7,
        workoutState: .rowing,
        rowingState: .active,
        strokeState: .driving,
        dragFactor: 120
    )
    let data = C2GeneralStatus.encode(original)
    XCTAssertEqual(data.count, 19)
    let decoded = C2GeneralStatus.decode(data)
    XCTAssertEqual(decoded.elapsedTime!, 125.50, accuracy: 0.01)
    XCTAssertEqual(decoded.distance!, 432.7, accuracy: 0.1)
    XCTAssertEqual(decoded.workoutState, .rowing)
    XCTAssertEqual(decoded.dragFactor, 120)
}
```

Additional tests:
- Boundary values (0, max for each field size)
- FTMS flag combinations (all flags set, none set, various subsets)
- FTMS bit 0 inversion behavior
- ByteReader/ByteWriter independently

### RowingBLE Tests

- `ProtocolDetector`: given service UUIDs, returns correct `RowingProtocolType`
- Session lifecycle: mock CBPeripheral, verify correct characteristics are subscribed
- Peripheral session: verify `updateValue` is called with correctly encoded data
- State machine: verify `ConnectionState` transitions

## Which Apps Import What

| App | Imports | Uses |
|-----|---------|------|
| **RowUp** | `RowingBLE` | `RowingCentral` to scan and connect, `RowingDataProvider` for data |
| **ErgSim** | `RowingBLE` | `RowingPeripheral` to advertise and publish snapshots |
| **Future rowing app** | `RowingBLE` | Same as RowUp — scan, connect, get snapshots |
| **Data analysis tool** | `RowingProtocols` only | Decode recorded BLE captures without CoreBluetooth |
| **RowUp Watch** | Neither | Uses WatchConnectivity, not BLE (but could conform to `RowingDataProvider` locally) |

## Versioning

Semantic versioning. Apps pin to a compatible range.

| Version | Milestone |
|---------|-----------|
| 0.1.0 | RowingProtocols: core types, byte coding, C2 encode/decode |
| 0.2.0 | RowingProtocols: FTMS encode/decode |
| 0.3.0 | RowingBLE: central side (scan, connect, C2 + FTMS sessions) |
| 0.4.0 | RowingBLE: peripheral side |
| 1.0.0 | Stable API, used by ErgSim and RowUp in production |
