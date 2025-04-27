import Foundation
import Security
import UIKit
import UniformTypeIdentifiers

// External C functions from openssl_tools
@_silgen_name("provision_file_validation")
func provision_file_validation(_ path: String)

@_silgen_name("p12_password_check")
func p12_password_check(_ path: String, _ password: String) -> Bool

class CertImportingViewController: UITableViewController {
    lazy var saveButton = UIBarButtonItem(
        title: String.localized("SAVE"),
        style: .plain,
        target: self,
        action: #selector(saveAction)
    )
    private var passwordTextField: UITextField?
    private var backdoorFile: BackdoorFile?

    enum FileType: Hashable {
        case provision
        case p12
        case password
        case backdoor
    }

    var sectionData = [
        "backdoor",
        "provision",
        "certs",
        "pass",
    ]

    private var selectedFiles: [FileType: Any] = [:]

    init() { super.init(style: .insetGrouped) }
    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupViews()
    }

    fileprivate func setupViews() {
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }

    fileprivate func setupNavigation() {
        self.navigationItem.largeTitleDisplayMode = .never
        self.title = String.localized("CERT_IMPORTING_VIEWCONTROLLER_TITLE")
        saveButton.isEnabled = false
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: String.localized("DISMISS"),
            style: .done,
            target: self,
            action: #selector(closeSheet)
        )
    }

    @objc func closeSheet() {
        dismiss(animated: true, completion: nil)
    }

    @objc func saveAction() {
        // Check if we have a backdoor file
        if let backdoorFile = self.backdoorFile {
            // Create temporary files for the extracted components
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

                // Save the p12 and mobileprovision to disk temporarily
                let p12URL = tempDir.appendingPathComponent("backdoor.p12")
                let provisionURL = tempDir.appendingPathComponent("backdoor.mobileprovision")

                try backdoorFile.saveP12(to: p12URL)
                try backdoorFile.saveMobileProvision(to: provisionURL)

                // Parse mobileprovision
                if let certData = CertData.parseMobileProvisioningFile(atPath: provisionURL) {
                    // Create files dictionary with our temporary files
                    var files: [FileType: Any] = [
                        .provision: provisionURL,
                        .p12: p12URL,
                    ]
                    
                    // Keep the original backdoor file reference if it exists
                    if let backdoorFile = selectedFiles[.backdoor] {
                        files[.backdoor] = backdoorFile
                    }

                    // Add password if available
                    if let password = selectedFiles[.password] as? String {
                        files[.password] = password
                    }

                    // Save the backdoor information in CoreData
                    CoreDataManager.shared.addToCertificates(cert: certData, files: files)
                    self.dismiss(animated: true)
                } else {
                    Debug.shared.log(message: "Failed to parse mobileprovision from backdoor file", type: .error)
                    showAlert(title: "Error", message: "Failed to parse mobileprovision data from backdoor file")
                }
            } catch {
                Debug.shared.log(message: "Error processing backdoor file: \(error)", type: .error)
                showAlert(title: "Error", message: "Failed to process backdoor file: \(error.localizedDescription)")
            }
            return
        }

        // Handle traditional certificate imports - now with automatic conversion to backdoor format
        guard let mobileProvisionPath = selectedFiles[.provision] as? URL else {
            Debug.shared.log(message: "Missing mobileprovision path", type: .error)
            return
        }

        guard let p12Path = selectedFiles[.p12] as? URL else {
            Debug.shared.log(message: "Missing p12 path", type: .error)
            return
        }

        #if !targetEnvironment(simulator)
            // Call functions from openssl_tools.hpp
            provision_file_validation(mobileProvisionPath.path)
            if !p12_password_check(p12Path.path, selectedFiles[.password] as? String ?? "") {
                let alert = UIAlertController(
                    title: String.localized("CERT_IMPORTING_VIEWCONTROLLER_PW_ALERT_TITLE"),
                    message: String.localized("CERT_IMPORTING_VIEWCONTROLLER_PW_ALERT_DESCRIPTION"),
                    preferredStyle: UIAlertController.Style.alert
                )
                alert.addAction(UIAlertAction(
                    title: String.localized("OK"),
                    style: UIAlertAction.Style.default,
                    handler: nil
                ))
                self.present(alert, animated: true, completion: nil)
                return
            }
        #endif

        // Parse mobileprovision content
        if let fileContent = CertData.parseMobileProvisioningFile(atPath: mobileProvisionPath) {
            // Create a temporary directory for our backdoor file
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

                // Create path for the backdoor file
                let backdoorURL = tempDir.appendingPathComponent("certificate.backdoor")

                // Convert p12 and mobileprovision to backdoor format
                try createBackdoorFileFromSelection(outputURL: backdoorURL)

                // Now load this backdoor file to verify it was created correctly
                let backdoorData = try Data(contentsOf: backdoorURL)

                // Now create files dictionary including the backdoor file (this is crucial for proper storage)
                var files: [FileType: Any] = [
                    .provision: mobileProvisionPath,
                    .p12: p12Path,
                    .backdoor: backdoorURL, // This ensures the .backdoor format is saved
                ]

                // Add password if available
                if let password = selectedFiles[.password] as? String {
                    files[.password] = password
                }

                // Save the backdoor information in CoreData
                CoreDataManager.shared.addToCertificates(cert: fileContent, files: files)
                self.dismiss(animated: true)
            } catch {
                Debug.shared.log(message: "Error creating backdoor file: \(error)", type: .error)

                // Fall back to traditional certificate import if backdoor creation fails
                Debug.shared.log(message: "Falling back to traditional certificate import", type: .warning)
                CoreDataManager.shared.addToCertificates(cert: fileContent, files: selectedFiles)
                self.dismiss(animated: true)
            }
        } else {
            Debug.shared.log(message: String.localized("ERROR_FAILED_TO_READ_MOBILEPROVISION"), type: .error)
        }
    }

    /// Creates a backdoor file from the currently selected p12 and mobileprovision files
    /// - Parameters:
    ///   - outputURL: Where to save the resulting backdoor file
    ///   - encrypt: Whether to encrypt sensitive data in the file (default: true)
    private func createBackdoorFileFromSelection(outputURL: URL, encrypt: Bool = true) throws {
        guard let p12URL = selectedFiles[.p12] as? URL else {
            throw NSError(
                domain: "CertImporting",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No p12 file selected"]
            )
        }

        guard let mobileProvisionURL = selectedFiles[.provision] as? URL else {
            throw NSError(
                domain: "CertImporting",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No mobileprovision file selected"]
            )
        }

        let password = selectedFiles[.password] as? String

        try BackdoorConverter.createBackdoorFile(
            p12URL: p12URL,
            mobileProvisionURL: mobileProvisionURL,
            outputURL: outputURL,
            p12Password: password,
            encrypt: encrypt
        )

        let messageType = encrypt ? "encrypted" : "legacy"
        Debug.shared.log(
            message: "Successfully created \(messageType) backdoor file from p12 and mobileprovision",
            type: .info
        )
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard textField === passwordTextField else { return }

        if let password = textField.text {
            selectedFiles[.password] = password
        }
    }

    private func processBackdoorFile(at url: URL) {
        // First check if the file has a .backdoor extension or appears to be in backdoor format
        if !BackdoorDecoder.isBackdoorFile(at: url) {
            Debug.shared.log(message: "Selected file is not a valid .backdoor file", type: .error)
            showAlert(title: "Invalid Format", message: "The selected file is not a valid .backdoor certificate file.")
            return
        }

        do {
            let backdoorData = try Data(contentsOf: url)

            // Decode the backdoor file
            let backdoorFile = try BackdoorDecoder.decodeBackdoor(from: backdoorData)
            self.backdoorFile = backdoorFile

            // Save reference in selectedFiles
            selectedFiles[.backdoor] = url

            // Update the save button
            saveButton.isEnabled = true

            // Update UI to show this file was selected
            tableView.reloadData()

            Debug.shared.log(
                message: "Successfully processed .backdoor file: \(backdoorFile.certificateName)",
                type: .info
            )
        } catch {
            Debug.shared.log(message: "Error processing .backdoor file: \(error)", type: .error)
            showAlert(
                title: "Processing Error",
                message: "Failed to process .backdoor file: \(error.localizedDescription)"
            )
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension CertImportingViewController {
    override func numberOfSections(in _: UITableView) -> Int { return sectionData.count }
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { return 1 }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.selectionStyle = .default

        let imageView = UIImageView(image: UIImage(systemName: "circle"))
        imageView.tintColor = .quaternaryLabel
        cell.accessoryView = imageView

        cell.textLabel?.font = .boldSystemFont(ofSize: 15)
        cell.detailTextLabel?.textColor = .secondaryLabel

        let fileType: FileType

        switch sectionData[indexPath.section] {
        case "backdoor":
            cell.textLabel?.text = "Import Backdoor Certificate"
            cell.detailTextLabel?.text = ".backdoor file (secured certificate format)"
            fileType = .backdoor

            if selectedFiles[.backdoor] != nil {
                let checkmarkImage = UIImage(systemName: "checkmark")
                let checkmarkImageView = UIImageView(image: checkmarkImage)
                checkmarkImageView.tintColor = .systemBlue
                cell.accessoryView = checkmarkImageView
            } else {
                let circleImage = UIImage(systemName: "circle")
                let circleImageView = UIImageView(image: circleImage)
                circleImageView.tintColor = .quaternaryLabel
                cell.accessoryView = circleImageView
            }

            return cell
        case "provision":
            cell.textLabel?.text = String.localized("CERT_IMPORTING_VIEWCONTROLLER_CELL_IMPORT_PROV")
            cell.detailTextLabel?.text = ".mobileprovision"
            fileType = .provision

            // Disable this option if backdoor file is selected
            if selectedFiles[.backdoor] != nil {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .lightGray
                cell.detailTextLabel?.textColor = .lightGray
            }
        case "certs":
            cell.textLabel?.text = String.localized("CERT_IMPORTING_VIEWCONTROLLER_CELL_IMPORT_CERT")
            cell.detailTextLabel?.text = ".p12"
            fileType = .p12

            if selectedFiles[.p12] != nil {
                let checkmarkImage = UIImage(systemName: "checkmark")
                let checkmarkImageView = UIImageView(image: checkmarkImage)
                checkmarkImageView.tintColor = .systemBlue
                cell.accessoryView = checkmarkImageView
            } else {
                let circleImage = UIImage(systemName: "circle")
                let circleImageView = UIImageView(image: circleImage)
                circleImageView.tintColor = .quaternaryLabel
                cell.accessoryView = circleImageView
            }

            // Disable this option if backdoor file is selected
            if selectedFiles[.backdoor] != nil {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .lightGray
                cell.detailTextLabel?.textColor = .lightGray
            }

            return cell
        case "pass":
            let passwordCell = UITableViewCell(style: .default, reuseIdentifier: "PasswordCell")
            let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))

            textField.placeholder = String.localized("CERT_IMPORTING_VIEWCONTROLLER_CELL_IMPORT_ENTER_PW")
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

            passwordCell.textLabel?.text = String.localized("CERT_IMPORTING_VIEWCONTROLLER_CELL_IMPORT_PW")
            passwordCell.selectionStyle = .none
            passwordCell.accessoryView = textField

            passwordTextField = textField

            return passwordCell
        default:
            return cell
        }

        if selectedFiles[fileType] != nil {
            let checkmarkImage = UIImage(systemName: "checkmark")
            let checkmarkImageView = UIImageView(image: checkmarkImage)
            checkmarkImageView.tintColor = .systemBlue
            cell.accessoryView = checkmarkImageView
        } else {
            let circleImage = UIImage(systemName: "circle")
            let circleImageView = UIImageView(image: circleImage)
            circleImageView.tintColor = .quaternaryLabel
            cell.accessoryView = circleImageView
        }

        return cell
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sectionData[section] {
        case "backdoor":
            return "Import a .backdoor file - an all-in-one certificate format that contains certificate, p12, and mobileprovision with signature verification."
        case "provision":
            return String.localized("CERT_IMPORTING_VIEWCONTROLLER_FOOTER_PROV")
        case "certs":
            return String.localized("CERT_IMPORTING_VIEWCONTROLLER_FOOTER_CERT")
        case "pass":
            return String.localized("CERT_IMPORTING_VIEWCONTROLLER_FOOTER_PASS")
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fileType: FileType

        // If backdoor is already selected, don't allow selecting provision or p12
        if selectedFiles[.backdoor] != nil,
           sectionData[indexPath.section] == "provision" || sectionData[indexPath.section] == "certs"
        {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        // If provision or p12 are already selected, don't allow selecting backdoor
        if selectedFiles[.provision] != nil || selectedFiles[.p12] != nil,
           sectionData[indexPath.section] == "backdoor"
        {
            showAlert(
                title: "Selection Conflict",
                message: "Please clear existing certificate selections before importing a backdoor certificate."
            )
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        switch sectionData[indexPath.section] {
        case "backdoor":
            fileType = .backdoor
        case "provision":
            fileType = .provision
        case "certs":
            fileType = .p12
        default:
            return
        }

        guard selectedFiles[fileType] == nil else {
            // Allow deselecting a file by tapping again
            selectedFiles.removeValue(forKey: fileType)

            if fileType == .backdoor {
                self.backdoorFile = nil
            }

            // Update button state
            if selectedFiles[.backdoor] != nil {
                saveButton.isEnabled = true
            } else if selectedFiles[.provision] != nil, selectedFiles[.p12] != nil {
                saveButton.isEnabled = true
            } else {
                saveButton.isEnabled = false
            }

            tableView.reloadData()
            return
        }

        switch sectionData[indexPath.section] {
        case "backdoor":
            // Create a custom UTType for .backdoor files
            let backdoorUTType: UTType
            if let customType = UTType(filenameExtension: "backdoor") {
                backdoorUTType = customType
            } else {
                // Fallback to data type if the system doesn't recognize .backdoor
                backdoorUTType = .data
            }

            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [backdoorUTType], asCopy: true)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            present(documentPicker, animated: true, completion: nil)
        case "provision":
            presentDocumentPicker(fileExtension: [UTType(filenameExtension: "mobileprovision")!])
        case "certs":
            presentDocumentPicker(fileExtension: [UTType(filenameExtension: "p12")!])
        default:
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension CertImportingViewController: UIDocumentPickerDelegate {
    func presentDocumentPicker(fileExtension: [UTType]) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: fileExtension, asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }

        let fileType: FileType?

        switch selectedFileURL.pathExtension.lowercased() {
        case "mobileprovision":
            fileType = .provision
        case "p12":
            fileType = .p12
        case "backdoor":
            // Process .backdoor file explicitly by extension
            processBackdoorFile(at: selectedFileURL)
            return
        default:
            // For other files, try to detect if it's a backdoor file by content
            Debug.shared.log(message: "Processing unknown file extension as potential backdoor file", type: .info)
            processBackdoorFile(at: selectedFileURL)
            return
        }

        if let fileType = fileType {
            selectedFiles[fileType] = selectedFileURL
            tableView.reloadData()
        }

        if (selectedFiles[.provision] != nil) && (selectedFiles[.p12] != nil) {
            saveButton.isEnabled = true
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    func checkIfFileIsCert(cert: URL?) -> Bool {
        guard let cert = cert, cert.isFileURL else { return false }

        do {
            let fileContent = try String(contentsOf: cert, encoding: .utf8)
            if fileContent.contains("BEGIN CERTIFICATE") {
                return true
            }
        } catch {
            Debug.shared.log(message: "Error reading file: \(error)")
        }

        return false
    }
}
