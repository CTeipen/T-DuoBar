import Combine
import Foundation

@MainActor
final class AccessoryBatteryService: ObservableObject {
    @Published private(set) var accessories: [AccessoryBattery] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var lastRefresh = Date.distantPast

    func start() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard refreshTask == nil, Date().timeIntervalSince(lastRefresh) >= 60 else { return }
        lastRefresh = Date()
        isRefreshing = true
        refreshTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Self.readReport() }.value
            guard let self, !Task.isCancelled else { return }
            self.accessories = result ?? []
            self.errorMessage = result == nil ? localized("Accessory battery data unavailable") : nil
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    nonisolated private static func readReport() -> [AccessoryBattery]? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("duobar-batteries-\(UUID().uuidString).json")
        guard FileManager.default.createFile(atPath: url.path, contents: nil),
              let output = try? FileHandle(forWritingTo: url) else { return nil }
        defer { try? output.close(); try? FileManager.default.removeItem(at: url) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(10)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
            guard !process.isRunning else { process.terminate(); return nil }
            guard process.terminationStatus == 0 else { return nil }
            try output.synchronize()
            let data = try Data(contentsOf: url)
            return try AccessoryBatteryParser.parse(data)
        } catch { return nil }
    }

    deinit { timer?.invalidate(); refreshTask?.cancel() }
}
