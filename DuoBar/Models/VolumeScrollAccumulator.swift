import Foundation

struct VolumeScrollAccumulator {
    private var remainder = 0.0
    private var lastTimestamp: TimeInterval?
    private var deviceUID: String?
    private var preciseInput: Bool?

    mutating func reset() { self = Self() }

    mutating func change(deltaY: Double, precise: Bool, inverted: Bool, momentum: Bool,
                         timestamp: TimeInterval, deviceUID: String, beginsGesture: Bool = false) -> Double? {
        guard deltaY.isFinite, timestamp.isFinite, !momentum, deltaY != 0 else { return nil }
        if beginsGesture || self.deviceUID != deviceUID || preciseInput != precise
            || lastTimestamp.map({ timestamp < $0 || timestamp - $0 > 0.4 }) == true {
            reset()
        }
        self.deviceUID = deviceUID
        preciseInput = precise
        lastTimestamp = timestamp
        let delta = inverted ? -deltaY : deltaY
        if remainder != 0, remainder.sign != delta.sign { remainder = 0 }
        // Bound untrusted/accelerated deltas before accumulating. Discard whole
        // excess steps so a fast gesture cannot leave a queue of volume changes.
        let threshold = precise ? 12.0 : 1.0
        remainder += min(max(delta, -threshold * 5), threshold * 5)
        let steps = (remainder / threshold).rounded(.towardZero)
        remainder.formTruncatingRemainder(dividingBy: threshold)
        return steps == 0 ? nil : steps * 0.02
    }
}
