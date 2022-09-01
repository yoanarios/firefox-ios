// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation

/// This struct defines all the accessibility identifiers to be added to
/// screen elements for testing.
///
/// These should be organized logically according to main screen or the
/// main element wherein they appear. As we continue updating views, all
/// `.accessibilityIdentifier` identifiers from the client and the tests
/// should be move here and updated throughout the app.
public struct AccessibilityIdentifiers {

    struct Toolbar {
        static let settingsMenuButton = "TabToolbar.menuButton"
        static let homeButton = "TabToolbar.homeButton"
        static let trackingProtection = "TabLocationView.trackingProtectionButton"
        static let readerModeButton = "TabLocationView.readerModeButton"
        static let reloadButton = "TabLocationView.reloadButton"
    }

    struct FirefoxHomepage {

        static let collectionView = "FxCollectionView"

        struct HomeTabBanner {
            static let titleLabel = "HomeTabBanner.titleLabel"
            static let descriptionLabel = "HomeTabBanner.descriptionLabel"
            static let ctaButton = "HomeTabBanner.ctaButton"
        }

        struct OtherButtons {
            static let logoButton = "FxHomeLogoButton"
            static let customizeHome = "FxHomeCustomizeHomeSettingButton"
        }

        struct MoreButtons {
            static let recentlySaved = "recentlySavedSectionMoreButton"
            static let jumpBackIn = "jumpBackInSectionMoreButton"
            static let historyHighlights = "historyHighlightsSectionMoreButton"
            static let customizeHomePage = "FxHomeCustomizeHomeSettingButton"
        }

        struct SectionTitles {
            static let jumpBackIn = "jumpBackInTitle"
            static let recentlySaved = "recentlySavedTitle"
            static let historyHighlights = "historyHightlightsTitle"
            static let pocket = "pocketTitle"
            static let topSites = "topSitesTitle"
        }

        struct TopSites {
            static let itemCell = "TopSitesCell"
        }

        struct Pocket {
            static let itemCell = "PocketCell"
        }

        struct HistoryHighlights {
            static let itemCell = "HistoryHighlightsCell"
        }

        struct JumpBackIn {
            static let itemCell = "JumpBackInCell"
        }

        struct SyncedTab {
            static let itemCell = "SyncedTabCell"
            static let cardTitle = "SyncedTabCardTitle"
            static let showAllButton = "SyncedTabShowAllButton"
            static let heroImage = "SyncedTabHeroImage"
            static let itemTitle = "SyncedTabItemTitle"
            static let favIconImage = "SyncedTabFavIconImage"
            static let fallbackFavIconImage = "SyncedTabFallbackFavIconImage"
            static let descriptionLabel = "SyncedTabDescriptionLabel"
        }
    }

    struct GeneralizedIdentifiers {
        public static let back = "Back"
    }

    struct TabTray {
        static let filteredTabs = "filteredTabs"
        static let deleteCloseAllButton = "TabTrayController.deleteButton.closeAll"
        static let deleteCancelButton = "TabTrayController.deleteButton.cancel"
        static let syncedTabs = "Synced Tabs"
        static let inactiveTabHeader = "InactiveTabs.header"
        static let inactiveTabDeleteButton = "InactiveTabs.deleteButton"
    }

    struct LibraryPanels {
        static let bookmarksView = "LibraryPanels.Bookmarks"
        static let historyView = "LibraryPanels.History"
        static let downloadsView = "LibraryPanels.Downloads"
        static let readingListView = "LibraryPanels.ReadingList"
        static let segmentedControl = "librarySegmentControl"
        static let topLeftButton = "libraryPanelTopLeftButton"
        static let topRightButton = "libraryPanelTopRightButton"
        static let bottomLeftButton = "libraryPanelBottomLeftButton"
        static let bottomRightButton = "bookmarksPanelBottomRightButton"
        static let bottomSearchButton = "historyBottomSearchButton"
        static let bottomDeleteButton = "historyBottomDeleteButton"

        struct BookmarksPanel {
            static let tableView = "Bookmarks List"
        }

        struct HistoryPanel {
            static let tableView = "History List"
            static let clearHistoryCell = "HistoryPanel.clearHistory"
            static let recentlyClosedCell = "HistoryPanel.recentlyClosedCell"
            static let syncedHistoryCell = "HistoryPanel.syncedHistoryCell"
        }

        struct GroupedList {
            static let tableView = "grouped-items-table-view"
        }
    }

    struct Onboarding {
        static let backgroundImage = "Onboarding.BackgroundImage"
        static let welcomeCard = "WelcomeCard"
        static let wallpapersCard = "WallpapersCard"
        static let signSyncCard = "SignSyncCard"
        static let closeButton = "CloseButton"
        static let pageControl = "PageControl"

        struct Wallpaper {
            static let card = "wallpaperCard"
            static let title = "wallpaperOnboardingTitle"
            static let description = "wallpaperOnboardingDescription"
            static let settingsButton = "wallpaperOnboardingSettingsButton"
        }
    }

    struct Upgrade {
        static let backgroundImage = "Upgrade.BackgroundImage"
        static let welcomeCard = "Upgrade.WelcomeCard"
        static let signSyncCard = "Upgrade.SignSyncCard"
        static let closeButton = "Upgrade.CloseButton"
        static let pageControl = "Upgrade.PageControl"
    }

    struct Settings {
        static let tableViewController = "AppSettingsTableViewController.tableView"

        struct Homepage {
            static let homeSettings = "Home"
            static let homePageNavigationBar = "Homepage"

            struct StartAtHome {
                static let afterFourHours = "StartAtHomeAfterFourHours"
                static let always = "StartAtHomeAlways"
                static let disabled = "StartAtHomeDisabled"
            }

            struct CustomizeFirefox {
                struct Shortcuts {
                    static let settingsPage = "TopSitesSettings"
                    static let topSitesRows = "TopSitesRows"
                }

                struct Wallpaper {
                    static let collectionTitle = "wallpaperCollectionTitle"
                    static let collectionDescription = "wallpaperCollectionDescription"
                    static let collectionButton = "wallpaperCollectionButton"
                    static let card = "wallpaperCard"
                }

                static let jumpBackIn = "Jump Back In"
                static let recentlySaved = "Recently Saved"
                static let recentVisited = "Recently Visited"
                static let recommendedByPocket = "Recommended by Pocket"
                static let wallpaper = "WallpaperSettings"
            }
        }

        struct FirefoxAccount {
            static let qrButton = "QRCodeSignIn.button"
            static let continueButton = "Sign up or sign in"
            static let emailTextField = "Enter your email"
            static let fxaNavigationBar = "Sync and Save Data"
            static let fxaSettingsButton = "Sync and Save Data"
        }

        struct Search {
            static let customEngineViewButton = "customEngineViewButton"
            static let searchNavigationBar = "Search"
            static let deleteMozillaEngine = "Delete Mozilla Engine"
            static let deleteButton = "Delete"
        }

        struct Logins {
            static let loginsSettings = "Logins"
        }

        struct ClearData {
            static let clearPrivatedata = "ClearPrivateData"
        }

        struct SearchBar {
            static let searchBarSetting = "SearchBarSetting"
            static let topSetting = "TopSearchBar"
            static let bottomSetting = "BottomSearchBar"
        }
    }
}
