import UIKit

/// Bridge class to integrate FLEX functionality into our debugger
/// This class provides a wrapper around FLEX's functionality to make it compatible with our debugger
public final class FLEXIntegration {
    // MARK: - Singleton
    
    /// Shared instance of the FLEX integration
    public static let shared = FLEXIntegration()
    
    // MARK: - Properties
    
    /// Logger for debugger operations
    private let logger = Debug.shared
    
    /// Flag indicating whether FLEX is available
    private var isFLEXAvailable: Bool = false
    
    /// Dynamic reference to FLEXManager to avoid compile-time dependency
    private var flexManager: AnyObject?
    
    // MARK: - Initialization
    
    private init() {
        setupFLEX()
    }
    
    // MARK: - Setup
    
    /// Set up FLEX integration
    private func setupFLEX() {
        // Check if FLEX is available at runtime
        if let flexManagerClass = NSClassFromString("FLEXManager") {
            // Get the shared manager using runtime invocation
            if let sharedManagerMethod = class_getClassMethod(flexManagerClass, NSSelectorFromString("sharedManager")),
               let sharedManager = objc_msgSend(flexManagerClass, sharedManagerMethod) as? AnyObject {
                flexManager = sharedManager
                isFLEXAvailable = true
                logger.log(message: "FLEX integration initialized successfully", type: .info)
            }
        } else {
            logger.log(message: "FLEX not available - some advanced debugging features will be disabled", type: .warning)
        }
    }
    
    // MARK: - Public Methods
    
    /// Show the FLEX explorer
    public func showExplorer() {
        guard isFLEXAvailable, let flexManager = flexManager else {
            logger.log(message: "FLEX not available", type: .warning)
            return
        }
        
        // Call showExplorer method using runtime invocation
        if flexManager.responds(to: NSSelectorFromString("showExplorer")) {
            _ = flexManager.perform(NSSelectorFromString("showExplorer"))
            logger.log(message: "FLEX explorer shown", type: .info)
        }
    }
    
    /// Hide the FLEX explorer
    public func hideExplorer() {
        guard isFLEXAvailable, let flexManager = flexManager else {
            return
        }
        
        // Call hideExplorer method using runtime invocation
        if flexManager.responds(to: NSSelectorFromString("hideExplorer")) {
            _ = flexManager.perform(NSSelectorFromString("hideExplorer"))
            logger.log(message: "FLEX explorer hidden", type: .info)
        }
    }
    
    /// Toggle the FLEX explorer
    public func toggleExplorer() {
        guard isFLEXAvailable, let flexManager = flexManager else {
            logger.log(message: "FLEX not available", type: .warning)
            return
        }
        
        // Call toggleExplorer method using runtime invocation
        if flexManager.responds(to: NSSelectorFromString("toggleExplorer")) {
            _ = flexManager.perform(NSSelectorFromString("toggleExplorer"))
            logger.log(message: "FLEX explorer toggled", type: .info)
        }
    }
    
    /// Present a specific FLEX tool
    /// - Parameters:
    ///   - viewController: The view controller to present
    ///   - completion: Completion handler called when the tool is presented
    public func presentTool(_ viewController: UIViewController, completion: (() -> Void)? = nil) {
        guard isFLEXAvailable, let flexManager = flexManager else {
            logger.log(message: "FLEX not available", type: .warning)
            completion?()
            return
        }
        
        // Wrap in navigation controller
        let navController = UINavigationController(rootViewController: viewController)
        
        // Create a block that returns the navigation controller
        let viewControllerProvider: @convention(block) () -> UINavigationController = {
            return navController
        }
        
        // Create an Objective-C block for the completion handler
        let completionBlock: @convention(block) () -> Void = {
            completion?()
        }
        
        // Call presentTool:completion: method using runtime invocation
        if flexManager.responds(to: NSSelectorFromString("presentTool:completion:")) {
            _ = flexManager.perform(
                NSSelectorFromString("presentTool:completion:"),
                with: viewControllerProvider,
                with: completionBlock
            )
            logger.log(message: "FLEX tool presented", type: .info)
        }
    }
    
    /// Check if FLEX is currently visible
    /// - Returns: True if FLEX is visible, false otherwise
    public func isExplorerVisible() -> Bool {
        guard isFLEXAvailable, let flexManager = flexManager else {
            return false
        }
        
        // Check isHidden property and invert it
        if flexManager.responds(to: NSSelectorFromString("isHidden")),
           let isHidden = flexManager.perform(NSSelectorFromString("isHidden"))?.takeRetainedValue() as? Bool {
            return !isHidden
        }
        
        return false
    }
    
    /// Get the FLEX toolbar
    /// - Returns: The FLEX toolbar as AnyObject, or nil if not available
    public func getToolbar() -> AnyObject? {
        guard isFLEXAvailable, let flexManager = flexManager else {
            return nil
        }
        
        // Get toolbar property
        if flexManager.responds(to: NSSelectorFromString("toolbar")),
           let toolbar = flexManager.perform(NSSelectorFromString("toolbar"))?.takeRetainedValue() {
            return toolbar
        }
        
        return nil
    }
    
    /// Get the FLEX manager
    /// - Returns: The FLEX manager as AnyObject, or nil if not available
    public func getFlexManager() -> AnyObject? {
        guard isFLEXAvailable else {
            return nil
        }
        
        return flexManager
    }
    
    /// Present an object explorer for the given object
    /// - Parameters:
    ///   - object: The object to explore
    ///   - completion: Completion handler called when the explorer is presented
    public func presentObjectExplorer(_ object: Any, completion: (() -> Void)? = nil) {
        guard isFLEXAvailable, let flexManager = flexManager else {
            logger.log(message: "FLEX not available", type: .warning)
            completion?()
            return
        }
        
        // Create an Objective-C block for the completion handler
        let completionBlock: @convention(block) (UINavigationController) -> Void = { _ in
            completion?()
        }
        
        // Call presentObjectExplorer:completion: method using runtime invocation
        if flexManager.responds(to: NSSelectorFromString("presentObjectExplorer:completion:")) {
            _ = flexManager.perform(
                NSSelectorFromString("presentObjectExplorer:completion:"),
                with: object,
                with: completionBlock
            )
            logger.log(message: "FLEX object explorer presented", type: .info)
        }
    }
}