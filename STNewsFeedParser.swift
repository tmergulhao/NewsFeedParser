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
    // ask for feed.abortParsing() for feed info only
    func didFinishFeedParsing(feed : STNewsFeedParser)
    // send when the feed is parsed and all it's entries are validated
    
    optional func newsFeed(feed : STNewsFeedParser, XMLParserError error:NSError)
    
    optional func newsFeed(feed : STNewsFeedParser, corruptFeed error:NSError)
    optional func newsFeed(feed : STNewsFeedParser, unknownElement elementName:String, withAttributes attributeDict:NSDictionary, andError error: NSError)
}

// MARK: - STNewsFeed

// TODO: Feed discovery class
// TODO: Native assyncronous parsing and newEntriesArray


public class STNewsFeedParser: NSObject, NSXMLParserDelegate {
    // MARK: - Public
    public weak var delegate : STNewsFeedParserDelegate?
    
    public var info : STNewsFeedInfo!
    public var entries : Array<STNewsFeedEntry> = []
    
    private var url : NSURL!
    
    public init (feedFromUrl address : NSURL) {
        super.init()
        
        url = address
        
        info = STNewsFeedInfo()
        info.address = address.absoluteString
        
        target = info
    }
    public func parse () {
        entries.removeAll(keepCapacity: true)
        
        if let parser = NSXMLParser(contentsOfURL: url) {
            self.parser = parser
            
            parser.delegate = self
            parser.parse()
        } else {
            let errorCode = STNewsFeedError.Address
            let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "INVALID ADDRESS does not trigger NSXMLParser: [" + info.address + "]"])
            
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
            case "entry", "item":
                if parseMode == .FEED {
                    if info.normalized {
                        delegate?.willBeginFeedParsing(self)
                    } else {
                        parser.abortParsing()
                        
                        let errorCode = STNewsFeedError.CorruptFeed
                        let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "CORRUPT feedType [\(info.address)]"])
                        
                        delegate?.newsFeed?(self, corruptFeed: parseError)
                    }
                }
                
                parseMode = ParseMode.ENTRY
                target = STNewsFeedEntry(feed: info)
            case "link", "url":
                target.properties["link"] = attributeDict.valueForKey("href") as? String
                
            case "title", "updated", "id", "summary", "content", "author", "name", "subtitle", "rights", "uri", "description", "copyright", "language", "pubDate", "guid":
                // Element is not needed for parsing
                break
            default:
                let errorCode = STNewsFeedError.Element
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "UNKNOWN element [\(elementName)] with attributes: \(attributeDict)"])
                delegate?.newsFeed?(self, unknownElement: elementName, withAttributes: attributeDict, andError: parseError)
            }
        default:
            switch elementName {
            case "feed":
                info.sourceType = FeedType.ATOM
            case "channel", "rss":
                info.sourceType = FeedType.RSS
            default:
                parser.abortParsing()
                
                let errorCode = STNewsFeedError.CorruptFeed
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo: ["description" : "CORRUPT feedType [\(info.address)]" + "\nBegining with [\(elementName)]"])
                
                delegate?.newsFeed?(self, corruptFeed: parseError)
            }
        }
    }
    
    public func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName:String!) {
        
        switch info.sourceType {
        case FeedType.ATOM, FeedType.RSS:
            switch elementName {
            case "entry", "item":
                switch parseMode {
                case .ENTRY:
                    if target.normalized {
                        entries.append(target)
                    }
                case .FEED:
                    break
                }
            default:
                switch parseMode {
                case .ENTRY:
                    target.properties[elementName] = currentContent
                case .FEED:
                    info.properties[elementName] = currentContent
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
        delegate?.didFinishFeedParsing(self)
        
        self.parser.delegate = nil
        self.parser = nil
    }
}
