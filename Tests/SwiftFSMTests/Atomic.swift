//
//  Atomic.swift
//
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation

class Atomic<T> {
	private var _value: T
	private let lock: NSLock = NSLock()

	init(_ value: T) {
		self._value = value
	}

	public var value: T {
		get {
			lock.lock()
			defer {
				lock.unlock()
			}
			return _value
		}
		set {
			lock.lock()
			defer {
				lock.unlock()
			}
			_value = newValue
		}
	}

	func sync(_ job: (_ value: T) -> T) {
		lock.lock()
		defer {
			lock.unlock()
		}
		_value = job(_value)
	}
}

func sync<R>(_ job: () -> R) -> R {
	job()
}

func sync<R>(_ job: () throws -> R) throws -> R {
	try job()
}
