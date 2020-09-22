import XCTest
@testable import SwiftFSM

final class SwiftFSMTests: XCTestCase {
	func testSameState() {
		let machine = FSM(initial: "start",
			events: [
				FSM.EventDesc(source: "start",
					event: "run",
					destination: "start"
				)
			]
		)

		XCTAssertEqual(machine.current(), "start")
		XCTAssertNotNil(machine.fire(event: "run"))
		XCTAssertEqual(machine.current(), "start")
	}

	func testSetState() {
		let machine = FSM(initial: "walking", events: [
			FSM.EventDesc(source: "start", event: "walk", destination: "walking")
			])

		XCTAssertEqual(machine.current(), "walking")
		XCTAssertNil(machine.set(current: "start"))
		XCTAssertEqual(machine.current(), "start")
		XCTAssertNil(machine.fire(event: "walk"))
		XCTAssertEqual(machine.current(), "walking")
	}

	func testInappropriateEvent() {
		let machine = FSM(initial: "closed", events: [
			FSM.EventDesc(source: "closed", event: "open", destination: "open"),
			FSM.EventDesc(source: "open", event: "close", destination: "closed")
			])

		XCTAssertEqual(machine.current(), "closed")
		let err = machine.fire(event: "close")
		XCTAssertNotNil(err)
		XCTAssert(err is FSM.FSMError)
		guard case let FSM.FSMError.invalidEvent(event, state) = (err as! FSM.FSMError) else {
			XCTAssert(false)
			return
		}
		XCTAssert((event, state) == ("close", "closed"))
	}

	func testUnknownEvent() {
		let machine = FSM(initial: "closed", events: [
			FSM.EventDesc(source: "closed", event: "open", destination: "open"),
			FSM.EventDesc(source: "open", event: "close", destination: "closed")
			])
		let err = machine.fire(event: "lock")
		XCTAssertNotNil(err)
		XCTAssert(err is FSM.FSMError)
		guard case let FSM.FSMError.unknownEvent(event) = (err as! FSM.FSMError) else {
			XCTAssert(false)
			return
		}
		XCTAssertEqual(event, "lock")
	}

	func testDoubleTransition() {
		var machine: FSM? = nil

		let waitGroup = Atomic<Int>(2)

		machine = FSM(initial: "start",
			events: [
				FSM.EventDesc(source: "start", event: "run", destination: "end")
			],
			callbacks: [
				"before_run": { event in
					waitGroup.sync { $0 - 1 }
					// Imagine a concurrent event coming in of the same type while
					// the data access mutex is unlocked because the current transition
					// is running is event callbacks, getting around the "active"
					// transition checks.
					if event.args.isEmpty {
						// Must be concurrent so the test may pass when we add a mutex that synchronizes
						// calls to machine.fire(event:args...). It will then fail as an inappropriate transition as we
						// have changed state.
						DispatchQueue.global().async {
							XCTAssertNotNil(machine!.fire(event: "run", "second run"))
							waitGroup.sync { $0 - 1 }
						}
					} else {
						XCTFail("Able to reissue an event mid-transition")
					}
				}
			])

		XCTAssertNil(machine!.fire(event: "run"))

		while waitGroup.value != 0 { }
	}

	func testAsync() {
		let machine = FSM(initial: "start", events: [
			FSM.EventDesc(source: "start", event: "run", destination: "end")
			], callbacks: [
				"leave_start": { event in
					event.async()
				}
			])

		XCTAssertEqual(machine.current(), "start")
		guard let err = machine.fire(event: "run") else {
			XCTFail("should generate error")
			return
		}
		XCTAssert(err is FSM.FSMError)
		let fsmError = err as! FSM.FSMError
		guard case let FSM.FSMError.async(error) = fsmError else {
			XCTFail("should be async FSMError")
			return
		}
		XCTAssertEqual(machine.current(), "start")
		XCTAssertNil(error)
		XCTAssertNil(machine.completeTransition())
		XCTAssertEqual(machine.current(), "end")
	}

	func testLeaveStateCallback() {
		sync { // callback for specific state
			var callbackGetCalled: Bool = false

			let machine = FSM(initial: "start", events: [
				FSM.EventDesc(source: "start", event: "run", destination: "end")
				], callbacks: [
					"leave_start": { event in
						XCTAssertEqual(event.event, "run")
						XCTAssertEqual(event.src, "start")
						XCTAssertEqual(event.dst, "end")

						callbackGetCalled = true
					}
				])


			XCTAssertFalse(callbackGetCalled)
			XCTAssertEqual(machine.current(), "start")
			XCTAssertNil(machine.fire(event: "run"))
			XCTAssertTrue(callbackGetCalled)
			XCTAssertEqual(machine.current(), "end")
		}
		sync { // callback for all states
			var counter = 0

			let machine = FSM(initial: "off", events: [
				FSM.EventDesc(source: "on", event: "toggle", destination: "off"),
				FSM.EventDesc(source: "off", event: "toggle", destination: "on")
				], callbacks: [
					"leave_state": { event in
						XCTAssertEqual(event.event, "toggle")
						if counter % 2 == 0 { // off
							XCTAssertEqual(event.src, "off")
							XCTAssertEqual(event.dst, "on")
						} else {
							XCTAssertEqual(event.src, "on")
							XCTAssertEqual(event.dst, "off")
						}
						counter += 1
					}
				])

			for i in 0...100 {
				XCTAssertEqual(i, counter)
				XCTAssertNil(machine.fire(event: "toggle"))
			}
		}
		sync { // callback for both
			var onCounter = 0
			var allCounter = 0


			let machine = FSM(initial: "off", events: [
				FSM.EventDesc(source: "on", event: "toggle", destination: "off"),
				FSM.EventDesc(source: "off", event: "toggle", destination: "on")
				], callbacks: [
					"leave_state": { event in
						XCTAssertEqual(event.event, "toggle")
						if allCounter % 2 == 0 { // off
							XCTAssertEqual(event.src, "off")
							XCTAssertEqual(event.dst, "on")
						} else {
							XCTAssertEqual(event.src, "on")
							XCTAssertEqual(event.dst, "off")
						}
						allCounter += 1
					},
					"leave_on": { event in
						XCTAssertEqual(event.event, "toggle")
						XCTAssertEqual(event.src, "on")

						onCounter += 1
						XCTAssertEqual(event.dst, "off")
					}
				])

			for i in 0...100 {
				XCTAssertEqual(i, allCounter)
				XCTAssertEqual(i / 2, onCounter)
				XCTAssertNil(machine.fire(event: "toggle"))
			}
		}
	}

