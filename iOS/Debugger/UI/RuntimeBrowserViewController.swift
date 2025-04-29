import UIKit

/// View controller for browsing the runtime
class RuntimeBrowserViewController: UIViewController {
    // MARK: - Properties
    
    /// Table view for displaying classes
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    /// Search bar for filtering classes
    private let searchBar = UISearchBar()
    
    /// Runtime inspector
    private let runtimeInspector = RuntimeInspector.shared
    
    /// FLEX integration
    private let flexIntegration = FLEXIntegration.shared
    
    /// Logger instance
    private let logger = Debug.shared
    
    /// All classes
    private var allClasses: [String] = []
    
    /// Filtered classes
    private var filteredClasses: [String] = []
    
    /// Current search text
    private var searchText: String = ""
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadClasses()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set title
        title = "Runtime Browser"
        
        // Set up search bar
        searchBar.placeholder = "Filter classes..."
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ClassCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add FLEX button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "FLEX",
            style: .plain,
            target: self,
            action: #selector(flexButtonTapped)
        )
    }
    
    // MARK: - Data Loading
    
    private func loadClasses() {
        // Get all loaded classes
        allClasses = runtimeInspector.getLoadedClasses()
        
        // Apply filter
        filterClasses()
    }
    
    private func filterClasses() {
        // Apply search filter
        if searchText.isEmpty {
            filteredClasses = allClasses
        } else {
            filteredClasses = allClasses.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
        
        // Reload table view
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func flexButtonTapped() {
        // Show FLEX explorer
        flexIntegration.showExplorer()
    }
}

// MARK: - UITableViewDataSource

extension RuntimeBrowserViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredClasses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ClassCell", for: indexPath)
        
        // Configure cell
        let className = filteredClasses[indexPath.row]
        cell.textLabel?.text = className
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension RuntimeBrowserViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get class name
        let className = filteredClasses[indexPath.row]
        
        // Show class details
        let classDetailsVC = ClassDetailsViewController(className: className)
        navigationController?.pushViewController(classDetailsVC, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension RuntimeBrowserViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Update search text
        self.searchText = searchText
        
        // Apply filter
        filterClasses()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Dismiss keyboard
        searchBar.resignFirstResponder()
    }
}

// MARK: - ClassDetailsViewController

class ClassDetailsViewController: UIViewController {
    // MARK: - Properties
    
    /// Table view for displaying class details
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    /// Runtime inspector
    private let runtimeInspector = RuntimeInspector.shared
    
    /// FLEX integration
    private let flexIntegration = FLEXIntegration.shared
    
    /// Logger instance
    private let logger = Debug.shared
    
    /// Class name
    private let className: String
    
    /// Methods
    private var methods: [String] = []
    
    /// Properties
    private var properties: [String] = []
    
    /// Ivars
    private var ivars: [String] = []
    
    /// Protocols
    private var protocols: [String] = []
    
    // MARK: - Initialization
    
    init(className: String) {
        self.className = className
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadClassDetails()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set title
        title = className
        
        // Set up table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DetailCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add FLEX button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "FLEX",
            style: .plain,
            target: self,
            action: #selector(flexButtonTapped)
        )
    }
    
    // MARK: - Data Loading
    
    private func loadClassDetails() {
        // Get methods
        methods = runtimeInspector.getMethods(forClass: className)
        
        // Get properties
        properties = runtimeInspector.getProperties(forClass: className)
        
        // Get ivars
        ivars = runtimeInspector.getIvars(forClass: className)
        
        // Get protocols
        protocols = runtimeInspector.getProtocols(forClass: className)
        
        // Reload table view
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func flexButtonTapped() {
        // Show FLEX explorer
        flexIntegration.showExplorer()
    }
}

// MARK: - UITableViewDataSource

extension ClassDetailsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return properties.count
        case 1:
            return methods.count
        case 2:
            return ivars.count
        case 3:
            return protocols.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell", for: indexPath)
        
        // Configure cell
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = properties[indexPath.row]
        case 1:
            cell.textLabel?.text = methods[indexPath.row]
        case 2:
            cell.textLabel?.text = ivars[indexPath.row]
        case 3:
            cell.textLabel?.text = protocols[indexPath.row]
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Properties (\(properties.count))"
        case 1:
            return "Methods (\(methods.count))"
        case 2:
            return "Ivars (\(ivars.count))"
        case 3:
            return "Protocols (\(protocols.count))"
        default:
            return nil
        }
    }
}

// MARK: - UITableViewDelegate

extension ClassDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get item
        let item: String
        switch indexPath.section {
        case 0:
            item = properties[indexPath.row]
        case 1:
            item = methods[indexPath.row]
        case 2:
            item = ivars[indexPath.row]
        case 3:
            item = protocols[indexPath.row]
        default:
            return
        }
        
        // Show item details
        let alert = UIAlertController(
            title: item,
            message: "Class: \(className)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}