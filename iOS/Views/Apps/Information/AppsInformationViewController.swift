import CoreData
import Foundation
import UIKit

class AppsInformationViewController: UIViewController {
    var tableView: UITableView!

    var tableData = [
        [
            String.localized("APPS_INFORMATION_TITLE_NAME"),
            String.localized("APPS_INFORMATION_TITLE_VERSION"),
            String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"),
            // String.localized("APPS_INFORMATION_TITLE_SIZE")
        ],
        [
            String.localized("APPS_INFORMATION_TITLE_DATE_ADDED"),
        ],
        [
            String.localized("APPS_INFORMATION_TITLE_BUNDLE_NAME"),
            String.localized("APPS_INFORMATION_TITLE_BUNDLE_PATH"),
            String.localized("APPS_INFORMATION_TITLE_ICON_FILE"),
            "UUID",
        ],
        [
            String.localized("APPS_INFORMATION_TITLE_OPEN_IN_FILES"),
        ],
    ]

    var sectionTitles = [
        "Info",
        "",
        String.localized("APPS_INFORMATION_SECTION_TITLE_NAME"),
        "",
    ]

    var source: NSManagedObject!
    var filePath: URL!
    var headerImage: UIImage!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNavigation()
    }

    private func setupViews() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableHeaderView = configureHeaderView()

        if !FileManager.default.fileExists(atPath: filePath.path) {
            tableData.insert([String.localized("APPS_INFORMATION_TITLE_DELETED_FILE")], at: 0)
            sectionTitles.insert("", at: 0)
        }

        view.addSubview(tableView)
        tableView.constraintCompletely(to: view)
    }

    private func configureHeaderView() -> UIView {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 100))
        headerView.backgroundColor = .clear

        if let iconURL = source.value(forKey: "iconURL") as? String {
            let imagePath = filePath.appendingPathComponent(iconURL)
            if let image = CoreDataManager.shared.loadImage(from: imagePath) {
                headerImage = image
            } else {
                headerImage = UIImage(named: "unknown")!
            }
        } else {
            headerImage = UIImage(named: "unknown")!
        }

        let imageView = UIImageView(image: headerImage)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: (view.frame.width - 80) / 2, y: 0, width: 80, height: 80)
        imageView.layer.cornerRadius = 18
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        headerView.addSubview(imageView)

        return headerView
    }

    private func setupNavigation() {
        title = nil
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeSheet)
        )
    }

    @objc func closeSheet() {
        dismiss(animated: true, completion: nil)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let threshold: CGFloat = 40

        if scrollView.contentOffset.y > threshold {
            if let appName = source.value(forKey: "name") as? String {
                title = appName
            }
        } else {
            title = nil
        }
    }
}

extension AppsInformationViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        return sectionTitles.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionTitles[section].isEmpty ? 5 : 40
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = sectionTitles[section]
        return InsetGroupedSectionHeader(title: title)
    }

    func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        default:
            return nil
        }
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "Cell"
        var cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.selectionStyle = .none

        let cellText = tableData[indexPath.section][indexPath.row]
        cell.textLabel?.text = cellText

        switch cellText {
        case String.localized("APPS_INFORMATION_TITLE_DELETED_FILE"):
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")

            cell.textLabel?.text = String.localized("APPS_INFORMATION_TITLE_DELETED_FILE_TITLE")
            cell.textLabel?.textColor = .systemRed

            cell.detailTextLabel?.text = String.localized("APPS_INFORMATION_TITLE_DELETED_FILE_DESCRIPTION")
            cell.detailTextLabel?.textColor = .systemYellow

            // cell.textLabel?.textAlignment = .center
            // cell.detailTextLabel?.textAlignment = .center
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0

        case String.localized("APPS_INFORMATION_TITLE_NAME"):
            if let appName = source.value(forKey: "name") as? String {
                cell.detailTextLabel?.text = appName
            }

        case String.localized("APPS_INFORMATION_TITLE_VERSION"):
            if let version = source.value(forKey: "version") as? String {
                cell.detailTextLabel?.text = version
            }

        case String.localized("APPS_INFORMATION_TITLE_SIZE"):
            cell.detailTextLabel?.text = "test"

        case String.localized("APPS_INFORMATION_TITLE_DATE_ADDED"):
            if let dateAdded = source.value(forKey: "dateAdded") as? Date {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let dateString = dateFormatter.string(from: dateAdded)
                cell.detailTextLabel?.text = dateString
            }

        case String.localized("APPS_INFORMATION_TITLE_BUNDLE_NAME"):
            if let appPath = source.value(forKey: "appPath") as? String {
                cell.detailTextLabel?.text = appPath
            }

        case String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"):
            if let bundleID = source.value(forKey: "bundleidentifier") as? String {
                cell.detailTextLabel?.text = bundleID
            }

        case String.localized("APPS_INFORMATION_TITLE_ICON_FILE"):
            if let iconURL = source.value(forKey: "iconURL") as? String {
                cell.detailTextLabel?.text = iconURL
            }

        case "UUID":
            if let uuid = source.value(forKey: "uuid") as? String {
                cell.detailTextLabel?.text = uuid
            }

        case String.localized("APPS_INFORMATION_TITLE_BUNDLE_PATH"):
            cell.detailTextLabel?.text = filePath.path

        case String.localized("APPS_INFORMATION_TITLE_OPEN_IN_FILES"):
            cell.textLabel?.textColor = Preferences.appTintColor.uiColor
            cell.textLabel?.textAlignment = .center
            cell.selectionStyle = .default

        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let itemTapped = tableData[indexPath.section][indexPath.row]

        switch itemTapped {
        case String.localized("APPS_INFORMATION_TITLE_OPEN_IN_FILES"):
            guard let fileURL = filePath else {
                Debug.shared.log(message: "File path is nil or invalid.")
                return
            }

            let path = fileURL.deletingLastPathComponent()
            let documentPath = path.absoluteString.replacingOccurrences(
                of: "file://",
                with: "shareddocuments://"
            )

            if let url = URL(string: documentPath) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        Debug.shared.log(message: "File opened successfully.")
                    } else {
                        Debug.shared.log(message: "Failed to open file.")
                    }
                }
            }

        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
