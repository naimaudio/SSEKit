//: Playground - noun: a place where people can play

import UIKit

func extractValue(scanner: NSScanner) -> (String?, String?) {
    
	var field: NSString?
	scanner.scanUpToString(":", intoString: &field)
	scanner.scanString(":", intoString: nil)
    
	var value: NSString?
	scanner.scanUpToString("\n", intoString: &value)
    
	return (field?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()), value?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
}

func extractValue(forField field: String, scanner: NSScanner) -> String? {
    
	scanner.scanUpToString(field, intoString: nil)
	scanner.scanString(field, intoString: nil)
    
	var value: NSString?
	scanner.scanUpToString("\n", intoString: &value)
    
	return value as? String
}

var str = "id: 88e92600-e220-11e5-8f19-6b8864780aab\n\rdata: I'm busy"
var str2 = "id: 8ab35eb0-e220-11e5-8f19-6b8864780aab\n\revent: user-connected\n\rdata: Martin"

for event in [str, str2] {
    
	let scanner = NSScanner(string: event as String)
	scanner.charactersToBeSkipped = NSCharacterSet.whitespaceCharacterSet()
    
    
//    let identifier = extractValue(forField: "id:", scanner: scanner)
//    let event = extractValue(forField: "event:", scanner: scanner)
//    let data = extractValue(forField: "data:", scanner: scanner)

	var entity: (String?, String?)
    
	repeat {
        
		entity = extractValue(scanner)
        
		if entity.1 != nil {
			print("\(entity.0!):\t\(entity.1!)")
		}
        
	} while(entity.0 != nil && entity.1 != nil)
    
    
//    let identifier = extractValue(scanner)
//    let event = extractValue(scanner)
//    let data = extractValue(scanner)
//    
//    if identifier.1 != nil {
//        print("ID:\t\t\(identifier.1!)")
//    }
//    
//    if event.1 != nil {
//        print("EVENT:\t\(event.1!)")
//    }
//    
//    if data.1 != nil {
//        print("DATA:\t\(data.1!)")
//    }
    
	print("---------------------------------------------------------------")
}