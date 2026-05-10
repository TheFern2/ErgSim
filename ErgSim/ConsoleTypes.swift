import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let text: String
}

struct DecodedField: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    let decoded: String
}
