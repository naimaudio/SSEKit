//
//  EventSourceConfiguration.swift
//  SSEKit
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Richard Stelling All rights reserved.
//

import Foundation

public struct EventSourceConfiguration {
    
    internal let name: String?
    
    internal let hostAddress: String
    internal let port: Int
    internal let endpoint: String
    
    internal let timeout: NSTimeInterval
    
    internal let events: [String]?
    
    internal var uri: String {
        return "\(self.hostAddress):\(self.port)\(self.endpoint)"
    }
    
    //options?
    
    public init(withHost host: String, port: Int = 80, endpoint: String, timeout: NSTimeInterval = 5, events: [String]? = nil, name: String? = nil) {
        
        precondition(endpoint.characters.first == "/", "Endpoint does not begin with a /")
        
        self.hostAddress = host
        self.port = port
        self.endpoint = endpoint
        self.timeout = timeout
        
        self.events = events
        
        self.name = name
    }
}
