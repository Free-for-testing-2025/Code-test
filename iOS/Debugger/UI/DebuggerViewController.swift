import UIKit

/// Protocol for debugger view controller delegate
protocol DebuggerViewControllerDelegate: AnyObject {
    /// Called when the debugger view controller requests dismissal
    func debuggerViewControllerDidRequestDismissal(_ viewController: DebuggerViewController)
}

/// Main view controller for the debugger UI
class DebuggerViewController: UIViewController {
    // MARK: - Properties

    /// Delegate for handling view controller events
    weak var delegate: DebuggerViewControllerDelegate?

    /// The debugger engine
    private let debuggerEngine = DebuggerEngine.shared
    
    /// FLEX integration
    private let flexIntegration = FLEXIntegration.shared

    /// Logger instance
    private let logger = Debug.shared

    /// Tab bar controller for different debugger features
    private var debugTabBarController = UITabBarController()

    /// View controllers for each tab
    private var viewControllers: [UIViewController] = []
    
    /// Object to focus on in variables tab
    private var focusObject: Any?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupTabBarController()

        logger.log(message: "DebuggerViewController loaded", type: .info)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Register as delegate for debugger engine
        debuggerEngine.delegate = self
        
        // If we have a focus object, show it in the variables tab
        if let focusObject = focusObject {
            showVariablesTab(withObject: focusObject)
            self.focusObject = nil
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Unregister as delegate
        if debuggerEngine.delegate === self {
            debuggerEngine.delegate = nil
        }
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        // Set title
        title = "Runtime Debugger"

        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // Add FLEX mode button
        let flexModeButton = UIBarButtonItem(
            image: UIImage(systemName: "hammer.fill"),
            style: .plain,
            target: self,
            action: #selector(flexModeButtonTapped)
        )
        flexModeButton.tintColor = .systemBlue
        
        navigationItem.rightBarButtonItems = [closeButton, flexModeButton]

        // Add execution control buttons
        let pauseButton = UIBarButtonItem(
            image: UIImage(systemName: "pause.fill"),
            style: .plain,
            target: self,
            action: #selector(pauseButtonTapped)
        )

        let resumeButton = UIBarButtonItem(
            image: UIImage(systemName: "play.fill"),
            style: .plain,
            target: self,
            action: #selector(resumeButtonTapped)
        )

        let stepOverButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.right"),
            style: .plain,
            target: self,
            action: #selector(stepOverButtonTapped)
        )

        let stepIntoButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down"),
            style: .plain,
            target: self,
            action: #selector(stepIntoButtonTapped)
        )

        let stepOutButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up"),
            style: .plain,
            target: self,
            action: #selector(stepOutButtonTapped)
        )

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // Add toolbar with execution controls
        navigationController?.isToolbarHidden = false
        toolbarItems = [
            pauseButton,
            flexibleSpace,
            resumeButton,
            flexibleSpace,
            stepOverButton,
            flexibleSpace,
            stepIntoButton,
            flexibleSpace,
            stepOutButton,
        ]
    }

    private func setupTabBarController() {
        // Add tab bar controller as child view controller
        addChild(debugTabBarController)
        view.addSubview(debugTabBarController.view)
        debugTabBarController.view.frame = view.bounds
        debugTabBarController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        debugTabBarController.didMove(toParent: self)

        // Create view controllers for each tab
        let consoleVC = createConsoleViewController()
        let breakpointsVC = createBreakpointsViewController()
        let variablesVC = createVariablesViewController()
        let memoryVC = createMemoryViewController()
        let networkVC = createNetworkViewController()
        let performanceVC = createPerformanceViewController()
        let fileBrowserVC = createFileBrowserViewController()
        let systemLogVC = createSystemLogViewController()
        let runtimeBrowserVC = createRuntimeBrowserViewController()

        // Set tab bar items
        consoleVC.tabBarItem = UITabBarItem(title: "Console", image: UIImage(systemName: "terminal"), tag: 0)
        breakpointsVC.tabBarItem = UITabBarItem(
            title: "Breakpoints",
            image: UIImage(systemName: "pause.circle"),
            tag: 1
        )
        variablesVC.tabBarItem = UITabBarItem(title: "Variables", image: UIImage(systemName: "list.bullet"), tag: 2)
        memoryVC.tabBarItem = UITabBarItem(title: "Memory", image: UIImage(systemName: "memorychip"), tag: 3)
        networkVC.tabBarItem = UITabBarItem(title: "Network", image: UIImage(systemName: "network"), tag: 4)
        performanceVC.tabBarItem = UITabBarItem(title: "Performance", image: UIImage(systemName: "gauge"), tag: 5)
        fileBrowserVC.tabBarItem = UITabBarItem(title: "Files", image: UIImage(systemName: "folder"), tag: 6)
        systemLogVC.tabBarItem = UITabBarItem(title: "System Log", image: UIImage(systemName: "doc.text"), tag: 7)
        runtimeBrowserVC.tabBarItem = UITabBarItem(title: "Runtime", image: UIImage(systemName: "hammer"), tag: 8)

        // Set view controllers
        viewControllers = [
            UINavigationController(rootViewController: consoleVC),
            UINavigationController(rootViewController: breakpointsVC),
            UINavigationController(rootViewController: variablesVC),
            UINavigationController(rootViewController: memoryVC),
            UINavigationController(rootViewController: networkVC),
            UINavigationController(rootViewController: performanceVC),
            UINavigationController(rootViewController: fileBrowserVC),
            UINavigationController(rootViewController: systemLogVC),
            UINavigationController(rootViewController: runtimeBrowserVC)
        ]

        debugTabBarController.viewControllers = viewControllers
        debugTabBarController.selectedIndex = 0
    }

    // MARK: - Tab View Controllers

    private func createConsoleViewController() -> UIViewController {
        return ConsoleViewController()
    }

    private func createBreakpointsViewController() -> UIViewController {
        return BreakpointsViewController()
    }

    private func createVariablesViewController() -> UIViewController {
        return VariablesViewController()
    }

    private func createMemoryViewController() -> UIViewController {
        return MemoryViewController()
    }

    private func createNetworkViewController() -> UIViewController {
        return NetworkMonitorViewController()
    }

    private func createPerformanceViewController() -> UIViewController {
        return PerformanceViewController()
    }
    
    private func createFileBrowserViewController() -> UIViewController {
        return FileBrowserViewController()
    }
    
    private func createSystemLogViewController() -> UIViewController {
        return SystemLogViewController()
    }
    
    private func createRuntimeBrowserViewController() -> UIViewController {
        return RuntimeBrowserViewController()
    }
    
    // MARK: - Public Methods
    
    /// Show the variables tab and focus on the given object
    /// - Parameter object: The object to focus on
    func showVariablesTab(withObject object: Any) {
        // If view is loaded, show the variables tab and set the object
        if isViewLoaded {
            debugTabBarController.selectedIndex = 2
            
            // Get the variables view controller
            if let navController = viewControllers[2] as? UINavigationController,
               let variablesVC = navController.topViewController as? VariablesViewController {
                variablesVC.focusOn(object: object)
            }
        } else {
            // Store the object to focus on when the view loads
            focusObject = object
        }
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        delegate?.debuggerViewControllerDidRequestDismissal(self)
    }
    
    @objc private func flexModeButtonTapped() {
        // Switch to FLEX mode
        NotificationCenter.default.post(
            name: .switchDebugMode,
            object: DebuggerManager.DebugMode.flex
        )
        
        // Dismiss this view controller
        delegate?.debuggerViewControllerDidRequestDismissal(self)
        
        // Show FLEX explorer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.flexIntegration.showExplorer()
        }
    }

    @objc private func pauseButtonTapped() {
        debuggerEngine.pause()
    }

    @objc private func resumeButtonTapped() {
        debuggerEngine.resume()
    }

    @objc private func stepOverButtonTapped() {
        debuggerEngine.stepOver()
    }

    @objc private func stepIntoButtonTapped() {
        debuggerEngine.stepInto()
    }

    @objc private func stepOutButtonTapped() {
        debuggerEngine.stepOut()
    }
}

