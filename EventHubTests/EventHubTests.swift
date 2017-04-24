import XCTest
@testable import LotumEventHub


class EventHubTest: XCTestCase {
    
    func testEmitEvent() {
        let e = expectation(description: "hub")
        
        let hub = EventHub<String, Void>()
        hub.once("test") {
            e.fulfill()
        }
        hub.emit("test")
        
        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func testOnlyFiringMatchingEvents() {
        let hub = EventHub<String, Void>()
        hub.once("test") {
            XCTFail()
        }
        hub.emit("not_registered")
    }
    
    func testMutlipleEmit() {
        let e1 = expectation(description: "test1")
        let e2 = expectation(description: "test2")
        let e3 = expectation(description: "test3")
        
        let hub = EventHub<String, Void>()
        hub.once("test1") {
            e1.fulfill()
        }
        hub.once("test1") {
            e2.fulfill()
        }
        hub.once("test2") {
            e3.fulfill()
        }
        
        hub.emit("test1")
        hub.emit("test2")
        
        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func testOnlyOnce() {
        let e = expectation(description: "hub")
        
        let hub = EventHub<String, Void>()
        hub.once("test") {
            e.fulfill()
        }
        hub.emit("test")
        hub.emit("test")
        
        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func testEmitFromWithinOn() {
        let e = expectation(description: "hub")
        
        let hub = EventHub<String, Void>()
        hub.once("test") {
            hub.emit("test")
        }
        hub.emit("test")
        
        e.fulfill()
        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func test_remove_listener() {
        let e = expectation(description: "remove")
        
        let hub = EventHub<String, Void>()
        
        hub.once("remove") {
            e.fulfill()
        }
        
        let disposer = hub.on("remove") {
            XCTFail()
        }
        disposer.dispose()
        hub.emit("remove")
        
        waitForExpectations(timeout: 1.5, handler: nil)
    }
    
    func test_schedule_on_queue() {
        let e = expectation(description: "on_queue")
        
        let q = DispatchQueue(label: "my_queue")
        let hub = EventHub<String, Void>()
        
        hub.once("fire") {
            if #available(iOS 10.0, *) {
                dispatchPrecondition(condition: .onQueue(q))
            } else {
                // Fallback on earlier versions
            }
            e.fulfill()
        }
        hub.emit("fire", on: q)
        
        waitForExpectations(timeout: 1.5, handler: nil)
    }
    
    
}
