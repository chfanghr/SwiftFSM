//
//  main.swift
//  
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation
import SwiftFSM

let machine = FSM(initial: "start", events: [
    FSM.EventDesc(sources: ["start"], event: "run", destination: "end"),
],callbacks:[
    "leave_start" : { event in
        event.async()
    }
])
