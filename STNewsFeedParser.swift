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

// MARK: - STNewsFeedError
public enum STNewsFeedError : Int {
    case Element, Address, CorruptFeed
    var domain : String {
        return "stae.rs.STNewsFeed"
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

// MARK: - STNewsFeed

// TODO: Feed discovery class


public class STNewsFeedParser: NSObject, NSXMLParserDelegate {
    // MARK: - Public
    public weak var delegate : STNewsFeedParserDelegate?
    
    public var info : STNewsFeedInfo!
    public var entries : Array<STNewsFeedEntry> = []
    
    private var url : NSURL!
    
    public var lastUpdated : NSDate?
    
    struct Dispatch {
        private static var secondaryQueue : dispatch_queue_t!
    }
    
    public init (feedFromUrl address : NSURL) {
        super.init()
        
        url = address
        
        info = STNewsFeedInfo()
        
        info.properties["address"] = address.absoluteString
        
        target = info
    }
    public func parse () {
        if Dispatch.secondaryQueue == nil {
            Dispatch.secondaryQueue = dispatch_queue_create("stae.rs.STNewsFeed ", DISPATCH_QUEUE_SERIAL)
        }
        
        entries.removeAll(keepCapacity: true)
        info.sourceType = FeedType.NONE
        
        parseMode = .FEED
        
        if let parser = NSXMLParser(contentsOfURL: url) {
            self.parser = parser
            
            parser.delegate = self
            
            dispatch_async (Dispatch.secondaryQueue, {
                parser.parse()
                
                parser.description
            })
        } else {
            let errorCode = STNewsFeedError.Address
            let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "INVALID ADDRESS does not trigger NSXMLParser: [" + url.absoluteString! + "]"])
            
            delegate?.newsFeed?(self, corruptFeed: parseError)
        }
    }
    public func abortParsing () {
        parser.abortParsing()
    }
    
    // MARK: - Private, NSXMLParserDelegate
    private enum ParseMode {
        case FEED, ENTRY
    }
    
    private weak var parser : NSXMLParser!
    
    private var target : STNewsFeedEntry!
    
    private var lastParseMode : ParseMode = ParseMode.FEED
    private var parseMode : ParseMode = ParseMode.FEED
    
    private var currentContent:String = ""
    
    func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: NSDictionary!) {
        
        currentContent = ""
        
        switch info.sourceType {
        case FeedType.ATOM, FeedType.RSS:
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
                            }
                        }
                        
                        delegate?.willBeginFeedParsing(self)
                    } else {
                        abortParsing()
                        
                        let errorCode = STNewsFeedError.CorruptFeed
                        let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "CORRUPT FEED [\(url.absoluteString)]"])
                        
                        delegate?.newsFeed?(self, corruptFeed: parseError)
                    }
                }
                
                parseMode = ParseMode.ENTRY
                target = STNewsFeedEntry(feed: info)
            case "link", "url":
                target.properties["link"] = attributeDict.valueForKey("href") as? String
            default:
                let errorCode = STNewsFeedError.Element
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "UNKNOWN ELEMENT [\(elementName)]\nATTRIBUTES: [\(attributeDict)]"])
                delegate?.newsFeed?(self, unknownElement: elementName, withAttributes: attributeDict, andError: parseError)
            }
        default:
            switch elementName {
            case "feed":
                info.sourceType = FeedType.ATOM
            case "channel", "rss":
                info.sourceType = FeedType.RSS
            default:
                abortParsing()
                
                let errorCode = STNewsFeedError.CorruptFeed
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "CORRUPT FEED [\(url.absoluteString)] [\(elementName)]"])
                
                delegate?.newsFeed?(self, corruptFeed: parseError)
            }
        }
    }
    
    public func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName:String!) {
        
        currentContent = currentContent.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        switch info.sourceType {
        case FeedType.ATOM, FeedType.RSS:
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
                        let errorCode = STNewsFeedError.CorruptFeed
                        let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "CORRUPT POST [\(url.absoluteString)]\nPOST \(target.properties)"])
                        
                        delegate?.newsFeed?(self, corruptFeed: parseError)
                    }
                case .FEED:
                    break
                }
            default:
                if currentContent != "" {
                    switch parseMode {
                    case .ENTRY:
                        target.properties[elementName] = currentContent
                    case .FEED:
                        info.properties[elementName] = currentContent
                    }
                }
            }
        default:
            break
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
        
        self.parser.delegate = nil
        self.parser = nil
        
        delegate?.didFinishFeedParsing(self)
    }
}
