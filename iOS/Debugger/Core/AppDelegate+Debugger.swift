import UIKit
import ObjectiveC


    /// Extension to AppDelegate for initializing the debugger
    extension AppDelegate {
        /// Initialize the debugger
        func initializeDebugger() {
            // Initialize the debugger manager
            DebuggerManager.shared.initialize()
            
            // Enable network monitoring
            NetworkMonitor.shared.enable()
            
            // Set up method swizzling for view controller lifecycle
            swizzleViewControllerLifecycle()

            // Log initialization
            Debug.shared.log(message: "Debugger initialized", type: .info)
        }
        
        /// Swizzle view controller lifecycle methods for debugging
        private func swizzleViewControllerLifecycle() {
            // Swizzle viewDidLoad
            swizzleMethod(
                originalClass: UIViewController.self,
                originalSelector: #selector(UIViewController.viewDidLoad),
                swizzledClass: UIViewController.self,
                swizzledSelector: #selector(UIViewController.debugger_viewDidLoad)
            )
            
            // Swizzle viewWillAppear
            swizzleMethod(
                originalClass: UIViewController.self,
                originalSelector: #selector(UIViewController.viewWillAppear(_:)),
                swizzledClass: UIViewController.self,
                swizzledSelector: #selector(UIViewController.debugger_viewWillAppear(_:))
            )
            
            // Swizzle viewDidAppear
            swizzleMethod(
                originalClass: UIViewController.self,
                originalSelector: #selector(UIViewController.viewDidAppear(_:)),
                swizzledClass: UIViewController.self,
                swizzledSelector: #selector(UIViewController.debugger_viewDidAppear(_:))
            )
            
            // Swizzle viewWillDisappear
            swizzleMethod(
                originalClass: UIViewController.self,
                originalSelector: #selector(UIViewController.viewWillDisappear(_:)),
                swizzledClass: UIViewController.self,
                swizzledSelector: #selector(UIViewController.debugger_viewWillDisappear(_:))
            )
            
            // Swizzle viewDidDisappear
            swizzleMethod(
                originalClass: UIViewController.self,
                originalSelector: #selector(UIViewController.viewDidDisappear(_:)),
                swizzledClass: UIViewController.self,
                swizzledSelector: #selector(UIViewController.debugger_viewDidDisappear(_:))
            )
        }
        
        /// Swizzle a method
        private func swizzleMethod(
            originalClass: AnyClass,
            originalSelector: Selector,
            swizzledClass: AnyClass,
            swizzledSelector: Selector
        ) {
            guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
                  let swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector) else {
                return
            }
            
            let didAddMethod = class_addMethod(
                originalClass,
                swizzledSelector,
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
            )
            
            if didAddMethod {
                class_replaceMethod(
                    originalClass,
                    swizzledSelector,
                    method_getImplementation(originalMethod),
                    method_getTypeEncoding(originalMethod)
                )
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }