//
//  OperationQueue.swift
//  
//
//  Created by Richard Stelling on 19/10/2015.
//
//

import Foundation

extension NSOperationQueue {
    
	//private let underlyingQueue: dispatch_queue_t!
    
	convenience init(qualityOfService: NSQualityOfService, maxConcurrentOperationCount: Int = 1, underlyingQueue: dispatch_queue_t?) {
        
		self.init()
        
		self.qualityOfService = qualityOfService
		self.maxConcurrentOperationCount = maxConcurrentOperationCount
        
		if let queue = underlyingQueue {
			self.underlyingQueue = queue
		}
//        else {
//            let attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0)
//            underlyingQueue = dispatch_queue_create("com.naim.DuleQueue", attrs)
//            
//            self.underlyingQueue = underlyingQueue
//        }
	}
    
//    convenience init(qualityOfService: NSQualityOfService, maxConcurrentOperationCount: Int = 1) {
//        self.init()
//        
//        self.qualityOfService = qualityOfService
//        self.maxConcurrentOperationCount = maxConcurrentOperationCount
//    }
}