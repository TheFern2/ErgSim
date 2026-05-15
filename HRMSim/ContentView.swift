import SwiftUI
import RowingBLE
import RowingProtocols
import CoreBluetooth

struct ContentView: View {
    @State private var peripheral = RowingPeripheral(protocolType: .heartRateMonitor)
    @State private var engine = HRSimulationEngine()
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("HRMSim")
                .font(.largeTitle.bold())

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

            GroupBox("Heart Rate") {
                VStack(spacing: 8) {
                    Text("\(engine.currentHeartRate)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Picker("Profile", selection: $engine.selectedProfile) {
                ForEach(HRSimulationEngine.Profile.allCases) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isRunning)

            Button(isRunning ? "Stop" : "Start") {
                if isRunning { stop() } else { start() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRunning ? .red : .green)
        }
        .padding(24)
        .frame(width: 300, height: 350)
        .onChange(of: engine.currentHeartRate) { _, hr in
            guard isRunning else { return }
            peripheral.publish(snapshot: RowingSnapshot(heartRate: hr))
        }
    }

    private func start() {
        peripheral.startAdvertising(name: "HRMSim")
        engine.start()
        isRunning = true
    }

    private func stop() {
        engine.stop()
        peripheral.stopAdvertising()
        isRunning = false
    }

    private func statusRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(color)
        }
    }
}

#Preview {
    ContentView()
}
