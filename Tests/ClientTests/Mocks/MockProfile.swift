// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

@testable import Client
import Foundation
import Account
import Shared
import Storage
import Sync
import XCTest

open class MockSyncManager: SyncManager {
    open var isSyncing = false
    open var lastSyncFinishTime: Timestamp?
    open var syncDisplayState: SyncDisplayState?

    open func hasSyncedHistory() -> Deferred<Maybe<Bool>> {
        return deferMaybe(true)
    }

    private func completedWithStats(collection: String) -> Deferred<Maybe<SyncStatus>> {
        return deferMaybe(SyncStatus.completed(SyncEngineStatsSession(collection: collection)))
    }

    open func syncClients() -> SyncResult { return completedWithStats(collection: "mock_clients") }
    open func syncClientsThenTabs() -> SyncResult { return completedWithStats(collection: "mock_clientsandtabs") }
    open func syncHistory() -> SyncResult { return completedWithStats(collection: "mock_history") }
    open func syncLogins() -> SyncResult { return completedWithStats(collection: "mock_logins") }
    open func syncBookmarks() -> SyncResult { return completedWithStats(collection: "mock_bookmarks") }
    open func syncEverything(why: SyncReason) -> Success {
        return succeed()
    }
    open func syncNamedCollections(why: SyncReason, names: [String]) -> Success {
        return succeed()
    }
    open func beginTimedSyncs() {}
    open func endTimedSyncs() {}
    open func applicationDidBecomeActive() {
        self.beginTimedSyncs()
    }
    open func applicationDidEnterBackground() {
        self.endTimedSyncs()
    }

    open func onNewProfile() {
    }

    open func onAddedAccount() -> Success {
        return succeed()
    }
    open func onRemovedAccount() -> Success {
        return succeed()
    }

    open func hasSyncedLogins() -> Deferred<Maybe<Bool>> {
        return deferMaybe(true)
    }
}

open class MockTabQueue: TabQueue {
    open func addToQueue(_ tab: ShareItem) -> Success {
        return succeed()
    }

    open func getQueuedTabs() -> Deferred<Maybe<Cursor<ShareItem>>> {
        return deferMaybe(ArrayCursor<ShareItem>(data: []))
    }

    open func clearQueuedTabs() -> Success {
        return succeed()
    }
}

class MockFiles: FileAccessor {
    init() {
        let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        super.init(rootPath: (docPath as NSString).appendingPathComponent("testing"))
    }
}

open class MockProfile: Client.Profile {
    public var rustFxA: RustFirefoxAccounts {
        return RustFirefoxAccounts.shared
    }

    // Read/Writeable properties for mocking
    public var recommendations: HistoryRecommendations
    public var places: RustPlaces
    public var tabs: RustRemoteTabs
    public var files: FileAccessor
    public var history: BrowserHistory & SyncableHistory & ResettableSyncStorage
    public var logins: RustLogins
    public var syncManager: SyncManager!

    fileprivate var legacyPlaces: BrowserHistory & Favicons & SyncableHistory & ResettableSyncStorage & HistoryRecommendations

    var database: BrowserDB
    var readingListDB: BrowserDB

    fileprivate let name: String = "mockaccount"

    init(databasePrefix: String = "mock") {
        files = MockFiles()
        syncManager = MockSyncManager()

        let oldLoginsDatabasePath = URL(fileURLWithPath: (try! files.getAndEnsureDirectory()), isDirectory: true).appendingPathComponent("\(databasePrefix)_logins.db").path
        try? files.remove("\(databasePrefix)_logins.db")

        let newLoginsDatabasePath = URL(fileURLWithPath: (try! files.getAndEnsureDirectory()), isDirectory: true).appendingPathComponent("\(databasePrefix)_loginsPerField.db").path
        try? files.remove("\(databasePrefix)_loginsPerField.db")

        logins = RustLogins(sqlCipherDatabasePath: oldLoginsDatabasePath, databasePath: newLoginsDatabasePath)
        _ = logins.reopenIfClosed()
        database = BrowserDB(filename: "\(databasePrefix).db", schema: BrowserSchema(), files: files)
        readingListDB = BrowserDB(filename: "\(databasePrefix)_ReadingList.db", schema: ReadingListSchema(), files: files)
        let placesDatabasePath = URL(fileURLWithPath: (try! files.getAndEnsureDirectory()), isDirectory: true).appendingPathComponent("\(databasePrefix)_places.db").path
        places = RustPlaces(databasePath: placesDatabasePath)

        let tabsDbPath = URL(fileURLWithPath: (try! files.getAndEnsureDirectory()), isDirectory: true).appendingPathComponent("\(databasePrefix)_tabs.db").path

        tabs = RustRemoteTabs(databasePath: tabsDbPath)

        legacyPlaces = SQLiteHistory(db: self.database, prefs: MockProfilePrefs())
        recommendations = legacyPlaces
        history = legacyPlaces
    }

