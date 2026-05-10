import SwiftUI
import RowingBLE
import RowingProtocols
import CoreBluetooth

struct ContentView: View {
    @State private var selectedProtocol: RowingProtocolType = .concept2
    @State private var peripheral = RowingPeripheral(protocolType: .concept2)
    @State private var engine = SimulationEngine()
    @State private var isRunning = false
    @State private var selectedProfileID: String = SimulationProfile.default.id
    @State private var showConsole = false
    @State private var logEntries: [LogEntry] = []
    @State private var decodedFields: [DecodedField] = []

    @State private var spmMin: Int = SimulationProfile.default.spmMin
    @State private var spmMax: Int = SimulationProfile.default.spmMax
    @State private var powerMin: Int = SimulationProfile.default.powerMin
    @State private var powerMax: Int = SimulationProfile.default.powerMax
    @State private var paceMin: Int = Int(SimulationProfile.default.paceMin)
    @State private var paceMax: Int = Int(SimulationProfile.default.paceMax)

    private var isControlsDisabled: Bool { isRunning }

    var body: some View {
        VStack(spacing: 16) {
            Text("ErgSim")
                .font(.largeTitle.bold())

            HStack(alignment: .top, spacing: 20) {
                leftColumn
                rightColumn
            }

            startStopButton
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 500)
        .onChange(of: engine.latestSnapshot) { _, snapshot in
            guard let snapshot else { return }
            if showConsole {
                captureEncodedData(snapshot)
            }
            peripheral.publish(snapshot: snapshot)
        }
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        VStack(spacing: 16) {
            controlsSection
            statusSection
        }
        .frame(width: 300)
    }

    private var controlsSection: some View {
        GroupBox("Controls") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Protocol", selection: $selectedProtocol) {
                    Text("Concept2").tag(RowingProtocolType.concept2)
                    Text("FTMS").tag(RowingProtocolType.ftms)
                }
                .pickerStyle(.segmented)
                .disabled(isControlsDisabled)

                Picker("Profile", selection: $selectedProfileID) {
                    ForEach(SimulationProfile.presets) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                    Text("Custom").tag("custom")
                }
                .disabled(isControlsDisabled)
                .onChange(of: selectedProfileID) { _, newID in
                    if let profile = SimulationProfile.presets.first(where: { $0.id == newID }) {
                        applyProfile(profile)
                    }
                }

                Divider()

                rangeRow("SPM", min: $spmMin, max: $spmMax, range: 16...44)
                rangeRow("Power", min: $powerMin, max: $powerMax, range: 50...500)
                rangeRow("Pace", min: $paceMin, max: $paceMax, range: 70...180)

