//
//  ViewController.swift
//  SSEKitExample
//
//  Created by Richard Stelling on 07/10/2015.
//  Copyright © 2015 Naim Audio Ltd. All rights reserved.
//

import UIKit
import SSEKit

class ViewController: UIViewController {

	let sse = EventSource(host: "lamp.private", path: "/sse.php")
    
	override func viewDidLoad() {
		super.viewDidLoad()
            
		print("SSEKit version: \(sse.versionString)")

	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

}
/*
class ViewController: UIViewController, StateDelegate {

	enum ExampleState {
		case Initial
	}
    
	typealias StateType = ExampleState
    
	override func viewDidLoad() {
		super.viewDidLoad()
        
		let stateMachine = State<ViewController>(initialState:.Initial, delegate:self)
        
		print("State: \(stateMachine.state)")
		print("State Machine version: \(stateMachine.version)")
        
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK: StateDelegate
    
	func shouldTransitionFrom(from:StateType, to:StateType) -> Bool {
		return true
	}
    
	func didTransitionFrom(from:StateType, to:StateType) {
        
	}
    
	func failedTransitionFrom(from:StateType, to:StateType) {
        
	}
}

*/