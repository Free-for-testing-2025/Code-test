import UIKit

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

        // Delay showing the floating button to ensure the view hierarchy is ready
        // Use a longer delay to ensure the app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            
            // Only show the button if the app is active and not in background
            if UIApplication.shared.applicationState == .active {
                self.showFloatingButton()
                self.logger.log(message: "Showing floating button after delay", type: .info)
            } else {
                self.logger.log(message: "App not active, skipping floating button", type: .info)
            }
        }
    }

    /// Show the debugger UI
    public func showDebugger() {
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
        guard isDebuggerVisible, let debuggerVC = debuggerViewController else { return }

        DispatchQueue.main.async {
            debuggerVC.dismiss(animated: true) {
                self.isDebuggerVisible = false
                self.logger.log(message: "Debugger dismissed", type: .info)
            }
        }
    }

    /// Show the floating button
    public func showFloatingButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Try to find the top view controller
            if let topVC = UIApplication.shared.topMostViewController() {
                // Remove from current superview
                self.floatingButton.removeFromSuperview()

                // Add to the top view controller's view
                topVC.view.addSubview(self.floatingButton)
                self.logger.log(message: "Floating debugger button added to top VC", type: .info)
            } 
            // Fallback to key window if no top view controller
            else if let keyWindow = UIApplication.shared.keyWindow {
                // Remove from current superview
                self.floatingButton.removeFromSuperview()

                // Add to the key window
                keyWindow.addSubview(self.floatingButton)
                self.logger.log(message: "Floating debugger button added to key window", type: .info)
            }
            // Fallback to any window
            else if let window = UIApplication.shared.windows.first {
                // Remove from current superview
                self.floatingButton.removeFromSuperview()

                // Add to the first window
                window.addSubview(self.floatingButton)
                self.logger.log(message: "Floating debugger button added to first window", type: .info)
            }
            else {
                self.logger.log(message: "No view controller or window to add floating button", type: .error)
            }
        }
    }

    /// Hide the floating button
    public func hideFloatingButton() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingButton.removeFromSuperview()
            self?.logger.log(message: "Floating debugger button removed", type: .info)
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
        if !isDebuggerVisible {
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
