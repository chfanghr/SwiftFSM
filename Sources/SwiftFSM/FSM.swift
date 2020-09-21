//
//  FSM.swift
//
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation

/// The state machine that holds the current state.
public class FSM {
    private class Transitioner {
        /// Completes an asynchronous state change.
        ///
        /// The callback for leave_*STATE* must previously have called Async on its
        /// event to have initiated an asynchronous state transition.
        func transition(_ machine: FSM) -> Error? {
            guard let transition = machine.transition else {
                return FSMError.notInTransition
            }
            transition()
            machine.transition = nil
            return nil
        }
    }

    public typealias Callback = (_ event: Event) -> ()

    public struct Key {
        /// Used to keeping the callbacks mapped to a target.
        public struct Callback: Hashable {
            public enum Category {
                case none
                case beforeEvent
                case leaveState
                case enterState
                case afterEvent
            }

            /// Either the name of a state or an event depending on which
            /// callback type the key refers to. It can also be empty for a non-target.
            public let target: String

            /// The situation when the callback will be run.
            public let type: Category

            public func hash(into hasher: inout Hasher) {
                hasher.combine(target)
                hasher.combine(type)
            }

            public static func ==(lhs: Callback, rhs: Callback) -> Bool {
                lhs.target == rhs.target && lhs.type == rhs.type
            }
        }

        /// Used to storing the transition map.
        public struct Event: Hashable {
            /// The name of the event that the keys refers to.
            public let event: String
            /// Source from where the event can transition.
            public let src: String

            public func hash(into hasher: inout Hasher) {
                hasher.combine(event)
                hasher.combine(src)
            }

            public static func ==(lhs: Event, rhs: Event) -> Bool {
                lhs.event == rhs.event && lhs.src == rhs.src
            }
        }
    }

    /// Represent an event when initializing the FSM.
    ///
    /// The event can have one or more source states that is valid for performing
    /// the transition. If the FSM is in one of the source states it will end up in
    /// the specified destination state, calling all defined callbacks as it goes.
    public struct EventDesc {
        /// The event name used when calling for a transition.
        public let name: String

        // An array of source states that the FSM must be in to perform a state transition.
        public let sources: [String]

        /// The destination state that the FSM will be in if the transition succeeds.
        public let destination: String

        public init(sources: [String], event: String, destination: String) {
            self.name = event
            self.sources = sources
            self.destination = destination
        }
    }

    /// The state that the FSM is currently in.
    private(set) var currentState: String

    /// The predefined initial state of the machine.
    public let initialState: String

    /// Dictionary which maps events and source states to destination states.
    public let transitions: [Key.Event: String]

    /// Dictionary which maps events and targets to callback functions.
    public let callbacks: [Key.Callback: Callback]

    /// The internal transition functions used either directly
    /// or when transition is called in an asynchronous state transition.
    internal var transition: (() -> ())? = nil

    private let transitioner = Transitioner()

    private let dispatchQueue = DispatchQueue.global()

    /// All valid states of the machine.
    public var allStates: Set<String> {
        var states = Set<String>()

        states.insert(initialState)

        for (event, dst) in transitions {
            states.insert(dst)
            states.insert(event.src)
        }

        return states
    }

    /// All events of the machine.
    public var allEvents: Set<String> {
        var events = Set<String>()

        for (event, _) in transitions {
            events.insert(event.event)
        }

        return events
    }

