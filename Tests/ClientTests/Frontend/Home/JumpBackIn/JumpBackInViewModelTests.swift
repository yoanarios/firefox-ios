// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

@testable import Client
import XCTest
import WebKit
import Storage
import Shared
import Common

class JumpBackInViewModelTests: XCTestCase {
    var mockProfile: MockProfile!
    var mockTabManager: MockTabManager!

    var stubBrowserViewController: BrowserViewController!
    var adaptor: JumpBackInDataAdaptorMock!

    let iPhone14ScreenSize = CGSize(width: 390, height: 844)

    override func setUp() {
        super.setUp()

        DependencyHelperMock().bootstrapDependencies()
        adaptor = JumpBackInDataAdaptorMock()
        mockProfile = MockProfile()
        mockTabManager = MockTabManager()
        stubBrowserViewController = BrowserViewController(
            profile: mockProfile,
            tabManager: TabManager(profile: mockProfile, imageStore: nil)
        )

        FeatureFlagsManager.shared.initializeDeveloperFeatures(with: mockProfile)
    }

    override func tearDown() {
        super.tearDown()
        AppContainer.shared.reset()
        adaptor = nil
        stubBrowserViewController = nil
        mockTabManager = nil
        mockProfile = nil
    }

    // MARK: - Switch to group

    func test_switchToGroup_noBrowserDelegate_doNothing() {
        let subject = createSubject()
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [], timestamp: 0)
        var completionDidRun = false
        subject.onTapGroup = { tab in
            completionDidRun = true
        }

        subject.switchTo(group: group)

