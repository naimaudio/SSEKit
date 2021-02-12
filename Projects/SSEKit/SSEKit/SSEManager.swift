//
//  SSEManager.swift
//  SSEKit
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Naim Audio All rights reserved.
//

import Foundation

// MARK: Notifications
public extension SSEManager {
    
	enum Notification: String {
        
		case Connected
		case Event
		case Disconnected
        
		public enum Key: String {
            
			// Event
			case Source
			case Identifier
			case Name
			case Data
			case JSONData
			case Timestamp
		}
	}
}

// MARK: - SSEManager
open class SSEManager : NSObject, URLSessionDelegate  {
	
	public typealias CompletionClosure = (_ error: NSError?) -> ();
	
	public enum ConnectionState: Int {
		case idle = 0
		case connecting = 1
		case connected = 2
		case disconnecting = 3
	}
	
	// TODO: remove
	public var _connectionState = ConnectionState.idle
	public internal(set) var connectionState:ConnectionState {
		get {
			return _connectionState
		}
		set {
			NSLog("\(self) SSEKit state \(_connectionState.rawValue) -> \(newValue.rawValue)")
			_connectionState = newValue
		}
	}
	
	internal var session:URLSession? = nil
	internal var sessionTask: URLSessionDataTask? = nil
	internal var connectionURL: URL? = nil
	
	private static var instanceCount = 0  // debug!
	fileprivate var eventSources = Set<EventSource>()
	
	internal var queue =  DispatchQueue(label: "com.naim.ssekit")
	internal var connectionRetries = 0
	public var maxConnectionRetries = 3
	public var logEvents: Set<String>? = nil // log all events on empty set, no events on nil
	
	fileprivate var shouldDisconnectOnLastSource = false // TODO: just used for old EventSourceConfiguration usage
	
	private var connectCompletionClosure: CompletionClosure? = nil
    
	public override init() {
		SSEManager.instanceCount = SSEManager.instanceCount + 1
//		NSLog("SSEManager init - instances \(SSEManager.instanceCount)")
	}
	
	@available(*, deprecated, message: "EventSourceConfiguration to be removed")
	public convenience init(sources: [EventSourceConfiguration]) {
		self.init()
		for eventSourceConfig in sources {
			_ = self.addEventSource(eventSourceConfig)
		}
	}
	
	deinit {
		SSEManager.instanceCount = SSEManager.instanceCount - 1
//		NSLog("SSEManager dealloc - deinit \(SSEManager.instanceCount)")
	}
	
	/// connect to the given SSE endpoint
	///
	/// - Parameter url: url of the product probably http://<productip>:15081/notify
	open func connect(toURL url: URL, completion: CompletionClosure? = nil ) {
		self.queue.async {
			
			guard self.connectionState == .idle else {
				completion?(NSError(domain:"com.naim.ssekit", code:1, userInfo:[NSLocalizedDescriptionKey: "Already connected/connecting"]))
				return
			}
			
			self.connectCompletionClosure = completion
			
			self.connectionState = .connecting
			
			let sessionConfig = URLSessionConfiguration.default
			sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
			sessionConfig.timeoutIntervalForRequest = TimeInterval(5) // configuration
			sessionConfig.timeoutIntervalForResource = TimeInterval(INT_MAX)
			sessionConfig.httpAdditionalHeaders = ["Accept" : "text/event-stream", "Cache-Control" : "no-cache"]
			
			if self.session != nil {
				self.session!.invalidateAndCancel()
			}
			
			let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil) //This requires self be marked as @objc
			
			self.session = session
			
			self.connectionURL = url
			self.sessionTask = session.dataTask(with: url)
			
			self.sessionTask?.resume()
			
		}
	}
	
	/// disconnect the SSE connection socket
	///
	/// - Parameter completion: completion closure
	open func disconnect(completion:@escaping ()->() = {}) {
		
		self.queue.async {
			guard self.connectionState != .disconnecting && self.connectionState != .idle else {
				completion()
				return
			}
			
			self.connectionState = .disconnecting
			self.session?.invalidateAndCancel()
			self.session = nil
			
			self.sessionTask?.cancel()
			self.sessionTask = nil
			self.connectionState = .idle
			
			DispatchQueue.main.sync {
				self.eventSources.forEach({ (eventSource) in
					NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Disconnected.rawValue), object: eventSource, userInfo: [ Notification.Key.Source.rawValue : self.connectionURL!.absoluteString ])
				})
				
				NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Disconnected.rawValue), object: self, userInfo: [ Notification.Key.Source.rawValue : self.connectionURL!.absoluteString ])
			}
			
			completion()
		}
	}
    
	
	/// create a new event source given the config.
	///
	/// - Parameter eventSourceConfig: a populated EventSourceConfig instance
	/// - Returns: the new EventSource instance
	@available(*, deprecated, message: "EventSourceConfiguration to be removed, use connect and the addEventSource that takes strings")
	open func addEventSource(_ eventSourceConfig: EventSourceConfiguration) -> EventSource {
		
		self.queue.async {
			if (self.connectionState == .idle) {
				self.shouldDisconnectOnLastSource = true
				self.connect(toURL: URL(string: eventSourceConfig.uri)!)
			}
		}
		return self.addEventSource(forEvents: eventSourceConfig.events ?? [])
	}
	
	/// create a new event source that listens to the provided events
	///
	/// - Parameter events: array of event name strings, if empty array [] listen to everything
	/// - Returns: the EventSource instance
	open func addEventSource(forEvents events:[String]) -> EventSource {
		var eventSource: EventSource!
		
		eventSource = EventSource(withManager: self, events: events)
		
		self.queue.async {
			
			precondition(eventSource != nil, "Cannot be nil.")
			
			self.eventSources.insert(eventSource)
			
		}
		
		return eventSource
	}
	
	
	/// remove the event source from listening to events
	///
	/// - Parameter eventSource: the EventSource instance to remove
	/// - Parameter completion: completion closure
	open func removeEventSource(_ eventSource: EventSource, _ completion:@escaping ()->() = {}) {
	
		self.queue.async {
		
			self.eventSources.remove(eventSource)
			
			if self.shouldDisconnectOnLastSource && self.eventSources.count == 0 {
				self.disconnect() {
					DispatchQueue.main.async {
						completion()
					}
				}
			}
			else {
				DispatchQueue.main.async {
					completion()
				}
			}
			
		}
	}
	
	/// remove all the listening event sources
	///
	/// - Parameter completion: completion closure
	open func removeAllEventSources(_ completion:@escaping ()->() = {}) {
		
		self.queue.async {
			
			self.eventSources.removeAll()
			
			if self.shouldDisconnectOnLastSource {
				self.disconnect() {
					DispatchQueue.main.async {
						completion()
					}
				}
			}
			else {
				DispatchQueue.main.async {
					completion()
				}
			}
		}
	}
}


