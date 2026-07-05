//
//  ShellExecutorTests.swift
//  PintTests
//

import XCTest
@testable import Pint

final class ShellExecutorTests: XCTestCase {

    /// Brew 6 defaults to "ask mode" (interactive y/N confirmation) for
    /// install/upgrade/reinstall. Pint drives brew over pipes, so the
    /// environment must always opt out or operations hang.
    func testBrewEnvironment_disablesAskModeAndAutoUpdate() {
        let env = ShellExecutor.brewEnvironment()

        XCTAssertEqual(env["HOMEBREW_NO_ASK"], "1")
        XCTAssertEqual(env["HOMEBREW_NO_AUTO_UPDATE"], "1")
        XCTAssertEqual(env["HOMEBREW_NO_INSTALL_CLEANUP"], "1")
        XCTAssertNotNil(env["PATH"])
    }
}
