//
//  ViewController.swift
//  MacSSE
//
//  Created by Richard Stelling on 23/05/2016.
//  Copyright © 2016 Richard Stelling. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

	@IBOutlet weak var logviewer: NSScrollView!
	@IBOutlet weak var ipAddress: NSTextField!
    
	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.
	}

	override var representedObject: AnyObject? {
		didSet {
		// Update the view, if already loaded.
		}
	}

	@IBAction func onConnect(sender: NSButton) {
        
	}
    
    
}

@IBOutlet weak var logViewer: UITextView!
