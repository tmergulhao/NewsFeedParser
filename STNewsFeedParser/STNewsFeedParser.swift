//
//  STNewsFeedParser.swift
//  STNewsFeed
//
//  Created by Tiago Mergulhão on 25/12/14.
//  Copyright (c) 2014 Tiago Mergulhão. All rights reserved.
//

//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation

//	TODO: Refactor parser class on Swift tuple protocol patterns for error handling
//	http://nshipster.com/the-death-of-cocoa/

//	TODO: Document framework
//	http://www.appcoda.com/documenting-source-code-in-xcode/

// MARK: - Extensions

private extension Date {
	func isBefore (_ someDate : Date) -> Bool {
		switch self.compare(someDate) {
		case .orderedAscending:
			return true
		case .orderedDescending, .orderedSame:
			return false
		}
	}
}

internal extension String {
	func trimWhitespace () -> String {
		return self.trimmingCharacters(in: CharacterSet.whitespaces)
	}
	var length : Int {
		let nsstring = NSString(string: self)
		return nsstring.length
	}
	
	//	How do you use String.substringWithRange? (or, how do Ranges work in Swift?) on StackOverflow
	//	http://stackoverflow.com/questions/24044851/how-do-you-use-string-substringwithrange-or-how-do-ranges-work-in-swift
	/*
	func hasInfix (input : String) -> Bool {
		let length = self.length
		let inputLength = input.length
		
		if inputLength > length {
			return false
		}
		
		for var i = 1; i + inputLength < length; i++ {
			let excerpt = self.substringWithRange(
				Range<String.Index>(
					start: advance(self.startIndex, i),
					end: advance(self.startIndex, i + inputLength)))
			
			if excerpt == input {
				return true
			}
		}
		
		return false
	}
	*/
	func hasInfix (_ input : Character) -> Bool {
		return self.range(of: "\(input)", options: NSString.CompareOptions.backwards, range: nil, locale: nil) != nil
	}
}

// MARK: - STNewsFeedParserError

public enum STNewsFeedParserError : Int {
    case element, address, corruptFeed, dispatchError
    var domain : String {
        return "stae.rs.STNewsFeedParser"
    }
}

public enum STNewsFeedParserConcurrencyType : Int {
	case mainQueue, privateQueue, customQueue
}

// MARK: - STNewsFeedDelegate
// The parser's delegate is informed of events throught the methods
@objc public protocol STNewsFeedParserDelegate : NSObjectProtocol {
    //	Feed lifecicle methods
	//	sent after feed header was read and body is about to be parsed
	@objc optional func newsFeed(shouldBeginFeedParsing feed : STNewsFeedParser,  withInfo info : STNewsFeedEntry) -> Bool // DEFAULT TRUE
			 func newsFeed(didFinishFeedParsing	  feed : STNewsFeedParser,	withInfo info : STNewsFeedEntry, withEntries entries : Array<STNewsFeedEntry>)
    // send when the feed is parsed and all it's entries are validated
	
	//	Fatal error methods
	//	AFTER THIS CALL THE FEED PARSING WILL BE ABORTED
			 func newsFeed(XMLParserErrorOn feed : STNewsFeedParser, withError error:NSError)
			 func newsFeed(corruptFeed		feed : STNewsFeedParser, withError error:NSError)
	
	//	Inconsistency on parsing methods
	//	This call will not yield abortion of parsing
	@objc optional func newsFeed(corruptEntryOn   feed : STNewsFeedParser, entry : STNewsFeedEntry,   withError error:NSError)
	@objc optional func newsFeed(unknownElementOn feed : STNewsFeedParser, ofName elementName:String, withAttributes attributeDict:NSDictionary, andContent content : String)
}

// MARK: - STNewsFeedParser

open class STNewsFeedParser: NSObject, XMLParserDelegate {
	
    // MARK: - Public
	
    open weak var delegate : STNewsFeedParserDelegate?
    
    fileprivate var info : STNewsFeedEntry!
    fileprivate var entries : Array<STNewsFeedEntry> = []
    
    open var lastUpdated : Date?
	
	fileprivate var concurrencyType : STNewsFeedParserConcurrencyType!
    
    fileprivate struct Dispatch {
        fileprivate static var concurrentQueue : DispatchQueue!
    }
	
	open lazy var concurrentQueue : DispatchQueue? = {
		switch self.concurrencyType! {
		
		case .customQueue: return nil
		
		case .mainQueue: return DispatchQueue.main
		
		case .privateQueue:
			
			if Dispatch.concurrentQueue == nil {
				Dispatch.concurrentQueue = DispatchQueue(
												label: "stae.rs.STNewsFeedParser.concurrentQueue",
												attributes: DispatchQueue.Attributes.concurrent)
			}
			
			return Dispatch.concurrentQueue
		}
	}()
    
	public init (feedFromUrl url : URL, concurrencyType : STNewsFeedParserConcurrencyType) {
        super.init()
        
        self.url = url
		self.concurrencyType = concurrencyType
        
        info = STNewsFeedEntry()
        info.info = info
        
        info.properties["link"] = url.absoluteString
        
        target = info
    }
	
