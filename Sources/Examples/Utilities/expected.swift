//
//  expected.swift
//
//
//  Created by 方泓睿 on 9/22/20.
//

import Foundation

public func expectError(_ err: Error?) {
	guard let err = err else {
		fatalError("expected error, but no error returned")
	}

	print("expected error: \(err)")
}

public func notExpectError(_ err: Error?) {
	if let err = err {
		fatalError("unexpected error: \(err)")
	}
}
