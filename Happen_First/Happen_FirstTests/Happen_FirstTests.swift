//
//  Happen_FirstTests.swift
//  Happen_FirstTests
//
//  Created by Vanessaw on 30/1/2026.
//

import XCTest
@testable import Happen_First

final class Happen_FirstTests: XCTestCase {
    func testAppStateToggle() {
        let s = AppState()
        XCTAssertFalse(s.isActive)
        s.isActive = true
        XCTAssertTrue(s.isActive)
    }
}