    public func localName() -> String {
        return name
    }

    public func _reopen() {
        isShutdown = false

        database.reopenIfClosed()
        _ = logins.reopenIfClosed()
        _ = places.reopenIfClosed()
        _ = tabs.reopenIfClosed()
    }

    public func _shutdown() {
        isShutdown = true

        database.forceClose()
        _ = logins.forceClose()
        _ = places.forceClose()
        _ = tabs.forceClose()
    }

    public var isShutdown: Bool = false

    public var favicons: Favicons {
        return self.legacyPlaces
    }

    lazy public var queue: TabQueue = {
        return MockTabQueue()
    }()

    lazy public var metadata: Metadata = {
        return SQLiteMetadata(db: self.database)
    }()

    lazy public var isChinaEdition: Bool = {
        return Locale.current.identifier == "zh_CN"
    }()

    lazy public var certStore: CertStore = {
        return CertStore()
    }()

    lazy public var searchEngines: SearchEngines = {
        return SearchEngines(prefs: self.prefs, files: self.files)
    }()

    lazy public var prefs: Prefs = {
        return MockProfilePrefs()
    }()

    lazy public var readingList: ReadingList = {
        return SQLiteReadingList(db: self.readingListDB)
    }()

    lazy public var recentlyClosedTabs: ClosedTabsStore = {
        return ClosedTabsStore(prefs: self.prefs)
    }()

    internal lazy var remoteClientsAndTabs: RemoteClientsAndTabs = {
        return SQLiteRemoteClientsAndTabs(db: self.database)
    }()

    fileprivate lazy var syncCommands: SyncCommands = {
        return SQLiteRemoteClientsAndTabs(db: self.database)
    }()

    public func hasSyncAccount(completion: @escaping (Bool) -> Void) {
        completion(hasSyncableAccountMock)
    }

    public func hasAccount() -> Bool {
        return hasSyncableAccountMock
    }

    var hasSyncableAccountMock: Bool = true
    public func hasSyncableAccount() -> Bool {
        return hasSyncableAccountMock
    }

    public func flushAccount() {}

    public func removeAccount() {
        self.syncManager.onRemovedAccount()
    }

    public func getClients() -> Deferred<Maybe<[RemoteClient]>> {
        return deferMaybe([])
    }

    public func getCachedClients() -> Deferred<Maybe<[RemoteClient]>> {
        return deferMaybe([])
    }

    public func getClientsAndTabs() -> Deferred<Maybe<[ClientAndTabs]>> {
        return deferMaybe([])
    }

    var mockClientAndTabs = [ClientAndTabs]()

    public func getCachedClientsAndTabs(completion: @escaping ([ClientAndTabs]) -> Void) {
        completion(mockClientAndTabs)
    }

    public func getCachedClientsAndTabs() -> Deferred<Maybe<[ClientAndTabs]>> {
        return deferMaybe(mockClientAndTabs)
    }

    public func cleanupHistoryIfNeeded() {}

    public func storeTabs(_ tabs: [RemoteTab]) -> Deferred<Maybe<Int>> {
        return deferMaybe(0)
    }

    public func sendItem(_ item: ShareItem, toDevices devices: [RemoteDevice]) -> Success {
        return succeed()
    }

    public func sendQueuedSyncEvents() {}
}
