import UIKit

extension UIApplication {
    func topMostViewController() -> UIViewController? {
        // First try to get the active window scene
        if let windowScene = connectedScenes.first(where: { 
            $0.activationState == .foregroundActive 
        }) as? UIWindowScene {
            // Try to get the key window first
            if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return findTopViewController(from: window.rootViewController)
            }
            
            // Fallback to any window
            if let window = windowScene.windows.first {
                return findTopViewController(from: window.rootViewController)
            }
        }
        
        // Fallback for older iOS versions or if no active scene
        if let window = windows.first(where: { $0.isKeyWindow }) {
            return findTopViewController(from: window.rootViewController)
        } else if let window = windows.first {
            return findTopViewController(from: window.rootViewController)
        }
        
        return nil
    }
    
    private func findTopViewController(from viewController: UIViewController?) -> UIViewController? {
        guard let viewController = viewController else { return nil }
        
        // If presenting a view controller, recursively find the top
        if let presentedVC = viewController.presentedViewController {
            return findTopViewController(from: presentedVC)
        }
        
        // Handle navigation controllers
        if let navController = viewController as? UINavigationController, 
           let topVC = navController.topViewController {
            return findTopViewController(from: topVC)
        }
        
        // Handle tab bar controllers
        if let tabController = viewController as? UITabBarController, 
           let selectedVC = tabController.selectedViewController {
            return findTopViewController(from: selectedVC)
        }
        
        return viewController
    }
}

// Define notification names in a central location
// These notification names need to be unique across the app

// This is now defined in NotificationNames to avoid redeclaration issues
// Do not add changeTab here - use NotificationNames.changeTab instead

// Centralized enum for notification names to avoid ambiguity
public enum NotificationNames {
    // Used for tab switching across the app
    static let changeTab = Notification.Name("com.backdoor.notifications.changeTab")
    // Define other notification names here
}
