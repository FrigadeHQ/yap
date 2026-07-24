import Foundation

/// Under the test harness the app must not boot: a second `ModelContainer` for
/// the same model in one process would trap.
enum RuntimeMode {
    static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
