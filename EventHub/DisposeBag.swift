/*
 Copyright (c) 2017 LOTUM GmbH
 Licensed under Apache License v2.0
 
 See https://github.com/LOTUM/EventHub/blob/master/LICENSE for license information
 */



import Foundation



public final class DisposeBag: Disposable {
    
    public init() {}
    
    public func dispose() {
        disposes.forEach { $0.dispose() }
        disposes = []
    }
    
    deinit {
        dispose()
    }
    
    
    fileprivate func add(_ disposable: Disposable) {
        disposes.append(disposable)
    }
    
    private var disposes: [Disposable] = []
}



public extension Disposable {

    public func addTo(_ bag: DisposeBag) {
        bag.add(self)
    }
}
