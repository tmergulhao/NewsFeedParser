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
			return self.substring(
				with: (self.startIndex ..< advance(self.endIndex, -1)))
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
    case corruptHTML
    var domain : String {
        return "stae.rs.STNewsFeedDiscovery"
    }
}

open class FeedAddress {
	var type : FeedType
	var title : String?
	var url : URL!
	
	init? (ofElement element : String, onPageOfTitle pageTitle : String?) {
		if let titleAttr = (element =~ regexTitleAttr).items.last {
			title = titleAttr.trimWhitespace()
		} else {
			title = pageTitle?.trimWhitespace()
		}
		
		url = URL()
		type = FeedType.none
		
		if let typeAttr = (element =~ regexTypeAttr).items.last {
			switch typeAttr {
			case "rss":
				type = .rss
			case "atom":
				type = .atom
			default:
				type = .none
			}
		} else {
			return nil
		}
		
		if let addressAttr = (element =~ regexAddressAttr).items.last {
			if let someURL = URL(string: addressAttr) {
				url = someURL
			} else {
				return nil
			}
		} else {
			return nil
		}
	}
	
	fileprivate var regexTitle = "<title>(.*)</title>"
	
	fileprivate var regexTypeAttr = "type=\"application/(rss|atom)?\\+xml\""
	fileprivate var regexTitleAttr = "title=\"([\\w|\\s|!|—|-]*)\""
	fileprivate var regexAddressAttr = "href=\"(\\S*)\""
}

// MARK: - STNewsFeedDelegate
// The parser's delegate is informed of events throught the methods
@objc public protocol STNewsFeedDiscoveryDelegate : NSObjectProtocol {
    // Discoverer lifecycle method
	func feedDiscovery(didFinishPage page : STNewsFeedDiscovery, withAddresses addresses : Array<FeedAddress>)
    // send when the feed is parsed and all it's entries are validated
	
    func feedDiscovery(_ page : STNewsFeedDiscovery, corruptHTML error:NSError)
}

// MARK: - STNewsFeedDiscovery

open class STNewsFeedDiscovery: NSObject, XMLParserDelegate {
    // MARK: - Public
    open weak var delegate : STNewsFeedDiscoveryDelegate?
    
    open var addresses : Array<FeedAddress> = []
    
    open var title : String!
    open var imageURL : URL?
    open var url : URL!
    
    public init (pageFromUrl url : URL) {
        super.init()
        
        self.url = url
    }
    
    open func discover () {
		
		var error : NSError?
		
		var pageURLString : String! = url.absoluteString
		
		if pageURLString.hasSuffix("/") {
			pageURLString = pageURLString.removeFinalSlash()
		}
        
        if let givenError = error {
            
            delegate?.feedDiscovery(self, corruptHTML: givenError)
            
		} else if let	html = NSString(contentsOfURL: url, encoding: String.Encoding.utf8, error: &error) as? String,
						let head = (html =~ regexHead).items.first {
			
			if let givenTitle = (head =~ regexTitle).items.last {
				
                title = givenTitle.trimWhitespace()
				
				if let imageStringURL = (head =~ regexImage).items.last {
					if imageStringURL.hasPrefix("/") {
						imageURL = URL(string: pageURLString + imageStringURL)
					} else {
						imageURL = URL(string: imageStringURL)
					}
				} else if let imageStringURL = (head =~ regexFavicon).items.last {
					if imageStringURL.hasPrefix("/") {
						imageURL = URL(string: pageURLString + imageStringURL)
					} else {
						imageURL = URL(string: imageStringURL)
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
                
                let errorCode = STFeedDiscoveryError.corruptHTML
                let parseError = NSError(domain: errorCode.domain, code: errorCode.rawValue, userInfo:
                    ["description" : "CORRUPT HTML [\(url.absoluteString)]"])
                
                delegate?.feedDiscovery(self, corruptHTML: parseError)
                
            }
		}
		
    }
    /**
    Detect title of the page.
    */
    fileprivate var regexTitle = "<title>(.*)</title>"
	fileprivate var regexHead = "<head>(\\s|\\S)*</head>"
    /**
    Regular expression to scan from a HTML feed type, optional title and link on array. Examples:
    
    *  ["atom", "Title", "/feeds/main"]
    *  ["rss", "Title", "http://rss.example/feeds/main"]
    */
    fileprivate var regexLink = "<link" + "\\s*" + "rel=\"alternate\"" + "\\s*" + "type=\"application/(?:rss|atom)?\\+xml\"" + "\\s*" + "(?:title=\"[\\w|\\s|!|—|-|/\\&-|;]*\")?" + "\\s*" + "href=\"(?:\\S*)\""// + "[^>]*" + "/?>"
    /**
    Detect iOS image from HTML tag
    */
    fileprivate var regexImage = "<link\\s*rel=\"apple-touch-icon-?.*?\"\\s*href=\"(.*)\"\\s*/?>"
	fileprivate var regexFavicon = "<link\\s*rel=\"(?:.*)?icon\"\\s*\\s*href=\"(.*)\"\\s*/?>"
}
