# RowUp — Project Summary & Technical Reference

## Overview

RowUp is an indoor rowing companion app that connects to rowing ergometers via Bluetooth and to an Apple Watch via WatchConnectivity. It captures real-time workout data from multiple sources and unifies them into a single rowing experience.

---

## Project Structure

| Target | Platform | Purpose |
|--------|----------|---------|
| **RowUp** | iOS + iPadOS | Main rowing app — connects to ergs, displays workout data |
| **RowUp Watch** | watchOS | Core Motion stroke detection (strokes, SPM, power estimation) |
| **ErgSim** | iPadOS + macOS (Multiplatform) | Dev tool — simulates a C2 PM5 or FTMS rower over BLE for testing |
| **RowingProtocols** | Swift Package | Shared BLE protocol parsing, byte formats, `RowingDataProvider` abstraction |

ErgSim and RowUp **cannot run on the same device** — one is the BLE peripheral, the other the central. Two devices are always needed for BLE testing.

---

## Supported Protocols

### 1. Concept2 PM5 (Proprietary BLE)

The most open and data-rich protocol. C2 actively supports third-party developers.

- **Base UUID:** `CE06xxxx-43E5-11E4-916C-0800200C9A66`
- **Rowing Service:** `0x0030`
- **Does NOT use FTMS** — entirely proprietary, predates FTMS, and provides far more data

#### Key Characteristics

**`0x0031` — General Status (19 bytes)**

| Byte | Field | Resolution |
|------|-------|------------|
| 0–2 | Elapsed Time | 0.01 sec |
| 3–5 | Distance | 0.1 m |
| 6 | Workout Type | enum |
| 7 | Interval Type | enum |
| 8 | Workout State | enum |
| 9 | Rowing State | enum (0=inactive, 1=active) |
| 10 | Stroke State | enum (2=driving, 4=recovery) |
| 11–13 | Total Work Distance | 1 m |
| 14–16 | Workout Duration | 0.01 sec or meters |
| 17 | Workout Duration Type | enum (0x00=time, 0x80=dist, 0x40=cals) |
| 18 | Drag Factor | unitless |

**`0x0032` — Additional Status 1 (17 bytes)**

| Byte | Field | Resolution |
|------|-------|------------|
| 0–2 | Elapsed Time | 0.01 sec |
| 3–4 | Speed | 0.001 m/s |
| 5 | Stroke Rate | strokes/min |
| 6 | Heart Rate | bpm (255=invalid) |
| 7–8 | Current Pace | 0.01 sec per 500m |
| 9–10 | Average Pace | 0.01 sec per 500m |
| 11–12 | Rest Distance | meters |
| 13–15 | Rest Time | 0.01 sec |
| 16 | Erg Machine Type | enum |

**`0x0035` — Stroke Data (20 bytes)**

| Byte | Field | Resolution |
|------|-------|------------|
| 0–2 | Elapsed Time | 0.01 sec |
| 3–5 | Distance | 0.1 m |
| 6 | Drive Length | 0.01 m (max 2.55m) |
| 7 | Drive Time | 0.01 sec (max 2.55s) |
| 8–9 | Stroke Recovery Time | 0.01 sec |
| 10–11 | Stroke Distance | 0.01 m |
| 12–13 | Peak Drive Force | 0.1 lbs |
| 14–15 | Avg Drive Force | 0.1 lbs |
| 16–17 | Work Per Stroke | 0.1 Joules |
| 18–19 | Stroke Count | count |

**`0x0036` — Additional Stroke Data (15 bytes)**

| Byte | Field | Resolution |
|------|-------|------------|
| 0–2 | Elapsed Time | 0.01 sec |
| 3–4 | Stroke Power | watts |
| 5–6 | Stroke Calories | cals/hr |
| 7–8 | Stroke Count | count |
| 9–11 | Projected Work Time | seconds |
| 12–14 | Projected Work Distance | meters |

**`0x0034` — Sample Rate (1 byte, write)**

| Value | Rate |
|-------|------|
| 0 | 1 sec |
| 1 | 500ms (default) |
| 2 | 250ms |
| 3 | 100ms |

#### C2 Enums

```
Workout Type: 0=JustRow, 2=FixedDist, 4=FixedTime, 6=TimeInterval, 7=DistInterval
Workout State: 0=WaitToBegin, 1=Rowing, 3=IntervalRest, 10=End, 11=Terminate
Rowing State:  0=Inactive, 1=Active
Stroke State:  0=WaitingMinSpeed, 1=WaitingAccel, 2=Driving, 3=Dwelling, 4=Recovery
Erg Type:      0=StaticD, 5=StaticE, 128=Ski, 192=Bike
```

#### C2 Resources

