import AlertKit
import Foundation
import Nuke
import UIKit

// MARK: - SourceAppViewController Button Actions

extension SourceAppViewController {
    // MARK: - Download Button Actions

    @objc func getButtonTapped(_ sender: UIButton) {
        let indexPath = IndexPath(row: sender.tag, section: 0)
        guard let app = getAppAt(indexPath: indexPath) else { return }

        guard let downloadURL = getDownloadURL(for: app) else { return }
        let appUUID = app.bundleIdentifier

        // Add pulsing LED effect around button when tapped
        sender.addLEDEffect(
            color: UIColor(hex: "#FF6482"),
            intensity: 0.7,
            spread: 15,
            animated: true,
            animationDuration: 0.8
        )

        // Remove the effect after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sender.removeLEDEffect()
        }

        handleDownloadAction(for: appUUID, at: indexPath, downloadURL: downloadURL)
    }

    private func getAppAt(indexPath: IndexPath) -> StoreAppsData? {
        guard indexPath.row < (isFiltering ? filteredApps.count : apps.count) else { return nil }
        return isFiltering ? filteredApps[indexPath.row] : apps[indexPath.row]
    }

    private func getDownloadURL(for app: StoreAppsData) -> URL? {
        if let appDownloadURL = app.versions?.first?.downloadURL {
            return appDownloadURL
        } else if let appDownloadURL = app.downloadURL {
            return appDownloadURL
        }
        return nil
    }

    private func handleDownloadAction(for appUUID: String, at indexPath: IndexPath, downloadURL: URL) {
        if let task = DownloadTaskManager.shared.task(for: appUUID) {
            switch task.state {
            case .inProgress:
                DownloadTaskManager.shared.cancelDownload(for: appUUID)
            default:
                break
            }
        } else {
            let sourceLocation = name ?? String.localized("UNKNOWN")
            startDownloadIfNeeded(
                for: indexPath,
                in: tableView,
                downloadURL: downloadURL,
                appUUID: appUUID,
                sourceLocation: sourceLocation
            )
        }
    }

    // MARK: - Long Press Actions

    @objc func getButtonHold(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let button = gesture.view as? UIButton else { return }

        let indexPath = IndexPath(row: button.tag, section: 0)
        guard let app = getAppAt(indexPath: indexPath) else { return }

        let message = String.localized("SOURCES_CELLS_ACTIONS_HOLD_AVAILABLE_VERSIONS")
        let alertController = UIAlertController(
            title: app.name,
            message: message,
            preferredStyle: .actionSheet
        )

        addVersionActions(to: alertController, for: app, at: indexPath)
        alertController.addAction(UIAlertAction(title: String.localized("CANCEL"), style: .cancel))

        presentAlertController(alertController)
    }

    private func addVersionActions(
        to alertController: UIAlertController,
        for app: StoreAppsData,
        at indexPath: IndexPath
    ) {
        guard let sortedVersions = app.versions else { return }

        for version in sortedVersions {
            let versionString = version.version
            let downloadURL = version.downloadURL
            let sourceLocation = name ?? String.localized("UNKNOWN")

            let action = UIAlertAction(title: versionString, style: .default) { [weak self] _ in
                guard let self = self else { return }

                self.startDownloadIfNeeded(
                    for: indexPath,
                    in: self.tableView,
                    downloadURL: downloadURL,
                    appUUID: app.bundleIdentifier,
                    sourceLocation: sourceLocation
                )
            }

            alertController.addAction(action)
        }
    }

    private func presentAlertController(_ alertController: UIAlertController) {
        DispatchQueue.main.async {
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .last

            if let viewController = keyWindow?.rootViewController {
                viewController.present(alertController, animated: true)
            }
        }
    }
}
