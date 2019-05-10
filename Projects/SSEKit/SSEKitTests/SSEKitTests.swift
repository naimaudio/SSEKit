//
//  SSEKitTests.swift
//  SSEKitTests
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Naim Audio All rights reserved.
//

import XCTest
@testable import SSEKit

let DUT_SSE_Endpoint = URL(string: "http://192.168.0.20:15081/notify")!

// TODO: mock/stub URLSession & Data task


class SSEKitTests: XCTestCase {
    
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
    
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
    
	func testConnectSendDisconnectOK() {
		
		let connectExpectation = self.expectation(description: "should connect ok")
		let connectEventExpectation = self.expectation(description: "should get connect event")
		let disconnectEventExpectation = self.expectation(description: "has sent disconnection event")
		let npEventExpectation = self.expectation(description: "has sent now playing event")
		let disconnectExpectation = self.expectation(description: "should disconnect ok")
		
		let manager = SSEManager()
		manager.connect(toURL: DUT_SSE_Endpoint) { (error) in
			XCTAssert(error == nil)
			XCTAssert(Thread.isMainThread, "closure should be on main thread")
 			connectExpectation.fulfill()
		}
		
		let eventSource = manager.addEventSource(forEvents: []) // listen to all events
		let cheeseSource = manager.addEventSource(forEvents: ["cheese"])  // listen for cheese
		
		let observer = NotificationCenter.default.addObserver(forName: Notification.Name(SSEManager.Notification.Connected.rawValue), object:eventSource, queue: nil) { (notification) in
			
			XCTAssert(Thread.isMainThread, "Notifications should be on main thread")
			XCTAssert(notification.object as! EventSource == eventSource, "should be eventSource")
			
			// simulate cheese event
			manager.parseEventData(Data("id:11713\nevent:cheese\ndata:{\"version\":\"1\",\"ussi\":\"cheese\",\"id\":\"1\",\"parameters\":{\"transportPosition\":\"8872\"}}".utf8))
			
			connectEventExpectation.fulfill()
		}
		
		
		let npObserver = NotificationCenter.default.addObserver(forName: Notification.Name(SSEManager.Notification.Event.rawValue), object:cheeseSource, queue: nil) { (notification) in
			
			XCTAssert(Thread.isMainThread, "Notifications should be on main thread")
			XCTAssert(notification.object as! EventSource == cheeseSource, "should be cheeseSource")
			
			// we are done, lets diconnect
			manager.disconnect() {
				XCTAssert(manager.connectionState == .idle, "should be in idle state at the end")
				disconnectExpectation.fulfill()
			}
			
			npEventExpectation.fulfill()
		}
		
		
		let disconnectObserver = NotificationCenter.default.addObserver(forName: Notification.Name(SSEManager.Notification.Disconnected.rawValue), object:eventSource, queue: nil) { (notification) in
			XCTAssert(Thread.isMainThread, "Notifications should be on main thread")
			disconnectEventExpectation.fulfill()
		}
		
		self.waitForExpectations(timeout: 15) { (error) in
			XCTAssertNil(error)
			
			NotificationCenter.default.removeObserver(observer)
			NotificationCenter.default.removeObserver(disconnectObserver)
			NotificationCenter.default.removeObserver(npObserver)
		}
	}
	
	func testConnectSendOK_depricated() {  // use the old way
		
		let connectExpectation = self.expectation(description: "should connect ok")
		let cheeseEventExpectation = self.expectation(description: "has sent cheese event")
		let disconnectExpectation = self.expectation(description: "should disconnect ok")
		
		let manager = SSEManager(sources: [])
		
		let eventSource = manager.addEventSource(EventSourceConfiguration(withHost: DUT_SSE_Endpoint.host!, port: DUT_SSE_Endpoint.port!, endpoint: DUT_SSE_Endpoint.path, timeout: 5, events: nil, name: "everything!"))
		let cheeseSource = manager.addEventSource(EventSourceConfiguration(withHost: DUT_SSE_Endpoint.host!, port: DUT_SSE_Endpoint.port!, endpoint: DUT_SSE_Endpoint.path, timeout: 5, events: ["cheese"], name: "cheese!"))
		
		let observer = NotificationCenter.default.addObserver(forName: Notification.Name(SSEManager.Notification.Connected.rawValue), object:eventSource, queue: nil) { (notification) in
			
			XCTAssert(Thread.isMainThread, "Notifications should be on main thread")
			
			connectExpectation.fulfill()
			
			// simulate cheese event
			manager.parseEventData(Data("id:11713\nevent:cheese\ndata:{\"version\":\"1\",\"ussi\":\"cheese\",\"id\":\"1\",\"parameters\":{\"transportPosition\":\"8872\"}}".utf8))
			
		}
		
		let cheeseObserver = NotificationCenter.default.addObserver(forName: Notification.Name(SSEManager.Notification.Event.rawValue), object:cheeseSource, queue: nil) { (notification) in
			
			XCTAssert(Thread.isMainThread, "Notifications should be on main thread")
			XCTAssert(notification.object as! EventSource == cheeseSource, "should be cheeseSource")
			
			manager.removeAllEventSources {
				XCTAssert(manager.connectionState == .idle, "should be in idle state at the end")
				disconnectExpectation.fulfill()
			}
			
			cheeseEventExpectation.fulfill()
		}
		
		self.waitForExpectations(timeout: 5) { (error) in
			XCTAssertNil(error)
			
			NotificationCenter.default.removeObserver(observer)
			NotificationCenter.default.removeObserver(cheeseObserver)
		}
	}
	
	func testConnectNOK() {
		let connectResponseExpectation = self.expectation(description: "should call connect closure")
		
		
		let manager = SSEManager()
		
		manager.maxConnectionRetries = 2 // or test takes too long!
		
		// connect to an invalid ip (get a request timed out)
		manager.connect(toURL:  URL(string: "http://999.999.999.999:15081/notify")!, completion: { (error) in
			XCTAssert(error != nil)
			XCTAssert(Thread.isMainThread, "closure should be on main thread")
			connectResponseExpectation.fulfill()
		})
		
		self.waitForExpectations(timeout: 15) { (error) in
			XCTAssertNil(error)
		}
	}
	
	
	func testConnectOKThenFail() {
		let connectResponseExpectation = self.expectation(description: "should call connect closure")
		let disconnectEventExpectation = self.expectation(description: "should disconnect")
		
		let manager = SSEManager()
		
		manager.maxConnectionRetries = 0 // stop retries
		
		manager.connect(toURL:  DUT_SSE_Endpoint, completion: { (error) in
			XCTAssert(error == nil)
			XCTAssert(Thread.isMainThread, "closure should be on main thread")
			connectResponseExpectation.fulfill()
			
			// force an error
			manager.urlSession(manager.session!, task: manager.sessionTask!, didCompleteWithError: NSError(domain: "com.naim.ssekittest", code: 1, userInfo: [:]) as Error)
		})
		
		let disconnectObserver = NotificationCenter.default.addObserver(forName: Notification.Name(SSEManager.Notification.Disconnected.rawValue), object:manager, queue: nil) { (notification) in
			XCTAssert(Thread.isMainThread, "Notifications should be on main thread")
			disconnectEventExpectation.fulfill()
		}
		
		self.waitForExpectations(timeout: 15) { (error) in
			XCTAssertNil(error)
			XCTAssert(manager.connectionState == SSEManager.ConnectionState.idle, "should be idle")
			NotificationCenter.default.removeObserver(disconnectObserver)
		}
	}
    
	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure {
			// Put the code you want to measure the time of here.
		}
	}
    
}
