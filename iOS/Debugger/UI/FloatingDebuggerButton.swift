import UIKit

// Floating button that provides quick access to the debugger
class FloatingDebuggerButton: UIButton {
    // Default position values
    private let defaultPosition = CGPoint(x: 60, y: 500)
    private let cornerRadius: CGFloat = 25
    private let buttonSize: CGFloat = 50

    // Pan gesture for dragging the button
    private var panGesture: UIPanGestureRecognizer!
    
    // Long press gesture for switching modes
    private var longPressGesture: UILongPressGestureRecognizer!

    // Logger instance
    private let logger = Debug.shared

    // Keys for saving position
    private let positionXKey = "floating_debugger_button_x"
    private let positionYKey = "floating_debugger_button_y"
    
    // Current debug mode
    private var currentMode: DebuggerManager.DebugMode = .standard

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        // Configure button appearance
        frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
        layer.cornerRadius = cornerRadius

        // Shadow for better visibility
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4

        // Button image (bug emoji)
        setTitle("🐞", for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 24)
        backgroundColor = UIColor.systemRed

        // Set up gestures
        setupGestures()

        // Set up appearance
        updateAppearance()

        // Add target action for tap
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        logger.log(message: "Floating debugger button initialized", type: .info)
    }

    private func setupGestures() {
        // Pan gesture for dragging
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
        
        // Long press gesture for switching modes
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.8
        addGestureRecognizer(longPressGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }

        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            // Animate a slight scale up when dragging begins
            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }

        case .changed:
            // Update button position
            center = CGPoint(
                x: center.x + translation.x,
                y: center.y + translation.y
            )

            // Reset translation
            gesture.setTranslation(.zero, in: superview)

        case .ended, .cancelled:
            // Constrain to safe area
            let safeArea = superview.safeAreaInsets
            let minX = buttonSize / 2 + safeArea.left
            let maxX = superview.bounds.width - buttonSize / 2 - safeArea.right
            let minY = buttonSize / 2 + safeArea.top
            let maxY = superview.bounds.height - buttonSize / 2 - safeArea.bottom

            let constrainedX = min(max(center.x, minX), maxX)
            let constrainedY = min(max(center.y, minY), maxY)

            // Animate to constrained position
            UIView.animate(withDuration: 0.3, animations: {
                self.center = CGPoint(x: constrainedX, y: constrainedY)
                self.transform = .identity
            }) { _ in
                // Save position for future sessions
                self.savePosition()
            }

        default:
            break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Show mode selection menu
            showModeSelectionMenu()
        }
    }
    
    private func showModeSelectionMenu() {
        // Create alert controller with mode options
        let alertController = UIAlertController(
            title: "Select Debug Mode",
            message: "Choose which debugging interface to use",
            preferredStyle: .actionSheet
        )
        
        // Add standard mode option
        let standardAction = UIAlertAction(title: "Standard Debugger", style: .default) { _ in
            NotificationCenter.default.post(
                name: .switchDebugMode,
                object: DebuggerManager.DebugMode.standard
            )
        }
        
        // Add FLEX mode option
        let flexAction = UIAlertAction(title: "FLEX Explorer", style: .default) { _ in
            NotificationCenter.default.post(
                name: .switchDebugMode,
                object: DebuggerManager.DebugMode.flex
            )
        }
        
        // Add cancel option
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        // Add actions to alert controller
        alertController.addAction(standardAction)
        alertController.addAction(flexAction)
        alertController.addAction(cancelAction)
        
        // Present the alert controller
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            // For iPad, set the source view and rect
            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = self
                popoverController.sourceRect = bounds
            }
            
            rootViewController.present(alertController, animated: true, completion: nil)
        }
    }

    private func savePosition() {
        UserDefaults.standard.set(center.x, forKey: positionXKey)
        UserDefaults.standard.set(center.y, forKey: positionYKey)
    }

    private func restorePosition() {
        // Get saved position, or use default
        let x = UserDefaults.standard.double(forKey: positionXKey)
        let y = UserDefaults.standard.double(forKey: positionYKey)

        if x > 0 && y > 0 {
            center = CGPoint(x: x, y: y)
        } else {
            center = defaultPosition
        }
    }

    /// Update button appearance based on system theme
    func updateAppearance() {
        // Get current trait collection
        let interfaceStyle = UIScreen.main.traitCollection.userInterfaceStyle

        if interfaceStyle == .dark {
            // Dark mode
            backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        } else {
            // Light mode
            backgroundColor = UIColor.systemRed
        }
    }
    
    /// Update button appearance based on debug mode
    /// - Parameter mode: The current debug mode
    func updateAppearance(forMode mode: DebuggerManager.DebugMode) {
        currentMode = mode
        
        // Update button appearance based on mode
        switch mode {
        case .standard:
            // Standard mode - red button with bug emoji
            setTitle("🐞", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 24)
            
            let interfaceStyle = UIScreen.main.traitCollection.userInterfaceStyle
            if interfaceStyle == .dark {
                backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
            } else {
                backgroundColor = UIColor.systemRed
            }
            
        case .flex:
            // FLEX mode - blue button with hammer emoji
            setTitle("🔧", for: .normal)
            titleLabel?.font = UIFont.systemFont(ofSize: 24)
            
            let interfaceStyle = UIScreen.main.traitCollection.userInterfaceStyle
            if interfaceStyle == .dark {
                backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
            } else {
                backgroundColor = UIColor.systemBlue
            }
        }
    }

    @objc private func buttonTapped() {
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Post notification to launch debugger
        NotificationCenter.default.post(name: .showDebugger, object: nil)

        logger.log(message: "Floating debugger button tapped", type: .info)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        // Restore position when added to view
        if superview != nil {
            restorePosition()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Update appearance when theme changes
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance(forMode: currentMode)
        }
    }
}

// Add notification names for debugger button control
extension Notification.Name {
    static let showDebugger = Notification.Name("showDebugger")
    static let showDebuggerButton = Notification.Name("showDebuggerButton")
    static let hideDebuggerButton = Notification.Name("hideDebuggerButton")
    static let switchDebugMode = Notification.Name("switchDebugMode")
}
