enum AccessorySectionVisibility {
    static func showsSection(hideEmpty: Bool, deviceCount: Int, hasError: Bool) -> Bool {
        !hideEmpty || deviceCount > 0 || hasError
    }
}
