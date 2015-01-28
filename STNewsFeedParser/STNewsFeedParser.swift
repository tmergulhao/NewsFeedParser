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

// MARK: - Extensions

private extension NSDate {
	func isBefore (someDate : NSDate) -> Bool {
		switch self.compare(someDate) {
		case .OrderedAscending:
			return true
		case .OrderedDescending, .OrderedSame:
			return false
		}
	}
}

internal extension String {
	func trimWhitespace () -> String {
		return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
	}
	var length : Int {
		var nsstring = NSString(string: self)
		return nsstring.length
	}
	
	//	How do you use String.substringWithRange? (or, how do Ranges work in Swift?) on StackOverflow
	//	http://stackoverflow.com/questions/24044851/how-do-you-use-string-substringwithrange-or-how-do-ranges-work-in-swift
	
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
}

// MARK: - STNewsFeedParserError

public enum STNewsFeedParserError : Int {
    case Element, Address, CorruptFeed, DispatchError
    var domain : String {
        return "stae.rs.STNewsFeedParser"
    }
}

public enum STNewsFeedParserConcurrencyType : Int {
	case MainQueue, PrivateQueue, CustomQueue
}

// MARK: - STNewsFeedDelegate
// The parser's delegate is informed of events throught the methods
@objc public protocol STNewsFeedParserDelegate : NSObjectProtocol {
    //	Feed lifecicle methods
	//	sent after feed header was read and body is about to be parsed
	optional func newsFeed(shouldBeginFeedParsing feed : STNewsFeedParser,  withInfo info : STNewsFeedEntry) -> Bool // DEFAULT TRUE
			 func newsFeed(didFinishFeedParsing	  feed : STNewsFeedParser,	withInfo info : STNewsFeedEntry, withEntries entries : Array<STNewsFeedEntry>)
    // send when the feed is parsed and all it's entries are validated
	
	//	Fatal error methods
	//	AFTER THIS CALL THE FEED PARSING WILL BE ABORTED
			 func newsFeed(XMLParserErrorOn feed : STNewsFeedParser, withError error:NSError)
			 func newsFeed(corruptFeed		feed : STNewsFeedParser, withError error:NSError)
	
	//	Inconsistency on parsing methods
	//	This call will not yield abortion of parsing
	optional func newsFeed(corruptEntryOn   feed : STNewsFeedParser, entry : STNewsFeedEntry,   withError error:NSError)
	optional func newsFeed(unknownElementOn feed : STNewsFeedParser, ofName elementName:String, withAttributes attributeDict:NSDictionary, andContent content : String)
}

// MARK: - STNewsFeedParser

public class STNewsFeedParser: NSObject, NSXMLParserDelegate {
	
    // MARK: - Public
	
    public weak var delegate : STNewsFeedParserDelegate?
    
    private var info : STNewsFeedEntry!
    private var entries : Array<STNewsFeedEntry> = []
    
    public var lastUpdated : NSDate?
	
	private var concurrencyType : STNewsFeedParserConcurrencyType!
    
    private struct Dispatch {
        private static var concurrentQueue : dispatch_queue_t!
    }
	
	public lazy var concurrentQueue : dispatch_queue_t? = {
		switch self.concurrencyType! {
		
		case .CustomQueue: return nil
		
		case .MainQueue: return dispatch_get_main_queue()
		
		case .PrivateQueue:
			
			if Dispatch.concurrentQueue == nil {
				Dispatch.concurrentQueue = dispatch_queue_create(
												"stae.rs.STNewsFeedParser.concurrentQueue",
												DISPATCH_QUEUE_CONCURRENT)
			}
			
			return Dispatch.concurrentQueue
		}
	}()
    
	public init (feedFromUrl url : NSURL, concurrencyType : STNewsFeedParserConcurrencyType) {
        super.init()
        
        self.url = url
		self.concurrencyType = concurrencyType
        
        info = STNewsFeedEntry()
        info.info = info
        
        info.properties["link"] = url.absoluteString
        
        target = info
    }
	
