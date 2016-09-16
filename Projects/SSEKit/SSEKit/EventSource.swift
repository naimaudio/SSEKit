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
    case Connecting = 0
    case Open = 1
    case Closed = 2
}

public enum Error: ErrorType {
    
    case BadEvent
    case SourceConnectionTimeout
    case SourceNotFound(Int?) //HTTP Status code
    case Unknown
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

public class EventSource: NSObject {

    public var name: String? {
        return self.configuration.name
    }
    
    public var readyState: ReadyState = .Closed
    public var configuration: EventSourceConfiguration
    weak public var delegate: EventSourceDelegate?
    
    public required init(configuration: EventSourceConfiguration, delegate: EventSourceDelegate) {
        
        self.configuration = configuration //copy
        self.delegate = delegate
    }
	
	deinit {
		print("am i destroyed ever?")
	}
	
	public func disconnect() {
		// don't do anything - virtual?
	}
}

public struct Event: CustomDebugStringConvertible {
    
    struct Metadata {
        
        let timestamp: NSDate
        let hostUri: String
    }
    
    let metadata: Metadata
    let configuration: EventSourceConfiguration
    
    let identifier: String?
    let event: String?
    let data: NSData?
    
    init?(withEventSource eventSource: EventSource, identifier: String?, event: String?, data: NSData?) {
        
        guard identifier != nil else {
            
            return nil
        }
        
        configuration = eventSource.configuration
        self.metadata = Metadata(timestamp: NSDate(), hostUri: configuration.uri)
        
        self.identifier = identifier
        self.event = event
        self.data = data
    }
    
    public var debugDescription: String {
        
        return "Event {\(self.identifier != nil ? self.identifier! : "nil"), \(self.event != nil ? self.event! : "nil"), Data length: \(self.data != nil ? self.data!.length : 0)}"
    }
}

@objc
public final class PrimaryEventSource: EventSource, EventSourceConnectable {
    
    private var task: NSURLSessionDataTask?
    private var children = Set<ChildEventSource>()
    private var retries = 0
    private let maxRetries = 3
    
    internal func add(child child: ChildEventSource) {
        
        dispatch_sync(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            self.children.insert(child)
        }
    }
    
    internal func remove(child child: ChildEventSource) {
        
        dispatch_sync(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            self.children.remove(child)
        }
    }
    
    public func connect() {
        
        self.readyState = .Connecting
        
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfig.requestCachePolicy = .ReloadIgnoringLocalCacheData
        sessionConfig.timeoutIntervalForRequest = NSTimeInterval(INT_MAX)
        sessionConfig.timeoutIntervalForResource = NSTimeInterval(INT_MAX)
        sessionConfig.HTTPAdditionalHeaders = ["Accept" : "text/event-stream", "Cache-Control" : "no-cache"]
        
        let session = NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil) //This requires self be marked as @objc
        
        //???: We might need this task\\?
        
        let urlComponents = NSURLComponents()
        urlComponents.host = self.configuration.hostAddress
        urlComponents.path = self.configuration.endpoint
        urlComponents.port = self.configuration.port
        urlComponents.scheme = "http" //FIXME: This should be settable in config
        
        if let url = urlComponents.URL {
            
            //print("URL: \(url)")
            
            self.task = session.dataTaskWithURL(url)
            self.task?.resume()
        }
        else {
            //error
        }
    }
    
    public override func disconnect() {
        
        guard let t = self.task where t.state != .Canceling else {
            return
        }
        
        self.task?.cancel()
        self.task = nil
        self.readyState = .Closed

        if self.retries < self.maxRetries {
            self.retries++
            
            self.connect()
        } else {
            delegate?.eventSourceWillDisconnect(self)

            delegate?.eventSourceDidDisconnect(self)
        }
    }
}

