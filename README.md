# EventHub

EventHub is a observer pattern implementation. You can register for events and emit those events.

## Usage
### Hub
#### Simple events:
```
let hub = EventHub<String, Void>()
_ = hub.on("myEvent") {
	print("Event was fired!")
}
hub.emit("myEvent")
```

#### Sending payload:
```
let hub = EventHub<String, Int>()
_ = hub.on("increment") { count in
	print("New count is \(count)")
}
hub.emit("increment", with: 4)
```

#### Only fire once and unregisters:
```
hub.once("increment") { count in
	...
}
```

#### Manual dispose event registration:
```
let dis = hub.on("myEvent") { ... }
...
dis.dispose()
```

#### Using dispose bag:
Sometimes you want a registration to be alive as long as a certain object is still in memory.
```
let bag = DisposeBag()
hub.on("myEvent") { ... }.addTo(bag)
```

#### Fire events on specific queue:
With a specific queue dispatching the event is always async.
```
hub.emit("myEvent", on: DispatchQueue.main, with: 50)
```

#### Remove listener from the hub
```
hub.removeAllListeners(forEvent: "myEvent") //only for the given event
hub.removeAllListeners()										//all listeners get removed
```

#### Payload evaluation is lazy
```
//function is only evaluated if there are listeners registered
hub.emit("myEvent", with: expensiveToCalculateObject())
```

### Application state
You can observe application state
```
ApplicationState.shared.addChangeListener { status in
		switch status {
		case .active: print("App in foreground")
		case .inactive: print("App inactive")
		case .background: print("App in background")
		}
}.addTo(bag)
```

### Connection state
You can observe internet connection state
```
ConnectionState.shared.addChangeListener { status in
		switch status {
		case .unreachable: print("No internet connection")
		case .wwan: print("On 3G or Edge")
		case .wifi: print("On Wifi")
		}
}.addTo(bag)
```

## Example
```
enum LifecycleEvent {
    case didAppear
    case didDisappear
}

final class ViewController: UIViewController {

    let bag = DisposeBag()
    let hub = EventHub<LifecycleEvent, Void>()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hub.emit(.didAppear)
    }

    override func viewDidDisappear(_ animated: Bool) {
        hub.emit(.didDisappear)
        super.viewDidDisappear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hub.on(.didAppear) {
            print("VIEW DID APPEAR")
        }.addTo(bag)
    }
}
```


## Installation

Include EventHub via CocoaPods
