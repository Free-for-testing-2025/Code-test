import Foundation
import UIKit

/// Execution state of the debugger
public enum DebuggerExecutionState {
    case running
    case paused
    case stepping
}

/// Information about an exception
public struct ExceptionInfo {
    let name: String
    let reason: String
    let userInfo: [AnyHashable: Any]
    let callStack: [String]
}

/// Protocol for debugger engine delegate
public protocol DebuggerEngineDelegate: AnyObject {
    func debuggerEngine(_ engine: DebuggerEngine, didCatchException exception: ExceptionInfo)
    func debuggerEngine(_ engine: DebuggerEngine, didExecuteCommand command: String, withOutput output: String)
    func debuggerEngineDidChangeState(_ engine: DebuggerEngine)
}

/// Core engine for the debugger
public final class DebuggerEngine {
    // MARK: - Singleton

    /// Shared instance of the debugger engine
    public static let shared = DebuggerEngine()

    // MARK: - Properties

    /// Delegate for debugger events
    public weak var delegate: DebuggerEngineDelegate?

    /// Current execution state
    private(set) var executionState: DebuggerExecutionState = .running {
        didSet {
            if oldValue != executionState {
                delegate?.debuggerEngineDidChangeState(self)
                notificationCenter.post(name: .debuggerStateChanged, object: executionState)
            }
        }
    }

    /// Command history
    private(set) var commandHistory: [String] = []

    /// Maximum number of commands to keep in history
    private let maxCommandHistorySize = 100

    /// Logger for debugger operations
    private let logger = Debug.shared

    /// Notification center for posting notifications
    private let notificationCenter = NotificationCenter.default

    // MARK: - Initialization

    private init() {
        setupExceptionHandling()
        logger.log(message: "DebuggerEngine initialized", type: .info)
    }

    // MARK: - Public Methods

    /// Execute a command in the debugger
    /// - Parameter command: The command to execute
    /// - Returns: The output of the command
    @discardableResult
    public func executeCommand(_ command: String) -> String {
        logger.log(message: "Executing command: \(command)", type: .info)

        // Add to history
        addToCommandHistory(command)

        // Parse and execute command
        let output = parseAndExecuteCommand(command)

        // Notify delegate
        delegate?.debuggerEngine(self, didExecuteCommand: command, withOutput: output)

        return output
    }

    /// Pause execution
    public func pause() {
        executionState = .paused
        logger.log(message: "Execution paused", type: .info)
    }

    /// Resume execution
    public func resume() {
        executionState = .running
        logger.log(message: "Execution resumed", type: .info)
    }

    /// Step to next instruction
    public func step() {
        executionState = .stepping
        logger.log(message: "Stepping to next instruction", type: .info)

        // Simulate stepping and then pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.executionState = .paused
        }
    }

    /// Get the current memory usage
    /// - Returns: Memory usage in MB
    public func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }

        return 0.0
    }

    /// Get the CPU usage
    /// - Returns: CPU usage as a percentage
    public func getCPUUsage() -> Double {
        // This is a simplified implementation
        // In a real app, you would use host_processor_info
        return 0.0
    }

    /// Get the device information
    /// - Returns: Dictionary of device information
    public func getDeviceInfo() -> [String: String] {
        let device = UIDevice.current
        let screenBounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale

        return [
            "name": device.name,
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "screenResolution": "\(Int(screenBounds.width * scale))x\(Int(screenBounds.height * scale))",
            "screenScale": "\(scale)x",
        ]
    }

    // MARK: - Private Methods

    private func setupExceptionHandling() {
        // Set up exception handling with a closure that calls our static method
        NSSetUncaughtExceptionHandler({ exception in
            DebuggerEngine.handleUncaughtException(exception)
        })
    }
    
    // Static exception handler that doesn't capture self
    private static func handleUncaughtException(_ exception: NSException) {
        shared.handleException(exception)
    }

    private func handleException(_ exception: NSException) {
        // Use try-catch to prevent crashes in the exception handler itself
        do {
            let name = exception.name.rawValue
            let reason = exception.reason ?? "Unknown reason"
            let userInfo = exception.userInfo ?? [:]
            let callStack = exception.callStackSymbols

            // Log to console immediately for debugging
            print("UNCAUGHT EXCEPTION: \(name) - \(reason)")
            callStack.forEach { print($0) }
            
            // Create exception info object
            let exceptionInfo = ExceptionInfo(
                name: name,
                reason: reason,
                userInfo: userInfo,
                callStack: callStack
            )

            // Log through logger
            logger.log(message: "Exception caught: \(name) - \(reason)", type: .error)

            // Pause execution
            executionState = .paused

            // Record crash in SafeModeLauncher
            // This ensures we'll enter safe mode after repeated crashes
            DispatchQueue.main.async {
                // Don't reset the launch counter since we had an exception
                SafeModeLauncher.shared.recordLaunchAttempt()
            }

            // Notify delegate and post notification on main thread to avoid threading issues
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.debuggerEngine(self, didCatchException: exceptionInfo)
                self.notificationCenter.post(name: .debuggerExceptionCaught, object: exceptionInfo)
            }
        } catch {
            // Last resort if our exception handler itself crashes
            print("ERROR IN EXCEPTION HANDLER: \(error)")
        }
    }

    private func addToCommandHistory(_ command: String) {
        // Don't add empty commands or duplicates of the last command
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (commandHistory.first == command)
        {
            return
        }

        // Add to the beginning
        commandHistory.insert(command, at: 0)

        // Trim if needed
        if commandHistory.count > maxCommandHistorySize {
            commandHistory = Array(commandHistory.prefix(maxCommandHistorySize))
        }
    }

    private func parseAndExecuteCommand(_ command: String) -> String {
        // Simple command parser
        let components = command.components(separatedBy: .whitespaces)
        guard let firstComponent = components.first?.lowercased() else {
            return "Empty command"
        }

        switch firstComponent {
        case "help":
            return """
            Available commands:
            - help: Show this help
            - memory: Show memory usage
            - cpu: Show CPU usage
            - device: Show device information
            - pause: Pause execution
            - resume: Resume execution
            - step: Step to next instruction
            """
        case "memory":
            let memoryUsage = getMemoryUsage()
            return "Memory usage: \(String(format: "%.2f", memoryUsage)) MB"
        case "cpu":
            let cpuUsage = getCPUUsage()
            return "CPU usage: \(String(format: "%.2f", cpuUsage))%"
        case "device":
            let deviceInfo = getDeviceInfo()
            return deviceInfo.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        case "pause":
            pause()
            return "Execution paused"
        case "resume":
            resume()
            return "Execution resumed"
        case "step":
            step()
            return "Stepping to next instruction"
        default:
            return "Unknown command: \(firstComponent)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let debuggerStateChanged = Notification.Name("debuggerStateChanged")
    static let debuggerExceptionCaught = Notification.Name("debuggerExceptionCaught")
}