    public func parse () {
		if isParsing == false {
			
            info.sourceType = FeedType.NONE
            
            parseMode = .FEED
			
			if let workingQueue = concurrentQueue {
				
				dispatch_async (workingQueue, {
				
				if let parser = NSXMLParser(contentsOfURL: self.url) {
					
					self.parser = parser
					
					parser.delegate = self
					parser.parse()
					
				} else {
					
					let errorCode = STNewsFeedParserError.Address
					
					let criticalError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
						["description" : "INVALID ADDRESS does not trigger NSXMLParser: [" + self.url.absoluteString! + "]"])
					
					self.delegate?.newsFeed(corruptFeed: self, withError: criticalError)
					
				}
				
				})
			
			} else {
				
				let errorCode = STNewsFeedParserError.DispatchError
				
				let criticalError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
					["description" : "FOR CUSTOM DISPATCH QUEUE SET concurrentQueue FOR GIVEN INSTANCE"])
				
				self.delegate?.newsFeed(corruptFeed: self, withError: criticalError)
				
			}
        }
    }
	
    public func abortParsing () {
        parser?.abortParsing()
        parser?.delegate = nil
        parser = nil
    }
    
    // MARK: - NSXMLParserDelegate
    
    private enum ParseMode {
        case FEED, ENTRY
    }
	private var lastParseMode : ParseMode = ParseMode.FEED
	private var parseMode : ParseMode = ParseMode.FEED
	
	private var target : STNewsFeedEntry!
	
    private var url : NSURL!
	public var address : String {
		get {
			return url.absoluteString!
		}
	}
	
    private weak var parser : NSXMLParser!
	public var isParsing : Bool {
		get {
			return parser != nil
		}
    }
    
    private var currentContent : String = ""
	
	private struct UnkownElement {
		var name : String
		var attributeDict : NSDictionary
	}
	private var unknownElement : UnkownElement?
	
    func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: NSDictionary!) {
        
        currentContent = ""
        
        switch info.sourceType {
        case .NONE:
			
            switch elementName {
				
            case "feed": info.sourceType = FeedType.ATOM
				
            case "channel", "rss": info.sourceType = FeedType.RSS
				
			default:
				
				let errorCode = STNewsFeedParserError.CorruptFeed
				let criticalError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
					["description" : "CORRUPT FEED [\(self.address)] [\(elementName)]"])
				
				self.delegate?.newsFeed(corruptFeed: self, withError: criticalError)
				
				abortParsing()
				
            }
			
        case .ATOM, .RSS:
			
            switch elementName {
				
			case "entry", "item":
				
				if parseMode == .FEED {
					
					var error : NSError?
					
					if info.normalize(&error) == false {
						
						self.delegate?.newsFeed(corruptFeed: self, withError: error!)
						
						abortParsing()
						
					} else {
						
						if let date = lastUpdated {
							
							if date.isBefore(info.date) == false { parserDidEndDocument(parser); return }
							
						}
						
						if let shouldParse = delegate?.newsFeed?(shouldBeginFeedParsing: self, withInfo: info) {
							
							if shouldParse == false { abortParsing(); return }
							
						}
					}
				}
				
				parseMode = ParseMode.ENTRY
				
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
                target.properties["link"] = attributeDict.valueForKey("href") as? String
            default:
				unknownElement = UnkownElement(name: elementName, attributeDict: attributeDict)
            }
        }
    }
	
	public func parser(parser: NSXMLParser!, foundCharacters string: String!) { currentContent += string }
    
    public func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName:String!) {
		
		if let someElement = unknownElement {
			
			self.delegate?.newsFeed?(unknownElementOn: self, ofName: elementName, withAttributes: someElement.attributeDict, andContent: self.currentContent)
			
			unknownElement = nil
		}
		
		switch elementName {
			
		case "entry", "item":
			
			if parseMode == .ENTRY {
				
				var error : NSError?
				
				if target.normalize (&error) {
					
					if let date = lastUpdated {
						
						if date.isBefore(target.date) == false { parserDidEndDocument(parser); return }
						
					}
					
					entries.append(target)
					
				}
					
				else { delegate?.newsFeed?(corruptEntryOn: self, entry: target, withError: error!) }
			}
			
		default:
			
			currentContent = currentContent.trimWhitespace()
			
			if currentContent.isEmpty == false { target.properties[elementName] = currentContent }
			
		}
		
    }
	
    public func parser(parser: NSXMLParser!, parseErrorOccurred parseError: NSError!) {
		
		delegate?.newsFeed(XMLParserErrorOn: self, withError: parseError)
		
		abortParsing()
    }
    
    public func parserDidEndDocument(parser: NSXMLParser!) {
		
        lastUpdated = info.date
		
		self.delegate?.newsFeed(didFinishFeedParsing: self, withInfo: info, withEntries: entries)
		
		entries = []
		
        abortParsing()
    }
}
