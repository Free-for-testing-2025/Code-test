import UIKit
import ObjectiveC

/// Manager class for the runtime debugger
/// Handles the floating button and debugger UI
public final class DebuggerManager {
    // MARK: - Singleton

    /// Shared instance of the debugger manager
    public static let shared = DebuggerManager()

    // MARK: - Properties

    /// Logger for debugger operations
    private let logger = Debug.shared

    /// The floating debugger button
    private let floatingButton = FloatingDebuggerButton()

    /// The debugger engine
    private let debuggerEngine = DebuggerEngine.shared
    
    /// FLEX integration
    private let flexIntegration = FLEXIntegration.shared

    /// Current debugger view controller
    private weak var debuggerViewController: DebuggerViewController?

    /// Thread-safe state tracking with a dedicated queue
    private let stateQueue = DispatchQueue(label: "com.debugger.manager.state", qos: .userInteractive)
    private var _isDebuggerVisible = false
    private var isDebuggerVisible: Bool {
        get { stateQueue.sync { _isDebuggerVisible } }
        set { stateQueue.sync { _isDebuggerVisible = newValue } }
    }

    /// Thread-safe setup state
    private var _isSetUp = false
    private var isSetUp: Bool {
        get { stateQueue.sync { _isSetUp } }
        set { stateQueue.sync { _isSetUp = newValue } }
    }
    
    /// Debug mode - determines which UI to show
    public enum DebugMode {
        case standard  // Our custom debugger UI
        case flex      // FLEX explorer UI
    }
    
    /// Current debug mode
    private var _debugMode: DebugMode = .standard
    public var debugMode: DebugMode {
        get { stateQueue.sync { _debugMode } }
        set { 
            stateQueue.sync { _debugMode = newValue }
            // Update UI based on mode change
            if newValue == .flex {
                logger.log(message: "Switching to FLEX debug mode", type: .info)
            } else {
                logger.log(message: "Switching to standard debug mode", type: .info)
            }
        }
    }

    /// Weak references to parent views
    private weak var parentViewController: UIViewController?

    // MARK: - Initialization

    private init() {
        setupObservers()
        logger.log(message: "DebuggerManager initialized", type: .info)
    }

    // MARK: - Public Methods

    /// Initialize the debugger
    /// This should be called from the AppDelegate
    public func initialize() {
        logger.log(message: "Initializing debugger", type: .info)

        // Show the floating button
        DispatchQueue.main.async { [weak self] in
            self?.showFloatingButton()
        }
    }

