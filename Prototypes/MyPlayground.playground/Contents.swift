//: Playground - noun: a place where people can play

import UIKit

var str: String = "Hello, playground"

var index = str.startIndex
var end = str.endIndex

index = index.advancedBy(15)

let range = Range<String.Index>(start: index, end: end)
str.substringWithRange(range)

private let underlyingQueue: dispatch_queue_t! = dispatch_queue_create("com.naim.DuleQueue", DISPATCH_QUEUE_SERIAL)

class hold {
    
	init(queue: dispatch_queue_t!) {
		print("Git queue: \(queue)")
	}
    
}

class holdNumber {
    
	init(holdNumber: Int) {
		print("Got number: \(holdNumber)")
	}
    
}

public class test {
    
	lazy var underlyingQueue: dispatch_queue_t! = dispatch_queue_create("com.naim.DuleQueue", DISPATCH_QUEUE_SERIAL)
	internal var number: Int = 2
    
	//let myHold = hold(queue: underlyingQueue)
	private lazy var myNumber : holdNumber = holdNumber(holdNumber: self.number)
    
	func out() {
		print("Test: \(underlyingQueue)")
	}
}

var myTest = test()

myTest.out()
