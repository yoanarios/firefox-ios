// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import Shared
import MobileCoreServices

class ShareExtensionHelper: NSObject, FeatureFlaggable {
    private weak var selectedTab: Tab?

    private let url: URL
    private var onePasswordExtensionItem: NSExtensionItem!
    private let browserFillIdentifier = "org.appextension.fill-browser-action"
    private let pocketExtensionSchema = "com.ideashower.ReadItLaterPro.AddToPocketExtension"

    var areShareSheetChangesEnabled: Bool {
        return featureFlags.isFeatureEnabled(.shareSheetChanges, checking: .buildOnly) && !url.isFile
    }

    /// Exclude 'Add to Reading List' which currently uses Safari. If share sheet changes are enabled exclude
    /// Copy from system to provide custom activity
    private var excludingActivities: [UIActivity.ActivityType] {
        guard areShareSheetChangesEnabled else {
            return [UIActivity.ActivityType.addToReadingList]
        }

        return [UIActivity.ActivityType.addToReadingList,
                UIActivity.ActivityType.copyToPasteboard]
    }

    // Can be a file:// or http(s):// url
    init(url: URL, tab: Tab?) {
        self.url = url
        self.selectedTab = tab
    }

    func createActivityViewController(_ completionHandler: @escaping (_ completed: Bool, _ activityType: UIActivity.ActivityType?) -> Void) -> UIActivityViewController {

        let activityItems = getActivityItems(url: url)
        let appActivities = getApplicationActivities()
        let activityViewController = UIActivityViewController(activityItems: activityItems,
                                                              applicationActivities: appActivities)

        activityViewController.excludedActivityTypes = excludingActivities

        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in

            if completed && activityType?.rawValue == self.pocketExtensionSchema {
                TelemetryWrapper.recordEvent(category: .action,
                                             method: .tap,
                                             object: .shareSheet,
                                             value: .sharePocketAction,
                                             extras: nil)
            }
            completionHandler(completed, activityType)
        }

        return activityViewController
    }

    /// Get the data to be shared if the URL is a file we will share just the url if not we prepare
    /// UIPrintInfo to get the option to print the page and tab URL and title
    /// - Parameter url: url from the selected tab
    /// - Returns: An array of elements to be shared
    private func getActivityItems(url: URL) -> [Any] {
        // If url is file return only url to be shared
        guard !url.isFile else { return [url] }

        var activityItems = [Any]()
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = (url.absoluteString as NSString).lastPathComponent
        printInfo.outputType = .general
        activityItems.append(printInfo)

        // when tab is not loaded (webView != nil) don't show print activity
        if let tab = selectedTab, tab.webView != nil {
            activityItems.append(TabPrintPageRenderer(tab: tab))
        }

        if let title = selectedTab?.title {
            activityItems.append(TitleActivityItemProvider(title: title))
        }
        activityItems.append(self)

        return activityItems
    }

    private func getApplicationActivities() -> [UIActivity]? {
        guard areShareSheetChangesEnabled else {
            return nil
        }

        var appActivities = [UIActivity]()
        let copyLinkActivity = CopyLinkActivity(activityType: .copyLink, url: url)
        appActivities.append(copyLinkActivity)

        let sendToDeviceActivity = SendToDeviceActivity(activityType: .sendToDevice, url: url)
        appActivities.append(sendToDeviceActivity)

        return appActivities
    }
}

extension ShareExtensionHelper: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {

        if isPasswordManager(activityType: activityType) {
            return onePasswordExtensionItem
        } else if isOpenByCopy(activityType: activityType) {
            return url
        }

        // Return the URL for the selected tab. If we are in reader view then decode
        // it so that we copy the original and not the internal localhost one.
        return url.isReaderModeURL ? url.decodeReaderModeURL : url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if isPasswordManager(activityType: activityType) {
            return browserFillIdentifier
        } else if isOpenByCopy(activityType: activityType) {
            return url.isFile ? kUTTypeFileURL as String : kUTTypeURL as String
        }

        return activityType == nil ? browserFillIdentifier : kUTTypeURL as String
    }

    private func isPasswordManager(activityType: UIActivity.ActivityType?) -> Bool {
        guard let activityType = activityType?.rawValue else { return false }
        // A 'password' substring covers the most cases, such as pwsafe and 1Password.
        // com.agilebits.onepassword-ios.extension
        // com.app77.ios.pwsafe2.find-login-action-password-actionExtension
        // If your extension's bundle identifier does not contain "password", simply submit a pull request by adding your bundle identifier.
        return (activityType.contains("password"))
            || (activityType == "com.lastpass.ilastpass.LastPassExt")
            || (activityType == "in.sinew.Walletx.WalletxExt")
            || (activityType == "com.8bit.bitwarden.find-login-action-extension")
            || (activityType == "me.mssun.passforios.find-login-action-extension")
    }

    private func isOpenByCopy(activityType: UIActivity.ActivityType?) -> Bool {
        guard let activityType = activityType?.rawValue else { return false }
        return activityType.lowercased().contains("remoteopeninapplication-bycopy")
    }
}
