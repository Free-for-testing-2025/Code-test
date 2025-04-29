import Foundation

/// Network monitoring class that intercepts and records network requests
class NetworkMonitor {
    // MARK: - Singleton
    
    /// Shared instance of the network monitor
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Debug.shared
    
    /// Network requests
    private var networkRequests: [NetworkRequest] = []
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Flag indicating whether network monitoring is enabled
    private var isEnabled = false
    
    /// Custom URL protocol class
    private var urlProtocolClass: AnyClass?
    
    // MARK: - Initialization
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        // Register for app lifecycle notifications
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
        
        // Create custom URL protocol class
        createCustomURLProtocolClass()
    }
    
    private func createCustomURLProtocolClass() {
        // Define the custom URL protocol class
        let className = "DebuggerURLProtocol"
        let superClass: AnyClass = URLProtocol.self
        
        // Create the class
        guard let urlProtocolClass = objc_allocateClassPair(superClass, className, 0) else {
            logger.log(message: "Failed to create custom URL protocol class", type: .error)
            return
        }
        
        // Add methods
        
        // canInit method
        let canInitMethod = class_getClassMethod(URLProtocol.self, #selector(URLProtocol.canInit(with:)))!
        let canInitImp: @convention(c) (AnyObject, Selector, URLRequest) -> Bool = { _, _, request in
            // Accept all requests
            return true
        }
        class_addMethod(object_getClass(urlProtocolClass), #selector(URLProtocol.canInit(with:)), unsafeBitCast(canInitImp, to: IMP.self), method_getTypeEncoding(canInitMethod))
        
        // canonicalRequest method
        let canonicalRequestMethod = class_getInstanceMethod(URLProtocol.self, #selector(URLProtocol.canonicalRequest(for:)))!
        let canonicalRequestImp: @convention(c) (AnyObject, Selector, URLRequest) -> URLRequest = { _, _, request in
            // Return the request as is
            return request
        }
        class_addMethod(urlProtocolClass, #selector(URLProtocol.canonicalRequest(for:)), unsafeBitCast(canonicalRequestImp, to: IMP.self), method_getTypeEncoding(canonicalRequestMethod))
        
        // startLoading method
        let startLoadingMethod = class_getInstanceMethod(URLProtocol.self, #selector(URLProtocol.startLoading))!
        let startLoadingImp: @convention(c) (AnyObject, Selector) -> Void = { `self`, _ in
            // Get the request
            guard let urlProtocol = `self` as? URLProtocol else { return }
            let request = urlProtocol.request
            
            // Create a network request
            let networkRequest = NetworkRequest(
                url: request.url!,
                method: request.httpMethod ?? "GET",
                requestHeaders: request.allHTTPHeaderFields ?? [:],
                requestBody: request.httpBody != nil ? String(data: request.httpBody!, encoding: .utf8) : nil,
                responseStatus: 0,
                responseHeaders: [:],
                responseBody: nil,
                timestamp: Date(),
                duration: 0
            )
            
            // Add to network requests
            NetworkMonitor.shared.addNetworkRequest(networkRequest)
            
            // Create a new request to avoid infinite recursion
            var newRequest = request
            URLProtocol.setProperty(true, forKey: "DebuggerURLProtocolHandled", in: &newRequest)
            
            // Create a new session
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config, delegate: urlProtocol, delegateQueue: nil)
            
            // Start the task
            let task = session.dataTask(with: newRequest)
            URLProtocol.setProperty(task, forKey: "DebuggerURLProtocolTask", in: &newRequest)
            task.resume()
        }
        class_addMethod(urlProtocolClass, #selector(URLProtocol.startLoading), unsafeBitCast(startLoadingImp, to: IMP.self), method_getTypeEncoding(startLoadingMethod))
        
        // stopLoading method
        let stopLoadingMethod = class_getInstanceMethod(URLProtocol.self, #selector(URLProtocol.stopLoading))!
        let stopLoadingImp: @convention(c) (AnyObject, Selector) -> Void = { `self`, _ in
            // Cancel the task
            guard let urlProtocol = `self` as? URLProtocol else { return }
            if let task = URLProtocol.property(forKey: "DebuggerURLProtocolTask", in: urlProtocol.request) as? URLSessionTask {
                task.cancel()
            }
        }
        class_addMethod(urlProtocolClass, #selector(URLProtocol.stopLoading), unsafeBitCast(stopLoadingImp, to: IMP.self), method_getTypeEncoding(stopLoadingMethod))
        
        // Register the class
        objc_registerClassPair(urlProtocolClass)
        
        // Store the class
        self.urlProtocolClass = urlProtocolClass
    }
    
    // MARK: - Public Methods
    
    /// Enable network monitoring
    func enable() {
        guard !isEnabled, let urlProtocolClass = urlProtocolClass else { return }
        
        // Register the URL protocol
        URLProtocol.registerClass(urlProtocolClass)
        
        // Set flag
        isEnabled = true
        
        // Log
        logger.log(message: "Network monitoring enabled", type: .info)
    }
    
    /// Disable network monitoring
    func disable() {
        guard isEnabled, let urlProtocolClass = urlProtocolClass else { return }
        
        // Unregister the URL protocol
        URLProtocol.unregisterClass(urlProtocolClass)
        
        // Set flag
        isEnabled = false
        
        // Log
        logger.log(message: "Network monitoring disabled", type: .info)
    }
    
    /// Get all network requests
    /// - Returns: Array of network requests
    func getNetworkRequests() -> [NetworkRequest] {
        lock.lock()
        defer { lock.unlock() }
        
        return networkRequests
    }
    
    /// Add a network request
    /// - Parameter request: The network request
    func addNetworkRequest(_ request: NetworkRequest) {
        lock.lock()
        defer { lock.unlock() }
        
        // Add to network requests
        networkRequests.append(request)
        
        // Post notification
        NotificationCenter.default.post(name: .networkRequestAdded, object: request)
        
        // Log
        logger.log(message: "Added network request: \(request.url.absoluteString)", type: .info)
    }
    
    /// Update a network request
    /// - Parameters:
    ///   - url: URL of the request to update
    ///   - responseStatus: Response status code
    ///   - responseHeaders: Response headers
    ///   - responseBody: Response body
    ///   - duration: Request duration
    func updateNetworkRequest(
        url: URL,
        responseStatus: Int,
        responseHeaders: [String: String],
        responseBody: String?,
        duration: TimeInterval
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        // Find the request
        guard let index = networkRequests.firstIndex(where: { $0.url == url }) else {
            logger.log(message: "Network request not found: \(url.absoluteString)", type: .error)
            return
        }
        
        // Update the request
        let request = networkRequests[index]
        let updatedRequest = NetworkRequest(
            url: request.url,
            method: request.method,
            requestHeaders: request.requestHeaders,
            requestBody: request.requestBody,
            responseStatus: responseStatus,
            responseHeaders: responseHeaders,
            responseBody: responseBody,
            timestamp: request.timestamp,
            duration: duration
        )
        networkRequests[index] = updatedRequest
        
        // Post notification
        NotificationCenter.default.post(name: .networkRequestUpdated, object: updatedRequest)
        
        // Log
        logger.log(message: "Updated network request: \(url.absoluteString)", type: .info)
    }
    
    /// Clear all network requests
    func clearNetworkRequests() {
        lock.lock()
        defer { lock.unlock() }
        
        // Clear network requests
        networkRequests.removeAll()
        
        // Post notification
        NotificationCenter.default.post(name: .networkRequestsCleared, object: nil)
        
        // Log
        logger.log(message: "Cleared network requests", type: .info)
    }
    
    // MARK: - App Lifecycle
    
    @objc private func handleAppDidBecomeActive() {
        // Re-enable network monitoring if it was enabled
        if isEnabled {
            enable()
        }
    }
    
    @objc private func handleAppWillResignActive() {
        // No need to do anything when app resigns active
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkRequestAdded = Notification.Name("networkRequestAdded")
    static let networkRequestUpdated = Notification.Name("networkRequestUpdated")
    static let networkRequestsCleared = Notification.Name("networkRequestsCleared")
}

// MARK: - URLSessionDelegate

extension NetworkMonitor: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Get the URL protocol
        guard let urlProtocol = session.configuration.protocolClasses?.first as? URLProtocol else {
            completionHandler(.allow)
            return
        }
        
        // Forward the response to the URL protocol client
        urlProtocol.client?.urlProtocol(urlProtocol, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        // Allow the response
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Get the URL protocol
        guard let urlProtocol = session.configuration.protocolClasses?.first as? URLProtocol else {
            return
        }
        
        // Forward the data to the URL protocol client
        urlProtocol.client?.urlProtocol(urlProtocol, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Get the URL protocol
        guard let urlProtocol = session.configuration.protocolClasses?.first as? URLProtocol else {
            return
        }
        
        // Forward the completion to the URL protocol client
        if let error = error {
            urlProtocol.client?.urlProtocol(urlProtocol, didFailWithError: error)
        } else {
            urlProtocol.client?.urlProtocolDidFinishLoading(urlProtocol)
        }
    }
}