//
//  main.swift
//  
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation
import SwiftFSM

let machine=FSM(initial: "closed", events: [
    FSM.EventDesc(sources: ["closed"], event: "open", destination: "open"),
    FSM.EventDesc(sources: ["open"], event: "close", destination: "closed")
])

print(machine.current())

if let err=machine.fire(event: "open"){
    fatalError("unexpected error: \(err)")
}

print(machine.current())

if let err=machine.fire(event: "close"){
    fatalError("unexpected error: \(err)")
}

print(machine.current())
