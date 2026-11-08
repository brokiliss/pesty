import XCTest
@testable import Pesty

/// Guards the loading path, not just the tables: the two keys below used to be
/// written with lowercase `\u` escapes, which old-style plist parsing does not
/// decode, so the stored key never matched what the code looks up.
final class LocalizationTests: XCTestCase {
    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: "appLanguage")
    }

    override func tearDown() {
        LocalizationManager.shared.language = AppLanguage(rawValue: originalLanguage ?? "") ?? .system
        // Setting the language writes the raw value back; restore an absent key
        // as absent rather than as the string "system".
        if let originalLanguage {
            UserDefaults.standard.set(originalLanguage, forKey: "appLanguage")
        } else {
            UserDefaults.standard.removeObject(forKey: "appLanguage")
        }
        super.tearDown()
    }

    func testChineseLookupCoversTheKeysThatUsedToBeEscaped() {
        LocalizationManager.shared.language = .chineseSimplified

        let curlyQuoteKey = "No matches for \u{201C}%@\u{201D}"
        XCTAssertEqual(curlyQuoteKey.localized, "没有与\u{201C}%@\u{201D}匹配的结果")
        let apostropheKey = "Match each clip to its source app\u{2019}s familiar card color."
        XCTAssertTrue(
            apostropheKey.localized.contains("来源应用"),
            "expected Chinese, got \(apostropheKey.localized)"
        )
    }

    func testNewSettingsStringsResolve() {
        LocalizationManager.shared.language = .chineseSimplified
        XCTAssertEqual("Search".localized, "搜索")
        XCTAssertEqual("Pesty Settings".localized, "Pesty 设置")
        XCTAssertEqual("Play sound when a clip is copied".localized, "复制时播放音效")
        XCTAssertEqual("Sound volume".localized, "音效音量")
        XCTAssertEqual(
            "Clear the image cache after the bar closes".localized,
            "面板收起后清空图片缓存"
        )
    }

    func testBothTablesShareOneKeySet() {
        let en = table(for: "en")
        let zh = table(for: "zh-Hans")
        XCTAssertFalse(en.isEmpty)
        XCTAssertEqual(Set(en.keys), Set(zh.keys))
    }

    private func table(for code: String) -> [String: String] {
        guard let resource = Bundle.module.resourceURL else { return [:] }
        let candidates = [
            resource.appendingPathComponent("Resources/\(code).lproj/Localizable.strings"),
            resource.appendingPathComponent("\(code).lproj/Localizable.strings"),
        ]
        for url in candidates {
            if let dict = NSDictionary(contentsOf: url) as? [String: String] { return dict }
        }
        return [:]
    }
}
