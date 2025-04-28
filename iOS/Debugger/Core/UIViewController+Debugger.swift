import UIKit

/// Extension for UIViewController to add debugging functionality
extension UIViewController {
    // MARK: - Swizzled Methods
    
    /// Swizzled viewDidLoad method
    @objc func debugger_viewDidLoad() {
        // Call original implementation
        debugger_viewDidLoad()
        
        // Log view controller lifecycle
        Debug.shared.log(message: "[\(type(of: self))] viewDidLoad", type: .info)
    }
    
    /// Swizzled viewWillAppear method
    @objc func debugger_viewWillAppear(_ animated: Bool) {
        // Call original implementation
        debugger_viewWillAppear(animated)
        
        // Log view controller lifecycle
        Debug.shared.log(message: "[\(type(of: self))] viewWillAppear(animated: \(animated))", type: .info)
    }
    
    /// Swizzled viewDidAppear method
    @objc func debugger_viewDidAppear(_ animated: Bool) {
        // Call original implementation
        debugger_viewDidAppear(animated)
        
        // Log view controller lifecycle
        Debug.shared.log(message: "[\(type(of: self))] viewDidAppear(animated: \(animated))", type: .info)
    }
    
    /// Swizzled viewWillDisappear method
    @objc func debugger_viewWillDisappear(_ animated: Bool) {
        // Call original implementation
        debugger_viewWillDisappear(animated)
        
        // Log view controller lifecycle
        Debug.shared.log(message: "[\(type(of: self))] viewWillDisappear(animated: \(animated))", type: .info)
    }
    
    /// Swizzled viewDidDisappear method
    @objc func debugger_viewDidDisappear(_ animated: Bool) {
        // Call original implementation
        debugger_viewDidDisappear(animated)
        
        // Log view controller lifecycle
        Debug.shared.log(message: "[\(type(of: self))] viewDidDisappear(animated: \(animated))", type: .info)
    }
    
    // MARK: - Helper Methods
    
    /// Get the view hierarchy as a string
    /// - Returns: String representation of the view hierarchy
    func viewHierarchyDescription() -> String {
        return viewHierarchyDescription(for: view, level: 0)
    }
    
    /// Get the view hierarchy as a string for a specific view
    /// - Parameters:
    ///   - view: The view
    ///   - level: Indentation level
    /// - Returns: String representation of the view hierarchy
    private func viewHierarchyDescription(for view: UIView, level: Int) -> String {
        // Create indentation
        let indent = String(repeating: "  ", count: level)
        
        // Create description
        var description = "\(indent)[\(type(of: view))] frame=\(view.frame), alpha=\(view.alpha), hidden=\(view.isHidden)\n"
        
        // Add subviews
        for subview in view.subviews {
            description += viewHierarchyDescription(for: subview, level: level + 1)
        }
        
        return description
    }
    
    /// Get the view controller hierarchy as a string
    /// - Returns: String representation of the view controller hierarchy
    func viewControllerHierarchyDescription() -> String {
        return viewControllerHierarchyDescription(for: self, level: 0)
    }
    
    /// Get the view controller hierarchy as a string for a specific view controller
    /// - Parameters:
    ///   - viewController: The view controller
    ///   - level: Indentation level
    /// - Returns: String representation of the view controller hierarchy
    private func viewControllerHierarchyDescription(for viewController: UIViewController, level: Int) -> String {
        // Create indentation
        let indent = String(repeating: "  ", count: level)
        
        // Create description
        var description = "\(indent)[\(type(of: viewController))]\n"
        
        // Add child view controllers
        for childViewController in viewController.children {
            description += viewControllerHierarchyDescription(for: childViewController, level: level + 1)
        }
        
        // Add presented view controller
        if let presentedViewController = viewController.presentedViewController {
            description += "\(indent)  Presented:\n"
            description += viewControllerHierarchyDescription(for: presentedViewController, level: level + 2)
        }
        
        return description
    }
}