//: Playground - noun: a place where people can play

import UIKit
import XCPlayground
//import OperationQueue

XCPSetExecutionShouldContinueIndefinitely(true)

//extension NSOperationQueue {
//    
//    convenience init(qualityOfService:import  NSQualityOfService, maxConcurrentOperationCount: Int = 1, underlyingQueue: dispatch_queue_t?) {
//        
//        self.init()
//        
//        self.qualityOfService = qualityOfService
//        self.maxConcurrentOperationCount = maxConcurrentOperationCount
//        
//        if let queue = underlyingQueue {
//            self.underlyingQueue = queue
//        }
//    }
//    
//    convenience init(qualityOfService: NSQualityOfService, maxConcurrentOperationCount: Int = 1) {
//        self.init()
//        
//        self.qualityOfService = qualityOfService
//        self.maxConcurrentOperationCount = maxConcurrentOperationCount
//    }
//    
//}

class DuleQueue {
    
	//dispatch_queue_attr_make_with_qos_class
	private let underlyingQueue: dispatch_queue_t! // = dispatch_queue_create("com.naim.DuleQueue", DISPATCH_QUEUE_SERIAL)
    
	//private let testQueue: NSOperationQueue = NSOperationQueue(
    
	private let firstQueue = NSOperationQueue(qualityOfService: .Utility)
    
	private let secondQueue = NSOperationQueue(qualityOfService: .Utility)
    
	init() {
        
		let attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0)
		underlyingQueue = dispatch_queue_create("com.naim.DuleQueue", attrs)
        
		firstQueue.underlyingQueue = underlyingQueue
		secondQueue.underlyingQueue = underlyingQueue
	}
    
	func dispachOnFirstQueue(block: dispatch_block_t) {
    
		let operation = NSBlockOperation(block: block)
        
		firstQueue.addOperations([operation], waitUntilFinished: true)
	}
    
	func dispachOnSecondQueue(block: dispatch_block_t) {
        
		let operation = NSBlockOperation(block: block)
        
		secondQueue.addOperations([operation], waitUntilFinished: true)
	}
}

let queue = DuleQueue()
var count = 0

var data = [Int]()

for i in 0..<10 {
    
	queue.dispachOnFirstQueue {
		data.append(1)
		sleep(3)
	}
    
	queue.dispachOnSecondQueue {
		data.append(8)
		sleep(1)
	}
}

queue.dispachOnSecondQueue {
	print(" --> \(data)")
}

//for i in 0..<10 {
//    for j in 0..<5 {
//        
//        if (j > 0) && (j % 2) == 0 {
//            queue.dispachOnSecondQueue {
//                //data.append(3)
//                data[j] = (data[j] + 3)
//                sleep(arc4random_uniform(1))
//            }
//        }
//        
//        queue.dispachOnFirstQueue {
//            data.append(1)
//            sleep(arc4random_uniform(1))
//        }
//        
//        queue.dispachOnSecondQueue {
//            data.append(2)
//            sleep(arc4random_uniform(1))
//        }
//    }
//    
//    queue.dispachOnSecondQueue {
//        print(" --> \(data)")
//        data.removeAll()
//        sleep(arc4random_uniform(1))
//    }
//}

//for index in 1...10 {
//    queue.dispachOnSecondQueue {
//        data.append(2)
//    }
//}