- [PM5 BLE Interface Spec (PDF)](http://www.concept2.cn/files/pdf/us/monitors/PM5_BluetoothSmartInterfaceDefinition.pdf)
- [Concept2 iOS SDK (GitHub)](https://github.com/AerosportTechnology/Concept2-SDK) — MIT license
- [Concept2 Software Development page](https://www.concept2.com/support/software-development)

---

### 2. FTMS (Fitness Machine Service — Bluetooth SIG Standard)

Standard BLE protocol supported by NordicTrack, WaterRower (S4), LifeFitness, First Degree Fitness, and many others.

- **Service UUID:** `0x1826`
- **Rower Data Characteristic:** `0x2AD1` (notify)
- **All data is little-endian**

#### Rower Data Byte Layout

The packet starts with a 2-byte flags bitfield. **Bit 0 is inverted** — when bit 0 = 0, stroke rate and stroke count ARE present.

| Flag Bit | Controls | Fields (if set) | Size |
|----------|----------|-----------------|------|
| 0 (inverted) | Stroke Rate + Count | uint8 (rate × 2) + uint16 (count) | 3 bytes |
| 1 | Avg Stroke Rate | uint8 (× 2) | 1 byte |
| 2 | Total Distance | uint24 (meters) | 3 bytes |
| 3 | Instantaneous Pace | uint16 (sec/500m) | 2 bytes |
| 4 | Average Pace | uint16 (sec/500m) | 2 bytes |
| 5 | Instantaneous Power | sint16 (watts) | 2 bytes |
| 6 | Average Power | sint16 (watts) | 2 bytes |
| 7 | Resistance Level | sint16 | 2 bytes |
| 8 | Expended Energy | uint16 + uint16 + uint8 (total kcal, kcal/hr, kcal/min) | 5 bytes |
| 9 | Heart Rate | uint8 (bpm) | 1 byte |
| 10 | Metabolic Equivalent | uint8 (METs × 10) | 1 byte |
| 11 | Elapsed Time | uint16 (seconds) | 2 bytes |
| 12 | Remaining Time | uint16 (seconds) | 2 bytes |

#### FTMS Caveats

- Not all machines send all fields — parse flags defensively, never assume a field exists
- Some machines send zero for power or pace even when advertised
- Pace resolution is 1 sec (vs C2's 0.01 sec) — much coarser
- No equivalent of drag factor, drive force, drive length, or force curves
- Accuracy of stroke rate varies significantly between machine types

#### FTMS Resources

- [FTMS Spec (PDF)](https://www.onelap.cn/pdf/FTMS_v1.0.pdf)
- [GATT Rower Data XML (GitHub)](https://github.com/oesmith/gatt-xml/blob/master/org.bluetooth.characteristic.rower_data.xml)
- [FTMS-Bluetooth Swift Package](https://github.com/gamma/FTMS-Bluetooth)
- [FDF Bluetooth Developer Zone](https://fdflimited.com/wp-content/uploads/bluetooth/FDF_BluetoothConsole_FTMS_Specification_V1.21.pdf)

---

### 3. Apple Watch (WatchConnectivity + Core Motion)

Not a BLE protocol — the watch runs its own stroke detection algorithm using Core Motion (accelerometer + gyroscope) and sends computed results to the iPhone.

**Data provided:** Stroke count, SPM, power estimate, heart rate

**Testing approach:** Use a real watch or mock the `WCSession` in code. ErgSim does not simulate this path.

---

## Data Source Architecture

RowUp receives rowing data from three independent sources. All conform to a shared `RowingDataProvider` protocol:

| Source | Connection | Data Richness | Needs Erg? |
|--------|-----------|---------------|------------|
| C2 PM5 | CoreBluetooth (central) | Highest — stroke mechanics, drag, force curves | Yes |
| FTMS Rower | CoreBluetooth (central) | Basic — pace, power, SPM, distance, calories | Yes |
| Apple Watch | WatchConnectivity | Core Motion derived — SPM, strokes, power estimate, HR | No |

When multiple sources are active, the app needs a data fusion strategy (e.g., prefer erg for pace/distance, prefer watch for HR).

---

## Key Protocol Differences: C2 vs FTMS

| Aspect | Concept2 PM5 | FTMS |
|--------|-------------|------|
| Pace resolution | 0.01 sec | 1 sec |
| Force data | Peak + avg drive force (lbs) | Not available |
| Drive mechanics | Drive length, drive time, recovery time | Not available |
| Drag factor | Yes | Not available |
| Force curves | Yes (characteristic 0x003D) | Not available |
| Work per stroke | Yes (Joules) | Not available |
| Workout state machine | Full (wait, row, rest, intervals, end) | Not available |
| Sample rate control | Configurable (100ms–1s) | Machine-dependent |
| Field presence | Fixed layout, all fields always present | Flag-based, varies by machine |

---

## Testing Without Hardware

| Approach | What It Tests | Setup |
|----------|--------------|-------|
| **ErgSim (iPad/Mac)** | Full BLE connection, discovery, parsing for C2 and FTMS | Run on separate device from RowUp |
| **Nordic CoreBluetooth Mock** | BLE in Xcode Simulator, no physical device needed | Swift Package, define mock peripherals |
| **Protocol-level mock** | App logic, UI, data flow — no Bluetooth at all | `MockRowingProvider` conforming to shared protocol |
| **Real Apple Watch** | Core Motion stroke detection | Wear watch, do air strokes or row |

---

## Erg Compatibility Summary

| Machine | Protocol | Open? |
|---------|----------|-------|
| Concept2 (PM5) | Proprietary C2 BLE | Yes — public spec, SDK, logbook API |
| WaterRower (S4 monitor) | FTMS | Yes |
| NordicTrack | FTMS | Yes |
| LifeFitness | FTMS | Yes |
| First Degree Fitness | FTMS | Yes — has developer docs |
| Ergatta | FTMS (gated) | Partially — may require active subscription |
| Hydrow | Proprietary | No |
| Peloton Row | Proprietary | No |

---

## Next Steps

1. Build **RowingProtocols** Swift Package (shared byte parsing, `RowingDataProvider` protocol)
2. Build **ErgSim** (iPadOS + macOS multiplatform app, `CBPeripheralManager`)
3. Build **RowUp** BLE connection layer (CoreBluetooth central, protocol detection)
4. Build **RowUp Watch** app (Core Motion stroke detection, WatchConnectivity)
5. Add HR monitor support (BLE service `0x180D`, characteristic `0x2A37`)