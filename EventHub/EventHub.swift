/*
 Copyright (c) 2017 LOTUM GmbH
 Licensed under Apache License v2.0
 
 See https://github.com/LOTUM/EventHub/blob/master/LICENSE for license information
 */



import Foundation



/** 
 This class is a pub/sub implementation. You can register for events.
 And you can emit events on specific queues. Threadsafe.
 */
public final class EventHub<EventT: Hashable, PayloadT> {

    
    //MARK: Public API
    
    public init() {}
    
    public func on(_ event: EventT, action: @escaping (PayloadT)->Void) -> Disposable {
        return on(event, lifetime: .always, action: action)
    }
    
    @discardableResult
    public func once(_ event: EventT, action: @escaping (PayloadT)->Void) -> Disposable {
        return on(event, lifetime: .once, action: action)
    }
    
    public func on(oneOf events: Set<EventT>, action: @escaping (PayloadT)->Void) -> Disposable {
        return on(oneOf: events, lifetime: .always, action: action)
    }

    @discardableResult
    public func once(oneOf events: Set<EventT>, action: @escaping (PayloadT)->Void) -> Disposable {
        return on(oneOf: events, lifetime: .once, action: action)
    }
    
    public func removeAllListeners(forEvent: EventT? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if let event = forEvent {
            queuedActions[event] = nil
            oneOfActions = oneOfActions.compactMap { listener in
                var newListener = listener
                newListener.events.remove(event)
                if newListener.events.isEmpty {
                    return nil
                }
                return newListener
            }
        } else {
            queuedActions = [:]
            oneOfActions = []
        }
    }
    
    public func numberOfListeners(forEvent: EventT? = nil) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let event = forEvent {
            let queuedActionsCount = queuedActions[event]?.count ?? 0
            var oneOfCount = 0
            for listener in oneOfActions {
                if listener.events.contains(event) {
                    oneOfCount += 1
                }
            }
            return queuedActionsCount + oneOfCount
        } else {
            let queuedActionsCount = queuedActions.values.flatMap { $0 }.count
            return queuedActionsCount + oneOfActions.count
        }
    }
    
    /**
     The event listeners registered for the given event get fired. If you don't specify a queue the listeners get
     fired on the current queue synchronously. Otherwise they are called asynchronously on the given queue.
     
     The payload block only evaluate if there are listeners.
    */
    public func emit(_ event: EventT,
                     on queue: DispatchQueue? = nil,
                     with value: @autoclosure ()->PayloadT) {
        lock.lock()
        var actionsToExecute = queuedActions[event] ?? []
        let oneOfActionsToExecute = oneOfActions
            .filter { $0.events.contains(event) }
            .map { $0.action }
        actionsToExecute += oneOfActionsToExecute
        
        queuedActions[event] = actionsToExecute.compactMap { $0.reduce() }
        oneOfActions = oneOfActions.filter { $0.action.runTime == .always || !$0.events.contains(event) }
        
        lock.unlock()
        //run blocks after filtering the actions, so you can emit from within block()
        //without infinite recursion when emitting the same event although action lifetime is once
        guard actionsToExecute.count > 0 else { return }
        let valueToSend = value()
        actionsToExecute.forEach { $0.run(onQueue: queue, with: valueToSend) }
    }

    
    //MARK: Private
    
    private var queuedActions: [EventT:[Action<PayloadT>]] = [:]
    private var oneOfActions: [(action: Action<PayloadT>, events: Set<EventT>)] = []
    
    private let lock = NSLock()
    
    private func on(_ event: EventT,
                    lifetime: ActionLifetime,
                    action: @escaping (PayloadT)->Void) -> Disposable
    {
        lock.lock()
        let act = Action(runTime: lifetime, action: action)
        queuedActions[event] = (queuedActions[event] ?? []) + [act]
        lock.unlock()
        return EventDisposable { [weak self, weak act] in
            guard let act = act else { return }
            self?.removeListener(with: act, forEvent: event)
        }
    }
    
    private func on(oneOf events: Set<EventT>,
                    lifetime: ActionLifetime,
                    action: @escaping (PayloadT)->Void) -> Disposable
    {
        if events.count == 0 {
            return EventDisposable {}
        }
        if events.count == 1 {
            return on(events.first!, lifetime: lifetime, action: action)
        }
        
        lock.lock()
        let act = Action(runTime: lifetime, action: action)
        oneOfActions.append((action: act, events: events))
        lock.unlock()
        return EventDisposable { [weak self, weak act] in
            guard let act = act else { return }
            self?.removeOneOfListener(with: act)
        }
    }
    
    private func removeListener(with toRemove: Action<PayloadT>, forEvent event: EventT) {
        lock.lock()
        defer { lock.unlock() }
        if let allActionsForEvent = queuedActions[event] {
            let filteredActions = allActionsForEvent.filter { $0 !== toRemove }
            queuedActions[event] = filteredActions
        }
    }
    
    private func removeOneOfListener(with toRemove: Action<PayloadT>) {
        lock.lock()
        defer { lock.unlock() }
        oneOfActions = oneOfActions.filter { $0.action !== toRemove }
    }
}



extension EventHub where PayloadT == Void {
    
    public func emit(_ event: EventT,
                     on queue: DispatchQueue? = nil) {
        emit(event, on: queue, with: {}())
    }
    
}



//MARK:- Private


/// How often will the action fire for event
private enum ActionLifetime {
    case once, always
}



private final class EventDisposable: Disposable {
    
    private let disposeBlock: ()->Void
    
    init(_ block: @escaping ()->Void) {
        disposeBlock = block
    }
    
    func dispose() {
        disposeBlock()
    }
}



private final class Action<PayloadT> {
    
    let runTime: ActionLifetime
    let block: (PayloadT)->Void
    
    init(runTime rt: ActionLifetime, action act: @escaping (PayloadT)->Void) {
        runTime = rt
        block = act
    }
    
    func run(onQueue queue: DispatchQueue? = nil, with val: PayloadT) {
        let b = block
        
        if let q = queue {
            q.async(execute: { b(val) })
        } else {
            b(val)
        }
    }
    
    func reduce() -> Action? {
        switch runTime {
        case .always:
            return self
        case .once:
            return nil
        }
    }
}

