import UIKit
import OSLog

/// View controller for displaying system logs
class SystemLogViewController: UIViewController {
    // MARK: - Properties
    
    /// Text view for displaying logs
    private let textView = UITextView()
    
    /// Toolbar for controls
    private let toolbar = UIToolbar()
    
    /// Activity indicator for loading
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    /// Logger instance
    private let logger = Debug.shared
    
    /// Log level filter
    private var logLevelFilter: LogType?
    
    /// Search text
    private var searchText: String?
    
    /// Timer for auto-refresh
    private var refreshTimer: Timer?
    
    /// Auto-refresh interval in seconds
    private var refreshInterval: TimeInterval = 5.0
    
    /// Flag indicating if auto-refresh is enabled
    private var autoRefreshEnabled = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadLogs()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set title
        title = "System Log"
        
        // Set up text view
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up toolbar
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Add toolbar items
        let refreshButton = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshButtonTapped)
        )
        
        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: "line.horizontal.3.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(filterButtonTapped)
        )
        
        let searchButton = UIBarButtonItem(
            barButtonSystemItem: .search,
            target: self,
            action: #selector(searchButtonTapped)
        )
        
        let autoRefreshButton = UIBarButtonItem(
            image: UIImage(systemName: "timer"),
            style: .plain,
            target: self,
            action: #selector(autoRefreshButtonTapped)
        )
        
        let clearButton = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearButtonTapped)
        )
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            refreshButton,
            flexibleSpace,
            filterButton,
            flexibleSpace,
            searchButton,
            flexibleSpace,
            autoRefreshButton,
            flexibleSpace,
            clearButton
        ]
        
        // Set up activity indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(toolbar)
        view.addSubview(textView)
        view.addSubview(activityIndicator)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            
            textView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add navigation buttons
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareButtonTapped)
        )
    }
    
    // MARK: - Log Loading
    
    private func loadLogs() {
        // Show activity indicator
        activityIndicator.startAnimating()
        
        // Load logs asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            // Get app log file path
            let logFilePath = self.getDocumentsDirectory().appendingPathComponent("logs.txt")
            
            do {
                // Read log file contents
                var logContents = try String(contentsOf: logFilePath, encoding: .utf8)
                
                // Apply filter if needed
                if let filter = self.logLevelFilter {
                    logContents = self.filterLogs(logContents, byLevel: filter)
                }
                
                // Apply search if needed
                if let search = self.searchText, !search.isEmpty {
                    logContents = self.filterLogs(logContents, bySearchText: search)
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.textView.text = logContents
                    
                    // Scroll to bottom
                    if !logContents.isEmpty {
                        let bottom = NSRange(location: logContents.count - 1, length: 1)
                        self.textView.scrollRangeToVisible(bottom)
                    }
                    
                    self.activityIndicator.stopAnimating()
                }
                
            } catch {
                // Handle error
                DispatchQueue.main.async {
                    self.textView.text = "Error loading logs: \(error.localizedDescription)"
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func filterLogs(_ logs: String, byLevel level: LogType) -> String {
        // Get emoji for the log level
        let emoji: String
        switch level {
        case .success:
            emoji = "✅"
        case .info:
            emoji = "ℹ️"
        case .debug:
            emoji = "🐛"
        case .trace:
            emoji = "🔍"
        case .warning:
            emoji = "⚠️"
        case .error:
            emoji = "❌"
        case .critical, .fault:
            emoji = "🔥"
        default:
            emoji = "📝"
        }
        
        // Filter logs by emoji
        let lines = logs.components(separatedBy: .newlines)
        let filteredLines = lines.filter { $0.contains(emoji) }
        return filteredLines.joined(separator: "\n")
    }
    
    private func filterLogs(_ logs: String, bySearchText searchText: String) -> String {
        let lines = logs.components(separatedBy: .newlines)
        let filteredLines = lines.filter { $0.lowercased().contains(searchText.lowercased()) }
        return filteredLines.joined(separator: "\n")
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // MARK: - Actions
    
    @objc private func refreshButtonTapped() {
        loadLogs()
    }
    
    @objc private func filterButtonTapped() {
        // Create alert controller with filter options
        let alert = UIAlertController(
            title: "Filter Logs",
            message: "Select log level to filter by",
            preferredStyle: .actionSheet
        )
        
        // Add filter options
        alert.addAction(UIAlertAction(title: "All Logs", style: .default) { _ in
            self.logLevelFilter = nil
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Info", style: .default) { _ in
            self.logLevelFilter = .info
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Debug", style: .default) { _ in
            self.logLevelFilter = .debug
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Warning", style: .default) { _ in
            self.logLevelFilter = .warning
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Error", style: .default) { _ in
            self.logLevelFilter = .error
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Critical", style: .default) { _ in
            self.logLevelFilter = .critical
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // For iPad, set the source view and rect
        if let popoverController = alert.popoverPresentationController {
            if let filterButton = toolbar.items?[2] {
                popoverController.barButtonItem = filterButton
            } else {
                popoverController.sourceView = view
                popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }
        }
        
        present(alert, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        // Create alert controller for search
        let alert = UIAlertController(
            title: "Search Logs",
            message: "Enter text to search for",
            preferredStyle: .alert
        )
        
        // Add text field
        alert.addTextField { textField in
            textField.placeholder = "Search text"
            textField.text = self.searchText
        }
        
        // Add actions
        alert.addAction(UIAlertAction(title: "Search", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                self.searchText = text
                self.loadLogs()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Clear Search", style: .destructive) { _ in
            self.searchText = nil
            self.loadLogs()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true)
    }
    
    @objc private func autoRefreshButtonTapped() {
        // Toggle auto-refresh
        autoRefreshEnabled = !autoRefreshEnabled
        
        if autoRefreshEnabled {
            // Start refresh timer
            refreshTimer = Timer.scheduledTimer(
                timeInterval: refreshInterval,
                target: self,
                selector: #selector(refreshButtonTapped),
                userInfo: nil,
                repeats: true
            )
            
            // Update button appearance
            if let autoRefreshButton = toolbar.items?[6] {
                autoRefreshButton.image = UIImage(systemName: "timer.fill")
            }
            
            logger.log(message: "Auto-refresh enabled", type: .info)
            
        } else {
            // Stop refresh timer
            refreshTimer?.invalidate()
            refreshTimer = nil
            
            // Update button appearance
            if let autoRefreshButton = toolbar.items?[6] {
                autoRefreshButton.image = UIImage(systemName: "timer")
            }
            
            logger.log(message: "Auto-refresh disabled", type: .info)
        }
    }
    
    @objc private func clearButtonTapped() {
        // Confirm clear
        let alert = UIAlertController(
            title: "Clear Log View",
            message: "This will clear the current log view but won't delete the log file.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.textView.text = ""
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true)
    }
    
    @objc private func shareButtonTapped() {
        // Create temporary file with log contents
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("app_logs.txt")
        
        do {
            try textView.text.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            // Create activity view controller
            let activityViewController = UIActivityViewController(
                activityItems: [tempFileURL],
                applicationActivities: nil
            )
            
            // Present activity view controller
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.barButtonItem = navigationItem.rightBarButtonItem
            }
            
            present(activityViewController, animated: true)
            
        } catch {
            logger.log(message: "Error creating log file for sharing: \(error.localizedDescription)", type: .error)
        }
    }
}