//: Playground - noun: a place where people can play

//import UIKit
import XCPlayground
import Foundation
    
XCPSetExecutionShouldContinueIndefinitely(true)

extension NSOperationQueue {
    
	convenience init(qualityOfService: NSQualityOfService, maxConcurrentOperationCount: Int = 1) {
		self.init()
        
		self.qualityOfService = qualityOfService
		self.maxConcurrentOperationCount = maxConcurrentOperationCount
	}
    
}

class Producer {
    
	//private unowned let dataWrite: NSMutableData
	private var dataWriteString: DataContainer
    
	//private let dataToWrite = "abcdefghijklmnopqrstuvwxyz+0123456789+ABCDEFGHIJKLMNOPQRSTUVWXYZ+"
	private let dataToWrite = "abcd123+efgh456+abcd123+efgh456+abcd123+efgh456+abcd123+efgh456+abcd123+efgh456+a+b+c+d+f+g+h+i+j+k+l+aa+bb+cc+dd+aaa+bbb+ccc+efgh456abcd123efgh456efgh456abcd123efgh456+"
    
	var clock: NSTimer!
	//lazy var clock: NSTimer! = NSTimer.scheduledTimerWithTimeInterval(4, target: self, selector: "produceSomeData", userInfo: nil, repeats: true)
    
	var count = 0
    
	private unowned let consumer: Consumer
    
	init(data: DataContainer, consumer: Consumer) {
		dataWriteString = data
		self.consumer = consumer
        
		clock = NSTimer.scheduledTimerWithTimeInterval(0.0125, target: self, selector: "produceSomeData:", userInfo: nil, repeats: true)
		clock.fire()
        
		print("Created Producer...")
	}
    
	@objc func produceSomeData(timer: NSTimer) {
		//print("- tick")
        
		let length = dataToWrite.characters.count
		let randomInt = Int(arc4random_uniform(UInt32(length))) + 1 //no zeros
		let index = dataToWrite.startIndex.advancedBy(randomInt)
		let string = dataToWrite.substringToIndex(index)

		//print("Adding string \"\(string)\" to data container")
    
		//let data: NSData! = string.dataUsingEncoding(NSUTF8StringEncoding)
        
		//print("Adding string \"\(string)\" to data container")
		//print("Adding data \"\(data)\" to data container")
        
//        if(data != nil) {
//            dataWrite.appendData(data)
//            
//            consumer.scheduleDrain()
//        }
        
        //TODO: Set next fire date to a random time in the future 1..10
        
        //print("Data container size: \(dataWrite.length)")
        
        dataWriteString.append(string)
        consumer.scheduleDrain()
        
        count++
        if (count % 50) == 0 {  //(Int(arc4random_uniform(200))) + 10
            clock.fireDate = NSDate().dateByAddingTimeInterval(Double(arc4random_uniform(5)))
        }
	}
    
}

class Consumer {
    
	//private unowned let dataRead: NSMutableData
	private var dataReadString: DataContainer
    
	var clock: NSTimer!
    
	var location: String.Index!
	var distance: String.Index.Distance = 0
	var foundChuncks = 0
    
	var progressArray: [Float] = []
    
	let opsQueue = NSOperationQueue(qualityOfService: .Background)
    
	init(data: DataContainer) {
		dataReadString = data
		location = dataReadString.startIndex();
        
		clock = NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "consumeSomeData:", userInfo: nil, repeats: true)
        
