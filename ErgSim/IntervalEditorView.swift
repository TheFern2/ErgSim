import SwiftUI
import SwiftData

struct IntervalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \IntervalConfig.createdAt) private var configs: [IntervalConfig]

    @State private var selectedConfig: IntervalConfig?

    var body: some View {
        HSplitView {
            configList
                .frame(minWidth: 180, maxWidth: 220)
            if let config = selectedConfig {
                StepEditorView(config: config)
            } else {
                Text("Select or create a config")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 650, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var configList: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedConfig) {
                ForEach(configs) { config in
                    Text(config.name)
                        .tag(config)
                        .contextMenu {
                            Button("Delete") { deleteConfig(config) }
                        }
                }
            }

            Divider()

            HStack {
                Button(action: addConfig) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                if selectedConfig != nil {
                    Button(action: { deleteConfig(selectedConfig!) }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }
            .padding(8)
        }
    }

    private func addConfig() {
        let config = IntervalConfig(name: "New Interval")
        modelContext.insert(config)
        selectedConfig = config
    }

    private func deleteConfig(_ config: IntervalConfig) {
        if selectedConfig == config {
            selectedConfig = nil
        }
        modelContext.delete(config)
    }
}

struct StepEditorView: View {
    @Bindable var config: IntervalConfig
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Config Name", text: $config.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(config.sortedSteps) { step in
                        StepRow(step: step, onDelete: { removeStep(step) })
                        Divider()
                    }
                }
                .padding(.horizontal)
            }

            HStack {
                Button("Add Step") { addStep() }
                    .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    private func addStep() {
        let nextOrder = (config.steps.map(\.order).max() ?? -1) + 1
        let step = IntervalStep(order: nextOrder, workDuration: 120, workSendData: true)
        config.steps.append(step)
    }

    private func removeStep(_ step: IntervalStep) {
        config.steps.removeAll { $0.id == step.id }
        modelContext.delete(step)
    }
}

struct StepRow: View {
    @Bindable var step: IntervalStep
    var onDelete: () -> Void

    @State private var workMinutes: Int = 0
    @State private var workSeconds: Int = 0
    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Step \(step.order + 1)")
                    .font(.headline)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Work").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("m", value: $workMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                        Text("m")
                        TextField("s", value: $workSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                        Text("s")
                    }
                    Toggle("Send data", isOn: $step.workSendData)
                        .toggleStyle(.checkbox)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rest").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("m", value: $restMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                        Text("m")
                        TextField("s", value: $restSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                        Text("s")
                    }
                    Toggle("Send data", isOn: $step.restSendData)
                        .toggleStyle(.checkbox)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Repeat").font(.caption).foregroundStyle(.secondary)
                    TextField("N", value: $step.repeatCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Toggle("Loop point", isOn: $step.shouldLoop)
                        .toggleStyle(.checkbox)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { loadDurations() }
        .onChange(of: workMinutes) { _, _ in syncWork() }
        .onChange(of: workSeconds) { _, _ in syncWork() }
        .onChange(of: restMinutes) { _, _ in syncRest() }
        .onChange(of: restSeconds) { _, _ in syncRest() }
    }

    private func loadDurations() {
        workMinutes = Int(step.workDuration) / 60
        workSeconds = Int(step.workDuration) % 60
        restMinutes = Int(step.restDuration) / 60
        restSeconds = Int(step.restDuration) % 60
    }

    private func syncWork() {
        step.workDuration = TimeInterval(workMinutes * 60 + workSeconds)
    }

    private func syncRest() {
        step.restDuration = TimeInterval(restMinutes * 60 + restSeconds)
    }
}