        XCTAssertFalse(completionDidRun)
    }

    func test_switchToGroup_noGroupedItems_doNothing() {
        let subject = createSubject()
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [], timestamp: 0)
        var completionDidRun = false
        subject.onTapGroup = { tab in
            completionDidRun = true
        }

        subject.switchTo(group: group)

        XCTAssertFalse(completionDidRun)
    }

    func test_switchToGroup_callCompletionOnFirstGroupedItem() {
        let subject = createSubject()
        let expectedTab = createTab(profile: mockProfile)
        let group = ASGroup<Tab>(searchTerm: "", groupedItems: [expectedTab], timestamp: 0)
        var receivedTab: Tab?
        subject.onTapGroup = { tab in
            receivedTab = tab
        }

        subject.switchTo(group: group)

        XCTAssertEqual(expectedTab, receivedTab)
    }

    // MARK: - Switch to tab

    func test_switchToTab_notInOverlayMode_switchTabs() {
        let subject = createSubject()
        let tab = createTab(profile: mockProfile)

        subject.switchTo(tab: tab)

        XCTAssertFalse(mockTabManager.lastSelectedTabs.isEmpty)
    }

    func test_switchToTab_inOverlayMode_leaveOverlayMode() {
        let subject = createSubject()
        let tab = createTab(profile: mockProfile)

        subject.switchTo(tab: tab)

        XCTAssertFalse(mockTabManager.lastSelectedTabs.isEmpty)
    }

    func test_switchToTab_tabManagerSelectsTab() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile)

        subject.switchTo(tab: tab1)

        guard !mockTabManager.lastSelectedTabs.isEmpty else {
            XCTFail("No tabs were selected in mock tab manager.")
            return
        }
        XCTAssertEqual(mockTabManager.lastSelectedTabs[0], tab1)
    }

    // MARK: - Jump back in layout

    func testMaxJumpBackInItemsToDisplay_compactJumpBackIn() {
        let subject = createSubject()

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: false,
                                                               device: .phone)
        XCTAssertEqual(maxItems.tabsCount, 2)
        XCTAssertEqual(maxItems.syncedTabCount, 0)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)
    }

    func testMaxJumpBackInItemsToDisplay_compactSyncedTab() {
        let subject = createSubject()
        subject.featureFlags.set(feature: .jumpBackInSyncedTab, to: true)
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 0)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .compactSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_compactJumpBackInAndSyncedTab() {
        let subject = createSubject()
        subject.featureFlags.set(feature: .jumpBackInSyncedTab, to: true)
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 1)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackInAndSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_mediumIphone() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.mockHasSyncedTabFeatureEnabled = false

        // iPhone layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 4)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .medium)
    }

    func testMaxJumpBackInItemsToDisplay_mediumWithSyncedTabIphone() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        // iPhone layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 2)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .mediumWithSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_mediumIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.mockHasSyncedTabFeatureEnabled = false

        // iPad layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .pad)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .pad)

        XCTAssertEqual(maxItems.tabsCount, 4)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .medium)
    }

    func testMaxJumpBackInItemsToDisplay_mediumWithSyncedTabIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        // iPad layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .pad)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .pad)

        XCTAssertEqual(maxItems.tabsCount, 2)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .mediumWithSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_regularIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.mockHasSyncedTabFeatureEnabled = false

        // iPad layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .pad)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .pad)

        XCTAssertEqual(maxItems.tabsCount, 6)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .regular)
    }

    // This case should never happen on a real device
    func testMaxJumpBackInItemsToDisplay_regularIphone() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.mockHasSyncedTabFeatureEnabled = false

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 6)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .regular)
    }

    func testMaxJumpBackInItemsToDisplay_regularWithSyncedTabIpad() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        // iPad layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .pad)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .pad)

        XCTAssertEqual(maxItems.tabsCount, 4)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .regularWithSyncedTab)
    }

    // This case should never happen on a real device
    func testMaxJumpBackInItemsToDisplay_regularWithSyncedTabIphone() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 4)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .regularWithSyncedTab)
    }

    func testMaxJumpBackInItemsToDisplay_mediumWithSyncedTabIphone_hasNoSyncedTabFallsIntoMediumLayout() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]

        // iPhone layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .phone)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .phone)

        XCTAssertEqual(maxItems.tabsCount, 4)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .medium)
    }

    func testMaxJumpBackInItemsToDisplay_regularWithSyncedTabIpad_hasNoSyncedTabFallsIntoRegularLayout() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]

        // iPad layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .pad)
        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .pad)

        XCTAssertEqual(maxItems.tabsCount, 6)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
        XCTAssertEqual(subject.sectionLayout, .regular)
    }

    func testUpdateLayoutSectionBeforeRefreshData() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab2 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab3 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1, tab2, tab3]
        subject.didLoadNewData()

        // Start in portrait
        let portraitTrait = MockTraitCollection()
        portraitTrait.overridenHorizontalSizeClass = .compact
        portraitTrait.overridenVerticalSizeClass = .regular

        subject.refreshData(for: portraitTrait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)

        // Mock rotation to landscape
        let landscapeTrait = MockTraitCollection()
        landscapeTrait.overridenHorizontalSizeClass = .regular
        landscapeTrait.overridenVerticalSizeClass = .compact
        subject.refreshData(for: landscapeTrait, size: iPhone14ScreenSize, isPortrait: false, device: .phone)
        XCTAssertEqual(subject.sectionLayout, .medium)

        // Go back to portrait
        subject.refreshData(for: portraitTrait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)
    }

    // MARK: - Sync tab layout

    func testMaxDisplayedItemSyncedTab_withAccount() {
        let subject = createSubject()

        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: true,
                                                               device: .pad)
        XCTAssertEqual(maxItems.tabsCount, 2)
        XCTAssertEqual(maxItems.syncedTabCount, 1)
    }

    func testMaxDisplayedItemSyncedTab_withoutAccount() {
        let subject = createSubject()

        let maxItems = subject.sectionLayout.maxItemsToDisplay(hasAccount: false,
                                                               device: .pad)
        XCTAssertEqual(maxItems.tabsCount, 2)
        XCTAssertEqual(maxItems.syncedTabCount, 0)
    }

    // MARK: Refresh data

    func testRefreshData_noData() {
        let subject = createSubject()
        subject.didLoadNewData()
        subject.refreshData(for: MockTraitCollection(), size: iPhone14ScreenSize)

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNil(subject.mostRecentSyncedTab)
    }

    func testRefreshData_jumpBackInList() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        subject.didLoadNewData()
        subject.refreshData(for: MockTraitCollection(), size: iPhone14ScreenSize)

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 1)
        XCTAssertNil(subject.mostRecentSyncedTab)
    }

    func testRefreshData_syncedTab() {
        let subject = createSubject()
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)

        subject.didLoadNewData()
        subject.refreshData(for: MockTraitCollection(), size: iPhone14ScreenSize)

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNotNil(subject.mostRecentSyncedTab)
    }

    // MARK: - End to end

    func testCompactJumpBackIn_withThreeJumpBackInTabs() {
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab2 = createTab(profile: mockProfile, urlString: "www.firefox2.com")
        let tab3 = createTab(profile: mockProfile, urlString: "www.firefox3.com")
        adaptor.recentTabs = [tab1, tab2, tab3]
        let subject = createSubject()

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)

        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)
        let jumpBackIn = subject.jumpBackInList
        XCTAssertEqual(jumpBackIn.tabs.count, 2, "iPhone portrait has 2 tabs in it's jumpbackin layout")
        XCTAssertEqual(jumpBackIn.tabs[0], tab1)
        XCTAssertEqual(jumpBackIn.tabs[1], tab2)
        XCTAssertFalse(jumpBackIn.tabs.contains(tab3), "The third tab doesn't appear")
    }

    func testCompactJumpBackIn_withOneJumpBackInTabs() {
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        let subject = createSubject()

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)

        XCTAssertEqual(subject.sectionLayout, .compactJumpBackIn)
        let jumpBackIn = subject.jumpBackInList
        XCTAssertEqual(jumpBackIn.tabs.count, 1, "With a max of 2 items, only shows 1 item when only 1 is available")
        XCTAssertEqual(jumpBackIn.tabs[0], tab1)
    }

    func testCompactJumpBackInAndSyncedTab_withThreeJumpBackInTabsAndARemoteTabs() {
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab2 = createTab(profile: mockProfile, urlString: "www.firefox2.com")
        let tab3 = createTab(profile: mockProfile, urlString: "www.firefox3.com")
        adaptor.recentTabs = [tab1, tab2, tab3]
        let subject = createSubject()

        // iPhone layout portrait
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .compact
        trait.overridenVerticalSizeClass = .regular

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: true, device: .phone)

        let jumpBackIn = subject.jumpBackInList
        XCTAssertEqual(jumpBackIn.tabs.count, 1, "iPhone portrait has 1 tab in it's jumpbackin layout")
        XCTAssertEqual(jumpBackIn.tabs[0], tab1)
        XCTAssertFalse(jumpBackIn.tabs.contains(tab2))
        XCTAssertFalse(jumpBackIn.tabs.contains(tab3))
        XCTAssertEqual(subject.sectionLayout, .compactJumpBackInAndSyncedTab)

        let syncTab = subject.mostRecentSyncedTab
        XCTAssertNotNil(syncTab, "iPhone portrait will show 1 sync tab")
    }

    func testMediumIphone_withThreeJumpbackInTabs() {
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab2 = createTab(profile: mockProfile, urlString: "www.firefox2.com")
        let tab3 = createTab(profile: mockProfile, urlString: "www.firefox3.com")
        adaptor.recentTabs = [tab1, tab2, tab3]
        let subject = createSubject()

        // iPhone layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .phone)

        let jumpBackIn = subject.jumpBackInList
        XCTAssertEqual(jumpBackIn.tabs.count, 3, "iPhone landscape has 3 tabs in it's jumpbackin layout, up until 4")
        XCTAssertEqual(jumpBackIn.tabs[0], tab1)
        XCTAssertEqual(jumpBackIn.tabs[1], tab2)
        XCTAssertEqual(jumpBackIn.tabs[2], tab3)
        XCTAssertEqual(subject.sectionLayout, .medium)

        let syncTab = subject.mostRecentSyncedTab
        XCTAssertNil(syncTab)
    }

    func testMediumWithSyncedTabIphone_withSyncTabAndJumpbackInTabs() {
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        let tab2 = createTab(profile: mockProfile, urlString: "www.firefox2.com")
        let tab3 = createTab(profile: mockProfile, urlString: "www.firefox3.com")
        adaptor.recentTabs = [tab1, tab2, tab3]
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        let subject = createSubject()

        // iPhone layout landscape
        let trait = MockTraitCollection()
        trait.overridenHorizontalSizeClass = .regular
        trait.overridenVerticalSizeClass = .compact

        subject.didLoadNewData()
        subject.refreshData(for: trait, size: iPhone14ScreenSize, isPortrait: false, device: .phone)

        let jumpBackIn = subject.jumpBackInList
        XCTAssertEqual(jumpBackIn.tabs.count, 2, "iPhone landscape has 2 tabs in it's jumpbackin layout, up until 2")
        XCTAssertEqual(jumpBackIn.tabs[0], tab1)
        XCTAssertEqual(jumpBackIn.tabs[1], tab2)
        XCTAssertFalse(jumpBackIn.tabs.contains(tab3))
        XCTAssertEqual(subject.sectionLayout, .mediumWithSyncedTab)

        let syncTab = subject.mostRecentSyncedTab
        XCTAssertNotNil(syncTab, "iPhone landscape will show 1 sync tab")
    }

    // MARK: Did load new data

    func testDidLoadNewData_noNewData() {
        let subject = createSubject()
        subject.didLoadNewData()

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNil(subject.recentSyncedTab)
    }

    func testDidLoadNewData_recentTabs() {
        let subject = createSubject()
        let tab1 = createTab(profile: mockProfile, urlString: "www.firefox1.com")
        adaptor.recentTabs = [tab1]
        subject.didLoadNewData()

        XCTAssertEqual(subject.recentTabs.count, 1)
        XCTAssertNil(subject.recentSyncedTab)
    }

    func testDidLoadNewData_syncedTab() {
        let subject = createSubject()
        adaptor.syncedTab = JumpBackInSyncedTab(client: remoteClient, tab: remoteTab)
        subject.didLoadNewData()

        XCTAssertEqual(subject.jumpBackInList.tabs.count, 0)
        XCTAssertNotNil(subject.recentSyncedTab)
    }
}

