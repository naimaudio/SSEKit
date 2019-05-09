//
//  EventSourceConfiguration.swift
//  SSEKit
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Naim Audio All rights reserved.
//

import Foundation

// TODO: delete this file!
// leaving in for now in case we want to patch 5.13

public struct EventSourceConfiguration {
    
	internal let name: String?
    
	internal let hostAddress: String
	internal let port: Int
	internal let endpoint: String
    
	internal let timeout: TimeInterval
    
	internal let events: [String]?
    
	internal var uri: String {
		return "http:\(self.hostAddress):\(self.port)\(self.endpoint)"
	}
    
	//options?
    
	public init(withHost host: String, port: Int = 80, endpoint: String, timeout: TimeInterval = 5, events: [String]? = nil, name: String? = nil) {
        
		precondition(endpoint.first == "/", "Endpoint does not begin with a /")
        
		self.hostAddress = host
		self.port = port
		self.endpoint = endpoint
		self.timeout = timeout
        
		self.events = events
        
		self.name = name
	}
}
