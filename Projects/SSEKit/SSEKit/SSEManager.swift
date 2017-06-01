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
    private static var instanceCount = 0  // debug!
	
    fileprivate var primaryEventSource: PrimaryEventSource?
    fileprivate var eventSources = Set<EventSource>()
	
	fileprivate var queue =  DispatchQueue(label: "com.naim.ssekit")
    
    public init(sources: [EventSourceConfiguration]) {
        
        for config in sources {
            _ = addEventSource(config)
        }
		SSEManager.instanceCount = SSEManager.instanceCount + 1
		NSLog("SSEManager init - instances \(SSEManager.instanceCount)")
    }
	
	deinit {
		self.primaryEventSource = nil
		SSEManager.instanceCount = SSEManager.instanceCount - 1
		NSLog("SSEManager dealloc - deinit \(SSEManager.instanceCount)")
	}
    
    /**
     Add an EventSource to the manager.
     */
    open func addEventSource(_ eventSourceConfig: EventSourceConfiguration) -> EventSource {
        
        var eventSource: EventSource!
		
		_ = self.queue.sync { // must be sync, need to check there is a primary source
			
            if self.primaryEventSource == nil {
                eventSource = PrimaryEventSource(configuration: eventSourceConfig, delegate: self, queue: self.queue)
                self.primaryEventSource = eventSource as? PrimaryEventSource
            }
            else {
				eventSource = ChildEventSource(withConfiguration: eventSourceConfig, primaryEventSource: self.primaryEventSource!, delegate: self, queue:self.queue)
            }
        }
		
        precondition(eventSource != nil, "Cannot be nil.")
        
		_ = self.queue.async {
            self.eventSources.insert(eventSource)
        }
		
		
        eventSource?.connect()
        
        return eventSource
    }
	
	public func reconnect() {
		if (self.primaryEventSource?.readyState != .open && self.primaryEventSource?.readyState != .connecting) {
			self.primaryEventSource?.connect()
			for eventSource in self.eventSources {
				if (eventSource != self.primaryEventSource) {
					eventSource.connect()
				}
			}
		}
	}
	
    /**
     Disconnect and remove EventSource from manager.
     */
    open func removeEventSource(_ eventSource: EventSource, _ completion:@escaping ()->() = {}) {
		        
        eventSource.disconnect(allowRetry: false)

        
        self.queue.async {
			if (eventSource == self.primaryEventSource) {
				self.primaryEventSource	= nil
			}
            self.eventSources.remove(eventSource)
			
			DispatchQueue.main.async {
				
				completion()
			}
        }
    }
	
	open func removeAllEventSources(_ completion:@escaping ()->()) {
		
		self.queue.async {
			if self.eventSources.count > 0 { // recurse until no more
				self.removeEventSource(self.eventSources.first!, {
					self.removeAllEventSources {
						completion() // already on main
					}
				})
			}
			else {
				DispatchQueue.main.async {
					completion()
				}
			}
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
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Connected.rawValue), object: eventSource, userInfo: [ Notification.Key.Source.rawValue : eventSource.configuration.uri ])
		}
    }
    
    public func eventSourceWillDisconnect(_ eventSource: EventSource) {}
    
    public func eventSourceDidDisconnect(_ eventSource: EventSource) {
        
        //Remove disconnected EventSource objects from the array
//        self.queue.async {
            //TODO
//            if let esIndex = self.eventSources.indexOf(eventSource) {
//                self.eventSources.removeAtIndex(esIndex)
//            }
//        }
        DispatchQueue.main.async {
			NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Disconnected.rawValue), object: eventSource, userInfo: [ Notification.Key.Source.rawValue : eventSource.configuration.uri ])
		}
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
		
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: Notification.Event.rawValue), object: eventSource, userInfo: userInfo)
		}
    }
    
    public func eventSource(_ eventSource: EventSource, didEncounterError error: EventSourceError) {
        
        //TODO: Send error notification
        //print("Error -> \(eventSource) -> \(error)")
    }
}
