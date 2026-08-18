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

    /// `brew update-if-needed` is a thin wrapper around brew's `auto-update`
    /// helper, which returns immediately when HOMEBREW_NO_AUTO_UPDATE is set.
    /// Leaving the variable in place would make the command a silent no-op.
    func testBrewEnvironment_allowAutoUpdate_clearsNoAutoUpdate() {
        let env = ShellExecutor.brewEnvironment(allowAutoUpdate: true)

        XCTAssertNil(env["HOMEBREW_NO_AUTO_UPDATE"])
        XCTAssertEqual(env["HOMEBREW_NO_ASK"], "1")
        XCTAssertEqual(env["HOMEBREW_NO_INSTALL_CLEANUP"], "1")
    }
}