// MARK: - Helpers
extension JumpBackInViewModelTests {
    func createSubject() -> JumpBackInViewModel {
        let subject = JumpBackInViewModel(
            isZeroSearch: false,
            profile: mockProfile,
            isPrivate: false,
            theme: LightTheme(),
            tabManager: mockTabManager,
            adaptor: adaptor,
            wallpaperManager: WallpaperManager()
        )

        trackForMemoryLeaks(subject)

        return subject
    }

    func createTab(profile: MockProfile,
                   configuration: WKWebViewConfiguration = WKWebViewConfiguration(),
                   urlString: String? = "www.website.com") -> Tab {
        let tab = Tab(profile: profile, configuration: configuration)

        if let urlString = urlString {
            tab.url = URL(string: urlString)!
        }
        return tab
    }

    var remoteClient: RemoteClient {
        return RemoteClient(guid: nil,
                            name: "Fake client",
                            modified: 1,
                            type: nil,
                            formfactor: nil,
                            os: nil,
                            version: nil,
                            fxaDeviceId: nil)
    }

    var remoteTab: RemoteTab {
        return RemoteTab(clientGUID: "1",
                         URL: URL(string: "www.mozilla.org")!,
                         title: "Mozilla 1",
                         history: [],
                         lastUsed: 1,
                         icon: nil)
    }
}

class JumpBackInDataAdaptorMock: JumpBackInDataAdaptor {
    var recentTabs = [Tab]()
    func getRecentTabData() -> [Tab] {
        return recentTabs
    }

    var recentGroups: [ASGroup<Tab>]?
    func getGroupsData() -> [ASGroup<Tab>]? {
        return recentGroups
    }

    var mockHasSyncedTabFeatureEnabled: Bool = true
    var hasSyncedTabFeatureEnabled: Bool {
        return mockHasSyncedTabFeatureEnabled
    }

    var syncedTab: JumpBackInSyncedTab?
    func getSyncedTabData() -> JumpBackInSyncedTab? {
        return syncedTab
    }
}
