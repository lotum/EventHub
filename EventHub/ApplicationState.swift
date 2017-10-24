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

    public typealias ListenerBlock = (ApplicationStatus, ApplicationStatus)->Void
    
    //MARK: Public
    
    public static let shared = ApplicationState()
    
    public var callbackQueue = DispatchQueue.main
    
    public func addChangeListener(_ listener: @escaping (ApplicationStatus)->Void) -> Disposable {
        let completeListener: ListenerBlock = { (newStatus, oldStatus) in listener(newStatus) }
        defer { fire(listener: completeListener) }
        return hub.on("change", action: completeListener)
    }

    public func addChangeListener(_ listener: @escaping ListenerBlock) -> Disposable {
        defer { fire(listener: listener) }
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
    
    private func fire(listener: ListenerBlock? = nil) {
        fire(newState: applicationState, oldState: applicationState, toListener: listener)
    }
    
    private func fire(newState: UIApplicationState,
                      oldState: UIApplicationState,
                      toListener: ListenerBlock? = nil)
    {
        let payload = (ApplicationStatus(applicationState: newState), ApplicationStatus(applicationState: oldState))
        if let listener = toListener {
            listener(payload.0, payload.1)
        } else {
            fireApplicationEvent(payload)
        }
    }
}

