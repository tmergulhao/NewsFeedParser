//
//  STNewsFeedDiscovery.swift
//  STNewsFeedParser
//
//  Created by Tiago Mergulhão on 26/12/14.
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

// MARK: - STNewsFeedDiscoveryError

public enum STFeedDiscoveryError : Int {
    case CorruptHTML
    var domain : String {
        return "stae.rs.STNewsFeedDiscovery"
    }
}

// MARK: - STNewsFeedDelegate
// The parser's delegate is informed of events throught the methods
@objc public protocol STNewsFeedDiscoveryDelegate : NSObjectProtocol {
    // Discoverer lifecycle method
	func feedDiscovery(didFinishPage page : STNewsFeedDiscovery, withAddresses addresses : Array<FeedAddress>)
    // send when the feed is parsed and all it's entries are validated
	
    func feedDiscovery(page : STNewsFeedDiscovery, corruptHTML error:NSError)
}

// MARK: - STNewsFeedDiscovery

public class STNewsFeedDiscovery: NSObject, NSXMLParserDelegate {
    // MARK: - Public
    public weak var delegate : STNewsFeedDiscoveryDelegate?
    
    public var feeds : Array<FeedLinks> = []
    
    public var title : String!
    public var image : String!
    
    public var url : NSURL!
    
    public init (pageFromUrl url : NSURL) {
        super.init()
        
        self.url = url
    }
    
    public struct FeedLinks {
        var type : FeedType = FeedType.NONE
        var title : String!
        var address : String!
        var validate : Bool {
            if type == .NONE { return false }
            if title == nil || title == "" { return false }
            if address == nil || address == "" { return false }
            
            return true
        }
    }
    
    public func discover () {
        var error : NSError?
        
        var html = NSString(contentsOfURL: self.url, encoding: NSUTF8StringEncoding, error: &error)
        
        if let givenError = error {
            
            delegate?.feedDiscovery(self, corruptHTML: givenError)
            
        } else {
            if let givenTitle = (html! =~ regexTitle).items.last {
                self.title = givenTitle
                self.image = (html! =~ regexImage).items.last
                
                for item in (html! =~ regexLink).items {
                    var typeAttr = (item =~ regexTypeAttr).items.last
                    var title = (item =~ regexTitleAttr).items.last
                    var address = (item =~ regexAddressAttr).items.last
                    
                    if title == nil {
                        title = self.title
                    }
                    
                    var type : FeedType!
                    switch typeAttr! {
                    case "rss":
                        type = FeedType.RSS
                    case "atom":
                        type = FeedType.ATOM
                    default:
                        type = FeedType.NONE
                    }
                    
                    var feed = FeedLinks(type: type, title: title, address: address)
                    
                    if feed.validate {
                        feeds.append(feed)
                    }
                }
                
                delegate?.feedDiscovery(didFinishPage: self, withAddresses: addresses)
                
            } else {
                
                let errorCode = STFeedDiscoveryError.CorruptHTML
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                    ["description" : "CORRUPT HTML [\(url.absoluteString)]"])
                
                delegate?.feedDiscovery(self, corruptHTML: parseError)
                
            }
		}
		
    }
    /**
    Detect title of the page.
    */
    private var regexTitle = "<title>(.*)</title>"
    /**
    Regular expression to scan from a HTML feed type, optional title and link on array. Examples:
    
    *  ["atom", "Title", "/feeds/main"]
    *  ["rss", "Title", "http://rss.example/feeds/main"]
    */
    private var regexTypeAttr = "type=\"application/(rss|atom)?\\+xml\""
    private var regexTitleAttr = "title=\"([\\w|\\s|!|—|-]*)\""
    private var regexAddressAttr = "href=\"(\\S*)\""
    private var regexLink = "<link" + "\\s*" + "rel=\"alternate\"" + "\\s*" + "type=\"application/(?:rss|atom)?\\+xml\"" + "\\s*" + "(?:title=\"([\\w|\\s|!|—|-]*)\")?" + "\\s*" + "href=\"(?:\\S*)\"" + "[^>]*" + "/>"
    /**
    Detect iOS image from HTML tag
    */
    private var regexImage = "<link\\s*rel=\"apple-touch-icon-?.*?\"\\s*href=\"(.*)\"\\s*/>"
}
