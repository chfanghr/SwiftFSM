//
//  main.swift
//  
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation
import ExampleUtilities
import SwiftFSM

class Door{
    let of:String
    
    // Workaround: 'self' captured by a closure before all members were initialized
    private var _machine: FSM? = nil
    private var machine: FSM{
        set{
            _machine = newValue
        }
        get{
            _machine!
        }
    }
    
    init(of: String = "老 八 撤 🔒"){
        self.of=of
        self.machine=FSM(initial: "closed", events: [
            FSM.EventDesc(source: "closed", event: "toggle", destination: "open"),
            FSM.EventDesc(source: "open", event: "toggle", destination: "closed")
        ], callbacks: [
            "enter_state": { event in
                self.onEnterState(event: event)
            }
        ])
    }
    
    private func onEnterState(event:FSM.Event){
        print("The door of \(of) is \(event.dst)", terminator: "")
    }
    
    func toggle(){
        notExpectError(machine.fire(event: "toggle"))
    }
}

let door=Door()

door.toggle()

while let _ = readLine(){
    door.toggle()
}