	func testNoTransition() {
		let machine = FSM(initial: "start", events: [
			FSM.EventDesc(source: "start", event: "run", destination: "start")
			])

		guard let err = machine.fire(event: "run") else {
			XCTFail("expect error but got nothing")
			return
		}

		guard case let FSM.FSMError.noTransition(nestedError) = err else {
			XCTFail("expect no transition error but got other wise")
			return
		}

		XCTAssertNil(nestedError)
	}

	func testNoDeadlock() {
		let machine = FSM(initial: "start", events: [
			FSM.EventDesc(source: "start", event: "run", destination: "end")
			], callbacks: [
				"run": { event in
					_ = event.machine.current() // Should not result in deadlock
				}
			])

		XCTAssertNil(machine.fire(event: "run"))
		XCTAssertEqual(machine.current(), "end")
	}

	func testCallbackArgs() {
		let machine = FSM(initial: "start", events: [
			FSM.EventDesc(source: "start", event: "run", destination: "end")
			], callbacks: [
				"run": { event in
					XCTAssertEqual(event.args.count, 1)
					XCTAssertNotNil(event.args.first)
					XCTAssertTrue(event.args.first! is String)
				}
			])

		XCTAssertNil(machine.fire(event: "run", "test"))
	}

	func testMultipleSources() {
		let machine = FSM(initial: "one", events: [
			FSM.EventDesc(source: "one", event: "first", destination: "two"),
			FSM.EventDesc(source: "two", event: "second", destination: "three"),
			FSM.EventDesc(sources: [
				"one", "two", "three"
				], event: "reset", destination: "one")
			])

		XCTAssertNil(machine.fire(event: "first"))
		XCTAssertEqual(machine.current(), "two")
		XCTAssertNil(machine.fire(event: "reset"))
		XCTAssertEqual(machine.current(), "one")
		XCTAssertNil(machine.fire(event: "first"))
		XCTAssertEqual(machine.current(), "two")
		XCTAssertNil(machine.fire(event: "second"))
		XCTAssertEqual(machine.current(), "three")
		XCTAssertNil(machine.fire(event: "reset"))
		XCTAssertEqual(machine.current(), "one")
	}

	func testMultipleEvents() {
		let machine = FSM(initial: "start", events: [
			FSM.EventDesc(source: "start", event: "first", destination: "one"),
			FSM.EventDesc(source: "start", event: "second", destination: "two"),
			FSM.EventDesc(source: "one", event: "reset", destination: "reset_one"),
			FSM.EventDesc(source: "two", event: "reset", destination: "reset_two"),
			FSM.EventDesc(sources: [
				"reset_one", "reset_two"
				], event: "reset", destination: "start")
			])

		XCTAssertNil(machine.fire(event: "first"))
		XCTAssertEqual(machine.current(), "one")
		XCTAssertNil(machine.fire(event: "reset"))
		XCTAssertEqual(machine.current(), "reset_one")
		XCTAssertNil(machine.fire(event: "reset"))
		XCTAssertEqual(machine.current(), "start")
	}

	func testGenericCallbacks() {
		var beforeEvent = false
		var afterEvent = false
		var enterState = false
		var leaveState = false

		let machine = FSM(initial: "start", events: [
			FSM.EventDesc(source: "start", event: "run", destination: "end")
			], callbacks: [
				"before_event": { _ in beforeEvent = true },
				"after_event": { _ in afterEvent = true },
				"enter_state": { _ in enterState = true },
				"leave_state": { _ in leaveState = true },
			])

		XCTAssertNil(machine.fire(event: "run"))
		XCTAssertTrue(beforeEvent)
		XCTAssertTrue(afterEvent)
		XCTAssertTrue(enterState)
		XCTAssertTrue(leaveState)
	}

	func testAtmoic() {
		let counter = Atomic<Int>(0)
		DispatchQueue.concurrentPerform(iterations: 100) { _ in
			counter.sync { $0 + 1 }
		}
		XCTAssertEqual(counter.value, 100)
	}

	static var allTests = [
		("testSameState", testSameState),
		("testSetState", testSetState),
		("testInappropriateEvent", testInappropriateEvent),
		("testUnknownEvent", testUnknownEvent),
		("testDoubleTransition", testDoubleTransition),
		("testAsync", testAsync),
		("testLeaveStateCallback", testLeaveStateCallback),
		("testNoTransition", testNoTransition),
		("testCallbackArgs", testCallbackArgs),
		("testMultipleSources", testMultipleSources),
		("testGenericCallbacks", testGenericCallbacks),
		("testAtmoic", testAtmoic)
	]
}
