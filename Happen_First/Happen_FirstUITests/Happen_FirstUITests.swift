//
//  Happen_FirstUITests.swift
//  Happen_FirstUITests
//
//  Created by Vanessaw on 30/1/2026.
//

import XCTest

final class Happen_FirstUITests: XCTestCase {
    func testLaunchAndToggleButton() throws {
        let app = XCUIApplication()
        app.launch()
        // 断言按钮存在并点击
        let button = app.buttons.firstMatch
        XCTAssertTrue(button.exists)
        button.tap()
        // 断言 app 状态（需要在 UI 中显示相关标识以供测试）
        // 例如查找文字 "Ready" / "Listening..."
    }
}