    /// Construct a FSM from events and callbacks.
    ///
    /// The events and transitions are specified as an array of `EventDesc` classes.
    /// Each Event is mapped to one or more internal transitions
    ///  from `EventDesc.sources` to `EventDesc.destination`.
    ///
    /// Callbacks are added as a dictionary where the key is parsed
    /// as the callback event as follows, and called in the same order:
    ///
    /// 1.  before_*EVENT* - called before event named *EVENT*
    ///
    /// 2.  before_event - called before all events
    ///
    /// 3.  leave_*OLD_STATE* - called before leaving *OLD_STATE*
    ///
    /// 4.  leave_state - called before leaving all states
    ///
    /// 5.  enter_*NEW_STATE* - called after entering *NEW_STATE*
    ///
    /// 6.  enter_state - called after entering all states
    ///
    /// 7.  after_*EVENT* - called after event named *EVENT*
    ///
    /// 8.  after_event - called after all events
    ///
    /// There are also two short form versions for the most commonly used callbacks.
    /// They are simply the name of the event or state:
    ///
    /// 1. *NEW_STATE* - called after entering *NEW_STATE*
    ///
    /// 2. *EVENT* - called after event named *EVENT*
    ///
    /// If both a shorthand version and a full version is specified it is undefined
    /// which version of the callback will end up in the internal map. This is due
    /// to the psuedo random nature of swift dictionaries. No checking for multiple keys is
    /// currently performed.
    public init(initial: String, events: [EventDesc], callbacks: [String: Callback] = [:]) {
        self.currentState = initial
        self.initialState = initial

        var finalTransitions = [Key.Event: String]()
        var finalCallbacks = [Key.Callback: Callback]()

        for event in events {
            for source in event.sources {
                finalTransitions[Key.Event(event: event.name, src: source)] = event.destination
            }
        }

        enum type {
            case none
            case event
            case state
        }

        let find = { (_ target: String) -> type in
            for (event, dst) in finalTransitions {
                if event.src == target || dst == target {
                    return .state
                }
                if event.event == target {
                    return .event
                }
            }
            return .none
        }

        let isEvent = { (_ target: String) -> Bool in
            find(target) == .event
        }

        let isState = { (_ target: String) -> Bool in
            find(target) == .state
        }

        for (name, callback) in callbacks {
            var target: String = ""
            var callbackCategory: Key.Callback.Category = .none

            let setTargetIfHasPrefix = { (_ prefix: String) -> Bool in
                guard name.hasPrefix(prefix) else {
                    return false
                }
                target = String(name.dropFirst(prefix.count))
                return true
            }

            if setTargetIfHasPrefix("before_") {
                if target == "event" {
                    target = ""
                    callbackCategory = .beforeEvent
                } else if isEvent(target) {
                    callbackCategory = .beforeEvent
                }
            } else if setTargetIfHasPrefix("leave_") {
                if target == "state" {
                    target = ""
                    callbackCategory = .leaveState
                } else if isState(target) {
                    callbackCategory = .leaveState
                }
            } else if setTargetIfHasPrefix("enter_") {
                if target == "state" {
                    target = ""
                    callbackCategory = .enterState
                } else if isState(target) {
                    callbackCategory = .enterState
                }
            } else if setTargetIfHasPrefix("after_") {
                if target == "event" {
                    target = ""
                    callbackCategory = .afterEvent
                } else if isState(target) {
                    callbackCategory = .afterEvent
                }
            } else {
                target = name
                if isState(target) {
                    callbackCategory = .enterState
                } else if isEvent(target) {
                    callbackCategory = .afterEvent
                }
            }

            if callbackCategory != .none {
                finalCallbacks[Key.Callback(target: target, type: callbackCategory)] = callback
            }
        }

        self.transitions = finalTransitions
        self.callbacks = finalCallbacks
    }

    
    /// Initiates a state transition with the named event.
    ///
    /// The call takes a variable number of arguments that will be passed to the
    /// callback, if defined.
    ///
    /// It will return nil if the state change is ok or one of these errors:
    ///
    /// - `event` inappropriate because previous transition did not complete
    ///
    /// - `event` inappropriate in current state Y
    ///
    /// - `event` does not exist
    ///
    /// - internal error on state transition
    ///
    /// The last error should never occur in this situation and is a sign of an
    /// internal bug.
    ///
    /// - Parameters:
    ///     - event: Event to be raised.
    ///     - args: Arguments for callback functions.
    public func fire(event: String, _ args: Any...) -> Error? {
        dispatchQueue.sync {
            if transition != nil {
                return FSMError.inTransition(event: event)
            }

            guard let dst = transitions[Key.Event(event: event, src: currentState)] else {
                for (eventKey, _) in transitions {
                    if eventKey.event == event {
                        return FSMError.invalidEvent(event: event, state: currentState)
                    }
                }
                return FSMError.unknownEvent(event: event)
            }

            let eventObj = Event(self, from: currentState, on: event, to: dst)
            eventObj.args = args

            if let err = callBeforeEventCallbacks(event: eventObj) {
                return err
            }

            if currentState == dst {
                callAfterEventCallbacks(event: eventObj)
                return FSMError.noTransition(error: eventObj.error)
            }

            transition = {
                self.currentState = dst

                self.callEnterStateCallbacks(event: eventObj)
                self.callAfterEventCallbacks(event: eventObj)
            }

            if let err = callLeaveStateCallbacks(event: eventObj) {
                if let fsmErr = err as? FSMError {
                    if case FSMError.canceledEvent(_) = fsmErr {
                        transition = nil
                    }
                }
                return err
            }

            if let _ = doTransition() {
                return FSMError.unknown
            }

            return eventObj.error
        }
    }

