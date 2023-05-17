// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import UIKit
import Storage
import Common
import Shared

protocol RemotePanelDelegate: AnyObject {
    func remotePanelDidRequestToSignIn()
    func remotePanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool)
    func remotePanel(didSelectURL url: URL, visitType: VisitType)
}

// MARK: - RemoteTabsPanel
class RemoteTabsPanel: UIViewController, Themeable {
    var themeManager: ThemeManager
    var themeObserver: NSObjectProtocol?
    var notificationCenter: NotificationProtocol
    var remotePanelDelegate: RemotePanelDelegate?
    var profile: Profile
    var tableViewController: RemoteTabsTableViewController

    init(profile: Profile,
         themeManager: ThemeManager = AppContainer.shared.resolve(),
         notificationCenter: NotificationProtocol = NotificationCenter.default) {
        self.profile = profile
        self.themeManager = themeManager
        self.notificationCenter = notificationCenter
        self.tableViewController = RemoteTabsTableViewController(profile: profile)

        super.init(nibName: nil, bundle: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(notificationReceived),
                                       name: .FirefoxAccountChanged,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(notificationReceived),
                                       name: .ProfileDidFinishSyncing,
                                       object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewController.remoteTabsPanel = self

        listenForThemeChange(view)
        setupLayout()
        applyTheme()
    }

    private func setupLayout() {
        tableViewController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(tableViewController)
        view.addSubview(tableViewController.view)
        tableViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            tableViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            tableViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func applyTheme() {
        view.backgroundColor = themeManager.currentTheme.colors.layer4
        tableViewController.tableView.backgroundColor =  themeManager.currentTheme.colors.layer3
        tableViewController.tableView.separatorColor = themeManager.currentTheme.colors.borderPrimary
        tableViewController.tableView.reloadData()
    }

    func forceRefreshTabs() {
        tableViewController.refreshTabs(updateCache: true)
    }

    @objc
    func notificationReceived(_ notification: Notification) {
        switch notification.name {
        case .FirefoxAccountChanged, .ProfileDidFinishSyncing:
            DispatchQueue.main.async {
                self.tableViewController.updateDelegateClientAndTabData()
            }
            break
        default:
            // no need to do anything at all
            break
        }
    }
}

protocol RemoteTabsPanelDataSource: UITableViewDataSource, UITableViewDelegate {
}

protocol CollapsibleTableViewSection: AnyObject {
    func hideTableViewSection(_ section: Int)
}

// MARK: - RemoteTabsTableViewController
class RemoteTabsTableViewController: UITableViewController, Themeable {
    struct UX {
        static let rowHeight = SiteTableViewControllerUX.RowHeight
    }

    weak var remoteTabsPanel: RemoteTabsPanel?
    private var profile: Profile!
    var themeManager: ThemeManager
    var themeObserver: NSObjectProtocol?
    var notificationCenter: NotificationProtocol
    private var clientAndTabs = [ClientAndTabs]()
    var tableViewDelegate: RemoteTabsPanelDataSource? {
        didSet {
            tableView.dataSource = tableViewDelegate
            tableView.delegate = tableViewDelegate
        }
    }

    private lazy var longPressRecognizer: UILongPressGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(longPress))
    }()

    init(profile: Profile,
         themeManager: ThemeManager = AppContainer.shared.resolve(),
         notificationCenter: NotificationProtocol = NotificationCenter.default) {
        self.profile = profile
        self.themeManager = themeManager
        self.notificationCenter = notificationCenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.addGestureRecognizer(longPressRecognizer)
        tableView.register(SiteTableViewHeader.self,
                           forHeaderFooterViewReuseIdentifier: SiteTableViewHeader.cellIdentifier)
        tableView.register(TwoLineImageOverlayCell.self,
                           forCellReuseIdentifier: TwoLineImageOverlayCell.cellIdentifier)
        tableView.register(RemoteTabsErrorCell.self,
                           forCellReuseIdentifier: RemoteTabsErrorCell.cellIdentifier)

        tableView.rowHeight = UX.rowHeight
        tableView.separatorInset = .zero
        tableView.alwaysBounceVertical = false

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }

        tableView.delegate = nil
        tableView.dataSource = nil

        tableView.accessibilityIdentifier = AccessibilityIdentifiers.TabTray.syncedTabs
        listenForThemeChange(view)
        applyTheme()

