/*
 Copyright (c) 2017 LOTUM GmbH
 Licensed under Apache License v2.0
 
 See https://github.com/LOTUM/EventHub/blob/master/LICENSE for license information
 */



import Foundation
import SystemConfiguration



public enum ConnectionStatus: String, CustomStringConvertible {
    
    case unreachable, wifi, wwan
    
    public var reachable: Bool {
        return self != .unreachable
    }
    
    public var description: String { return rawValue }
}



final public class ConnectionState {

    
    //MARK: Public
    
    /** 
        Set this if you want to check for connection to this host: "www.google.com"
        If you want to use this property set it before you call ConnectionState.shared
     */
    public static var hostname: String?
    
    /// Get shared connection state
    public static let shared = ConnectionState()

    /// Queue on which change listener is fired
    public var callbackQueue = DispatchQueue.main
    
    public func addChangeListener(_ listener: @escaping (ConnectionStatus)->Void) -> Disposable {
        defer { fire() }
        return hub.on("change", action: listener)
    }
    
    
    //MARK: Private
    
    private let hub = EventHub<String, ConnectionStatus>()
    private var status: ConnectionStatus? {
        didSet {
            if status != oldValue {
                fire()
            }
        }
    }
    
    private init() {
        do {
            if let host = ConnectionState.hostname {
                Network.reachability = try Reachability(hostname: host)
            } else {
                Network.reachability = try Reachability()
            }
            
            do {
                try Network.reachability?.start()
                status = Network.reachability?.status
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(connectionChange),
                                                       name: .flagsChanged,
                                                       object: nil)
            } catch let error as Network.Error {
                print("CONNECTION STATE ERROR: \(error)")
            } catch {
                print("CONNECTION STATE ERROR: \(error)")
            }
        } catch {
            print("CONNECTION STATE ERROR: \(error)")
        }
    }
    
    @objc private func connectionChange() {
        status = Network.reachability?.status
    }
    
    private func fire() {
        guard let status = status else { return }
        hub.emit("change", on: callbackQueue, with: status)
    }
}



/**
 Copyright by http://stackoverflow.com/users/416397/a-r-younce
 From: http://stackoverflow.com/questions/27310465/detecting-network-connectivity-changes-using-reachability-nsnotification-and-ne
 Date: 07.04.2017
 */
private class Reachability {
    var hostname: String?
    var isRunning = false
    var isReachableOnWWAN: Bool
    var reachability: SCNetworkReachability?
    var reachabilityFlags = SCNetworkReachabilityFlags()
    let reachabilitySerialQueue = DispatchQueue(label: "ReachabilityQueue")
    init?(hostname: String) throws {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, hostname) else {
            throw Network.Error.failedToCreateWith(hostname)
        }
        self.reachability = reachability
        self.hostname = hostname
        isReachableOnWWAN = true
    }
    init?() throws {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }}) else {
                throw Network.Error.failedToInitializeWith(zeroAddress)
        }
        self.reachability = reachability
        isReachableOnWWAN = true
    }
    var status: ConnectionStatus {
        return  !isConnectedToNetwork ? .unreachable :
            isReachableViaWiFi    ? .wifi :
            isRunningOnDevice     ? .wwan : .unreachable
    }
    var isRunningOnDevice: Bool = {
        #if targetEnvironment(simulator)
            return false
        #else
            return true
        #endif
    }()
    deinit { stop() }
}

extension Reachability {
    func start() throws {
        guard let reachability = reachability, !isRunning else { return }
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged<Reachability>.passUnretained(self).toOpaque()
        guard SCNetworkReachabilitySetCallback(reachability, callout, &context) else { stop()
            throw Network.Error.failedToSetCallout
        }
        guard SCNetworkReachabilitySetDispatchQueue(reachability, reachabilitySerialQueue) else { stop()
            throw Network.Error.failedToSetDispatchQueue
        }
        reachabilitySerialQueue.async { self.flagsChanged() }
        isRunning = true
    }
    func stop() {
        defer { isRunning = false }
        guard let reachability = reachability else { return }
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        self.reachability = nil
    }
    var isConnectedToNetwork: Bool {
        return isReachable &&
            !isConnectionRequiredAndTransientConnection &&
            !(isRunningOnDevice && isWWAN && !isReachableOnWWAN)
    }
    var isReachableViaWiFi: Bool {
        return isReachable && isRunningOnDevice && !isWWAN
    }
    