// MARK: - DebuggerEngineDelegate

extension DebuggerViewController: DebuggerEngineDelegate {
    func debuggerEngine(_: DebuggerEngine, didHitBreakpoint breakpoint: Breakpoint) {
        logger.log(message: "Hit breakpoint at \(breakpoint.file):\(breakpoint.line)", type: .info)

        // Switch to breakpoints tab
        DispatchQueue.main.async {
            self.debugTabBarController.selectedIndex = 1
        }
    }

    func debuggerEngine(
        _: DebuggerEngine,
        didTriggerWatchpoint watchpoint: Watchpoint,
        oldValue _: Any?,
        newValue _: Any?
    ) {
        logger.log(message: "Watchpoint triggered at address \(watchpoint.address)", type: .info)
    }

    func debuggerEngine(_: DebuggerEngine, didCatchException exception: ExceptionInfo) {
        logger.log(message: "Caught exception: \(exception.name) - \(exception.reason)", type: .error)

        // Switch to console tab
        DispatchQueue.main.async {
            self.debugTabBarController.selectedIndex = 0
        }
    }

    func debuggerEngine(_: DebuggerEngine, didChangeExecutionState state: ExecutionState) {
        logger.log(message: "Execution state changed to \(state)", type: .info)

        // Update UI based on execution state
        DispatchQueue.main.async {
            self.updateUIForExecutionState(state)
        }
    }

    private func updateUIForExecutionState(_ state: ExecutionState) {
        // Update toolbar buttons based on execution state
        guard let toolbarItems = toolbarItems else { return }

        let pauseButton = toolbarItems[0]
        let resumeButton = toolbarItems[2]
        let stepOverButton = toolbarItems[4]
        let stepIntoButton = toolbarItems[6]
        let stepOutButton = toolbarItems[8]

        switch state {
        case .running:
            pauseButton.isEnabled = true
            resumeButton.isEnabled = false
            stepOverButton.isEnabled = false
            stepIntoButton.isEnabled = false
            stepOutButton.isEnabled = false
        case .paused:
            pauseButton.isEnabled = false
            resumeButton.isEnabled = true
            stepOverButton.isEnabled = true
            stepIntoButton.isEnabled = true
            stepOutButton.isEnabled = true
        case .stepping:
            pauseButton.isEnabled = false
            resumeButton.isEnabled = false
            stepOverButton.isEnabled = false
            stepIntoButton.isEnabled = false
            stepOutButton.isEnabled = false
        }
    }
}
