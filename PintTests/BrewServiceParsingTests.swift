//
//  BrewServiceParsingTests.swift
//  PintTests
//
//  Tests the JSON → BrewPackage parsing logic in BrewService without
//  needing a real brew binary. All fixtures are static JSON strings.
//

import XCTest
@testable import Pint

final class BrewServiceParsingTests: XCTestCase {

    private let service = BrewService()

    // MARK: - Fixtures

    // swiftlint:disable line_length
    private static let wgetFormulaJSON = #"{"formulae":[{"name":"wget","desc":"Internet file retriever","homepage":"https://www.gnu.org/software/wget/","installed":[{"version":"1.21.4","installed_on_request":true}],"outdated":false,"pinned":false,"caveats":null,"versions":{"stable":"1.21.4"}}],"casks":[]}"#

    private static let pinnedOutdatedFormulaJSON = #"{"formulae":[{"name":"openssl","desc":"Cryptography and SSL/TLS Toolkit","homepage":"https://openssl.org","installed":[{"version":"3.1.0","installed_on_request":false}],"outdated":true,"pinned":true,"caveats":null,"versions":{"stable":"3.2.0"}}],"casks":[]}"#

    private static let formulaWithCaveatsJSON = #"{"formulae":[{"name":"mysql","desc":"Open source relational database","homepage":"https://dev.mysql.com","installed":[{"version":"8.0.33","installed_on_request":true}],"outdated":false,"pinned":false,"caveats":"We've installed your MySQL database without a root password.","versions":{"stable":"8.0.33"}}],"casks":[]}"#

    private static let formulaEmptyCaveatsJSON = #"{"formulae":[{"name":"curl","desc":"Get a file from HTTP/FTP","homepage":"https://curl.se","installed":[{"version":"8.1.2","installed_on_request":true}],"outdated":false,"pinned":false,"caveats":"","versions":{"stable":"8.1.2"}}],"casks":[]}"#

    private static let dependencyFormulaJSON = #"{"formulae":[{"name":"libidn2","desc":"International domain name library","homepage":"https://www.gnu.org/software/libidn/#libidn2","installed":[{"version":"2.3.4","installed_on_request":false}],"outdated":false,"pinned":false,"caveats":null,"versions":{"stable":"2.3.4"}}],"casks":[]}"#

    private static let outdatedBothJSON = #"{"formulae":[{"name":"wget","installed_versions":["1.21.3"],"current_version":"1.21.4"}],"casks":[{"name":"firefox","installed_versions":["119.0"],"current_version":"120.0"}]}"#

    private static let outdatedUnsortedJSON = #"{"formulae":[{"name":"zsh","installed_versions":["5.9"],"current_version":"5.9.1"},{"name":"awk","installed_versions":["1.3"],"current_version":"1.4"}],"casks":[]}"#
    // swiftlint:enable line_length

    // MARK: - parseInstalledFormulae

    func testParseFormula_basic() {
        let packages = service.parseInstalledFormulae(Self.wgetFormulaJSON)
        XCTAssertEqual(packages.count, 1)
        let pkg = packages[0]
        XCTAssertEqual(pkg.name, "wget")
        XCTAssertEqual(pkg.version, "1.21.4")
        XCTAssertEqual(pkg.description, "Internet file retriever")
        XCTAssertEqual(pkg.homepage, "https://www.gnu.org/software/wget/")
        XCTAssertEqual(pkg.type, .formula)
        XCTAssertFalse(pkg.isOutdated)
        XCTAssertFalse(pkg.isPinned)
        XCTAssertTrue(pkg.installedOnRequest)
        XCTAssertNil(pkg.caveats)
    }

    func testParseFormula_idFormat() {
        let packages = service.parseInstalledFormulae(Self.wgetFormulaJSON)
        XCTAssertEqual(packages[0].id, "formula-wget")
    }

    func testParseFormula_pinnedAndOutdated() {
        let packages = service.parseInstalledFormulae(Self.pinnedOutdatedFormulaJSON)
        XCTAssertEqual(packages.count, 1)
        let pkg = packages[0]
        XCTAssertTrue(pkg.isPinned)
        XCTAssertTrue(pkg.isOutdated)
        XCTAssertFalse(pkg.installedOnRequest)
        XCTAssertEqual(pkg.latestVersion, "3.2.0")
    }

