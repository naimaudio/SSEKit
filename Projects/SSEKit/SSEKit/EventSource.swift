//
//  EventSource.swift
//  SSEKit
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Richard Stelling All rights reserved.
//

import Foundation

// TODO: Split out into multiple files

public enum ReadyState: Int {
    case connecting = 0
    case open = 1
    case closed = 2
}

public enum EventSourceError: Error {
    
    case badEvent
    case sourceConnectionTimeout
    case sourceNotFound(Int?) //HTTP Status code
    case unknown
}

open class EventSource: NSObject {
	
	internal var queue:DispatchQueue
	
    open var name: String? {
        return self.configuration.name
    }
    
    open var readyState: ReadyState = .closed
    open var configuration: EventSourceConfiguration
    weak open var delegate: EventSourceDelegate?
    
    public required init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate, queue:DispatchQueue) {
        self.queue = queue
        self.configuration = configuration //copy
        self.delegate = delegate
    }
	
	deinit {
		
	}
	
	open func connect() {
		// virtual
	}
	
	open func disconnect(allowRetry:Bool = true) {
		// don't do anything - virtual?
	}
}

public struct Event: CustomDebugStringConvertible {
    
    struct Metadata {
        
        let timestamp: Date
        let hostUri: String
    }
    
    let metadata: Metadata
    let configuration: EventSourceConfiguration
    
    let identifier: String?
    let event: String?
    let data: Data?
	let jsonData: Dictionary<String, AnyObject>?
    
    init?(withEventSource eventSource: EventSource, identifier: String?, event: String?, data: Data?) {
        
        guard identifier != nil else {
            
            return nil
        }
        
        configuration = eventSource.configuration
        self.metadata = Metadata(timestamp: Date(), hostUri: configuration.uri)
        
        self.identifier = identifier
        self.event = event
        self.data = data
		if (data != nil) {
			let jsonData = try? JSONSerialization.jsonObject(with: data!, options:[])
			self.jsonData = jsonData as? Dictionary<String, AnyObject>
		}
		else {
			self.jsonData = nil;
		}
    }
    
    public var debugDescription: String {
        
        return "Event {\(self.identifier != nil ? self.identifier! : "nil"), \(self.event != nil ? self.event! : "nil"), Data length: \(self.data != nil ? self.data!.count : 0)}"
    }
}

@objc
public final class PrimaryEventSource: EventSource {
    
    fileprivate var task: URLSessionDataTask?
    fileprivate var children = Set<ChildEventSource>()
    fileprivate var retries = 0
    fileprivate let maxRetries = 3
	var session:URLSession?
    
    internal func add(child: ChildEventSource) {
		
        _ = self.queue.async {
            self.children.insert(child)
        }
    }
    
    internal func remove(child: ChildEventSource) {
        
        _ = self.queue.async {
            self.children.remove(child)
        }
    }
    
    public override func connect() {
        _ = self.queue.async {
			self.readyState = .connecting
			
			let sessionConfig = URLSessionConfiguration.default
			sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
			sessionConfig.timeoutIntervalForRequest = TimeInterval(5)
			sessionConfig.timeoutIntervalForResource = TimeInterval(INT_MAX)
			sessionConfig.httpAdditionalHeaders = ["Accept" : "text/event-stream", "Cache-Control" : "no-cache"]
			
			if self.session != nil {
				self.session!.invalidateAndCancel()
			}
			
			let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil) //This requires self be marked as @objc
			
			self.session = session
			
			var urlComponents = URLComponents()
			urlComponents.host = self.configuration.hostAddress
			urlComponents.path = self.configuration.endpoint
			urlComponents.port = self.configuration.port
			urlComponents.scheme = "http" //FIXME: This should be settable in config
			
			if let url = urlComponents.url {
				
				//print("URL: \(url)")
				
				self.task = session.dataTask(with: url)
				self.task?.resume()
			}
			else {
				//error
			}
		}
    }
    
	public override func disconnect(allowRetry:Bool = true) {
		_ = self.queue.async {
			self.session?.invalidateAndCancel()
			self.session = nil
			
			guard let t = self.task, t.state != .canceling else {
				return
			}
			
			self.task?.cancel()
			self.task = nil
			self.readyState = .closed

			if allowRetry &&  self.retries < self.maxRetries {
				self.retries = self.retries + 1
				self.connect()
			} else {
				self.delegate?.eventSourceWillDisconnect(self)

				self.delegate?.eventSourceDidDisconnect(self)
				
				for child in self.children {
					child.delegate?.eventSourceWillDisconnect(child)
					
					child.delegate?.eventSourceDidDisconnect(child)
				}
			}
		}
	}
}

