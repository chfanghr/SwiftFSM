//
//  main.swift
//
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation
import SwiftFSM
import ExampleUtilities

let machine = FSM(initial: "start", events: [
	FSM.EventDesc(source: "start", event: "run", destination: "end"),
	], callbacks: [
		"leave_start": { event in
			event.async()
		}
	])

print(machine.current())
expectError(machine.fire(event: "run"))
print(machine.current())
notExpectError(machine.completeTransition())
print(machine.current())