    func testParseFormula_withCaveats() {
        let packages = service.parseInstalledFormulae(Self.formulaWithCaveatsJSON)
        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].caveats, "We've installed your MySQL database without a root password.")
    }

    func testParseFormula_emptyCaveatsBecomesNil() {
        // brew can return "" instead of null — must be normalised to nil so the
        // Caveats section isn't rendered with empty content.
        let packages = service.parseInstalledFormulae(Self.formulaEmptyCaveatsJSON)
        XCTAssertEqual(packages.count, 1)
        XCTAssertNil(packages[0].caveats, "Empty caveats string should be normalised to nil")
    }

    func testParseFormula_dependency_notInstalledOnRequest() {
        let packages = service.parseInstalledFormulae(Self.dependencyFormulaJSON)
        XCTAssertEqual(packages.count, 1)
        XCTAssertFalse(packages[0].installedOnRequest)
    }

    func testParseFormula_malformedJSON_returnsEmpty() {
        XCTAssertTrue(service.parseInstalledFormulae("{not valid json").isEmpty)
    }

    func testParseFormula_emptyFormulaeArray_returnsEmpty() {
        XCTAssertTrue(service.parseInstalledFormulae(#"{"formulae":[],"casks":[]}"#).isEmpty)
    }

    // MARK: - parseInstalledCasks

    func testParseCasks_basic() {
        let packages = service.parseInstalledCasks("firefox 120.0\nvisual-studio-code 1.80.1\n")
        XCTAssertEqual(packages.count, 2)
        XCTAssertEqual(packages[0].name, "firefox")
        XCTAssertEqual(packages[0].version, "120.0")
        XCTAssertEqual(packages[0].type, .cask)
        XCTAssertEqual(packages[1].name, "visual-studio-code")
        XCTAssertEqual(packages[1].version, "1.80.1")
    }

    func testParseCasks_idFormat() {
        let packages = service.parseInstalledCasks("firefox 120.0\n")
        XCTAssertEqual(packages[0].id, "cask-firefox")
    }

    func testParseCasks_emptyOutput_returnsEmpty() {
        XCTAssertTrue(service.parseInstalledCasks("").isEmpty)
    }

    func testParseCasks_multiWordVersion() {
        // Some cask versions contain spaces (e.g. "1.0 arm64").
        let packages = service.parseInstalledCasks("some-cask 1.0 arm64\n")
        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].version, "1.0 arm64")
    }

    // MARK: - parseOutdated

    func testParseOutdated_formulaAndCask() throws {
        let packages = service.parseOutdated(Self.outdatedBothJSON)
        XCTAssertEqual(packages.count, 2)
        let formula = try XCTUnwrap(packages.first { $0.type == .formula })
        let cask    = try XCTUnwrap(packages.first { $0.type == .cask })
        XCTAssertEqual(formula.name, "wget")
        XCTAssertEqual(formula.currentVersion, "1.21.3")
        XCTAssertEqual(formula.latestVersion, "1.21.4")
        XCTAssertTrue(formula.isOutdated)
        XCTAssertEqual(cask.name, "firefox")
        XCTAssertEqual(cask.currentVersion, "119.0")
        XCTAssertEqual(cask.latestVersion, "120.0")
        XCTAssertTrue(cask.isOutdated)
    }

    func testParseOutdated_sortedAlphabetically() {
        let packages = service.parseOutdated(Self.outdatedUnsortedJSON)
        XCTAssertEqual(packages.map { $0.name }, ["awk", "zsh"])
    }

    func testParseOutdated_malformedJSON_returnsEmpty() {
        XCTAssertTrue(service.parseOutdated("{bad json}").isEmpty)
    }

    func testParseOutdated_emptyArrays_returnsEmpty() {
        XCTAssertTrue(service.parseOutdated(#"{"formulae":[],"casks":[]}"#).isEmpty)
    }
}