extension PrimaryEventSource: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        disconnect()
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        guard self.readyState != .closed else {
            
            //Discard any data from here on in
            return
        }
        
        guard let response = dataTask.response as? HTTPURLResponse else {
            
            return //not connected yet
        }
        
        if self.readyState == .connecting {
            
            switch response.statusCode {
                
            case 200...299:
                fallthrough
            case 300...399:
                self.delegate?.eventSourceDidConnect(self)
                self.readyState = .open
                self.retries = 0
                break
                
            case 400...499:
                fallthrough
            default:
                self.delegate?.eventSource(self, didEncounterError: .sourceNotFound(response.statusCode))
                disconnect()
                return
            }
        }
        
        inline_URLSession(session, dataTask: dataTask, didReceiveData: data)
    }
    
    public func inline_URLSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, didReceiveData data: Data) {
		
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
				
				// is this actually optional?
//				guard eventName !=  nil else { // finished
//					NSLog("SSEKit SSE - No event name!")
//					return
//				}
				
				eventData = scan(scanner, field:"data")
				
				guard eventData != nil else { // finished
					NSLog("SSEKit SSE - No event data!")
					return
				}
				
				
				
				// Send all events to children
				for child in self.children {
					self.queue.async {
						
						if let event = Event(withEventSource: child, identifier: eventId, event: eventName, data: eventData?.data(using: String.Encoding.utf8)) {
							child.eventSource(self, didReceiveEvent: event)
						}
					}
				}
				
				// Don't create events if nobody is listerning
				if let evnArray = self.configuration.events, let evn = eventName, evnArray.contains(evn) {
					
					self.queue.async {
						
						if let event = Event(withEventSource: self, identifier: eventId, event: evn, data: eventData?.data(using: String.Encoding.utf8)) {
							self.delegate?.eventSource(self, didReceiveEvent: event)
						}
					}
				}
				else if self.configuration.events == nil {
					
					self.queue.async {
						
						if let event = Event(withEventSource: self, identifier: eventId, event: eventName, data: eventData?.data(using: String.Encoding.utf8)) {
							self.delegate?.eventSource(self, didReceiveEvent: event)
						}
					}
				}
				
			} while(!scanner.isAtEnd)
		}
    }
}

@objc
public final class ChildEventSource: EventSource {
    
    weak public var primaryEventSource: PrimaryEventSource?
	public required init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate, queue:DispatchQueue) {
		
		super.init(configuration: configuration, delegate: delegate, queue:queue)
    }
    
    internal convenience init(withConfiguration config: EventSourceConfiguration, primaryEventSource: PrimaryEventSource, delegate: EventSourceDelegate, queue:DispatchQueue) {
        self.init(configuration: config, delegate: delegate, queue:queue)
        self.primaryEventSource = primaryEventSource
    }
	
	public required init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate) {
		fatalError("init(configuration:delegate:) has not been implemented")
	}
	
    public override func connect() {
        
        // TODO: Return an error if there is a probelm with `primaryEventSource`
        
        //print("CHILD CONNECTED")
        self.primaryEventSource?.add(child: self)
        self.delegate?.eventSourceDidConnect(self)
    }
    
    public override func disconnect(allowRetry:Bool = true) {
        
        delegate?.eventSourceWillDisconnect(self)
        self.readyState = .closed
        delegate?.eventSourceDidDisconnect(self)
    }
}

extension ChildEventSource: EventSourceDelegate {
    
    public func eventSource(_ eventSource: EventSource, didChangeState state: ReadyState) { /* Ignore */ }
    
    public func eventSourceDidConnect(_ eventSource: EventSource) { /* Ignore */ }
    
    public func eventSourceWillDisconnect(_ eventSource: EventSource) { /* Ignore */ }
    
    public func eventSourceDidDisconnect(_ eventSource: EventSource) {
        self.disconnect()
    }
    
    public func eventSource(_ eventSource: EventSource, didReceiveEvent event: Event) {
    
        if let evnArray = self.configuration.events, let evn = event.event, evnArray.contains(evn) {
            
            self.queue.async {
                
                if let event = Event(withEventSource: self, identifier: event.identifier, event: event.event, data: event.data) {
                    self.delegate?.eventSource(self, didReceiveEvent: event)
                }
            }
        }
        else if self.configuration.events == nil {
            
            self.queue.async {
                
                if let event = Event(withEventSource: self, identifier: event.identifier, event: event.event, data: event.data) {
                    self.delegate?.eventSource(self, didReceiveEvent: event)
                }
            }
        }
    }
    
    public func eventSource(_ eventSource: EventSource, didEncounterError error: EventSourceError) { /* Ignore */ }
}

public protocol EventSourceDelegate: class {
    
    func eventSource(_ eventSource: EventSource, didChangeState state: ReadyState)
    
    func eventSourceDidConnect(_ eventSource: EventSource)
    func eventSourceWillDisconnect(_ eventSource: EventSource)
    func eventSourceDidDisconnect(_ eventSource: EventSource)
    
    func eventSource(_ eventSource: EventSource, didReceiveEvent event: Event)
    func eventSource(_ eventSource: EventSource, didEncounterError error: EventSourceError)
}
