//
//  Error.swift
//
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation

extension FSM {
	/// Errors that could be returned in transition
	public enum FSMError: Error, CustomStringConvertible {
		/// An asynchronous transition is already in progress.
		/// - event: The invalid event.
		case inTransition(event: String)
		/// Given event cannot be called in current state.
		/// - event: The invalid event.
		/// - state: Current state of the machine.
		case invalidEvent(event: String, state: String)
		/// Given event is not defined.
		/// - event: The undefined event.
		case unknownEvent(event: String)
		/// No asynchronous event is in transition.
		case notInTransition
		/// No transition have happened but callback throws.
		/// For example if the source and destination states are the same.
		/// - error: The error thrown from the callback ffunction.
		case noTransition(error: Error?)
		/// A callback have canceled a transition with error.
		/// - error: The error thrown from the callback function.
		case canceledEvent(error: Error?)
		/// The machine have already in an asynchronous transition.
		/// - error: The error thrown from the callback function.
		case async(error: Error?)
		case unknownState(state: String)
		/// Internal error and should never occured.
		case unknown

		public var description: String {
			switch self {
			case let .inTransition(event):
				return "event \(event) inappropriate because previous transition did not complete"
			case let .invalidEvent(event, state):
				return "event \(event) inappropriate in current state \(state)"
			case let .unknownEvent(event):
				return "event \(event) does not exist"
			case .notInTransition:
				return "transition inappropriate because no state change in progress"
			case let .noTransition(optErr):
				if let err = optErr {
					return "no transition happened: \(err)"
				}
				return "no transition happened"
			case let .canceledEvent(optErr):
				if let err = optErr {
					return "transition canceled: \(err)"
				}
				return "transition canceled"
			case let .async(optErr):
				if let err = optErr {
					return "async transition started: \(err)"
				}
				return "async transition started"
			case let .unknownState(state):
				return "state \(state) is not a valid state for the current machine"
			case .unknown:
				return "internal error on state transition"
			}
		}
	}
}
