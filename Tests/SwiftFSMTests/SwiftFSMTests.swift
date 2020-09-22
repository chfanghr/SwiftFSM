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

	static var allTests = [
		("testSameState", testSameState),
		("testSetState", testSetState),
		("testInappropriateEvent", testInappropriateEvent),
		("testUnknownEvent", testUnknownEvent),
		("testDoubleTransition", testDoubleTransition)
	]
}
