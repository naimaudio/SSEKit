//
//  EventSource.swift
//  SSEKit
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Naim Audio All rights reserved.
//

import Foundation


open class EventSource: NSObject {
	weak internal var manager: SSEManager?
	
	open var events: [String] = []
	
	public required init (withManager manager: SSEManager, events: [String]) {
		self.manager = manager
		self.events = events
	}
	
	
	internal func handleEvent(_ event: Event) {
		if self.events.count == 0 || self.events.contains(event.event!) == true  {
			
			var userInfo: [String: AnyObject] = [SSEManager.Notification.Key.Source.rawValue : self.manager!.connectionURL!.absoluteString as AnyObject, SSEManager.Notification.Key.Timestamp.rawValue : event.metadata.timestamp as AnyObject]
			
			if let identifier = event.identifier {
				userInfo[SSEManager.Notification.Key.Identifier.rawValue] = identifier as AnyObject
			}
			
			if let name = event.event {
				userInfo[SSEManager.Notification.Key.Name.rawValue] = name as AnyObject
			}
			
			if let data = event.data {
				userInfo[SSEManager.Notification.Key.Data.rawValue] = data as AnyObject
			}
			
			if let jsonData = event.jsonData {
				userInfo[SSEManager.Notification.Key.JSONData.rawValue] = jsonData as AnyObject
			}
			
			DispatchQueue.main.async {
				NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: SSEManager.Notification.Event.rawValue), object: self, userInfo: userInfo)
			}
		}
	}
	
	public func disconnect() {
		self.manager?.removeEventSource(self)
	}
	
	deinit {
		
	}
}

public struct Event: CustomDebugStringConvertible {
    
	struct Metadata {
        
		let timestamp: Date
		let hostUri: String
	}
    
	let metadata: Metadata
    
	let identifier: String?
	let event: String?
	let data: Data?
	let jsonData: Dictionary<String, AnyObject>?
    
	init?(withEventSource eventSource: EventSource, identifier: String?, event: String?, data: Data?) {
        
		guard identifier != nil else {
            
			return nil
		}
		
		self.metadata = Metadata(timestamp: Date(), hostUri: eventSource.manager!.connectionURL!.absoluteString)
        
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
