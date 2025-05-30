import UIKit

/// View controller for the AI Assistant tab
class AIViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let welcomeLabel = UILabel()
    private let startChatButton = UIButton(type: .system)
    private let recentChatsTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateView = UIView()
    
    // MARK: - Data
    
    private var recentSessions: [ChatSession] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        configureNavigationBar()
        setupTableView()
        setupEmptyState()
        
        // Log initialization
        Debug.shared.log(message: "AIViewController initialized", type: .info)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load recent chat sessions
        loadRecentSessions()
    }
    
    // MARK: - ViewControllerRefreshable Protocol Implementation
    
    override func refreshContent() {
        // Reload data when tab is selected to refresh content
        loadRecentSessions()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Welcome label
        welcomeLabel.text = "AI Assistant"
        welcomeLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        welcomeLabel.textAlignment = .center
        welcomeLabel.textColor = .label
        
        // Start chat button
        startChatButton.setTitle("Start New Chat", for: .normal)
        startChatButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        startChatButton.backgroundColor = Preferences.appTintColor.uiColor
        startChatButton.setTitleColor(.white, for: .normal)
        startChatButton.layer.cornerRadius = 12
        startChatButton.addTarget(self, action: #selector(startNewChat), for: .touchUpInside)
        
        // Add shadow to button
        startChatButton.layer.shadowColor = UIColor.black.cgColor
        startChatButton.layer.shadowOpacity = 0.2
        startChatButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        startChatButton.layer.shadowRadius = 4
        
        // Add subviews
        view.addSubview(welcomeLabel)
        view.addSubview(startChatButton)
        view.addSubview(recentChatsTableView)
        view.addSubview(emptyStateView)
        
        // Configure constraints
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        startChatButton.translatesAutoresizingMaskIntoConstraints = false
        recentChatsTableView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            welcomeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            welcomeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            welcomeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            startChatButton.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 20),
            startChatButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startChatButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startChatButton.heightAnchor.constraint(equalToConstant: 50),
            
            recentChatsTableView.topAnchor.constraint(equalTo: startChatButton.bottomAnchor, constant: 20),
            recentChatsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recentChatsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recentChatsTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: recentChatsTableView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: recentChatsTableView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: recentChatsTableView.widthAnchor, multiplier: 0.8),
            emptyStateView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func configureNavigationBar() {
        navigationItem.title = "AI Assistant"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    private func setupTableView() {
        recentChatsTableView.dataSource = self
        recentChatsTableView.delegate = self
        recentChatsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ChatSessionCell")
        recentChatsTableView.backgroundColor = UIColor.systemGroupedBackground
        recentChatsTableView.separatorStyle = UITableViewCell.SeparatorStyle.singleLine
        recentChatsTableView.tableFooterView = UIView()
    }
    
    private func setupEmptyState() {
        // Create empty state view
        let imageView = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.text = "No recent chats"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        
        emptyStateView.addSubview(imageView)
        emptyStateView.addSubview(label)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            label.bottomAnchor.constraint(lessThanOrEqualTo: emptyStateView.bottomAnchor)
        ])
        
        // Initially hidden, will show if no chats
        emptyStateView.isHidden = true
    }
    
    // MARK: - Data Loading
    
    private func loadRecentSessions() {
        // Load recent chat sessions from CoreData
        // Fetch up to 20 recent sessions
        recentSessions = CoreDataManager.shared.fetchRecentChatSessions(limit: 20)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Show/hide empty state based on data
            self.emptyStateView.isHidden = !self.recentSessions.isEmpty
            self.recentChatsTableView.reloadData()
        }
    }
    
    // MARK: - Actions
    
    @objc private func startNewChat() {
        // Create a new chat session
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let timestamp = dateFormatter.string(from: Date())
            let title = "Chat on \(timestamp)"
            
            guard let session = try? CoreDataManager.shared.createAIChatSession(title: title) else {
                throw NSError(domain: "com.backdoor.aiViewController", code: 1, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to create chat session"])
            }
            
            // Present chat view controller
            let chatVC = ChatViewController(session: session)
            
            // Set dismiss handler to refresh the list
            chatVC.dismissHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.loadRecentSessions()
                }
            }
            
            // Present chat view controller
            let navController = UINavigationController(rootViewController: chatVC)
            
            // Configure presentation style based on device
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad-specific presentation
                navController.modalPresentationStyle = .formSheet
                navController.preferredContentSize = CGSize(width: 540, height: 620)
            } else {
                // iPhone presentation
                if #available(iOS 15.0, *) {
                    if let sheet = navController.sheetPresentationController {
                        // Use sheet presentation for iOS 15+
                        sheet.detents = [.medium(), .large()]
                        sheet.prefersGrabberVisible = true
                        sheet.preferredCornerRadius = 24
                        
                        // Add delegate to handle dismissal properly
                        sheet.delegate = chatVC
                    }
                } else {
                    // Fallback for older iOS versions
                    navController.modalPresentationStyle = .fullScreen
                }
            }
            
            present(navController, animated: true)
            
        } catch {
            Debug.shared.log(message: "Failed to create chat session: \(error.localizedDescription)", type: .error)
            
            // Show error alert
            let alert = UIAlertController(
                title: "Chat Error",
                message: "Failed to start a new chat. Please try again later.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource

extension AIViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentSessions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatSessionCell", for: indexPath)
        
        // Configure cell
        let session = recentSessions[indexPath.row]
        
        // Use modern cell configuration if available
        if #available(iOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = session.title
            
            // Format date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            if let date = session.createdAt {
                content.secondaryText = dateFormatter.string(from: date)
            }
            
            content.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
            content.imageProperties.tintColor = Preferences.appTintColor.uiColor
            
            cell.contentConfiguration = content
        } else {
            // Fallback for older iOS versions
            cell.textLabel?.text = session.title
            
            // Format date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            if let date = session.createdAt {
                cell.detailTextLabel?.text = dateFormatter.string(from: date)
            }
        }
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return recentSessions.isEmpty ? nil : "Recent Chats"
    }
}