		print("Created Consumer...")
	}
    
	func scheduleDrain() {
        
//        let dataDelta = dataReadString.characters.count - location
//        XCPCaptureValue("Delta", value: dataDelta)
        
        if dataReadString.length > 64  {
            opsQueue.addOperationWithBlock {
                self.drain()
            }
        }
        
	}
    
	var count: Int = 0
    
	func drain() {
        
		count++
        
		//location in NSData is not the same as location in String
		//DATA->String->string buffer->consumer
		//let nextRange = Range<String.Index>(start: location, end: dataReadString.endIndex)
        
		//let nextRange: Range<Index> = NSMakeRange(location, (dataReadString.characters.count - location)) //range from location to end of data container
		//let subData = dataRead.subdataWithRange(nextRange)
		let newLocation = dataReadString.startIndex(); //This gets the Index for the current string size
		let newNewLoc = newLocation.advancedBy(distance)
        
		//let range = Range<String.Index>(start: newNewLoc, end: dataReadString.endIndex())
	// print("distance: \(distance)   range: \(range)")
       
	 let string = dataReadString.chunk(fromIndex: newNewLoc)
        
	 //print("Data: \(subData)")
        
	 //let string: String! = String(data: subData, encoding: NSUTF8StringEncoding)
        
	 if (string.characters.count > 0) {
            
	     let scanner = NSScanner(string: string)
            
	     while(!scanner.atEnd) {
                
	         var foundStr: NSString? = nil
                
	         if scanner.scanUpToString("+", intoString: &foundStr) { //capture string in nil
                    
	             if(scanner.scanString("+", intoString: nil)) { //scan past +)
                        
	                 //GET NEW LOCATION EVERY TIME
                        
	                 //location.advancedBy(foundStr!.length)
                        
	                 //print("Length: NS->\(foundStr!.length), S->\(foundString.characters.count)")
	                 //let dis: String.Index.Distance = foundString.characters.count as String.Index.Distance
	                // print("DISTANCE: \(dis)")
	                 //let newLocation = location.advancedBy(foundString.characters.count)
	                // print("NEW LOCATION: \(newLocation)")
                        
	                 let foundString: String = foundStr as! String
                        
	                 let distanceToAdvance = 1 + (foundString.characters.count as String.Index.Distance) //+1 for the '+'
	                 distance += distanceToAdvance
                        
	                 //print("location: \(location)")
                        
	                 foundChuncks++
	             }
	         }
	     }
        
	     if (dataReadString.length >= 512) || ((foundChuncks % 64) == 0) {
	         //TODO: only add one at a time
	         let op = NSBlockOperation {
	             let index = self.dataReadString.startIndex().advancedBy(self.distance)
	             self.dataReadString.trim(fromIndex: index)
	             self.distance = 0
	         }
                
	         op.queuePriority = .VeryHigh
                
	         opsQueue.addOperation(op)
	     }
	 }
	 else {
	     print("data string: \(dataReadString)")
	     print("Bad data: \(string)")
	 }
	}
    
	@objc func consumeSomeData(timer: NSTimer) {
        
		//print("Consumer storage length: \(dataReadString.length)")
        
		_ = dataReadString.length
		//XCPCaptureValue("Length", value: storageLength)
        
	// print("Location index: \(location)")
        
        
//        let progress = 1.0 - (Float(location) / Float(dataRead.length))
//        XCPCaptureValue("Delta", value: progress)
//        
//        let queueLength = opsQueue.operationCount
//        XCPCaptureValue("Queue Length", value: queueLength)
	}

}

class DataContainer {
    
	init() {
        
	}
    
	//location?
    
	var length: Int {
        
		get {
			return internalStringStorage.characters.count //TODO
		}
	}
    
//    func distanceToEnd(fromIndex index: Range<String.Index>) {
//        
//        
//        
//    }
    
	private var internalStringStorage = String()
    
	func append(data: String) {
        
		internalStringStorage += data //TODO: Thread safe?
        
	}
    
	func chunk(range: Range<String.Index>) -> String {
        
		return internalStringStorage.substringWithRange(range)
	}
    
	func chunk(fromIndex index: String.Index) -> String {
        
		let range = Range<String.Index>(start: index, end: internalStringStorage.endIndex)
        
		//print("\tchunk :: \(range) -> internalStringStorage")
        
		return internalStringStorage.substringWithRange(range)
	}
    
	func startIndex() -> String.Index {
		return internalStringStorage.startIndex
	}
    
	func endIndex() -> String.Index {
		return internalStringStorage.endIndex
	}
    
	func trim(fromIndex index: String.Index) {
        
		let trimmedString = chunk(fromIndex: index)
		internalStringStorage = trimmedString
	}
}

//let dataContainer:  NSMutableData! = NSMutableData(capacity: 512)
var dataContainer: DataContainer = DataContainer()

// the dataContainer should be a class

let consumer = Consumer(data: dataContainer)
let producer = Producer(data: dataContainer, consumer: consumer)


//let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(20 * Double(NSEC_PER_SEC)))

//dispatch_after(delayTime, dispatch_get_main_queue()) {
//    
//    consumer.scheduleDrain()
//    
//}

//let delayTime2 = dispatch_time(DISPATCH_TIME_NOW, Int64(75 * Double(NSEC_PER_SEC)))
//
//dispatch_after(delayTime2, dispatch_get_main_queue()) {
//    
//    consumer.drain()
//    
//}
