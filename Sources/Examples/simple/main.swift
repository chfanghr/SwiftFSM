//
//  main.swift
//  
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation
import SwiftFSM
import ExampleUtilities

let machine=FSM(initial: "closed", events: [
    FSM.EventDesc(source: "closed", event: "open", destination: "open"),
    FSM.EventDesc(source: "open", event: "close", destination: "closed")
])

print(machine.current())
notExpectError(machine.fire(event: "open"))
print(machine.current())
notExpectError(machine.fire(event: "close"))
print(machine.current())
