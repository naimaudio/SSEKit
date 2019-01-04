//
//  ViewController.swift
//  SSEKitExample
//
//  Created by Richard Stelling on 23/02/2016.
//  Copyright © 2016 Richard Stelling All rights reserved.
//

import UIKit
import SSEKit

class ViewController: UIViewController {

	var manager: SSEManager?
    
	@IBOutlet weak internal var logViewer: UITextView!
    
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
        
		NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) {
            
			//SSEManager.Notification.Key.Name.rawValue
            
			guard   let name = $0.userInfo?[SSEManager.Notification.Key.Name.rawValue],
			        let data = $0.userInfo?[SSEManager.Notification.Key.Data.rawValue] as? Data,
			        let identifier = $0.userInfo?[SSEManager.Notification.Key.Identifier.rawValue] as? String,
			        let timestamp = $0.userInfo?[SSEManager.Notification.Key.Timestamp.rawValue] as? Date
			else {
            
				return
			}
            
			let dataStr = String(data: data, encoding: String.Encoding(rawValue: 4))!
            
			print("\(timestamp): [\(identifier)] \(name) -> \(dataStr)")
		}
        
        
		//let config = EventSourceConfiguration(withHost: "192.168.37.123", port: 15081, endpoint: "/notify", timeout: 10, events: nil)
		//let config2 = EventSourceConfiguration(withHost: "192.168.37.123", port: 15081, endpoint: "/notify", events: ["nowplaying"])
		//let config4 = EventSourceConfiguration(withHost: "192.168.37.76", port: 8080, endpoint: "/sse", events: ["bad-event"])
        
		//let config2 = EventSourceConfiguration(withHost: "localhost", port: 8080, endpoint: "/sse2")
		//let config3 = EventSourceConfiguration(withHost: "localhost", port: 8081, endpoint: "/sse")

		manager = SSEManager(sources: [])
        
/*        for i in 0...10 {
        
            let config = EventSourceConfiguration(withHost: "192.168.37.123", port: 15081, endpoint: "/notify", timeout: 10, events: nil)
            let es = manager?.addEventSource(config)
            es?.name = ["0️⃣","1️⃣","2️⃣","3️⃣","4️⃣","5️⃣","6️⃣","7️⃣","8️⃣","9️⃣","🔟","1️⃣1️⃣","1️⃣2️⃣","1️⃣2️⃣","1️⃣3️⃣","1️⃣4️⃣","1️⃣5️⃣","1️⃣6️⃣","1️⃣7️⃣","1️⃣8️⃣","1️⃣9️⃣","2️⃣0️⃣"][i]
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onEvent(_:)), name: SSEManager.Notification.Event.rawValue, object: es)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onConnected(_:)), name: SSEManager.Notification.Connected.rawValue, object: es)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onDisconnected(_:)), name: SSEManager.Notification.Disconnected.rawValue, object: es)
        }
*/
        
        let configNowPlaying = EventSourceConfiguration(withHost: "192.168.103.90", port: 15081, endpoint: "/notify", timeout: 10, events: ["lists", "inputs", "albums"], name: "📢")
        let npEs = manager?.addEventSource(configNowPlaying)
        NotificationCenter.default.addObserver(self, selector: #selector(onEvent(_:)), name: NSNotification.Name(rawValue: SSEManager.Notification.Event.rawValue), object: npEs)
        
        let configInput = EventSourceConfiguration(withHost: "192.168.103.79", port: 15081, endpoint: "/notify", timeout: 10, events: ["nowplaying"], name: "🎙")
        let inptEs = manager?.addEventSource(configInput)
        NotificationCenter.default.addObserver(self, selector: #selector(onEvent(_:)), name: NSNotification.Name(rawValue: SSEManager.Notification.Event.rawValue), object: inptEs)
        
        //manager = SSEManager(sources: [config2])
        //manager = SSEManager(sources: [config3])
        
        
        //manager = SSEManager(sources: [config, config2, config3])
        
        //TODO: Closed is getting set twice
        
//        let es2 = manager?.addEventSource(config2)
//        
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onEvent2(_:)), name: SSEManager.Notification.Event.rawValue, object: es2)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
    
	@objc
	func onEvent(_ note: Notification) {
        
		if let identifier = note.userInfo?["Identifier"],
			let name = note.userInfo?["Name"],
			let source = note.userInfo?["Source"],
			let timestamp = note.userInfo?["Timestamp"] {
            
			guard let eventSource = note.object as? EventSource else {
				return
			}
            
			let event = "\(eventSource.name!) [\(identifier)]\t\(name)\t\(source)\t\(timestamp)\n"
            
			DispatchQueue.main.async {
				self.logViewer.text = (event + self.logViewer.text)
			}
		}
	}
    
	func onEvent2(_ note: Notification) {
        
		if let identifier = note.userInfo?["Identifier"],
			let name = note.userInfo?["Name"] {
            
			let event = "2️⃣[\(identifier)]\t\(name)\n"
            
			DispatchQueue.main.async {
				self.logViewer.text = (event + self.logViewer.text)
			}
            
		}
	}
    
	func onConnected(_ note: Notification) {
        
		DispatchQueue.main.async {
			self.logViewer.text = ("   **** CONNECTED ****" + self.logViewer.text)
		}
	}
    
	func onDisconnected(_ note: Notification) {
        
		DispatchQueue.main.async {
			self.logViewer.text = ("   ==== DISCONNECTED ===="  + self.logViewer.text)
		}
	}
    
	override var prefersStatusBarHidden : Bool {
		return true
	}
}
