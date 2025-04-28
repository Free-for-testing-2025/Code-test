import UIKit
import ObjectiveC

/// Runtime inspection class for examining objects at runtime
class RuntimeInspector {
    // MARK: - Singleton
    
    /// Shared instance of the runtime inspector
    static let shared = RuntimeInspector()
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Debug.shared
    
    /// Runtime class cache
    private var runtimeClassCache: [String: AnyClass] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Initialize the runtime inspector
        logger.log(message: "Runtime inspector initialized", type: .info)
    }
    
    // MARK: - Class Inspection
    
    /// Get all loaded classes
    /// - Returns: Array of class names
    func getLoadedClasses() -> [String] {
        var count: UInt32 = 0
        guard let classes = objc_copyClassList(&count) else {
            return []
        }
        
        var classNames: [String] = []
        for i in 0..<Int(count) {
            if let className = NSStringFromClass(classes[i]) as String? {
                classNames.append(className)
                
                // Cache the class for later use
                runtimeClassCache[className] = classes[i]
            }
        }
        
        // Free the memory
        free(classes)
        
        return classNames.sorted()
    }
    
    /// Get all methods for a class
    /// - Parameter className: Name of the class
    /// - Returns: Array of method names
    func getMethods(forClass className: String) -> [String] {
        // Get class from cache or lookup
        let cls: AnyClass
        if let cachedClass = runtimeClassCache[className] {
            cls = cachedClass
        } else if let foundClass = NSClassFromString(className) {
            cls = foundClass
            runtimeClassCache[className] = foundClass
        } else {
            return []
        }
        
        var methodCount: UInt32 = 0
        guard let methods = class_copyMethodList(cls, &methodCount) else {
            return []
        }
        
        var methodNames: [String] = []
        for i in 0..<Int(methodCount) {
            if let selector = method_getName(methods[i]) {
                let methodName = NSStringFromSelector(selector)
                methodNames.append(methodName)
            }
        }
        
        // Free the memory
        free(methods)
        
        return methodNames.sorted()
    }
    
    /// Get all properties for a class
    /// - Parameter className: Name of the class
    /// - Returns: Array of property names
    func getProperties(forClass className: String) -> [String] {
        // Get class from cache or lookup
        let cls: AnyClass
        if let cachedClass = runtimeClassCache[className] {
            cls = cachedClass
        } else if let foundClass = NSClassFromString(className) {
            cls = foundClass
            runtimeClassCache[className] = foundClass
        } else {
            return []
        }
        
        var propertyCount: UInt32 = 0
        guard let properties = class_copyPropertyList(cls, &propertyCount) else {
            return []
        }
        
        var propertyNames: [String] = []
        for i in 0..<Int(propertyCount) {
            if let propertyName = String(cString: property_getName(properties[i])) as String? {
                propertyNames.append(propertyName)
            }
        }
        
        // Free the memory
        free(properties)
        
        return propertyNames.sorted()
    }
    
    /// Get all ivars for a class
    /// - Parameter className: Name of the class
    /// - Returns: Array of ivar names
    func getIvars(forClass className: String) -> [String] {
        // Get class from cache or lookup
        let cls: AnyClass
        if let cachedClass = runtimeClassCache[className] {
            cls = cachedClass
        } else if let foundClass = NSClassFromString(className) {
            cls = foundClass
            runtimeClassCache[className] = foundClass
        } else {
            return []
        }
        
        var ivarCount: UInt32 = 0
        guard let ivars = class_copyIvarList(cls, &ivarCount) else {
            return []
        }
        
        var ivarNames: [String] = []
        for i in 0..<Int(ivarCount) {
            if let ivarName = String(cString: ivar_getName(ivars[i])!) as String? {
                ivarNames.append(ivarName)
            }
        }
        
        // Free the memory
        free(ivars)
        
        return ivarNames.sorted()
    }
    
    /// Get all protocols for a class
    /// - Parameter className: Name of the class
    /// - Returns: Array of protocol names
    func getProtocols(forClass className: String) -> [String] {
        // Get class from cache or lookup
        let cls: AnyClass
        if let cachedClass = runtimeClassCache[className] {
            cls = cachedClass
        } else if let foundClass = NSClassFromString(className) {
            cls = foundClass
            runtimeClassCache[className] = foundClass
        } else {
            return []
        }
        
        var protocolCount: UInt32 = 0
        guard let protocols = class_copyProtocolList(cls, &protocolCount) else {
            return []
        }
        
        var protocolNames: [String] = []
        for i in 0..<Int(protocolCount) {
            if let protocolName = String(cString: protocol_getName(protocols[i])) as String? {
                protocolNames.append(protocolName)
            }
        }
        
        // Free the memory
        free(protocols)
        
        return protocolNames.sorted()
    }
    
    // MARK: - Object Inspection
    
    /// Get the class hierarchy for an object
    /// - Parameter object: The object
    /// - Returns: Array of class names in the hierarchy
    func getClassHierarchy(for object: AnyObject) -> [String] {
        var hierarchy: [String] = []
        var cls: AnyClass? = object_getClass(object)
        
        while let currentClass = cls {
            hierarchy.append(NSStringFromClass(currentClass))
            cls = class_getSuperclass(currentClass)
        }
        
        return hierarchy
    }
    
    /// Get all properties and their values for an object
    /// - Parameter object: The object
    /// - Returns: Dictionary of property names and values
    func getPropertyValues(for object: AnyObject) -> [String: String] {
        var propertyValues: [String: String] = [:]
        
        // Get the class
        guard let cls = object_getClass(object) else {
            return propertyValues
        }
        
        // Get all properties
        var propertyCount: UInt32 = 0
        guard let properties = class_copyPropertyList(cls, &propertyCount) else {
            return propertyValues
        }
        
        // Get property values
        for i in 0..<Int(propertyCount) {
            if let propertyName = String(cString: property_getName(properties[i])) as String? {
                // Use key-value coding to get the property value
                do {
                    if let value = object.value(forKey: propertyName) {
                        propertyValues[propertyName] = String(describing: value)
                    } else {
                        propertyValues[propertyName] = "nil"
                    }
                } catch {
                    propertyValues[propertyName] = "Error: \(error.localizedDescription)"
                }
            }
        }
        
        // Free the memory
        free(properties)
        
        return propertyValues
    }
    
    /// Get the value of a property on an object
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - object: The object
    /// - Returns: The property value as a string
    func getPropertyValue(_ propertyName: String, onObject object: AnyObject) -> String {
        // Use key-value coding to get the property value
        if let value = object.value(forKey: propertyName) {
            return String(describing: value)
        } else {
            return "nil"
        }
    }
    
    /// Set the value of a property on an object
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - value: The value to set
    ///   - object: The object
    /// - Returns: True if successful, false otherwise
    func setPropertyValue(_ propertyName: String, value: Any, onObject object: AnyObject) -> Bool {
        do {
            // Use key-value coding to set the property value
            try object.setValue(value, forKey: propertyName)
            return true
        } catch {
            logger.log(message: "Error setting property value: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    /// Get all ivar values for an object
    /// - Parameter object: The object
    /// - Returns: Dictionary of ivar names and values
    func getIvarValues(for object: AnyObject) -> [String: String] {
        var ivarValues: [String: String] = [:]
        
        // Get the class
        guard let cls = object_getClass(object) else {
            return ivarValues
        }
        
        // Get all ivars
        var ivarCount: UInt32 = 0
        guard let ivars = class_copyIvarList(cls, &ivarCount) else {
            return ivarValues
        }
        
        // Get ivar values
        for i in 0..<Int(ivarCount) {
            if let ivar = ivars[i],
               let ivarName = String(cString: ivar_getName(ivar)!) as String? {
                // Get the ivar value
                let ivarValue = object_getIvar(object, ivar)
                ivarValues[ivarName] = String(describing: ivarValue as Any)
            }
        }
        
        // Free the memory
        free(ivars)
        
        return ivarValues
    }
    
    // MARK: - Method Invocation
    
    /// Invoke a method on an object
    /// - Parameters:
    ///   - methodName: Name of the method
    ///   - object: The object
    ///   - arguments: Method arguments
    /// - Returns: The method result as a string
    func invokeMethod(_ methodName: String, onObject object: AnyObject, arguments: [Any] = []) -> String {
        // Create selector
        let selector = NSSelectorFromString(methodName)
        
        // Check if the object responds to the selector
        guard object.responds(to: selector) else {
            return "Error: Object does not respond to selector \(methodName)"
        }
        
        // Invoke the method
        do {
            let result = object.perform(selector, with: arguments.first)?.takeRetainedValue()
            return String(describing: result as Any)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - View Hierarchy
    
    /// Get the view hierarchy
    /// - Returns: The root view controller
    func getViewHierarchy() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController
    }
    
    /// Get all windows
    /// - Returns: Array of windows
    func getAllWindows() -> [UIWindow] {
        return UIApplication.shared.windows
    }
    
    /// Get all view controllers
    /// - Returns: Array of view controllers
    func getAllViewControllers() -> [UIViewController] {
        var viewControllers: [UIViewController] = []
        
        // Get all windows
        let windows = getAllWindows()
        
        // Get root view controllers
        for window in windows {
            if let rootViewController = window.rootViewController {
                viewControllers.append(rootViewController)
                
                // Add presented view controllers
                viewControllers.append(contentsOf: getAllPresentedViewControllers(from: rootViewController))
            }
        }
        
        return viewControllers
    }
    
    /// Get all presented view controllers
    /// - Parameter viewController: The parent view controller
    /// - Returns: Array of presented view controllers
    private func getAllPresentedViewControllers(from viewController: UIViewController) -> [UIViewController] {
        var viewControllers: [UIViewController] = []
        
        // Add child view controllers
        for childViewController in viewController.children {
            viewControllers.append(childViewController)
            viewControllers.append(contentsOf: getAllPresentedViewControllers(from: childViewController))
        }
        
        // Add presented view controller
        if let presentedViewController = viewController.presentedViewController {
            viewControllers.append(presentedViewController)
            viewControllers.append(contentsOf: getAllPresentedViewControllers(from: presentedViewController))
        }
        
        return viewControllers
    }
    
    /// Get the view hierarchy for a view
    /// - Parameter view: The view
    /// - Returns: Dictionary representing the view hierarchy
    func getViewHierarchy(for view: UIView) -> [String: Any] {
        var hierarchy: [String: Any] = [
            "class": NSStringFromClass(type(of: view)),
            "frame": NSStringFromCGRect(view.frame),
            "tag": view.tag,
            "isHidden": view.isHidden,
            "alpha": view.alpha,
            "backgroundColor": view.backgroundColor?.description ?? "nil"
        ]
        
        // Add subviews
        var subviews: [[String: Any]] = []
        for subview in view.subviews {
            subviews.append(getViewHierarchy(for: subview))
        }
        hierarchy["subviews"] = subviews
        
        return hierarchy
    }
}