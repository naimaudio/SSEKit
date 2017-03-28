//
//  SSEManager.swift
//  SSEKit
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Richard Stelling All rights reserved.
//

import Foundation

// MARK: Notifications
public extension SSEManager {
    
    public enum Notification: String {
        
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
open class SSEManager {
    
    fileprivate var primaryEventSource: PrimaryEventSource?
    fileprivate var eventSources = Set<EventSource>()
    
    public init(sources: [EventSourceConfiguration]) {
        
        for config in sources {
            _ = addEventSource(config)
        }
    }
    
    /**
     Add an EventSource to the manager.
     */
    open func addEventSource(_ eventSourceConfig: EventSourceConfiguration) -> EventSource {
        
        var eventSource: EventSource!
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).sync {
            
            if self.primaryEventSource == nil {
                eventSource = PrimaryEventSource(configuration: eventSourceConfig, delegate: self)
                self.primaryEventSource = eventSource as? PrimaryEventSource
            }
            else {
                eventSource = ChildEventSource(withConfiguration: eventSourceConfig, primaryEventSource: self.primaryEventSource!, delegate: self)
            }
        }
        
        precondition(eventSource != nil, "Cannot be nil.")
        
        _ = DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).sync {
            self.eventSources.insert(eventSource)
        }
        
        // Cast `eventSource` to `EventSourceConnectable` and connect
        (eventSource as? EventSourceConnectable)?.connect()
        
        return eventSource
    }
	
	public func reconnect() {
		if (self.primaryEventSource?.readyState != .Open && self.primaryEventSource?.readyState != .Connecting) {
			self.primaryEventSource?.connect()
			for eventSource in self.eventSources {
				(eventSource as? EventSourceConnectable)?.connect()
			}
		}
	}
	
    /**
     Disconnect and remove EventSource from manager.
     */
    open func removeEventSource(_ eventSource: EventSource) {
        
        //TODO: Clean up - this is how clients disconnect the source.
        
        eventSource.disconnect()

        //TODO
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).sync {
			if (eventSource == self.primaryEventSource) {
				self.primaryEventSource	= nil
			}
            self.eventSources.remove(eventSource)
			
        }
    }
}

// MARK: - EventSourceDelegate
extension SSEManager: EventSourceDelegate {
    
    public func eventSource(_ eventSource: EventSource, didChangeState state: ReadyState) {
        
        //TODO: Logging
        print("State -> \(eventSource) -> \(state)")
    }
    
    public func eventSourceDidConnect(_ eventSource: EventSource) {
        
        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Connected.rawValue), object: eventSource, userInfo: [ Notification.Key.Source.rawValue : eventSource.configuration.uri ])
    }
    
    public func eventSourceWillDisconnect(_ eventSource: EventSource) {}
    
    public func eventSourceDidDisconnect(_ eventSource: EventSource) {
        
        //Remove disconnected EventSource objects from the array
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).sync {
            //TODO
//            if let esIndex = self.eventSources.indexOf(eventSource) {
//                self.eventSources.removeAtIndex(esIndex)
//            }
        }
        
        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Disconnected.rawValue), object: eventSource, userInfo: [ Notification.Key.Source.rawValue : eventSource.configuration.uri ])
    }
    
    public func eventSource(_ eventSource: EventSource, didReceiveEvent event: Event) {
        
        //print("[ES#: \(eventSources.count)] \(eventSource) -> \(event)")
        
        var userInfo: [String: AnyObject] = [Notification.Key.Source.rawValue : eventSource.configuration.uri as AnyObject, Notification.Key.Timestamp.rawValue : event.metadata.timestamp as AnyObject]
        
        if let identifier = event.identifier {
            userInfo[Notification.Key.Identifier.rawValue] = identifier as AnyObject
        }
        
        if let name = event.event {
            userInfo[Notification.Key.Name.rawValue] = name as AnyObject
        }
        
        if let data = event.data {
            userInfo[Notification.Key.Data.rawValue] = data as AnyObject
        }
		
		if let jsonData = event.jsonData {
			userInfo[Notification.Key.JSONData.rawValue] = jsonData as AnyObject
		}
		
        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Event.rawValue), object: eventSource, userInfo: userInfo)
    }
    
    public func eventSource(_ eventSource: EventSource, didEncounterError error: EventSourceError) {
        
        //TODO: Send error notification
        //print("Error -> \(eventSource) -> \(error)")
    }
}
