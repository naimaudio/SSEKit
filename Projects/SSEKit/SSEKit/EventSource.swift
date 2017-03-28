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

//public protocol EventSourceConformist {
//    
//    var readyState: ReadyState { get }
//    var configuration: EventSourceConfiguration { get set }
//    weak var delegate: EventSourceDelegate { get set }
//    
//    init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate)
//}

public protocol EventSourceConnectable {
    
    func connect()
    func disconnect()
}

open class EventSource: NSObject {

    open var name: String? {
        return self.configuration.name
    }
    
    open var readyState: ReadyState = .closed
    open var configuration: EventSourceConfiguration
    weak open var delegate: EventSourceDelegate?
    
    public required init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate) {
        
        self.configuration = configuration //copy
        self.delegate = delegate
    }
	
	deinit {
		
	}
	
	open func disconnect() {
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
public final class PrimaryEventSource: EventSource, EventSourceConnectable {
    
    fileprivate var task: URLSessionDataTask?
    fileprivate var children = Set<ChildEventSource>()
    fileprivate var retries = 0
    fileprivate let maxRetries = 3
    
    internal func add(child: ChildEventSource) {
        
        _ = DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).sync {
            self.children.insert(child)
        }
    }
    
    internal func remove(child: ChildEventSource) {
        
        _ = DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).sync {
            self.children.remove(child)
        }
    }
    
    public func connect() {
        
        self.readyState = .connecting
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.timeoutIntervalForRequest = TimeInterval(5)
        sessionConfig.timeoutIntervalForResource = TimeInterval(INT_MAX)
        sessionConfig.httpAdditionalHeaders = ["Accept" : "text/event-stream", "Cache-Control" : "no-cache"]
        
        let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil) //This requires self be marked as @objc
        
        //???: We might need this task\\?
        
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
    
    public override func disconnect() {
        
        guard let t = self.task, t.state != .canceling else {
            return
        }
        
        self.task?.cancel()
        self.task = nil
        self.readyState = .closed

        if self.retries < self.maxRetries {
            self.retries = self.retries + 1
            
            self.connect()
        } else {
            delegate?.eventSourceWillDisconnect(self)

            delegate?.eventSourceDidDisconnect(self)
            
            for child in self.children {
                child.delegate?.eventSourceWillDisconnect(child)
                
                child.delegate?.eventSourceDidDisconnect(child)
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
        
        guard let responce = dataTask.response as? HTTPURLResponse else {
            
            return //not connected yet
        }
        
        if self.readyState == .connecting {
            
            switch responce.statusCode {
                
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
                self.delegate?.eventSource(self, didEncounterError: .sourceNotFound(responce.statusCode))
                disconnect()
                return
            }
        }
        
        inline_URLSession(session, dataTask: dataTask, didReceiveData: data)
    }
    
    public func inline_URLSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, didReceiveData data: Data) {
        
        func extractValue(_ scanner: Scanner) -> (String?, String?) {
            
            var field: NSString?
            scanner.scanUpTo(":", into: &field)
            scanner.scanString(":", into: nil)
            
            var value: NSString?
            scanner.scanUpTo("\n", into: &value)
            
            return (field?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }
        
        //data.enumerateBytes { (pointer, range, stop) in
        
        //data.withUnsafeByte
        //let str: String? =
        if let eventString = String(data: data, encoding: .utf8) { //NSString(bytes: data.withUnsafeBytes length: data.count, encoding: 4) {
                
                let scanner = Scanner(string: eventString as String)
                scanner.charactersToBeSkipped = CharacterSet.whitespaces
                
                var eventId: String?, eventName: String?, eventData: String?
                var stop = false
                
                repeat {
                    
                    let entity = extractValue(scanner)
                    
                    if entity.0 == nil && entity.1 ==  nil {
                        stop = true
                    }
                    else if entity.0 == "id" {
                        eventId = entity.1
                    }
                    else if entity.0 == "event" {
                        eventName = entity.1
                    }
                    else if entity.0 == "data" {
                        eventData = entity.1
                    }
                    
                } while(!stop)
                
                // Send all events to children
                for child in self.children {
                    
                    DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                        
                        if let event = Event(withEventSource: self, identifier: eventId, event: eventName, data: eventData?.data(using: String.Encoding.utf8)) {
                            child.eventSource(self, didReceiveEvent: event)
                        }
                    }
                }
                
                // Don't create events if nobody is listerning
                if let evnArray = self.configuration.events, let evn = eventName, evnArray.contains(evn) {
                    
                    DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                        
                        if let event = Event(withEventSource: self, identifier: eventId, event: evn, data: eventData?.data(using: String.Encoding.utf8)) {
                            self.delegate?.eventSource(self, didReceiveEvent: event)
                        }
                    }
                }
                else if self.configuration.events == nil {
                    
                    DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                        
                        if let event = Event(withEventSource: self, identifier: eventId, event: eventName, data: eventData?.data(using: String.Encoding.utf8)) {
                            self.delegate?.eventSource(self, didReceiveEvent: event)
                        }
                    }
                }
            }
        //}
    }
}

@objc
public final class ChildEventSource: EventSource, EventSourceConnectable {
    
    weak public var primaryEventSource: PrimaryEventSource?
    
    public required init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate) {
        super.init(configuration: configuration, delegate: delegate)
    }
    
    internal convenience init(withConfiguration config: EventSourceConfiguration, primaryEventSource: PrimaryEventSource, delegate: EventSourceDelegate) {
        self.init(configuration: config, delegate: delegate)
        self.primaryEventSource = primaryEventSource
    }
    
    public func connect() {
        
        // TODO: Return an error if there is a probelm with `primaryEventSource`
        
        //print("CHILD CONNECTED")
        self.primaryEventSource?.add(child: self)
        self.delegate?.eventSourceDidConnect(self)
    }
    
    public override func disconnect() {
        
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
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                
                if let event = Event(withEventSource: self, identifier: event.identifier, event: event.event, data: event.data) {
                    self.delegate?.eventSource(self, didReceiveEvent: event)
                }
            }
        }
        else if self.configuration.events == nil {
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                
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
