import UIKit

/// View controller for browsing the file system
class FileBrowserViewController: UIViewController {
    // MARK: - Properties
    
    /// Table view for displaying files and directories
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    /// Current directory path
    private var currentPath: URL
    
    /// Files and directories in the current path
    private var items: [URL] = []
    
    /// Date formatter for file dates
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// File manager
    private let fileManager = FileManager.default
    
    /// FLEX integration
    private let flexIntegration = FLEXIntegration.shared
    
    /// Logger instance
    private let logger = Debug.shared
    
    // MARK: - Initialization
    
    init() {
        // Start at the app's document directory
        currentPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        // Start at the app's document directory
        currentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadItems()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set title
        title = "File Browser"
        
        // Set up table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FileCell")
        
        // Add table view to view hierarchy
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add navigation buttons
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshButtonTapped)
        )
        
        // Add "Go Up" button if not at root
        updateNavigationButtons()
    }
    
    // MARK: - Data Loading
    
    private func loadItems() {
        do {
            // Get contents of directory
            let contents = try fileManager.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // Sort directories first, then by name
            items = contents.sorted { (url1, url2) -> Bool in
                let isDirectory1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let isDirectory2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                
                if isDirectory1 && !isDirectory2 {
                    return true
                } else if !isDirectory1 && isDirectory2 {
                    return false
                } else {
                    return url1.lastPathComponent < url2.lastPathComponent
                }
            }
            
            // Reload table view
            tableView.reloadData()
            
            // Update title with current directory name
            title = currentPath.lastPathComponent
            
            // Update navigation buttons
            updateNavigationButtons()
            
        } catch {
            logger.log(message: "Error loading directory contents: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func updateNavigationButtons() {
        // Add "Go Up" button if not at root
        if currentPath.path != "/" {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Up",
                style: .plain,
                target: self,
                action: #selector(goUpButtonTapped)
            )
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }
    
    // MARK: - Actions
    
    @objc private func refreshButtonTapped() {
        loadItems()
    }
    
    @objc private func goUpButtonTapped() {
        // Navigate to parent directory
        if let parentURL = currentPath.deletingLastPathComponent() as URL? {
            currentPath = parentURL
            loadItems()
        }
    }
    
    // MARK: - File Operations
    
    private func showFileDetails(for url: URL) {
        do {
            // Get file attributes
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let creationDate = attributes[.creationDate] as? Date ?? Date()
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            let fileType = attributes[.type] as? String ?? "Unknown"
            
            // Format file size
            let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            
            // Create alert with file details
            let alert = UIAlertController(
                title: url.lastPathComponent,
                message: """
                Size: \(fileSizeString)
                Created: \(dateFormatter.string(from: creationDate))
                Modified: \(dateFormatter.string(from: modificationDate))
                Type: \(fileType)
                Path: \(url.path)
                """,
                preferredStyle: .alert
            )
            
            // Add actions based on file type
            let fileExtension = url.pathExtension.lowercased()
            
            // View action for text and image files
            if ["txt", "json", "plist", "xml", "html", "css", "js", "swift", "m", "h", "log"].contains(fileExtension) {
                alert.addAction(UIAlertAction(title: "View Contents", style: .default) { _ in
                    self.viewFileContents(url)
                })
            }
            
            // Delete action
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                self.deleteFile(url)
            })
            
            // Share action
            alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
                self.shareFile(url)
            })
            
            // Cancel action
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            // Present alert
            present(alert, animated: true)
            
        } catch {
            logger.log(message: "Error getting file attributes: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func viewFileContents(_ url: URL) {
        do {
            // Read file contents
            let contents = try String(contentsOf: url, encoding: .utf8)
            
            // Create and present text view controller
            let textViewController = UIViewController()
            let textView = UITextView()
            textView.text = contents
            textView.isEditable = false
            textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            
            textViewController.view = textView
            textViewController.title = url.lastPathComponent
            
            navigationController?.pushViewController(textViewController, animated: true)
            
        } catch {
            logger.log(message: "Error reading file contents: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func deleteFile(_ url: URL) {
        // Confirm deletion
        let alert = UIAlertController(
            title: "Confirm Deletion",
            message: "Are you sure you want to delete \(url.lastPathComponent)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            do {
                try self.fileManager.removeItem(at: url)
                self.loadItems()
            } catch {
                self.logger.log(message: "Error deleting file: \(error.localizedDescription)", type: .error)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true)
    }
    
    private func shareFile(_ url: URL) {
        // Create activity view controller
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Present activity view controller
        present(activityViewController, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension FileBrowserViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath)
        let url = items[indexPath.row]
        
        // Configure cell
        cell.textLabel?.text = url.lastPathComponent
        
        do {
            // Determine if item is a directory
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            
            // Set appropriate icon
            if isDirectory {
                cell.imageView?.image = UIImage(systemName: "folder")
                cell.accessoryType = .disclosureIndicator
            } else {
                // Choose icon based on file extension
                let fileExtension = url.pathExtension.lowercased()
                
                switch fileExtension {
                case "txt", "log":
                    cell.imageView?.image = UIImage(systemName: "doc.text")
                case "json", "plist", "xml":
                    cell.imageView?.image = UIImage(systemName: "doc.plaintext")
                case "jpg", "jpeg", "png", "gif":
                    cell.imageView?.image = UIImage(systemName: "photo")
                case "pdf":
                    cell.imageView?.image = UIImage(systemName: "doc.richtext")
                case "swift", "m", "h":
                    cell.imageView?.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
                default:
                    cell.imageView?.image = UIImage(systemName: "doc")
                }
                
                cell.accessoryType = .detailDisclosureButton
            }
            
        } catch {
            cell.imageView?.image = UIImage(systemName: "questionmark.circle")
            cell.accessoryType = .none
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FileBrowserViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let url = items[indexPath.row]
        
        do {
            // Check if item is a directory
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            
            if isDirectory {
                // Navigate to directory
                currentPath = url
                loadItems()
            } else {
                // Show file details
                showFileDetails(for: url)
            }
            
        } catch {
            logger.log(message: "Error determining item type: \(error.localizedDescription)", type: .error)
        }
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let url = items[indexPath.row]
        showFileDetails(for: url)
    }
}