                Text("Pace in seconds per 500m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rangeRow(_ label: String, min: Binding<Int>, max: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .frame(width: 50, alignment: .leading)
            TextField("Min", value: min, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            Text("-")
            TextField("Max", value: max, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
        }
        .disabled(isControlsDisabled)
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 6) {
                statusRow("Bluetooth", value: peripheral.state == .poweredOn ? "Ready" : "Unavailable",
                          color: peripheral.state == .poweredOn ? .green : .red)
                statusRow("Advertising", value: peripheral.isAdvertising ? "Yes" : "No",
                          color: peripheral.isAdvertising ? .green : .secondary)
                statusRow("Subscribers", value: "\(peripheral.subscribedCentrals)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(color)
        }
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        VStack(spacing: 16) {
            liveDataSection
            if showConsole {
                decodedTableSection
                logConsoleSection
            }
        }
        .frame(minWidth: 320)
    }

    private var liveDataSection: some View {
        GroupBox("Live Data") {
            VStack(alignment: .leading, spacing: 4) {
                dataRow("Time", value: formatTime(engine.elapsedTime))
                dataRow("Distance", value: String(format: "%.0f m", engine.distance))
                dataRow("Stroke Rate", value: "\(engine.currentSPM) spm")
                dataRow("Power", value: "\(engine.currentPower) W")
                dataRow("Pace", value: formatPace(engine.currentPace))
                dataRow("Strokes", value: "\(engine.strokeCount)")
                dataRow("Speed", value: String(format: "%.1f m/s", engine.currentSpeed))
                dataRow("Drive Time", value: String(format: "%.2fs", engine.driveTime))
                dataRow("Recovery", value: String(format: "%.2fs", engine.recoveryTime))

                Divider()

                if let snap = engine.latestSnapshot {
                    dataRow("Workout", value: snap.workoutState.map { "\($0)" } ?? "--")
                    dataRow("Rowing", value: snap.rowingState.map { "\($0)" } ?? "--")
                    dataRow("Stroke", value: snap.strokeState.map { "\($0)" } ?? "--")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var decodedTableSection: some View {
        GroupBox("Decoded Fields") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow {
                    Text("Field").bold()
                    Text("Raw Hex").bold()
                    Text("Decoded").bold()
                }
                .font(.system(.caption, design: .monospaced))
                Divider()
                ForEach(decodedFields) { field in
                    GridRow {
                        Text(field.name)
                        Text(field.hex)
                            .foregroundStyle(.secondary)
                        Text(field.decoded)
                            .foregroundStyle(.green)
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var logConsoleSection: some View {
        GroupBox("Console") {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(logEntries) { entry in
                            Text(entry.text)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: logEntries.count) { _, _ in
                    if let last = logEntries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .frame(height: 120)
            .font(.system(.caption, design: .monospaced))

            HStack {
                Spacer()
                Button("Clear") { logEntries.removeAll() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
    }

    // MARK: - Start/Stop

    private var startStopButton: some View {
        HStack {
            Toggle("Console", isOn: $showConsole)
                .toggleStyle(.checkbox)

            Spacer()

            Button(isRunning ? "Stop" : "Start") {
                if isRunning { stop() } else { start() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRunning ? .red : .green)
        }
    }

    // MARK: - Actions

    private func start() {
        syncProfileToEngine()
        peripheral = RowingPeripheral(protocolType: selectedProtocol)
        let name = selectedProtocol == .concept2 ? "ErgSim C2" : "ErgSim FTMS"
        peripheral.startAdvertising(name: name)
        engine.start()
        isRunning = true
    }

    private func stop() {
        engine.stop()
        peripheral.stopAdvertising()
        isRunning = false
    }

    private func applyProfile(_ profile: SimulationProfile) {
        spmMin = profile.spmMin
        spmMax = profile.spmMax
        powerMin = profile.powerMin
        powerMax = profile.powerMax
        paceMin = Int(profile.paceMin)
        paceMax = Int(profile.paceMax)
    }

    private func syncProfileToEngine() {
        engine.profile = SimulationProfile(
            id: "active",
            name: "Active",
            spmMin: spmMin, spmMax: Swift.max(spmMin, spmMax),
            powerMin: powerMin, powerMax: Swift.max(powerMin, powerMax),
            paceMin: TimeInterval(paceMin), paceMax: TimeInterval(Swift.max(paceMin, paceMax))
        )
    }

    private func captureEncodedData(_ snapshot: RowingSnapshot) {
        var fields: [DecodedField] = []
        var logLines: [String] = []
        let timestamp = formatTime(snapshot.elapsedTime ?? 0)

        if selectedProtocol == .concept2 {
            let gs = C2GeneralStatus.encode(snapshot)
            let as1 = C2AdditionalStatus1.encode(snapshot)
            let sd = C2StrokeData.encode(snapshot)
            let asd = C2AdditionalStrokeData.encode(snapshot)

            fields.append(contentsOf: decodeC2GeneralStatus(gs, snapshot))
            fields.append(contentsOf: decodeC2AdditionalStatus1(as1, snapshot))
            fields.append(contentsOf: decodeC2StrokeData(sd, snapshot))
            fields.append(contentsOf: decodeC2AdditionalStrokeData(asd, snapshot))

            logLines.append("[\(timestamp)] GS: \(hexString(gs))")
            logLines.append("[\(timestamp)] AS1: \(hexString(as1))")
            logLines.append("[\(timestamp)] SD: \(hexString(sd))")
            logLines.append("[\(timestamp)] ASD: \(hexString(asd))")
        } else {
            let rd = FTMSRowerData.encode(snapshot)
            fields.append(contentsOf: decodeFTMSRowerData(rd, snapshot))
            logLines.append("[\(timestamp)] RD: \(hexString(rd))")
        }

        decodedFields = fields
        for line in logLines {
            logEntries.append(LogEntry(text: line))
        }
    }

    private func decodeC2GeneralStatus(_ data: Data, _ snap: RowingSnapshot) -> [DecodedField] {
        [
            DecodedField(name: "elapsedTime", hex: hexSlice(data, 0..<3), decoded: String(format: "%.2fs", snap.elapsedTime ?? 0)),
            DecodedField(name: "distance", hex: hexSlice(data, 3..<6), decoded: String(format: "%.1fm", snap.distance ?? 0)),
            DecodedField(name: "workoutState", hex: hexSlice(data, 8..<9), decoded: snap.workoutState.map { "\($0)" } ?? "--"),
            DecodedField(name: "rowingState", hex: hexSlice(data, 9..<10), decoded: snap.rowingState.map { "\($0)" } ?? "--"),
            DecodedField(name: "strokeState", hex: hexSlice(data, 10..<11), decoded: snap.strokeState.map { "\($0)" } ?? "--"),
        ]
    }

    private func decodeC2AdditionalStatus1(_ data: Data, _ snap: RowingSnapshot) -> [DecodedField] {
        [
            DecodedField(name: "speed", hex: hexSlice(data, 3..<5), decoded: String(format: "%.3f m/s", snap.speed ?? 0)),
            DecodedField(name: "strokeRate", hex: hexSlice(data, 5..<6), decoded: "\(snap.strokeRate ?? 0) spm"),
            DecodedField(name: "pace", hex: hexSlice(data, 7..<9), decoded: formatPace(snap.pace ?? 0)),
        ]
    }

    private func decodeC2StrokeData(_ data: Data, _ snap: RowingSnapshot) -> [DecodedField] {
        [
            DecodedField(name: "driveTime", hex: hexSlice(data, 7..<8), decoded: String(format: "%.2fs", snap.driveTime ?? 0)),
            DecodedField(name: "recoveryTime", hex: hexSlice(data, 8..<10), decoded: String(format: "%.2fs", snap.recoveryTime ?? 0)),
            DecodedField(name: "strokeCount", hex: hexSlice(data, 18..<20), decoded: "\(snap.strokeCount ?? 0)"),
        ]
    }

    private func decodeC2AdditionalStrokeData(_ data: Data, _ snap: RowingSnapshot) -> [DecodedField] {
        [
            DecodedField(name: "power", hex: hexSlice(data, 3..<5), decoded: "\(snap.power ?? 0) W"),
        ]
    }

    private func decodeFTMSRowerData(_ data: Data, _ snap: RowingSnapshot) -> [DecodedField] {
        var fields: [DecodedField] = []
        fields.append(DecodedField(name: "flags", hex: hexSlice(data, 0..<2), decoded: ""))
        if let sr = snap.strokeRate {
            fields.append(DecodedField(name: "strokeRate", hex: hexSlice(data, 2..<3), decoded: "\(sr) spm"))
        }
        if let p = snap.power {
            fields.append(DecodedField(name: "power", hex: "", decoded: "\(p) W"))
        }
        if let d = snap.distance {
            fields.append(DecodedField(name: "distance", hex: "", decoded: String(format: "%.0fm", d)))
        }
        if let e = snap.elapsedTime {
            fields.append(DecodedField(name: "elapsedTime", hex: "", decoded: String(format: "%.0fs", e)))
        }
        return fields
    }

    private func hexSlice(_ data: Data, _ range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return "--" }
        return data[range].map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: TimeInterval) -> String {
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /500m", mins, secs)
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

#Preview {
    ContentView()
}
