/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

class ScreenGraphTest: XCTestCase {
    var navigator: Navigator<TestUserState>!
    var app: XCUIApplication!

    override func setUp() {
        app = XCUIApplication()
        navigator = createTestGraph(app).navigator(self)
        app.terminate()
        restart(app, args: [LaunchArguments.ClearProfile, LaunchArguments.SkipIntro])
    }

    func restart(_ app: XCUIApplication, args: [String] = []) {
        XCUIDevice.shared().press(.home)
        var launchArguments = [LaunchArguments.Test]
        args.forEach { arg in
            launchArguments.append(arg)
        }
        app.launchArguments = launchArguments
        app.activate()
    }
}

extension ScreenGraphTest {
    func testUserStateChanges() {
        XCTAssertNil(navigator.userState.url, "Current url is empty")
        navigator.goto(BrowserTab)

        XCTAssertTrue(navigator.userState.url?.starts(with: "support.mozilla.org") ?? false, "Current url recorded by from the url bar")
    }

    func testBackStack() {
        // We'll go through the browser tab, through the menu.
        navigator.goto(SettingsScreen)
        // Going back, there is no explicit way back to the browser tab,
        // and the menu will have dismissed. We should be detecting the existence of
        // elements as we go through each screen state, so if there are errors, they'll be
        // reported in the graph below.
        navigator.goto(BrowserTab)
    }
}

class TestUserState: UserState {
    required init() {
        super.init()
        initialScreenState = FirstRun
    }

    var url: String? = nil
}

fileprivate func createTestGraph(_ app: XCUIApplication) -> ScreenGraph<TestUserState> {
    let map = ScreenGraph(with: TestUserState.self)

    map.addScreenState(FirstRun) { screenState in
        screenState.noop(to: BrowserTab)
    }

    map.addScreenState(BrowserTab) { screenState in
        screenState.onEnter("exists != true", element: app.progressIndicators.element(boundBy: 0)) { userState in
            userState.url = app.textFields["url"].value as? String
        }

        screenState.tap(app.buttons["TabToolbar.menuButton"], to: BrowserTabMenu)
    }

    map.addScreenState(BrowserTabMenu) { screenState in
        screenState.dismissOnUse = true
        screenState.onEnter(element: app.tables["Context Menu"])
        screenState.tap(app.tables.cells["Settings"], to: SettingsScreen)

        screenState.backAction = {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        }
    }

    let navigationControllerBackAction = {
        app.navigationBars.element(boundBy: 0).buttons.element(boundBy: 0).tap()
    }

    map.addScreenState(SettingsScreen) { screenState in
        screenState.backAction = navigationControllerBackAction
    }

    return map
}