    open func parse () {
		if isParsing == false {
			
            info.sourceType = FeedType.none
            
            parseMode = .feed
			
			if let workingQueue = concurrentQueue {
				
				workingQueue.async (execute: {
				
				if let parser = XMLParser(contentsOf: self.url) {
					
					self.parser = parser
					
					parser.delegate = self
					parser.parse()
					
				} else {
					
					let errorCode = STNewsFeedParserError.address
					
					let criticalError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
						["description" : "INVALID ADDRESS does not trigger NSXMLParser: [" + self.url.absoluteString + "]"])
					
					self.delegate?.newsFeed(corruptFeed: self, withError: criticalError)
					
				}
				
				})
			
			} else {
				
				let errorCode = STNewsFeedParserError.dispatchError
				
				let criticalError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
					["description" : "FOR CUSTOM DISPATCH QUEUE SET concurrentQueue FOR GIVEN INSTANCE"])
				
				self.delegate?.newsFeed(corruptFeed: self, withError: criticalError)
				
			}
        }
    }
	
    open func abortParsing () {
        parser?.abortParsing()
        parser?.delegate = nil
        parser = nil
    }
    
    // MARK: - NSXMLParserDelegate
    
    fileprivate enum ParseMode {
        case feed, entry
    }
	fileprivate var lastParseMode : ParseMode = ParseMode.feed
	fileprivate var parseMode : ParseMode = ParseMode.feed
	
	fileprivate var target : STNewsFeedEntry!
	
    fileprivate var url : URL!
	open var address : String {
		get {
			return url.absoluteString
		}
	}
	
    fileprivate weak var parser : XMLParser!
	open var isParsing : Bool {
		get {
			return parser != nil
		}
    }
    
    fileprivate var currentContent : String = ""
	
	fileprivate struct UnkownElement {
		var name : String
		var attributeDict : NSDictionary
	}
	fileprivate var unknownElement : UnkownElement?
	
	open func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [AnyHashable: Any]) {
        
        currentContent = ""
        
        switch info.sourceType {
        case .none:
			
            switch elementName {
				
            case "feed": info.sourceType = FeedType.atom
				
            case "channel", "rss": info.sourceType = FeedType.rss
				
			default:
				
				let errorCode = STNewsFeedParserError.corruptFeed
				let criticalError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
					["description" : "CORRUPT FEED [\(self.address)] [\(elementName)]"])
				
				self.delegate?.newsFeed(corruptFeed: self, withError: criticalError)
				
				abortParsing()
				
            }
			
        case .atom, .rss:
			
            switch elementName {
				
			case "entry", "item":
				
				if parseMode == .feed {
					
					var error : NSError?
					
					if info.normalize(&error) == false {
						
						self.delegate?.newsFeed(corruptFeed: self, withError: error!)
						
						abortParsing()
						
					} else {
						
						if let date = lastUpdated , date.isBefore(info.date as Date) == false {
							
							parserDidEndDocument(parser)
							
						}
						
						if let shouldParse = delegate?.newsFeed?(shouldBeginFeedParsing: self, withInfo: info) , shouldParse == false {
							
							abortParsing()
							
						}
					}
				}
				
				parseMode = ParseMode.entry
				
				target = info.sourceType.entry(info)
			
			// DATA ELEMENTS
			case "title", "subtitle", "id", "description", "guid", "summary": break
				
			// DATETIME
			case "updated", "lastBuildDate", "pubDate", "published": break
				
			// UNSUPPORTED
			case "channel", "generator", "language", "rights", "comments",
				 "category", "content:encoded", "name", "author", "content",
				 "media:thumbnail", "uri", "ttl", "managingEditor": break
			
			// VENDOR UNSUPPORTED
			case let someElementName where someElementName.hasPrefix("atom"): break
			case let someElementName where someElementName.hasPrefix("dc"): break
			case let someElementName where someElementName.hasPrefix("feedburner"): break
			case let someElementName where someElementName.hasPrefix("sy"): break
			case let someElementName where someElementName.hasInfix(":"): break
			
            case "link", "url":
                target.properties["link"] = attributeDict["href"] as? String
            default:
				unknownElement = UnkownElement(name: elementName, attributeDict: attributeDict as NSDictionary)
            }
        }
    }
	
	open func parser(_ parser: XMLParser, foundCharacters string: String?) {
		if let someCharacters = string {
			currentContent += someCharacters
		}
	}
	
    open func parser(_ parser : XMLParser, didEndElement elementName : String, namespaceURI : String?, qualifiedName qName : String?) {
		
		if let someElement = unknownElement {
			
			self.delegate?.newsFeed?(unknownElementOn: self, ofName: elementName, withAttributes: someElement.attributeDict, andContent: self.currentContent)
			
			unknownElement = nil
		}
		
		switch elementName {
			
		case "entry", "item":
			
			if parseMode == .entry {
				
				var error : NSError?
				
				if target.normalize (&error) {
					
					if let date = lastUpdated , date.isBefore(target.date as Date) == false {
						
						parserDidEndDocument(parser)
						
					} else {
						
						entries.append(target)
						
					}
				}
					
				else {
					
					delegate?.newsFeed?(corruptEntryOn: self, entry: target, withError: error!)
					
				}
			}
			
		default:
			
			currentContent = currentContent.trimWhitespace()
			
			if currentContent.isEmpty == false { target.properties[elementName] = currentContent }
			
		}
		
    }
	
    open func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
		
		delegate?.newsFeed(XMLParserErrorOn: self, withError: parseError as NSError)
		
		abortParsing()
    }
    
    open func parserDidEndDocument(_ parser: XMLParser) {
		
        lastUpdated = info.date as Date?
		
		self.delegate?.newsFeed(didFinishFeedParsing: self, withInfo: info, withEntries: entries)
		
		entries = []
		
        abortParsing()
    }
}
