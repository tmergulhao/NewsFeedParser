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

// MARK: - STNewsFeedParserError
public enum STNewsFeedParserError : Int {
    case Element, Address, CorruptFeed
    var domain : String {
        return "stae.rs.STNewsFeedParser"
    }
}

// MARK: - STNewsFeedDelegate
// The parser's delegate is informed of events throught the methods
@objc public protocol STNewsFeedParserDelegate : NSObjectProtocol {
    // Feed lifecicle methods
    func willBeginFeedParsing(feed : STNewsFeedParser)
    // sent when the feed is validated and about to be parsed
    // ask for abortParsing() for feed info only
    func didFinishFeedParsing(feed : STNewsFeedParser)
    // send when the feed is parsed and all it's entries are validated
    
    optional func newsFeed(feed : STNewsFeedParser, XMLParserError error:NSError)
    
    optional func newsFeed(feed : STNewsFeedParser, corruptFeed error:NSError)
    optional func newsFeed(feed : STNewsFeedParser, unknownElement elementName:String, withAttributes attributeDict:NSDictionary, andError error: NSError)
}

// MARK: - STNewsFeedParser

public class STNewsFeedParser: NSObject, NSXMLParserDelegate {
    // MARK: - Public
    public weak var delegate : STNewsFeedParserDelegate?
    
    public var info : STNewsFeedEntry!
    public var entries : Array<STNewsFeedEntry> = []
    
    public var lastUpdated : NSDate?
    
    struct Dispatch {
        private static var parallel : dispatch_queue_t!
        private static var serial : dispatch_queue_t!
    }
    
    public init (feedFromUrl address : NSURL) {
        super.init()
        
        url = address
        
        info = STNewsFeedEntry()
        info.info = info
        
        info.properties["link"] = address.absoluteString
        
        target = info
        
        if Dispatch.parallel == nil {
            Dispatch.parallel = dispatch_queue_create("stae.rs.STNewsFeedParser.parallel", nil)
        }
        if Dispatch.serial == nil {
            Dispatch.serial = dispatch_queue_create("stae.rs.STNewsFeedParser.serial", DISPATCH_QUEUE_SERIAL)
        }
    }
    public func parse () {
        
        entries.removeAll(keepCapacity: true)
        info.sourceType = FeedType.NONE
        
        parseMode = .FEED
        
        dispatch_async (Dispatch.parallel, {
        
        if let parser = NSXMLParser(contentsOfURL: self.url) {
            self.parser = parser
            
            parser.delegate = self
            parser.parse()
        } else {
            let errorCode = STNewsFeedParserError.Address
            let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                ["description" : "INVALID ADDRESS does not trigger NSXMLParser: [" + self.url.absoluteString! + "]"])
            
            self.delegate?.newsFeed?(self, corruptFeed: parseError)
        }
            
        })
    }
    public func abortParsing () {
        parser?.abortParsing()
        parser?.delegate = nil
        parser = nil
    }
    
    // MARK: - Private, NSXMLParserDelegate
    
    private enum ParseMode {
        case FEED, ENTRY
    }
    
    private var url : NSURL!
    private weak var parser : NSXMLParser!
    public var isParsing : Bool {
        return parser == nil ? false : true
    }
    
    private var target : STNewsFeedEntry!
    
    private var lastParseMode : ParseMode = ParseMode.FEED
    private var parseMode : ParseMode = ParseMode.FEED
    
    private var currentContent:String = ""
    
    func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: NSDictionary!) {
        
        currentContent = ""
        
        switch info.sourceType {
        case FeedType.NONE:
            switch elementName {
            case "feed":
                info.sourceType = FeedType.ATOM
            case "channel", "rss":
                if let isPodcast = attributeDict["xmlns:itunes"] as? String {
                    info.sourceType = FeedType.PODCAST
                } else {
                    info.sourceType = FeedType.RSS
                }
            default:
                abortParsing()
                
                let errorCode = STNewsFeedParserError.CorruptFeed
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                    ["description" : "CORRUPT FEED [\(url.absoluteString)] [\(elementName)]"])
                
                delegate?.newsFeed?(self, corruptFeed: parseError)
            }
        
        case .ATOM, .RSS, .PODCAST:
            switch elementName {
            case "title", "subtitle", "id", "rights":
                // Not needed in the parsing fase
                break
            case "entry", "item":
                if parseMode == .FEED {
                    if info.normalized {
                        if let date = lastUpdated {
                            switch date.compare(info.date) {
                            case .OrderedAscending:
                                break
                            case .OrderedSame, .OrderedDescending:
                                abortParsing()
                                dispatch_async (Dispatch.serial, {
                                if true {
                                    self.delegate?.didFinishFeedParsing(self)
                                }
                                })
                            }
                        }
                        
                        delegate?.willBeginFeedParsing(self)
                    } else {
                        abortParsing()
                        
                        let errorCode = STNewsFeedParserError.CorruptFeed
                        let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                            ["description" : "CORRUPT FEED [\(url.absoluteString)]"])
                        
                        delegate?.newsFeed?(self, corruptFeed: parseError)
                    }
                }
                
                parseMode = ParseMode.ENTRY
                target = info.sourceType.entry(info)
                
            case "link", "url":
                target.properties["link"] = attributeDict.valueForKey("href") as? String
            default:
                let errorCode = STNewsFeedParserError.Element
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                    ["description" : "UNKNOWN ELEMENT [\(elementName)]\nATTRIBUTES: [\(attributeDict)]"])
                
                delegate?.newsFeed?(self, unknownElement: elementName, withAttributes: attributeDict, andError: parseError)
            }
        }
    }
    
    public func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName:String!) {
        
        currentContent = currentContent.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        switch info.sourceType {
        case .NONE:
            break
            
        case .ATOM, .RSS, .PODCAST:
            switch elementName {
                
                
            case "entry", "item":
                switch parseMode {
                case .ENTRY:
                    if target.normalized {
                        if let date = lastUpdated {
                            switch date.compare(target.date) {
                            case .OrderedAscending:
                                entries.append(target)
                            case .OrderedSame, .OrderedDescending:
                                abortParsing()
                                parserDidEndDocument(parser)
                            }
                        } else {
                            entries.append(target)
                        }
                    } else {
                        let errorCode = STNewsFeedParserError.CorruptFeed
                        let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                            ["description" : "CORRUPT POST [\(url.absoluteString)]"/*\nPOST \(target.properties)"*/])
                        
                        delegate?.newsFeed?(self, corruptFeed: parseError)
                    }
                case .FEED:
                    break
                }
            default:
                if !currentContent.isEmpty {
                    target.properties[elementName] = currentContent
                }
            }
        }
    }

    public func parser(parser: NSXMLParser!, foundCharacters string: String!) {
        currentContent += string
    }
    
    public func parser(parser: NSXMLParser!, parseErrorOccurred parseError: NSError!) {
        delegate?.newsFeed?(self, XMLParserError: parseError)
    }
    
    public func parserDidEndDocument(parser: NSXMLParser!) {
        lastUpdated = info.date
        
        abortParsing()
        
        dispatch_async (Dispatch.serial, {
            
        if true {
            self.delegate?.didFinishFeedParsing(self)
        }
            
        })
    }
}
