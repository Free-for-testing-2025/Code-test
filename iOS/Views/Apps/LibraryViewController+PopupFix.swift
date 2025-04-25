// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit
import CoreData

// Extension to fix popup presentation in LibraryViewController
extension LibraryViewController {

    /// Configures popup detents for proper height based on content - implementation moved to main class

    /// Fixed method to handle signing a downloaded app - ensures sign popup works correctly
    /// - Parameter app: The app to sign
    func startSigning(app: NSManagedObject) {
        // Ensure we have a valid DownloadedApps object
        guard let downloadedApp = app as? DownloadedApps else {
            backdoor.Debug.shared.log(message: "Invalid app object for signing", type: .error)
            return
        }

        // Create signing options with current user defaults
        let signingDataWrapper = SigningDataWrapper(signingOptions: UserDefaults.standard.signingOptions)

        // Create and configure signing view controller
        let signingVC = SigningsViewController(
            signingDataWrapper: signingDataWrapper,
            application: downloadedApp,
            appsViewController: self
        )

        // Set completion handler to refresh data after signing
        signingVC.signingCompletionHandler = { [weak self] success in
            if success {
                backdoor.Debug.shared.log(message: "Signing completed successfully", type: .info)
                self?.fetchSources()
                self?.tableView.reloadData()
            } else {
                backdoor.Debug.shared.log(message: "Signing failed or was cancelled", type: .warning)
            }
        }

        // Wrap in navigation controller and present
        let navigationController = UINavigationController(rootViewController: signingVC)
        navigationController.shouldPresentFullScreen()

        present(navigationController, animated: true)
    }
}
