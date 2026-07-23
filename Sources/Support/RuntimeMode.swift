import Foundation

/// Detects whether the process is running under the XCTest/Swift Testing harness,
/// so the full app (model container, services, windows) isn't booted during unit
/// tests. Two `ModelContainer`s for the same model in one process would trap.
enum RuntimeMode {
    static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