    /// Show the debugger UI
    public func showDebugger() {
        // If in FLEX mode, show FLEX explorer
        if debugMode == .flex {
            flexIntegration.showExplorer()
            return
        }
        
        // Otherwise show our standard debugger
        guard !isDebuggerVisible else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Find the top view controller to present the debugger
            guard let topVC = UIApplication.shared.topMostViewController() else {
                self.logger.log(message: "No view controller to present debugger", type: .error)
                return
            }

            // Create the debugger view controller
            let debuggerVC = DebuggerViewController()
            debuggerVC.delegate = self

            // Wrap in navigation controller
            let navController = UINavigationController(rootViewController: debuggerVC)

            // Configure presentation style
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad-specific presentation
                navController.modalPresentationStyle = .formSheet
                navController.preferredContentSize = CGSize(width: 700, height: 800)
            } else {
                // iPhone presentation
                if #available(iOS 15.0, *) {
                    if let sheet = navController.sheetPresentationController {
                        // Use sheet presentation for iOS 15+
                        sheet.detents = [.large()]
                        sheet.prefersGrabberVisible = true
                        sheet.preferredCornerRadius = 24
                    }
                } else {
                    // Fallback for older iOS versions
                    navController.modalPresentationStyle = .fullScreen
                }
            }

            // Present the debugger
            topVC.present(navController, animated: true) {
                self.isDebuggerVisible = true
                self.debuggerViewController = debuggerVC
                self.logger.log(message: "Debugger presented", type: .info)
            }
        }
    }

    /// Hide the debugger UI
    public func hideDebugger() {
        // If in FLEX mode, hide FLEX explorer
        if debugMode == .flex {
            flexIntegration.hideExplorer()
            return
        }
        
        // Otherwise hide our standard debugger
        guard isDebuggerVisible, let debuggerVC = debuggerViewController else { return }

        DispatchQueue.main.async {
            debuggerVC.dismiss(animated: true) {
                self.isDebuggerVisible = false
                self.logger.log(message: "Debugger dismissed", type: .info)
            }
        }
    }
    
    /// Toggle the debugger UI
    public func toggleDebugger() {
        if debugMode == .flex {
            flexIntegration.toggleExplorer()
        } else {
            if isDebuggerVisible {
                hideDebugger()
            } else {
                showDebugger()
            }
        }
    }

    /// Show the floating button
    public func showFloatingButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Find the top view controller to add the button
            guard let topVC = UIApplication.shared.topMostViewController() else {
                self.logger.log(message: "No view controller to add floating button", type: .error)
                return
            }

            // Remove from current superview
            self.floatingButton.removeFromSuperview()

            // Add to the top view controller's view
            topVC.view.addSubview(self.floatingButton)
            
            // Configure the button based on the current debug mode
            self.floatingButton.updateAppearance(forMode: self.debugMode)

            self.logger.log(message: "Floating debugger button added", type: .info)
        }
    }

    /// Hide the floating button
    public func hideFloatingButton() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingButton.removeFromSuperview()
            self?.logger.log(message: "Floating debugger button removed", type: .info)
        }
    }
    
    /// Switch between debug modes
    public func switchDebugMode(_ mode: DebugMode) {
        // If we're already in this mode, do nothing
        if debugMode == mode {
            return
        }
        
        // Hide current debugger UI
        if debugMode == .flex {
            flexIntegration.hideExplorer()
        } else if isDebuggerVisible {
            hideDebugger()
        }
        
        // Set new mode
        debugMode = mode
        
        // Update floating button appearance
        floatingButton.updateAppearance(forMode: mode)
    }
    
    /// Present an object explorer for the given object
    /// - Parameter object: The object to explore
    public func presentObjectExplorer(_ object: Any) {
        if debugMode == .flex {
            flexIntegration.presentObjectExplorer(object)
        } else {
            // Use our own object explorer or show variables view
            showDebugger()
            // Select the variables tab and focus on this object
            if let debuggerVC = debuggerViewController {
                debuggerVC.showVariablesTab(withObject: object)
            }
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Listen for button taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowDebugger),
            name: .showDebugger,
            object: nil
        )
        
        // Listen for mode switch
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitchDebugMode),
            name: .switchDebugMode,
            object: nil
        )

        // Listen for show/hide button notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowFloatingButton),
            name: .showDebuggerButton,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideFloatingButton),
            name: .hideDebuggerButton,
            object: nil
        )

        // Listen for orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleShowDebugger() {
        showDebugger()
    }
    
    @objc private func handleSwitchDebugMode(_ notification: Notification) {
        if let mode = notification.object as? DebugMode {
            switchDebugMode(mode)
        }
    }

    @objc private func handleShowFloatingButton() {
        showFloatingButton()
    }

    @objc private func handleHideFloatingButton() {
        hideFloatingButton()
    }

    @objc private func handleOrientationChange() {
        // Ensure the floating button is still visible after orientation change
        if floatingButton.superview != nil {
            DispatchQueue.main.async { [weak self] in
                self?.showFloatingButton()
            }
        }
    }

    @objc private func handleAppDidBecomeActive() {
        // Show the floating button when app becomes active
        if !isDebuggerVisible && debugMode == .standard {
            DispatchQueue.main.async { [weak self] in
                self?.showFloatingButton()
            }
        }
    }

    @objc private func handleAppWillResignActive() {
        // No need to do anything when app resigns active
    }
}

// MARK: - DebuggerViewControllerDelegate

extension DebuggerManager: DebuggerViewControllerDelegate {
    func debuggerViewControllerDidRequestDismissal(_: DebuggerViewController) {
        hideDebugger()
    }
}

// MARK: - UIApplication Extension

extension UIApplication {
    private func findTopViewController(_ controller: UIViewController) -> UIViewController {
        if let presentedController = controller.presentedViewController {
            return findTopViewController(presentedController)
        }

        if let navigationController = controller as? UINavigationController {
            if let topController = navigationController.topViewController {
                return findTopViewController(topController)
            }
            return navigationController
        }

        if let tabController = controller as? UITabBarController {
            if let selectedController = tabController.selectedViewController {
                return findTopViewController(selectedController)
            }
            return tabController
        }

        return controller
    }

    /// Get the key window
    var keyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first(where: { $0 is UIWindowScene })
                .flatMap { $0 as? UIWindowScene }?.windows
                .first(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        }
    }
}
