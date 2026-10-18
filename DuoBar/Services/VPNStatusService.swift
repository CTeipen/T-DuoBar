import Combine
import Foundation

@MainActor
final class VPNStatusService: ObservableObject {
    @Published private(set) var status = VPNStatus.unavailable
    @Published private(set) var isRefreshing = false
    private(set) var isMonitoring = false

    private let reader: @Sendable () async -> VPNStatus
    private let monitor: any VPNChangeMonitoring
    private var refreshTask: Task<Void, Never>?
    private var generation = 0
    private var needsRefresh = false

    init(reader: @escaping @Sendable () async -> VPNStatus = {
        guard !Task.isCancelled else { return .unavailable }
        let worker = Task.detached(priority: .utility) { () -> VPNStatus in
            guard !Task.isCancelled else { return .unavailable }
            return SystemConfigurationVPNReader.read()
        }
        return await withTaskCancellationHandler(operation: {
            await worker.value
        }, onCancel: {
            worker.cancel()
        })
    }, monitor: (any VPNChangeMonitoring)? = nil) {
        self.reader = reader
        self.monitor = monitor ?? SystemConfigurationVPNMonitor()
    }

    func start() {
        guard !isMonitoring else { return }
        generation &+= 1
        let expectedGeneration = generation
        isMonitoring = true
        guard monitor.start(onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == expectedGeneration else { return }
                self.refresh()
            }
        }) else {
            isMonitoring = false
            status = .unavailable
            return
        }
        refresh()
    }

    func refresh() {
        guard isMonitoring else { return }
        guard refreshTask == nil else {
            needsRefresh = true
            return
        }
        let expectedGeneration = generation
        isRefreshing = true
        refreshTask = Task { [weak self, reader] in
            guard !Task.isCancelled else { return }
            let value = await reader()
            guard !Task.isCancelled, let self, self.isMonitoring,
                  self.generation == expectedGeneration else { return }
            if self.status != value { self.status = value }
            self.isRefreshing = false
            self.refreshTask = nil
            if self.needsRefresh {
                self.needsRefresh = false
                self.refresh()
            }
        }
    }

    func stop() {
        generation &+= 1
        isMonitoring = false
        monitor.stop()
        refreshTask?.cancel()
        refreshTask = nil
        if isRefreshing { isRefreshing = false }
        needsRefresh = false
    }

    deinit { refreshTask?.cancel() }
}