        refreshTabs(updateCache: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (navigationController as? ThemedNavigationController)?.applyTheme()

        // Add a refresh control if the user is logged in and the control was not added before. If the user is not
        // logged in, remove any existing control.
        if profile.hasSyncableAccount() && refreshControl == nil {
            addRefreshControl()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if refreshControl != nil {
            removeRefreshControl()
        }
    }

    func applyTheme() {
        tableView.separatorColor = themeManager.currentTheme.colors.layerLightGrey30
        if let delegate = tableViewDelegate as? RemoteTabsErrorDataSource {
            delegate.applyTheme(theme: themeManager.currentTheme)
        }
    }

    // MARK: - Refreshing TableView

    func addRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(onRefreshPulled), for: .valueChanged)
        refreshControl = control
        tableView.refreshControl = control
    }

    func removeRefreshControl() {
        tableView.refreshControl = nil
        refreshControl = nil
    }

    @objc
    func onRefreshPulled() {
        refreshControl?.beginRefreshing()
        refreshTabs(updateCache: true)
    }

    func endRefreshing() {
        // Always end refreshing, even if we failed!
        refreshControl?.endRefreshing()

        // Remove the refresh control if the user has logged out in the meantime
        if !profile.hasSyncableAccount() {
            removeRefreshControl()
        }
    }

    func updateDelegateClientAndTabData() {
        guard let remoteTabsPanel = remoteTabsPanel else { return }

        guard !clientAndTabs.isEmpty else {
            tableViewDelegate = RemoteTabsErrorDataSource(remoteTabsPanel: remoteTabsPanel,
                                                          error: .noClients,
                                                          theme: themeManager.currentTheme)
            tableView.reloadData()
            return
        }

        let nonEmptyClientAndTabs = clientAndTabs.filter { !$0.tabs.isEmpty }
        if nonEmptyClientAndTabs.isEmpty {
            tableViewDelegate = RemoteTabsErrorDataSource(remoteTabsPanel: remoteTabsPanel,
                                                          error: .noTabs,
                                                          theme: themeManager.currentTheme)
        } else {
            let tabsPanelDataSource = RemoteTabsClientAndTabsDataSource(remoteTabPanel: remoteTabsPanel,
                                                                        clientAndTabs: nonEmptyClientAndTabs,
                                                                        profile: profile,
                                                                        theme: themeManager.currentTheme)
            tabsPanelDataSource.collapsibleSectionDelegate = self
            tableViewDelegate = tabsPanelDataSource
        }
        tableView.reloadData()
    }

    func refreshTabs(updateCache: Bool = false) {
        // Calls to refresh tabs are made back to back
        guard let remoteTabsPanel = remoteTabsPanel else { return }

        // Short circuit if the user is not logged in
        guard profile.hasSyncableAccount() else {
            endRefreshing()
            tableViewDelegate = RemoteTabsErrorDataSource(remoteTabsPanel: remoteTabsPanel,
                                                          error: .notLoggedIn,
                                                          theme: themeManager.currentTheme)
            return
        }

        // Get cached tabs.
        profile.getCachedClientsAndTabs().uponQueue(.main) { [weak self] result in
            guard let clientAndTabs = result.successValue else {
                self?.endRefreshing()
                self?.showFailedToSync()
                return
            }

            self?.clientAndTabs = clientAndTabs
            // Update UI with cached data.
            ensureMainThread {
                self?.updateDelegateClientAndTabData()
                self?.endRefreshing()
            }

            if updateCache {
                self?.getUpdatedClientAndTabs()
            }
        }
    }

    private func getUpdatedClientAndTabs() {
        // Fetch updated tabs.
        profile.getClientsAndTabs().uponQueue(.global(qos: .userInitiated)) { result in
            DispatchQueue.main.async {
                if let clientAndTabs = result.successValue {
                    // Update UI with updated tabs.
                    self.clientAndTabs = clientAndTabs
                    self.updateDelegateClientAndTabData()
                }

                self.endRefreshing()
            }
        }
    }

    private func showFailedToSync() {
        guard let remoteTabsPanel = remoteTabsPanel else { return }

        self.tableViewDelegate = RemoteTabsErrorDataSource(remoteTabsPanel: remoteTabsPanel,
                                                           error: .failedToSync,
                                                           theme: themeManager.currentTheme)
    }

    @objc
    private func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        guard longPressGestureRecognizer.state == .began else { return }
        let touchPoint = longPressGestureRecognizer.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: touchPoint) else { return }
        presentContextMenu(for: indexPath)
    }
}

extension RemoteTabsTableViewController: CollapsibleTableViewSection {
    func hideTableViewSection(_ section: Int) {
        guard let dataSource = tableViewDelegate as? RemoteTabsClientAndTabsDataSource else { return }

        if dataSource.hiddenSections.contains(section) {
            dataSource.hiddenSections.remove(section)
        } else {
            dataSource.hiddenSections.insert(section)
        }

        tableView.reloadData()
    }
}

// MARK: LibraryPanelContextMenu
extension RemoteTabsTableViewController: LibraryPanelContextMenu {
    func presentContextMenu(for site: Site, with indexPath: IndexPath,
                            completionHandler: @escaping () -> PhotonActionSheet?) {
        guard let contextMenu = completionHandler() else { return }

        present(contextMenu, animated: true, completion: nil)
    }

    func getSiteDetails(for indexPath: IndexPath) -> Site? {
        guard let tab = (tableViewDelegate as? RemoteTabsClientAndTabsDataSource)?.tabAtIndexPath(indexPath) else {
            return nil
        }
        return Site(url: String(describing: tab.URL), title: tab.title)
    }

    func getContextMenuActions(for site: Site, with indexPath: IndexPath) -> [PhotonRowActions]? {
        return getRemoteTabContextMenuActions(for: site, remotePanelDelegate: remoteTabsPanel?.remotePanelDelegate)
    }
}