    /// Completes the pending async transition.
    public func completeTransition() -> Error? {
        dispatchQueue.sync {
            doTransition()
        }
    }

    /// Indicates whether the given event can be raised in current state or not.
    public func can(fire event: String) -> Bool {
        dispatchQueue.sync {
            transition == nil && transitions[Key.Event(event: event, src: currentState)] != nil
        }
    }


    /// Allows users to move to the given state from current state.
    /// The give state must be vaild for the machine.
    public func set(current state: String) -> Error? {
        if !allStates.contains(state) {
            return FSMError.unknownState(state: state)
        }
        return dispatchQueue.sync {
            if transition != nil {
                return FSMError.inTransition(event: "")
            }
            currentState = state
            return nil
        }
    }

    /// The current state of the machine.
    public func current() -> String {
        dispatchQueue.sync {
            currentState
        }
    }

    public func isCurrent(state: String) -> Bool {
        dispatchQueue.sync {
            currentState == state
        }
    }

    /// Set the machine's state to initialState.
    public func reset() {
        dispatchQueue.sync {
            transition = nil
            currentState = initialState
        }
    }

    private func callBeforeEventCallbacks(event: Event) -> Error? {
        if let callback = callbacks[Key.Callback(target: event.event, type: .beforeEvent)] {
            callback(event)
            if event.canceled {
                return FSMError.canceledEvent(error: event.error)
            }
        }
        if let callback = callbacks[Key.Callback(target: "", type: .beforeEvent)] {
            callback(event)
            if event.canceled {
                return FSMError.canceledEvent(error: event.error)
            }
        }
        return nil
    }

    private func callAfterEventCallbacks(event: Event) {
        if let callback = callbacks[Key.Callback(target: event.event, type: .afterEvent)] {
            callback(event)
        }
        if let callback = callbacks[Key.Callback(target: "", type: .afterEvent)] {
            callback(event)
        }
    }

    private func callEnterStateCallbacks(event: Event) {
        if let callback = callbacks[Key.Callback(target: currentState, type: .enterState)] {
            callback(event)
        }
        if let callback = callbacks[Key.Callback(target: "", type: .enterState)] {
            callback(event)
        }
    }

    private func callLeaveStateCallbacks(event: Event) -> Error? {
        if let callback = callbacks[Key.Callback(target: currentState, type: .leaveState)] {
            callback(event)
            if event.canceled {
                return FSMError.canceledEvent(error: event.error)
            } else if event.isAsync {
                return FSMError.async(error: event.error)
            }
        }
        if let callback = callbacks[Key.Callback(target: "", type: .leaveState)] {
            callback(event)
            if event.canceled {
                return FSMError.canceledEvent(error: event.error)
            } else if event.isAsync {
                return FSMError.async(error: event.error)
            }
        }
        return nil
    }

    private func doTransition() -> Error? {
        transitioner.transition(self)
    }
}
