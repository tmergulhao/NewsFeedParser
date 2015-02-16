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

internal extension String {
	func removeFinalSlash () -> String {
		if self.hasSuffix("/") {
			return self.substringWithRange(
				Range<String.Index>(
					start: self.startIndex,
					end: advance(self.endIndex, -1)))
		}
		return self
	}
}

// MARK: - STNewsFeedDiscoveryError

//	TODO: Try more legible aproach to parsing HTML using TFHpple
//	https://github.com/topfunky/hpple
//	https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html#//apple_ref/doc/uid/TP40014216-CH10-XID_75
//	http://www.raywenderlich.com/14172/how-to-parse-html-on-ios

public enum STFeedDiscoveryError : Int {
    case CorruptHTML
    var domain : String {
        return "stae.rs.STNewsFeedDiscovery"
    }
}

public class FeedAddress {
	var type : FeedType
	var title : String?
	var url : NSURL!
	
	init? (ofElement element : String, onPageOfTitle pageTitle : String?) {
		if let titleAttr = (element =~ regexTitleAttr).items.last {
			title = titleAttr.trimWhitespace()
		} else {
			title = pageTitle?.trimWhitespace()
		}
		
		url = NSURL()
		type = FeedType.NONE
		
		if let typeAttr = (element =~ regexTypeAttr).items.last {
			switch typeAttr {
			case "rss":
				type = .RSS
			case "atom":
				type = .ATOM
			default:
				type = .NONE
			}
		} else {
			return nil
		}
		
		if let addressAttr = (element =~ regexAddressAttr).items.last {
			if let someURL = NSURL(string: addressAttr) {
				url = someURL
			} else {
				return nil
			}
		} else {
			return nil
		}
	}
	
	private var regexTitle = "<title>(.*)</title>"
	
	private var regexTypeAttr = "type=\"application/(rss|atom)?\\+xml\""
	private var regexTitleAttr = "title=\"([\\w|\\s|!|—|-]*)\""
	private var regexAddressAttr = "href=\"(\\S*)\""
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
    
    public var addresses : Array<FeedAddress> = []
    
    public var title : String!
    public var imageURL : NSURL?
    public var url : NSURL!
    
    public init (pageFromUrl url : NSURL) {
        super.init()
        
        self.url = url
    }
    
    public func discover () {
		
		var error : NSError?
		
		var pageURLString : String! = url.absoluteString
		
		if pageURLString.hasSuffix("/") {
			pageURLString = pageURLString.removeFinalSlash()
		}
        
        if let givenError = error {
            
            delegate?.feedDiscovery(self, corruptHTML: givenError)
            
		} else if let	html = NSString(contentsOfURL: url, encoding: NSUTF8StringEncoding, error: &error) as? String,
						head = (html =~ regexHead).items.first {
			
			if let givenTitle = (head =~ regexTitle).items.last {
				
                title = givenTitle.trimWhitespace()
				
				if let imageStringURL = (head =~ regexImage).items.last {
					if imageStringURL.hasPrefix("/") {
						imageURL = NSURL(string: pageURLString + imageStringURL)
					} else {
						imageURL = NSURL(string: imageStringURL)
					}
				} else if let imageStringURL = (head =~ regexFavicon).items.last {
					if imageStringURL.hasPrefix("/") {
						imageURL = NSURL(string: pageURLString + imageStringURL)
					} else {
						imageURL = NSURL(string: imageStringURL)
					}
				}
				
                for element in (head =~ regexLink).items {
					if let someAddress = FeedAddress(ofElement: element, onPageOfTitle: title) {
						if someAddress.url.absoluteString!.hasPrefix("/") {
							someAddress.url = NSURL(string: pageURLString + someAddress.url.absoluteString!)
						}
						
                        addresses.append(someAddress)
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
	private var regexHead = "<head>(\\s|\\S)*</head>"
    /**
    Regular expression to scan from a HTML feed type, optional title and link on array. Examples:
    
    *  ["atom", "Title", "/feeds/main"]
    *  ["rss", "Title", "http://rss.example/feeds/main"]
    */
    private var regexLink = "<link" + "\\s*" + "rel=\"alternate\"" + "\\s*" + "type=\"application/(?:rss|atom)?\\+xml\"" + "\\s*" + "(?:title=\"[\\w|\\s|!|—|-|/\\&-|;]*\")?" + "\\s*" + "href=\"(?:\\S*)\""// + "[^>]*" + "/?>"
    /**
    Detect iOS image from HTML tag
    */
    private var regexImage = "<link\\s*rel=\"apple-touch-icon-?.*?\"\\s*href=\"(.*)\"\\s*/?>"
	private var regexFavicon = "<link\\s*rel=\"(?:.*)?icon\"\\s*\\s*href=\"(.*)\"\\s*/?>"
}
