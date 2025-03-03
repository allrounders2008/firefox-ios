// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

let standardBlockedElementsString = "Firefox blocks cross-site trackers, social trackers, cryptominers, and fingerprinters."
let strictBlockedElementsString = "Firefox blocks cross-site trackers, social trackers, cryptominers, fingerprinters, and tracking content."

let websiteWithBlockedElements = "twitter.com"
let differentWebsite = path(forTestPage: "test-example.html")

class TrackingProtectionTests: BaseTestCase {
    // Smoketest
    func testTrackingProtection() {
        navigator.goto(URLBarOpen)
        waitForExistence(app.buttons["urlBar-cancel"], timeout: TIMEOUT_LONG)
        navigator.back()
        navigator.goto(TrackingProtectionSettings)

        // Make sure ETP is enabled by default
        XCTAssertTrue(app.switches["prefkey.trackingprotection.normalbrowsing"].isEnabled)

        // Turn off ETP
        navigator.performAction(Action.SwitchETP)

        // Verify it is turned off
        navigator.openURL(path(forTestPage: "test-mozilla-org.html"))
        waitUntilPageLoad()

        // The lock icon should still be there
        waitForExistence(app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection])
        waitForExistence(app.buttons[AccessibilityIdentifiers.Toolbar.settingsMenuButton], timeout: 5)

        // Switch to Private Browsing
        navigator.toggleOn(userState.isPrivate, withAction: Action.TogglePrivateMode)
        navigator.openURL(path(forTestPage: "test-mozilla-org.html"))
        waitUntilPageLoad()

        // Make sure TP is also there in PBM
        waitForExistence(app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection])
        waitForExistence(app.buttons[AccessibilityIdentifiers.Toolbar.settingsMenuButton], timeout: TIMEOUT)
        navigator.goto(BrowserTabMenu)
        waitForExistence(app.tables.otherElements[ImageIdentifiers.settings], timeout: 5)
        app.tables.otherElements[ImageIdentifiers.settings].tap()
        navigator.nowAt(SettingsScreen)
        waitForExistence(app.tables.cells["NewTab"], timeout: 5)
        app.tables.cells["NewTab"].swipeUp()
        // Enable TP again
        navigator.goto(TrackingProtectionSettings)
        // Turn on ETP
        navigator.performAction(Action.SwitchETP)
    }

    private func disableEnableTrackingProtectionForSite() {
        navigator.performAction(Action.TrackingProtectionperSiteToggle)
    }

    private func checkTrackingProtectionDisabledForSite() {
        waitForNoExistence(app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection])
    }

    private func checkTrackingProtectionEnabledForSite() {
        navigator.goto(TrackingProtectionContextMenuDetails)
        waitForExistence(app.cells.staticTexts["Enhanced Tracking Protection is ON for this site."])
    }

    private func enableStrictMode() {
        navigator.performAction(Action.EnableStrictMode)

        // Dismiss the alert and go back to the site
        app.alerts.buttons.firstMatch.tap()
        app.buttons["Done"].tap()
    }

    func testETPLockMenu() {
        navigator.openURL(differentWebsite)
        waitUntilPageLoad()
        waitForExistence(app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection])
        navigator.goto(TrackingProtectionContextMenuDetails)
        waitForExistence(app.staticTexts["Connection is not secure"], timeout: 5)
        var switchValue = app.switches.firstMatch.value!
        // Need to make sure first the setting was not turned off previously
        if switchValue as! String == "0" {
            app.switches.firstMatch.tap()
        }
        switchValue = app.switches.firstMatch.value!
        XCTAssertEqual(switchValue as! String, "1")

        app.switches.firstMatch.tap()
        let switchValueOFF = app.switches.firstMatch.value!
        XCTAssertEqual(switchValueOFF as! String, "0")

        // Open TP Settings menu
        app.buttons["Protection Settings"].tap()
        waitForExistence(app.navigationBars["Tracking Protection"], timeout: 5)
        let switchSettingsValue = app.switches["prefkey.trackingprotection.normalbrowsing"].value!
        XCTAssertEqual(switchSettingsValue as! String, "1")
        app.switches["prefkey.trackingprotection.normalbrowsing"].tap()
        // Disable ETP from setting and check that it applies to the site
        app.buttons["Settings"].tap()
        app.buttons["Done"].tap()
        navigator.nowAt(BrowserTab)
        navigator.goto(TrackingProtectionContextMenuDetails)
        waitForExistence(app.staticTexts["Connection is not secure"], timeout: 5)
        XCTAssertFalse(app.switches.element.exists)
    }

    func testBasicMoreInfo() {
        navigator.nowAt(NewTabScreen)
        navigator.goto(TrackingProtectionSettings)
        // See Basic mode info
        app.cells["Settings.TrackingProtectionOption.BlockListBasic"].buttons["More Info"].tap()
        XCTAssertTrue(app.navigationBars["Client.TPAccessoryInfo"].exists)
        XCTAssertTrue(app.cells.staticTexts["Social Trackers"].exists)
        XCTAssertTrue(app.cells.staticTexts["Cross-Site Trackers"].exists)
        XCTAssertTrue(app.cells.staticTexts["Fingerprinters"].exists)
        XCTAssertTrue(app.cells.staticTexts["Cryptominers"].exists)
        XCTAssertFalse(app.cells.staticTexts["Tracking content"].exists)

        // Go back to TP settings
        app.buttons["Tracking Protection"].tap()

        // See Strict mode info
        app.cells["Settings.TrackingProtectionOption.BlockListStrict"].buttons["More Info"].tap()
        XCTAssertTrue(app.cells.staticTexts["Tracking content"].exists)

        // Go back to TP settings
        app.buttons["Tracking Protection"].tap()
    }

    // https://testrail.stage.mozaws.net/index.php?/cases/view/1510468
    func testLockIconSecureConnection() {
        navigator.openURL("https://www.Mozilla.org")
        waitUntilPageLoad()
        // Tap "Secure connection"
        navigator.goto(TrackingProtectionContextMenuDetails)
        // A page displaying the connection is secure
        XCTAssertTrue(app.staticTexts["mozilla.org"].exists)
        XCTAssertTrue(app.staticTexts["Connection is secure"].exists, "Missing Connection is secure info")
        XCTAssertEqual(app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection].label, "Secure connection")
        // Dismiss the view and visit "badssl.com". Tap on "expired"
        app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection].tap(force: true)
        navigator.nowAt(BrowserTab)
        navigator.openURL("https://www.badssl.com")
        waitUntilPageLoad()
        app.links["expired"].tap()
        waitUntilPageLoad()
        // The page is correctly displayed with the lock icon disabled
        XCTAssertTrue(app.staticTexts["This Connection is Untrusted"].exists, "Missing This Connection is Untrusted info")
        XCTAssertTrue(app.staticTexts.elementContainingText("Firefox has not connected to this website.").exists)
        XCTAssertEqual(app.buttons[AccessibilityIdentifiers.Toolbar.trackingProtection].label, "Connection not secure")
    }
}
