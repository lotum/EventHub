/*
 Copyright (c) 2017 LOTUM GmbH
 Licensed under Apache License v2.0
 
 See https://github.com/LOTUM/EventHub/blob/master/LICENSE for license information
 */



import Foundation



/// Call dispose to release strong captured ressources
public protocol Disposable {
    func dispose()
}
