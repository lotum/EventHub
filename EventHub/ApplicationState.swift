/*
 Copyright (c) 2017 LOTUM GmbH
 Licensed under Apache License v2.0
 
 See https://github.com/LOTUM/EventHub/blob/master/LICENSE for license information
 */



import UIKit



public enum ApplicationStatus: String, CustomStringConvertible {
    
    case active, inactive, background
    
    public var description: String { return rawValue }
    
    fileprivate init(applicationState state: UIApplicationState) {
        switch state {
        case .active: self = .active
        case .inactive: self = .inactive
        case .background: self = .background
        }
    }
}



final public class ApplicationState {

    
    //MARK: Public
    
    public static let shared = ApplicationState()
    
    public var callbackQueue = DispatchQueue.main
    
    public func addChangeListener(_ listener: @escaping (ApplicationStatus)->Void) -> Disposable {
        defer { fire() }
        return hub.on("change", action: { (newStatus, oldStatus) in listener(newStatus) })
    }

    public func addChangeListener(_ listener: @escaping (ApplicationStatus, ApplicationStatus)->Void) -> Disposable {
        defer { fire() }
        return hub.on("change", action: listener)
    }

    
    //MARK: Private
    
    private let hub = EventHub<String, (ApplicationStatus, ApplicationStatus)>()
    private var applicationState: UIApplicationState {
        didSet {
            if applicationState != oldValue {
                fire(newState: applicationState, oldState: oldValue)
            }
        }
    }
    
    private init() {
        applicationState = UIApplication.shared.applicationState
        registerLifecycleEvents()
    }
    
    
    private func registerLifecycleEvents() {
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(lifecycleDidChange),
                         name: .UIApplicationWillEnterForeground,
                         object: nil)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(lifecycleDidChange),
                         name: .UIApplicationDidBecomeActive,
                         object: nil)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(lifecycleDidChange),
                         name: .UIApplicationWillResignActive,
                         object: nil)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(lifecycleDidChange),
                         name: .UIApplicationDidEnterBackground,
                         object: nil)
    }
    
    @objc private func lifecycleDidChange(notification: Notification) {
        updateState()
    }
    
    private func updateState() {
        applicationState = UIApplication.shared.applicationState
        DispatchQueue.main.async {
            self.applicationState = UIApplication.shared.applicationState
        }
    }
    
    private func fireApplicationEvent(_ event: (ApplicationStatus, ApplicationStatus)) {
        hub.emit("change", on: callbackQueue, with: event)
    }
    
    private func fire() {
        fire(newState: applicationState, oldState: applicationState)
    }
    
    private func fire(newState: UIApplicationState, oldState: UIApplicationState) {
        let payload = (ApplicationStatus(applicationState: newState), ApplicationStatus(applicationState: oldState))
        fireApplicationEvent(payload)
    }
}