// MARK: - UITableViewDelegate

extension AIViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get selected session
        let session = recentSessions[indexPath.row]
        
        // Present chat view controller with this session
        let chatVC = ChatViewController(session: session)
        
        // Set dismiss handler to refresh the list
        chatVC.dismissHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.loadRecentSessions()
            }
        }
        
        // Present chat view controller
        let navController = UINavigationController(rootViewController: chatVC)
        
        // Configure presentation style based on device
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad-specific presentation
            navController.modalPresentationStyle = .formSheet
            navController.preferredContentSize = CGSize(width: 540, height: 620)
        } else {
            // iPhone presentation
            if #available(iOS 15.0, *) {
                if let sheet = navController.sheetPresentationController {
                    // Use sheet presentation for iOS 15+
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                    sheet.preferredCornerRadius = 24
                    
                    // Add delegate to handle dismissal properly
                    sheet.delegate = chatVC
                }
            } else {
                // Fallback for older iOS versions
                navController.modalPresentationStyle = .fullScreen
            }
        }
        
        present(navController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Get session to delete
            let session = recentSessions[indexPath.row]
            
            // Delete from CoreData
            do {
                try CoreDataManager.shared.deleteChatSession(session)
                
                // Update local array
                recentSessions.remove(at: indexPath.row)
                
                // Update UI
                tableView.deleteRows(at: [indexPath], with: .fade)
                
                // Show empty state if needed
                emptyStateView.isHidden = !recentSessions.isEmpty
                
            } catch {
                Debug.shared.log(message: "Failed to delete chat session: \(error.localizedDescription)", type: .error)
                
                // Show error alert
                let alert = UIAlertController(
                    title: "Delete Error",
                    message: "Failed to delete the chat session. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}


