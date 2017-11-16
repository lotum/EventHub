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
        let e1 = expectation(description: "expectation1")
        let e2 = expectation(description: "expectation2")
        let e3 = expectation(description: "expectation3")
        
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
    
    func test_remove_one_of_listener() {
        let e1 = expectation(description: "one")
        let e2 = expectation(description: "two")
        
        let hub = EventHub<String, Void>()
        
        hub.once("event1") {
            e1.fulfill()
        }
        
        hub.once("event2") {
            e2.fulfill()
        }
        
        let disposer = hub.on(oneOf: ["event1", "event2"]) {
            XCTFail()
        }
        
        XCTAssertEqual(hub.numberOfListeners(), 3)
        disposer.dispose()
        XCTAssertEqual(hub.numberOfListeners(), 2)
        hub.emit("event1")
        hub.emit("event2")
        
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
    
    func test_number_of_listeners() {
        let hub = EventHub<String, Void>()
        
        XCTAssertEqual(hub.numberOfListeners(), 0)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 0)
        
        hub.once("test1") {}
        XCTAssertEqual(hub.numberOfListeners(), 1)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 1)
        
        hub.on("test2") {}
        XCTAssertEqual(hub.numberOfListeners(), 2)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 1)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test2"), 1)
        
        hub.on("test1") {}
        XCTAssertEqual(hub.numberOfListeners(), 3)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 2)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test2"), 1)
        
        hub.once(oneOf: ["test1", "test2"]) {}
        XCTAssertEqual(hub.numberOfListeners(), 4)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 3)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test2"), 2)
        
        hub.on(oneOf: ["test1", "test2"]) {}
        XCTAssertEqual(hub.numberOfListeners(), 5)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 4)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test2"), 3)
        
        hub.removeAllListeners(forEvent: "test1")
        XCTAssertEqual(hub.numberOfListeners(), 3)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 0)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test2"), 3)
        
        hub.removeAllListeners()
        XCTAssertEqual(hub.numberOfListeners(), 0)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test1"), 0)
        XCTAssertEqual(hub.numberOfListeners(forEvent: "test2"), 0)
    }
    
    func test_once_one_of() {
        let e1 = expectation(description: "one")
        let e2 = expectation(description: "two")
        
        let hub = EventHub<String, Void>()
        hub.once(oneOf: ["test1", "test2"]) {
            e1.fulfill()
        }

        hub.emit("test2")
        hub.emit("test2")
        hub.emit("test3")
        
        hub.once(oneOf: ["test1", "test2"]) {
            e2.fulfill()
        }
        
        hub.emit("test1")

        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func test_on_one_of() {
        let es = [expectation(description: "one"), expectation(description: "two")]
        
        let hub = EventHub<String, Void>()
        var index = 0
        hub.on(oneOf: ["test1", "test2"]) {
            es[index].fulfill()
            index += 1
        }
        
        hub.emit("test1")
        hub.emit("test2")
        hub.emit("test3")

        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func test_one_of_with_zero_events() {
        let hub = EventHub<String, Void>()
        
        let disposer = hub.once(oneOf: []) {
            XCTFail()
        }
        
        hub.emit("event")
        XCTAssertEqual(hub.numberOfListeners(), 0)
        disposer.dispose()
    }
    
    func test_one_of_with_single_event() {
        let e = expectation(description: "expectation")
        
        let hub = EventHub<String, Void>()
        
        hub.once(oneOf: ["event"]) {
            e.fulfill()
        }
        
        hub.emit("event")
        
        waitForExpectations(timeout: 0.1, handler: nil)
    }
}