    /// Flags that indicate the reachability of a network node name or address, including whether a connection is required, and whether some user intervention might be required when establishing a connection.
    var flags: SCNetworkReachabilityFlags? {
        guard let reachability = reachability else { return nil }
        var flags = SCNetworkReachabilityFlags()
        return withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(reachability, UnsafeMutablePointer($0))
            } ? flags : nil
    }
    
    /// compares the current flags with the previous flags and if changed posts a flagsChanged notification
    func flagsChanged() {
        guard let flags = flags, flags != reachabilityFlags else { return }
        reachabilityFlags = flags
        NotificationCenter.default.post(name: .flagsChanged, object: self)
    }
    
    /// The specified node name or address can be reached via a transient connection, such as PPP.
    var transientConnection: Bool { return flags?.contains(.transientConnection) == true }
    
    /// The specified node name or address can be reached using the current network configuration.
    var isReachable: Bool { return flags?.contains(.reachable) == true }
    
    /// The specified node name or address can be reached using the current network configuration, but a connection must first be established. If this flag is set, the kSCNetworkReachabilityFlagsConnectionOnTraffic flag, kSCNetworkReachabilityFlagsConnectionOnDemand flag, or kSCNetworkReachabilityFlagsIsWWAN flag is also typically set to indicate the type of connection required. If the user must manually make the connection, the kSCNetworkReachabilityFlagsInterventionRequired flag is also set.
    var connectionRequired: Bool { return flags?.contains(.connectionRequired) == true }
    
    /// The specified node name or address can be reached using the current network configuration, but a connection must first be established. Any traffic directed to the specified name or address will initiate the connection.
    var connectionOnTraffic: Bool { return flags?.contains(.connectionOnTraffic) == true }
    
    /// The specified node name or address can be reached using the current network configuration, but a connection must first be established.
    var interventionRequired: Bool { return flags?.contains(.interventionRequired) == true }
    
    /// The specified node name or address can be reached using the current network configuration, but a connection must first be established. The connection will be established "On Demand" by the CFSocketStream programming interface (see CFStream Socket Additions for information on this). Other functions will not establish the connection.
    var connectionOnDemand: Bool { return flags?.contains(.connectionOnDemand) == true }
    
    /// The specified node name or address is one that is associated with a network interface on the current system.
    var isLocalAddress: Bool { return flags?.contains(.isLocalAddress) == true }
    
    /// Network traffic to the specified node name or address will not go through a gateway, but is routed directly to one of the interfaces in the system.
    var isDirect: Bool { return flags?.contains(.isDirect) == true }
    
    /// The specified node name or address can be reached via a cellular connection, such as EDGE or GPRS.
    var isWWAN: Bool { return flags?.contains(.isWWAN) == true }
    
    /// The specified node name or address can be reached using the current network configuration, but a connection must first be established. If this flag is set
    /// The specified node name or address can be reached via a transient connection, such as PPP.
    var isConnectionRequiredAndTransientConnection: Bool {
        return (flags?.intersection([.connectionRequired, .transientConnection]) == [.connectionRequired, .transientConnection]) == true
    }
}

func callout(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }
    DispatchQueue.main.async {
        Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue().flagsChanged()
    }
}

extension Notification.Name {
    static let flagsChanged = Notification.Name("FlagsChanged")
}

private struct Network {
    fileprivate static var reachability: Reachability?
    enum Error: Swift.Error {
        case failedToSetCallout
        case failedToSetDispatchQueue
        case failedToCreateWith(String)
        case failedToInitializeWith(sockaddr_in)
    }
}
