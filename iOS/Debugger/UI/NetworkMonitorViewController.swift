import UIKit


    /// View controller for the network tab in the debugger
    class NetworkMonitorViewController: UIViewController {
        // MARK: - Properties

        /// The debugger engine
        private let debuggerEngine = DebuggerEngine.shared
        
        /// FLEX integration
        private let flexIntegration = FLEXIntegration.shared

        /// Logger instance
        private let logger = Debug.shared
        
        /// Toggle for using FLEX network monitoring
        private var useFLEXMonitoring = true

        /// Table view for displaying network requests
        private let tableView: UITableView = {
            let tableView = UITableView(frame: .zero, style: .plain)
            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.register(
                NetworkRequestTableViewCell.self,
                forCellReuseIdentifier: NetworkRequestTableViewCell.reuseIdentifier
            )
            return tableView
        }()

        /// Search bar for filtering requests
        private let searchBar: UISearchBar = {
            let searchBar = UISearchBar()
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            searchBar.placeholder = "Filter requests..."
            searchBar.searchBarStyle = .minimal
            return searchBar
        }()

        /// Refresh control for pulling to refresh
        private let refreshControl = UIRefreshControl()

        /// Clear button
        private let clearButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Clear", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.tintColor = UIColor.systemRed
            return button
        }()

        /// Network requests
        private var networkRequests: [NetworkRequest] = []

        /// Filtered network requests
        private var filteredRequests: [NetworkRequest] = []

        /// Current search text
        private var searchText: String = ""

        // MARK: - Lifecycle

        override func viewDidLoad() {
            super.viewDidLoad()

            setupUI()
            setupActions()
            setupNetworkMonitoring()

            // Set title
            title = "Network"

            // Add some sample data for demonstration
            addSampleData()
        }

        // MARK: - Setup

        private func setupUI() {
            // Set background color
            view.backgroundColor = UIColor.systemBackground

            // Add search bar
            view.addSubview(searchBar)

            // Add clear button
            view.addSubview(clearButton)

            // Add table view
            view.addSubview(tableView)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Search bar
                searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                searchBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                searchBar.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),

                // Clear button
                clearButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
                clearButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                clearButton.widthAnchor.constraint(equalToConstant: 60),
                clearButton.heightAnchor.constraint(equalToConstant: 30),

                // Table view
                tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            ])

            // Set up table view
            tableView.delegate = self
            tableView.dataSource = self

            // Add refresh control
            tableView.refreshControl = refreshControl

            // Set up search bar
            searchBar.delegate = self
            
            // Add FLEX button to navigation bar
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "FLEX",
                style: .plain,
                target: self,
                action: #selector(flexButtonTapped)
            )
        }

        private func setupActions() {
            // Add target for refresh control
            refreshControl.addTarget(self, action: #selector(refreshNetworkRequests), for: .valueChanged)

            // Add target for clear button
            clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        }

        private func setupNetworkMonitoring() {
            if useFLEXMonitoring {
                // Use FLEX's network monitoring capabilities
                logger.log(message: "Using FLEX network monitoring", type: .info)
                
                // FLEX automatically sets up network monitoring when initialized
                // We just need to make sure it's enabled
                
                // This is done through runtime invocation to avoid compile-time dependency
                if let flexManager = flexIntegration.getFlexManager() {
                    // Check if network monitoring is enabled
                    if let isNetworkDebuggingEnabledSelector = NSSelectorFromString("isNetworkDebuggingEnabled"),
                       flexManager.responds(to: isNetworkDebuggingEnabledSelector) {
                        
                        // If not enabled, enable it
                        if let result = flexManager.perform(isNetworkDebuggingEnabledSelector)?.takeRetainedValue() as? Bool,
                           !result {
                            if let setNetworkDebuggingEnabledSelector = NSSelectorFromString("setNetworkDebuggingEnabled:"),
                               flexManager.responds(to: setNetworkDebuggingEnabledSelector) {
                                _ = flexManager.perform(setNetworkDebuggingEnabledSelector, with: true)
                                logger.log(message: "FLEX network monitoring enabled", type: .info)
                            }
                        }
                    }
                }
            } else {
                // Use our custom network monitoring implementation
                NetworkMonitor.shared.enable()
                
                // Register for network request notifications
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleNetworkRequestAdded),
                    name: .networkRequestAdded,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleNetworkRequestUpdated),
                    name: .networkRequestUpdated,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleNetworkRequestsCleared),
                    name: .networkRequestsCleared,
                    object: nil
                )
                
                logger.log(message: "Custom network monitoring set up", type: .info)
            }
        }

        // MARK: - Actions

        @objc private func refreshNetworkRequests() {
            if useFLEXMonitoring {
                // Get network transactions from FLEX
                fetchFLEXNetworkTransactions()
            } else {
                // Get network requests from our custom monitor
                networkRequests = NetworkMonitor.shared.getNetworkRequests()
                filteredRequests = networkRequests
                
                // Reload table view
                tableView.reloadData()
            }

            // End refreshing
            refreshControl.endRefreshing()
        }

        @objc private func clearButtonTapped() {
            if useFLEXMonitoring {
                // Clear FLEX network transactions
                clearFLEXNetworkTransactions()
            } else {
                // Clear network requests from our custom monitor
                NetworkMonitor.shared.clearNetworkRequests()
            }
            
            // Clear network requests
            networkRequests.removeAll()
            filteredRequests.removeAll()

            // Reload table view
            tableView.reloadData()
        }
        
        @objc private func handleNetworkRequestAdded(_ notification: Notification) {
            // Get the network request
            guard let request = notification.object as? NetworkRequest else { return }
            
            // Add to network requests
            networkRequests.append(request)
            
            // Apply filter
            filterRequests()
            
            // Reload table view on main thread
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        @objc private func handleNetworkRequestUpdated(_ notification: Notification) {
            // Get the network request
            guard let updatedRequest = notification.object as? NetworkRequest else { return }
            
            // Find the request
            if let index = networkRequests.firstIndex(where: { $0.url == updatedRequest.url }) {
                // Update the request
                networkRequests[index] = updatedRequest
                
                // Apply filter
                filterRequests()
                
                // Reload table view on main thread
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
        
        @objc private func handleNetworkRequestsCleared(_ notification: Notification) {
            // Clear network requests
            networkRequests.removeAll()
            filteredRequests.removeAll()
            
            // Reload table view on main thread
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        @objc private func flexButtonTapped() {
            // Show FLEX network monitor directly
            if let flexManager = flexIntegration.getFlexManager() {
                // Try to present the network history view controller
                if let networkHistorySelector = NSSelectorFromString("showNetworkHistoryViewController"),
                   flexManager.responds(to: networkHistorySelector) {
                    _ = flexManager.perform(networkHistorySelector)
                    logger.log(message: "FLEX network history shown", type: .info)
                } else {
                    // Fallback to showing the explorer
                    flexIntegration.showExplorer()
                }
            } else {
                // Fallback to showing the explorer
                flexIntegration.showExplorer()
            }
        }
        
        private func fetchFLEXNetworkTransactions() {
            // Get network transactions from FLEX using runtime invocation
            if let flexManager = flexIntegration.getFlexManager() {
                // Try to get the network recorder
                if let networkRecorderSelector = NSSelectorFromString("networkRecorder"),
                   flexManager.responds(to: networkRecorderSelector),
                   let networkRecorder = flexManager.perform(networkRecorderSelector)?.takeRetainedValue() {
                    
                    // Try to get the network transactions
                    if let transactionsSelector = NSSelectorFromString("transactions"),
                       networkRecorder.responds(to: transactionsSelector),
                       let transactions = networkRecorder.perform(transactionsSelector)?.takeRetainedValue() as? [AnyObject] {
                        
                        // Convert FLEX transactions to our model
                        networkRequests = convertFLEXTransactionsToNetworkRequests(transactions)
                        filteredRequests = networkRequests
                        
                        // Reload table view
                        tableView.reloadData()
                        
                        logger.log(message: "Fetched \(transactions.count) FLEX network transactions", type: .info)
                    }
                }
            }
        }
        
        private func clearFLEXNetworkTransactions() {
            // Clear FLEX network transactions using runtime invocation
            if let flexManager = flexIntegration.getFlexManager() {
                // Try to get the network recorder
                if let networkRecorderSelector = NSSelectorFromString("networkRecorder"),
                   flexManager.responds(to: networkRecorderSelector),
                   let networkRecorder = flexManager.perform(networkRecorderSelector)?.takeRetainedValue() {
                    
                    // Try to clear the network transactions
                    if let clearRecorderSelector = NSSelectorFromString("clearRecordedActivity"),
                       networkRecorder.responds(to: clearRecorderSelector) {
                        _ = networkRecorder.perform(clearRecorderSelector)
                        logger.log(message: "Cleared FLEX network transactions", type: .info)
                    }
                }
            }
        }
        
        private func convertFLEXTransactionsToNetworkRequests(_ transactions: [AnyObject]) -> [NetworkRequest] {
            var requests: [NetworkRequest] = []
            
            for transaction in transactions {
                // Extract properties using KVC
                let url = transaction.value(forKey: "request")?.value(forKey: "URL") as? URL ?? URL(string: "https://unknown.url")!
                let method = transaction.value(forKey: "request")?.value(forKey: "HTTPMethod") as? String ?? "UNKNOWN"
                
                let requestHeaders = transaction.value(forKey: "request")?.value(forKey: "allHTTPHeaderFields") as? [String: String] ?? [:]
                let requestBody = transaction.value(forKey: "request")?.value(forKey: "HTTPBody") as? Data
                
                let responseStatus = transaction.value(forKey: "response")?.value(forKey: "statusCode") as? Int ?? 0
                let responseHeaders = transaction.value(forKey: "response")?.value(forKey: "allHeaderFields") as? [String: String] ?? [:]
                
                let responseBodyData = transaction.value(forKey: "responseBody") as? Data
                let responseBody = responseBodyData != nil ? String(data: responseBodyData!, encoding: .utf8) : nil
                
                let startTime = transaction.value(forKey: "startTime") as? TimeInterval ?? 0
                let duration = transaction.value(forKey: "duration") as? TimeInterval ?? 0
                
                let timestamp = Date(timeIntervalSince1970: startTime)
                
                // Create network request
                let request = NetworkRequest(
                    url: url,
                    method: method,
                    requestHeaders: requestHeaders,
                    requestBody: requestBody != nil ? String(data: requestBody!, encoding: .utf8) : nil,
                    responseStatus: responseStatus,
                    responseHeaders: responseHeaders,
                    responseBody: responseBody,
                    timestamp: timestamp,
                    duration: duration
                )
                
                requests.append(request)
            }
            
            return requests
        }

        // MARK: - Helper Methods

        private func addSampleData() {
            // Add some sample network requests for demonstration
            let request1 = NetworkRequest(
                url: URL(string: "https://api.example.com/users")!,
                method: "GET",
                requestHeaders: ["Authorization": "Bearer token123"],
                requestBody: nil,
                responseStatus: 200,
                responseHeaders: ["Content-Type": "application/json"],
                responseBody: "{\"users\": [{\"id\": 1, \"name\": \"John\"}]}",
                timestamp: Date(),
                duration: 0.35
            )

            let request2 = NetworkRequest(
                url: URL(string: "https://api.example.com/posts")!,
                method: "POST",
                requestHeaders: ["Authorization": "Bearer token123", "Content-Type": "application/json"],
                requestBody: "{\"title\": \"New Post\", \"content\": \"Hello, world!\"}",
                responseStatus: 201,
                responseHeaders: ["Content-Type": "application/json"],
                responseBody: "{\"id\": 42, \"title\": \"New Post\", \"content\": \"Hello, world!\"}",
                timestamp: Date().addingTimeInterval(-60),
                duration: 0.42
            )

            let request3 = NetworkRequest(
                url: URL(string: "https://api.example.com/invalid")!,
                method: "GET",
                requestHeaders: ["Authorization": "Bearer token123"],
                requestBody: nil,
                responseStatus: 404,
                responseHeaders: ["Content-Type": "application/json"],
                responseBody: "{\"error\": \"Not found\"}",
                timestamp: Date().addingTimeInterval(-120),
                duration: 0.28
            )

            // Add requests
            networkRequests = [request1, request2, request3]
            filteredRequests = networkRequests

            // Reload table view
            tableView.reloadData()
        }

        private func filterRequests() {
            // Apply search filter
            if searchText.isEmpty {
                filteredRequests = networkRequests
            } else {
                filteredRequests = networkRequests.filter { request in
                    request.url.absoluteString.lowercased().contains(searchText.lowercased()) ||
                        request.method.lowercased().contains(searchText.lowercased())
                }
            }

            // Reload table view
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDelegate

    extension NetworkMonitorViewController: UITableViewDelegate {
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)

            // Get request
            let request = filteredRequests[indexPath.row]

            // Show request details
            let detailsVC = NetworkRequestDetailsViewController(request: request)
            navigationController?.pushViewController(detailsVC, animated: true)
        }

        func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
            return 70
        }
    }

    // MARK: - UITableViewDataSource

    extension NetworkMonitorViewController: UITableViewDataSource {
        func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
            return filteredRequests.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: NetworkRequestTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? NetworkRequestTableViewCell else {
                return UITableViewCell()
            }

            // Configure cell
            let request = filteredRequests[indexPath.row]
            cell.configure(with: request)

            return cell
        }
    }

    // MARK: - UISearchBarDelegate

    extension NetworkMonitorViewController: UISearchBarDelegate {
        func searchBar(_: UISearchBar, textDidChange searchText: String) {
            // Update search text
            self.searchText = searchText

            // Apply filter
            filterRequests()
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            // Dismiss keyboard
            searchBar.resignFirstResponder()
        }
    }

    // MARK: - NetworkRequest

    struct NetworkRequest {
        let url: URL
        let method: String
        let requestHeaders: [String: String]
        let requestBody: String?
        let responseStatus: Int
        let responseHeaders: [String: String]
        let responseBody: String?
        let timestamp: Date
        let duration: TimeInterval

        var isSuccess: Bool {
            return responseStatus >= 200 && responseStatus < 300
        }

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)
        }

        var formattedDuration: String {
            return String(format: "%.2f s", duration)
        }
    }

    // MARK: - NetworkRequestTableViewCell

    class NetworkRequestTableViewCell: UITableViewCell {
        // MARK: - Properties

        static let reuseIdentifier = "NetworkRequestTableViewCell"

        /// URL label
        private let urlLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.numberOfLines = 1
            return label
        }()

        /// Method label
        private let methodLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .center
            return label
        }()

        /// Status label
        private let statusLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .center
            return label
        }()

        /// Time label
        private let timeLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor.secondaryLabel
            return label
        }()

        /// Duration label
        private let durationLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor.secondaryLabel
            label.textAlignment = .right
            return label
        }()

        // MARK: - Initialization

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            setupUI()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)

            setupUI()
        }

        // MARK: - Setup

        private func setupUI() {
            // Add method label
            contentView.addSubview(methodLabel)

            // Add URL label
            contentView.addSubview(urlLabel)

            // Add status label
            contentView.addSubview(statusLabel)

            // Add time label
            contentView.addSubview(timeLabel)

            // Add duration label
            contentView.addSubview(durationLabel)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Method label
                methodLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                methodLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                methodLabel.widthAnchor.constraint(equalToConstant: 60),

                // URL label
                urlLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                urlLabel.leadingAnchor.constraint(equalTo: methodLabel.trailingAnchor, constant: 8),
                urlLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),

                // Status label
                statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                statusLabel.widthAnchor.constraint(equalToConstant: 50),

                // Time label
                timeLabel.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 4),
                timeLabel.leadingAnchor.constraint(equalTo: methodLabel.trailingAnchor, constant: 8),
                timeLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),

                // Duration label
                durationLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
                durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                durationLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            ])
        }

        // MARK: - Configuration

        func configure(with request: NetworkRequest) {
            // Set URL label
            urlLabel.text = request.url.absoluteString

            // Set method label
            methodLabel.text = request.method

            // Set method label background color
            switch request.method {
            case "GET":
                methodLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
                methodLabel.textColor = UIColor.systemBlue
            case "POST":
                methodLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
                methodLabel.textColor = UIColor.systemGreen
            case "PUT":
                methodLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
                methodLabel.textColor = UIColor.systemOrange
            case "DELETE":
                methodLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
                methodLabel.textColor = UIColor.systemRed
            default:
                methodLabel.backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
                methodLabel.textColor = UIColor.systemGray
            }

            // Set status label
            statusLabel.text = "\(request.responseStatus)"

            // Set status label color
            if request.isSuccess {
                statusLabel.textColor = UIColor.systemGreen
            } else {
                statusLabel.textColor = UIColor.systemRed
            }

            // Set time label
            timeLabel.text = request.formattedTimestamp

            // Set duration label
            durationLabel.text = request.formattedDuration

            // Set accessory type
            accessoryType = .disclosureIndicator
        }
    }

    // MARK: - NetworkRequestDetailsViewController

    class NetworkRequestDetailsViewController: UIViewController {
        // MARK: - Properties

        /// The network request
        private let request: NetworkRequest

        /// Scroll view
        private let scrollView: UIScrollView = {
            let scrollView = UIScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            return scrollView
        }()

        /// Content view
        private let contentView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        /// Segmented control for switching between request and response
        private let segmentedControl: UISegmentedControl = {
            let items = ["Request", "Response"]
            let segmentedControl = UISegmentedControl(items: items)
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.selectedSegmentIndex = 0
            return segmentedControl
        }()

        /// Request view
        private let requestView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        /// Response view
        private let responseView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isHidden = true
            return view
        }()

        // MARK: - Initialization

        init(request: NetworkRequest) {
            self.request = request
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Lifecycle

        override func viewDidLoad() {
            super.viewDidLoad()

            setupUI()
            setupActions()

            // Set title
            title = request.url.lastPathComponent
        }

        // MARK: - Setup

        private func setupUI() {
            // Set background color
            view.backgroundColor = UIColor.systemBackground

            // Add scroll view
            view.addSubview(scrollView)

            // Add content view
            scrollView.addSubview(contentView)

            // Add segmented control
            contentView.addSubview(segmentedControl)

            // Add request view
            contentView.addSubview(requestView)

            // Add response view
            contentView.addSubview(responseView)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Scroll view
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

                // Content view
                contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

                // Segmented control
                segmentedControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
                segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

                // Request view
                requestView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
                requestView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                requestView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                requestView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

                // Response view
                responseView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
                responseView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                responseView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                responseView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])

            // Set up request view
            setupRequestView()

            // Set up response view
            setupResponseView()
        }

        private func setupRequestView() {
            // Create labels for request details
            let urlTitleLabel = createTitleLabel(text: "URL:")
            let urlValueLabel = createValueLabel(text: request.url.absoluteString)

            let methodTitleLabel = createTitleLabel(text: "Method:")
            let methodValueLabel = createValueLabel(text: request.method)

            let headersTitleLabel = createTitleLabel(text: "Headers:")
            let headersValueLabel = createValueLabel(text: formatHeaders(request.requestHeaders))

            let bodyTitleLabel = createTitleLabel(text: "Body:")
            let bodyValueLabel = createValueLabel(text: request.requestBody ?? "None")

            // Add labels to request view
            requestView.addSubview(urlTitleLabel)
            requestView.addSubview(urlValueLabel)
            requestView.addSubview(methodTitleLabel)
            requestView.addSubview(methodValueLabel)
            requestView.addSubview(headersTitleLabel)
            requestView.addSubview(headersValueLabel)
            requestView.addSubview(bodyTitleLabel)
            requestView.addSubview(bodyValueLabel)

            // Set up constraints
            NSLayoutConstraint.activate([
                // URL title label
                urlTitleLabel.topAnchor.constraint(equalTo: requestView.topAnchor, constant: 16),
                urlTitleLabel.leadingAnchor.constraint(equalTo: requestView.leadingAnchor, constant: 16),
                urlTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // URL value label
                urlValueLabel.topAnchor.constraint(equalTo: requestView.topAnchor, constant: 16),
                urlValueLabel.leadingAnchor.constraint(equalTo: urlTitleLabel.trailingAnchor, constant: 8),
                urlValueLabel.trailingAnchor.constraint(equalTo: requestView.trailingAnchor, constant: -16),

                // Method title label
                methodTitleLabel.topAnchor.constraint(equalTo: urlValueLabel.bottomAnchor, constant: 16),
                methodTitleLabel.leadingAnchor.constraint(equalTo: requestView.leadingAnchor, constant: 16),
                methodTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // Method value label
                methodValueLabel.topAnchor.constraint(equalTo: urlValueLabel.bottomAnchor, constant: 16),
                methodValueLabel.leadingAnchor.constraint(equalTo: methodTitleLabel.trailingAnchor, constant: 8),
                methodValueLabel.trailingAnchor.constraint(equalTo: requestView.trailingAnchor, constant: -16),

                // Headers title label
                headersTitleLabel.topAnchor.constraint(equalTo: methodValueLabel.bottomAnchor, constant: 16),
                headersTitleLabel.leadingAnchor.constraint(equalTo: requestView.leadingAnchor, constant: 16),
                headersTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // Headers value label
                headersValueLabel.topAnchor.constraint(equalTo: methodValueLabel.bottomAnchor, constant: 16),
                headersValueLabel.leadingAnchor.constraint(equalTo: headersTitleLabel.trailingAnchor, constant: 8),
                headersValueLabel.trailingAnchor.constraint(equalTo: requestView.trailingAnchor, constant: -16),

                // Body title label
                bodyTitleLabel.topAnchor.constraint(equalTo: headersValueLabel.bottomAnchor, constant: 16),
                bodyTitleLabel.leadingAnchor.constraint(equalTo: requestView.leadingAnchor, constant: 16),
                bodyTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // Body value label
                bodyValueLabel.topAnchor.constraint(equalTo: headersValueLabel.bottomAnchor, constant: 16),
                bodyValueLabel.leadingAnchor.constraint(equalTo: bodyTitleLabel.trailingAnchor, constant: 8),
                bodyValueLabel.trailingAnchor.constraint(equalTo: requestView.trailingAnchor, constant: -16),
                bodyValueLabel.bottomAnchor.constraint(equalTo: requestView.bottomAnchor, constant: -16),
            ])
        }

        private func setupResponseView() {
            // Create labels for response details
            let statusTitleLabel = createTitleLabel(text: "Status:")
            let statusValueLabel = createValueLabel(text: "\(request.responseStatus)")

            let headersTitleLabel = createTitleLabel(text: "Headers:")
            let headersValueLabel = createValueLabel(text: formatHeaders(request.responseHeaders))

            let bodyTitleLabel = createTitleLabel(text: "Body:")
            let bodyValueLabel = createValueLabel(text: request.responseBody ?? "None")

            // Add labels to response view
            responseView.addSubview(statusTitleLabel)
            responseView.addSubview(statusValueLabel)
            responseView.addSubview(headersTitleLabel)
            responseView.addSubview(headersValueLabel)
            responseView.addSubview(bodyTitleLabel)
            responseView.addSubview(bodyValueLabel)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Status title label
                statusTitleLabel.topAnchor.constraint(equalTo: responseView.topAnchor, constant: 16),
                statusTitleLabel.leadingAnchor.constraint(equalTo: responseView.leadingAnchor, constant: 16),
                statusTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // Status value label
                statusValueLabel.topAnchor.constraint(equalTo: responseView.topAnchor, constant: 16),
                statusValueLabel.leadingAnchor.constraint(equalTo: statusTitleLabel.trailingAnchor, constant: 8),
                statusValueLabel.trailingAnchor.constraint(equalTo: responseView.trailingAnchor, constant: -16),

                // Headers title label
                headersTitleLabel.topAnchor.constraint(equalTo: statusValueLabel.bottomAnchor, constant: 16),
                headersTitleLabel.leadingAnchor.constraint(equalTo: responseView.leadingAnchor, constant: 16),
                headersTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // Headers value label
                headersValueLabel.topAnchor.constraint(equalTo: statusValueLabel.bottomAnchor, constant: 16),
                headersValueLabel.leadingAnchor.constraint(equalTo: headersTitleLabel.trailingAnchor, constant: 8),
                headersValueLabel.trailingAnchor.constraint(equalTo: responseView.trailingAnchor, constant: -16),

                // Body title label
                bodyTitleLabel.topAnchor.constraint(equalTo: headersValueLabel.bottomAnchor, constant: 16),
                bodyTitleLabel.leadingAnchor.constraint(equalTo: responseView.leadingAnchor, constant: 16),
                bodyTitleLabel.widthAnchor.constraint(equalToConstant: 80),

                // Body value label
                bodyValueLabel.topAnchor.constraint(equalTo: headersValueLabel.bottomAnchor, constant: 16),
                bodyValueLabel.leadingAnchor.constraint(equalTo: bodyTitleLabel.trailingAnchor, constant: 8),
                bodyValueLabel.trailingAnchor.constraint(equalTo: responseView.trailingAnchor, constant: -16),
                bodyValueLabel.bottomAnchor.constraint(equalTo: responseView.bottomAnchor, constant: -16),
            ])

            // Set status value label color
            if request.isSuccess {
                statusValueLabel.textColor = UIColor.systemGreen
            } else {
                statusValueLabel.textColor = UIColor.systemRed
            }
        }

        private func setupActions() {
            // Add target for segmented control
            segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        }

        // MARK: - Actions

        @objc private func segmentChanged(_ sender: UISegmentedControl) {
            // Toggle visibility of request and response views
            requestView.isHidden = sender.selectedSegmentIndex == 1
            responseView.isHidden = sender.selectedSegmentIndex == 0
        }

        // MARK: - Helper Methods

        private func createTitleLabel(text: String) -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.text = text
            return label
        }

        private func createValueLabel(text: String) -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 14)
            label.text = text
            label.numberOfLines = 0
            return label
        }

        private func formatHeaders(_ headers: [String: String]) -> String {
            if headers.isEmpty {
                return "None"
            }

            return headers.map { key, value in
                "\(key): \(value)"
            }.joined(separator: "\n")
        }
    }
