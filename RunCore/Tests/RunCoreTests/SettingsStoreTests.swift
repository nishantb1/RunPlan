import XCTest
@testable import RunCore

final class SettingsStoreTests: XCTestCase {

    private var directory: URL!
    private var settings: SettingsStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("runcore-\(UUID().uuidString)")
        settings = SettingsStore(store: JSONStore(directory: directory))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDefaultsWhenNothingIsSaved() {
        XCTAssertEqual(settings.load(), AppSettings(keepScreenAwake: true, voiceCues: true, autoPause: false))
    }

    func testSaveThenLoad() throws {
        let changed = AppSettings(keepScreenAwake: false, voiceCues: false, autoPause: true)
        try settings.save(changed)
        XCTAssertEqual(settings.load(), changed)
    }

    func testMissingKeysTakeTheirDefaults() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"voiceCues":false}"#.utf8).write(to: directory.appendingPathComponent("settings.json"))
        XCTAssertEqual(settings.load(), AppSettings(keepScreenAwake: true, voiceCues: false, autoPause: false))
    }

    func testDeleteReturnsToDefaults() throws {
        try settings.save(AppSettings(keepScreenAwake: false, voiceCues: false, autoPause: true))
        settings.delete()
        XCTAssertEqual(settings.load(), AppSettings())
    }
}