extension PrimaryEventSource: NSURLSessionDataDelegate {
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        
        disconnect()
    }
    
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        
        guard self.readyState != .Closed else {
            
            //Discard any data from here on in
            return
        }
        
        guard let responce = dataTask.response as? NSHTTPURLResponse else {
            
            return //not connected yet
        }
        
        if self.readyState == .Connecting {
            
            switch responce.statusCode {
                
            case 200...299:
                fallthrough
            case 300...399:
                self.delegate?.eventSourceDidConnect(self)
                self.readyState = .Open
                self.retries = 0
                break
                
            case 400...499:
                fallthrough
            default:
                self.delegate?.eventSource(self, didEncounterError: .SourceNotFound(responce.statusCode))
                disconnect()
                return
            }
        }
        
        inline_URLSession(session, dataTask: dataTask, didReceiveData: data)
    }
    
    public func inline_URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        
        func extractValue(scanner: NSScanner) -> (String?, String?) {
            
            var field: NSString?
            scanner.scanUpToString(":", intoString: &field)
            scanner.scanString(":", intoString: nil)
            
            var value: NSString?
            scanner.scanUpToString("\n", intoString: &value)
            
            return (field?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()), value?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
        }
        
        data.enumerateByteRangesUsingBlock { (pointer, range, stop) in
            
            if let eventString = NSString(bytes: pointer, length: range.length, encoding: 4) {
                
                let scanner = NSScanner(string: eventString as String)
                scanner.charactersToBeSkipped = NSCharacterSet.whitespaceCharacterSet()
                
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
                    
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                        
                        if let event = Event(withEventSource: self, identifier: eventId, event: eventName, data: eventData?.dataUsingEncoding(NSUTF8StringEncoding)) {
                            child.eventSource(self, didReceiveEvent: event)
                        }
                    }
                }
                
                // Don't create events if nobody is listerning
                if let evnArray = self.configuration.events, let evn = eventName where evnArray.contains(evn) {
                    
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                        
                        if let event = Event(withEventSource: self, identifier: eventId, event: evn, data: eventData?.dataUsingEncoding(NSUTF8StringEncoding)) {
                            self.delegate?.eventSource(self, didReceiveEvent: event)
                        }
                    }
                }
                else if self.configuration.events == nil {
                    
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                        
                        if let event = Event(withEventSource: self, identifier: eventId, event: eventName, data: eventData?.dataUsingEncoding(NSUTF8StringEncoding)) {
                            self.delegate?.eventSource(self, didReceiveEvent: event)
                        }
                    }
                }
            }
        }
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
        self.readyState = .Closed
        delegate?.eventSourceDidDisconnect(self)
    }
}

extension ChildEventSource: EventSourceDelegate {
    
    public func eventSource(eventSource: EventSource, didChangeState state: ReadyState) { /* Ignore */ }
    
    public func eventSourceDidConnect(eventSource: EventSource) { /* Ignore */ }
    
    public func eventSourceWillDisconnect(eventSource: EventSource) { /* Ignore */ }
    
    public func eventSourceDidDisconnect(eventSource: EventSource) {
        self.disconnect()
    }
    
    public func eventSource(eventSource: EventSource, didReceiveEvent event: Event) {
    
        if let evnArray = self.configuration.events, let evn = event.event where evnArray.contains(evn) {
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                
                if let event = Event(withEventSource: self, identifier: event.identifier, event: event.event, data: event.data) {
                    self.delegate?.eventSource(self, didReceiveEvent: event)
                }
            }
        }
        else if self.configuration.events == nil {
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                
                if let event = Event(withEventSource: self, identifier: event.identifier, event: event.event, data: event.data) {
                    self.delegate?.eventSource(self, didReceiveEvent: event)
                }
            }
        }
    }
    
    public func eventSource(eventSource: EventSource, didEncounterError error: Error) { /* Ignore */ }
}

public protocol EventSourceDelegate: class {
    
    func eventSource(eventSource: EventSource, didChangeState state: ReadyState)
    
    func eventSourceDidConnect(eventSource: EventSource)
    func eventSourceWillDisconnect(eventSource: EventSource)
    func eventSourceDidDisconnect(eventSource: EventSource)
    
    func eventSource(eventSource: EventSource, didReceiveEvent event: Event)
    func eventSource(eventSource: EventSource, didEncounterError error: Error)
}