// MARK: - URLSessionDataDelegate
extension SSEManager: URLSessionDataDelegate {
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		self.queue.async {
			if let url = self.connectionURL, session == self.session {
				guard self.connectionState != .disconnecting else {
					self.connectionState = .idle
					return
				}
			
				// session ended...
				self.connectionRetries = self.connectionRetries + 1
				if (self.connectionRetries < self.maxConnectionRetries) {
					self.connectionState = .idle
					self.connect(toURL: url, completion: self.connectCompletionClosure)
				}
				else {
					DispatchQueue.main.sync {
						self.connectCompletionClosure?(error as NSError?)
						self.connectCompletionClosure = nil
					}
					self.disconnect() {
					}
				}
			}
		}
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		
		guard self.connectionState != .idle,
			self.connectionState != .disconnecting,
			session == self.session else {
			
			//Discard any data from here on in
			return
		}
		
		guard let response = dataTask.response as? HTTPURLResponse else {
			
			return //not connected yet
		}
		
		self.queue.async {
		
			if self.connectionState == .connecting {
				
//				NSLog("\(response)")
				switch response.statusCode {
					
				case 200...299:
					fallthrough
				case 300...399:
					self.connectionState = .connected
					self.connectionRetries = 0
					DispatchQueue.main.sync {
						self.eventSources.forEach({ (eventSource) in
							NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Connected.rawValue), object: eventSource, userInfo: [ Notification.Key.Source.rawValue : self.connectionURL!.absoluteString ])
						})
						self.connectCompletionClosure?(nil)
						self.connectCompletionClosure = nil
						NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Connected.rawValue), object: self, userInfo: [ Notification.Key.Source.rawValue : self.connectionURL!.absoluteString ])
					}
					break
					
				case 400...499:
					fallthrough
				default:
					self.disconnect {
					}
					return
				}
			}
			
			self.parseEventData(data)
		}
	}
	
	/// parse the event data, create Event instances, and tell all EventSources about them
	///
	/// - Parameter data: the event data received
	///
	/// TODO - this should be fileprivate - just enabling for test, put back when mocked URLSession properly
	internal func parseEventData(_ data: Data) {
		
		func scan(_ scanner: Scanner, field:String) -> (String?) {
			
			let originalLocation = scanner.scanLocation
			
			scanner.scanUpTo("\(field):", into: nil)
			
			guard scanner.scanString("\(field):", into:nil) else { // not found, reset and return nil
				scanner.scanLocation = originalLocation
				return nil
			}
			
			var value: NSString?
			scanner.scanUpTo("\n", into: &value)
			
			// get rid of any newlines
			scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: nil)
			
			return value as String?;
		}
		
		if let eventString = String(data: data, encoding: .utf8) { //NSString(bytes: data.withUnsafeBytes length: data.count, encoding: 4) {
			
			
			let scanner = Scanner(string: eventString as String)
			scanner.charactersToBeSkipped = CharacterSet.whitespaces
			
			repeat {
				
				var eventId: String?, eventName: String?, eventData: String?
				
				eventId = scan(scanner, field:"id")
				
				guard eventId !=  nil else { // finished
					NSLog("SSEKit SSE - No id!")
					return
				}
				
				let loc = scanner.scanLocation
				eventName = scan(scanner, field:"event")
				scanner.scanLocation = loc // reset, as this is optional...
			
				eventData = scan(scanner, field:"data")
				
				guard eventData != nil else { // finished
					NSLog("SSEKit SSE - No event data!")
					return
				}
				
				// SSE EVENT LOGGING
				// On if empty set, or specific event matches name
				if let logEvents = self.logEvents, logEvents.count == 0 || (eventName != nil && logEvents.contains(eventName!)) {
					NSLog("🔵 SSE EVENT:\(self.connectionURL!.host!) \(eventName ?? "nil") - \(eventData!)")
				}
				
				// Send events to all event sources
				for eventSource in self.eventSources {
					self.queue.async {
						
						if let event = Event(withEventSource: eventSource, identifier: eventId, event: eventName ?? "", data: eventData?.data(using: String.Encoding.utf8)) {
							eventSource.handleEvent(event)
						}
					}
				}
				
			} while(!scanner.isAtEnd)
		}
	}
}
