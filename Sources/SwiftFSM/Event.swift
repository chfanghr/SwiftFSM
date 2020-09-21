//
//  Event.swift
//
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation

extension FSM {
	/// The info that get passed as a reference to callbacks in the collection.
    public class Event: CustomStringConvertible{
		/// A reference to the current FSM.
		public var machine: FSM

		/// The name of event.
		public let event: String

		/// The state before transition.
		public let src: String

		/// The state after transition.
		public let dst: String

		/// An optional list of arguments passed to callbacks.
		public var args: [Any] = []

		/// An optional error that can be returned from callback.
		private(set) var error: Error? = nil

		/// An internal flag set if the transition is canceled.
		private(set) var isAsync: Bool = false

		/// An internal flag set if the transition should be asynchronous.
		private(set) var canceled: Bool = false

		internal init(_ machine: FSM, from src: String, on event: String, to dst: String) {
			self.machine = machine
			self.src = src
			self.event = event
			self.dst = dst
		}

		/// Can be called in before_*EVENT* or leave_*STATE* to cancel the
		/// current transition before it happens. It takes an optional error, which will
		/// overwrite `self.error`  if set before.
		public func cancel(error: Error? = nil) {
			if canceled {
				return
			}
			canceled = true
			self.error = error
		}

		/// Can be called in leave_*STATE* to do an asynchronous state transition.
		///
		/// The current state transition will be on hold in the old state until a final
		/// call to Transition is made. This will comlete the transition and possibly
		/// call the other callbacks.
		public func async() {
			isAsync = true
		}
    
        public var description: String{
            "\(src)--|\(event)|-->\(dst) (args=\(args)) (err=\(String(describing: error)))"
        }
	}
}
